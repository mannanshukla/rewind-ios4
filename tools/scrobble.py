#!/usr/bin/env python3
"""Send iPod plays to Last.fm.

Two sources are merged:
  * Documents/scrobbles.tsv, written by Rewind with exact start times for plays it saw.
  * The iPod's MediaLibrary.sqlitedb play counts. They catch plays Rewind missed:
    Music.app, or Rewind suspended in the background. Only the newest play of each
    song has a real time (date_played, when it ended). Earlier plays of the same
    song are placed one track length apart before it and marked "estimated".

Commands:
  auth             one-time Last.fm sign-in (keys come from the macOS Keychain)
  pull             copy the log and the library off the iPod
  plan [--from D]  show what would be sent, change nothing
  submit [--from D] [--dry-run]
  sync [--dry-run] pull, then submit

Keychain items (service names), add each with
  security add-generic-password -a lastfm -s <service> -w
which prompts for the value:
  rewind-lastfm-api-key, rewind-lastfm-api-secret; `auth` adds rewind-lastfm-session.

SSH: the iPod is reached at root@127.0.0.1 -p 2222 (iproxy 2222 22). Set
IPOD_SSH_PASS to use sshpass; IPOD_SSH_HOST / IPOD_SSH_PORT override the target.
Python standard library only.
"""
import argparse, hashlib, json, os, shutil, sqlite3, subprocess, sys, tempfile, time, urllib.parse, urllib.request
from datetime import datetime

STATE_DIR = os.path.expanduser(os.environ.get("REWIND_SCROBBLE_DIR", "~/Library/Application Support/RewindScrobbles"))
STATE = os.path.join(STATE_DIR, "state.json")
API = "https://ws.audioscrobbler.com/2.0/"
MAX_AGE = 14 * 86400 - 3600      # Last.fm refuses scrobbles older than 14 days
CORE_DATA_EPOCH = 978307200      # date_played counts seconds from 2001-01-01
LIBRARY = "/var/mobile/Media/iTunes_Control/iTunes"

# ---------- reading ----------

def read_log(path):
    plays = []
    if not os.path.exists(path):
        return plays
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            p = line.rstrip("\n").split("\t")
            if len(p) != 8 or p[0] != "1":
                continue
            try:
                plays.append({"ts": int(p[1]), "pid": int(p[2]), "artist": p[3], "track": p[4],
                              "album": p[5], "album_artist": p[6], "duration": int(p[7]), "source": "rewind"})
            except ValueError:
                continue
    return plays

def read_library(path):
    """Return (items by persistent ID, sync marker). The marker changes on each iTunes sync."""
    db = sqlite3.connect(path)
    if db.execute("pragma quick_check").fetchone()[0] != "ok":
        sys.exit("the copied library failed SQLite's integrity check; pull again")
    rows = db.execute("""
        select i.item_pid, e.title, coalesce(ia.item_artist,''), coalesce(al.album,''), coalesce(aa.album_artist,''),
               e.total_time_ms, e.media_kind, s.play_count_user, s.play_count_recent, s.date_played
        from item i join item_extra e using(item_pid) join item_stats s using(item_pid)
        left join item_artist ia on ia.item_artist_pid = i.item_artist_pid
        left join album al on al.album_pid = i.album_pid
        left join album_artist aa on aa.album_artist_pid = i.album_artist_pid""").fetchall()
    props = dict(db.execute("select key, value from _MLDatabaseProperties where key in "
                            "('MLSyncClientSyncAnchor', 'MLSyncClientGenerationID')").fetchall())
    db.close()
    marker = "%s/%s" % (props.get("MLSyncClientSyncAnchor"), props.get("MLSyncClientGenerationID"))
    return {r[0]: {"track": r[1], "artist": r[2], "album": r[3], "album_artist": r[4],
                   "duration": int(round((r[5] or 0) / 1000)), "music": r[6] == 1,
                   "count": r[7] or 0, "recent": r[8] or 0,
                   "played": (r[9] + CORE_DATA_EPOCH) if r[9] else 0} for r in rows}, marker

# ---------- planning ----------

def key(play):
    return "%d:%d" % (play["pid"], play["ts"])

def plan(log, library, state, now, marker=None):
    """Return (scrobbles to send, new snapshot, notes).

    Plays left over from an earlier run (state["pending"]) come first, unchanged, so
    a retry never sends a play under a second, re-estimated time."""
    sent = set(state.get("submitted", []))
    pending = state.get("pending", [])
    known = sent | {key(p) for p in pending}
    prev = state.get("snapshot")
    window = state.get("snapshot_time", now - MAX_AGE) if prev else now - MAX_AGE
    # play_count_recent counts plays since the last iTunes sync, and a sync resets it.
    # After a sync, everything now in it is new, even if it climbed back to its old value.
    synced = bool(prev) and (state.get("sync_marker") != marker or any(
        i["recent"] < prev[str(pid)]["recent"] for pid, i in library.items() if str(pid) in prev))
    out = [dict(p) for p in pending] + [dict(p) for p in log if key(p) not in known]
    notes = []
    for pid, item in library.items():
        if not item["music"] or item["duration"] <= 30 or not item["played"]:
            continue
        old = prev.get(str(pid)) if prev and not synced else None
        new = item["recent"] - old["recent"] if old else item["recent"]
        if new <= 0 or item["played"] <= window:
            continue
        # A logged play can be in the library count only if it could have finished by
        # the song's newest library play (date_played). A later one is still playing,
        # or was skipped. Either way it is not in this count.
        logged = [p["ts"] for p in log if p["pid"] == pid and p["ts"] > window - item["duration"]
                  and p["ts"] + 0.9 * item["duration"] <= item["played"] + 5]
        missing = new - len(logged)
        if missing <= 0:
            continue
        span = item["duration"] + 2
        slot, made = 0, 0
        while made < missing and slot < new + len(logged) + 1:
            ts = int(item["played"] - item["duration"] - slot * span)
            slot += 1
            if any(abs(ts - t) < item["duration"] / 2 for t in logged):
                continue      # this play is already in Rewind's log
            out.append({"ts": ts, "pid": pid, "artist": item["artist"], "track": item["track"],
                        "album": item["album"], "album_artist": item["album_artist"],
                        "duration": item["duration"], "source": "library" if slot == 1 else "estimated"})
            made += 1
    kept, seen = [], set()
    for p in out:
        if key(p) in sent or key(p) in seen:
            continue
        if p["ts"] < now - MAX_AGE:
            notes.append("too old for Last.fm (over 14 days): %s - %s" % (p["artist"], p["track"]))
        elif p["ts"] > now + 300 or not p["artist"] or not p["track"]:
            notes.append("skipped (bad time or missing artist/title): %s - %s" % (p["artist"], p["track"]))
        else:
            kept.append(p)
            seen.add(key(p))
    kept.sort(key=lambda p: p["ts"])
    snapshot = {str(pid): {"recent": i["recent"], "count": i["count"]} for pid, i in library.items()}
    return kept, snapshot, notes

def show(plays, notes):
    for p in plays:
        tag = "" if p["source"] == "rewind" else "  [%s]" % p["source"]
        print("%s  %s - %s%s" % (datetime.fromtimestamp(p["ts"]).strftime("%Y-%m-%d %H:%M"), p["artist"], p["track"], tag))
    for n in notes:
        print("note: " + n)
    print("%d to send (%d from Rewind, %d from library counts)" % (
        len(plays), sum(p["source"] == "rewind" for p in plays), sum(p["source"] != "rewind" for p in plays)))

# ---------- state ----------

def load_state():
    try:
        with open(STATE) as f:
            return json.load(f)
    except FileNotFoundError:
        return {}

def save_state(state):
    os.makedirs(STATE_DIR, exist_ok=True)
    tmp = STATE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(state, f)
    os.replace(tmp, STATE)

# ---------- iPod ----------

def ssh_base(tool):
    host, port = os.environ.get("IPOD_SSH_HOST", "root@127.0.0.1"), os.environ.get("IPOD_SSH_PORT", "2222")
    os.makedirs(STATE_DIR, exist_ok=True)
    # The iPod's host key is pinned on first use. After a restore, delete known_hosts.
    opts = ["-o", "KexAlgorithms=+diffie-hellman-group1-sha1,diffie-hellman-group14-sha1",
            "-o", "HostKeyAlgorithms=+ssh-rsa", "-o", "IdentitiesOnly=yes",
            "-o", "Ciphers=+aes128-cbc,3des-cbc", "-o", "MACs=+hmac-sha1", "-o", "LogLevel=ERROR",
            "-o", "StrictHostKeyChecking=accept-new", "-o", "UserKnownHostsFile=\"%s\"" % os.path.join(STATE_DIR, "known_hosts")]
    cmd = [tool] + opts + (["-O", "-P", port] if tool == "scp" else ["-p", port])
    if os.environ.get("IPOD_SSH_PASS"):
        sshpass = shutil.which("sshpass") or os.path.expanduser("~/Legacy-iOS-Kit/bin/macos/sshpass")
        cmd = [sshpass, "-e"] + cmd
    return cmd, host

def ipod_env():
    env = dict(os.environ)
    if "IPOD_SSH_PASS" in env:
        env["SSHPASS"] = env["IPOD_SSH_PASS"]
    return env

def md5(path):
    with open(path, "rb") as f:
        return hashlib.md5(f.read()).hexdigest()

def pull():
    ssh, host = ssh_base("ssh")
    scp, _ = ssh_base("scp")
    env = ipod_env()
    run = lambda command: subprocess.run(ssh + [host, command], env=env, capture_output=True, text=True, check=True).stdout
    found = run('for d in /var/mobile/Applications/*/; do [ -d "$d/Rewind.app" ] && echo "$d"; done; true').split()
    if len(found) != 1:
        sys.exit("expected one Rewind container on the iPod, found %d" % len(found))
    root = os.path.join(STATE_DIR, "pulls")
    os.makedirs(root, exist_ok=True)
    work = tempfile.mkdtemp(prefix=".partial-", dir=root)
    names = ["MediaLibrary.sqlitedb", "MediaLibrary.sqlitedb-wal"]
    hashes = "cd %s && md5sum %s" % (LIBRARY, " ".join(names))
    # The library is live and in WAL mode. Copy the database and its WAL, and keep the
    # copy only if neither file changed while it was being taken.
    for attempt in range(5):
        started = int(time.time())
        before = run(hashes)
        for name in names:
            subprocess.run(scp + ["%s:%s/%s" % (host, LIBRARY, name), work], env=env, check=True)
        after = run(hashes)
        local = "".join("%s  %s\n" % (md5(os.path.join(work, n)), n) for n in names)
        if before == after == local:
            break
        time.sleep(2)
    else:
        shutil.rmtree(work)
        sys.exit("the library kept changing while it was copied; try again when playback is idle")
    log = found[0].rstrip("/") + "/Documents/scrobbles.tsv"
    if run("test -f '%s' && echo yes || echo no" % log).strip() == "yes":
        subprocess.run(scp + ["%s:%s" % (host, log), work], env=env, check=True)
    with open(os.path.join(work, "pulled_at"), "w") as f:
        f.write(str(started))
    dest = os.path.join(root, time.strftime("%Y%m%d-%H%M%S", time.localtime(started)))
    os.rename(work, dest)      # only complete pulls get a real name
    print("pulled into " + dest)
    return dest

def latest_pull():
    root = os.path.join(STATE_DIR, "pulls")
    pulls = sorted(n for n in os.listdir(root) if not n.startswith(".")) if os.path.isdir(root) else []
    if not pulls:
        sys.exit("nothing pulled yet; run `pull` first")
    return os.path.join(root, pulls[-1])

def load_pull(folder):
    with open(os.path.join(folder, "pulled_at")) as f:
        pulled = int(f.read())
    # Open a scratch copy so SQLite can fold in the WAL without touching the pull.
    with tempfile.TemporaryDirectory() as tmp:
        for name in ["MediaLibrary.sqlitedb", "MediaLibrary.sqlitedb-wal"]:
            shutil.copy(os.path.join(folder, name), tmp)
        library, marker = read_library(os.path.join(tmp, "MediaLibrary.sqlitedb"))
    return read_log(os.path.join(folder, "scrobbles.tsv")), library, marker, pulled

# ---------- Last.fm ----------

def keychain(service):
    r = subprocess.run(["security", "find-generic-password", "-a", "lastfm", "-s", service, "-w"], capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None

def call(params, secret, post=True):
    params = dict(params)
    params["api_sig"] = hashlib.md5(("".join(k + params[k] for k in sorted(params)) + secret).encode("utf-8")).hexdigest()
    params["format"] = "json"
    data = urllib.parse.urlencode(params).encode()
    req = urllib.request.Request(API, data=data if post else None, headers={"User-Agent": "RewindScrobbler/1.0"})
    if not post:
        req = urllib.request.Request(API + "?" + data.decode(), headers={"User-Agent": "RewindScrobbler/1.0"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            body = json.load(r)
    except urllib.error.HTTPError as e:
        body = json.load(e)
    if "error" in body:
        raise RuntimeError("Last.fm error %s: %s" % (body["error"], body.get("message")))
    return body

def credentials():
    key, secret = keychain("rewind-lastfm-api-key"), keychain("rewind-lastfm-api-secret")
    if not key or not secret:
        sys.exit("add rewind-lastfm-api-key and rewind-lastfm-api-secret to the Keychain first (see --help)")
    return key, secret

def auth():
    key, secret = credentials()
    token = call({"method": "auth.getToken", "api_key": key}, secret, post=False)["token"]
    print("Open this page, allow access, then press Return:\nhttps://www.last.fm/api/auth/?api_key=%s&token=%s" % (key, token))
    input()
    session = call({"method": "auth.getSession", "api_key": key, "token": token}, secret, post=False)["session"]
    subprocess.run(["security", "add-generic-password", "-U", "-a", "lastfm", "-s", "rewind-lastfm-session", "-w", session["key"]], check=True)
    print("signed in as " + session["name"])

RETRY_LATER = {"4", "5"}   # timestamp too new, daily scrobble limit reached

def send(plays, done):
    """Send in batches of 50. done(finished, retry) runs after each batch."""
    key, secret = credentials()
    sk = keychain("rewind-lastfm-session")
    if not sk:
        sys.exit("run `auth` first")
    for start in range(0, len(plays), 50):
        batch = plays[start:start + 50]
        params = {"method": "track.scrobble", "api_key": key, "sk": sk}
        for i, p in enumerate(batch):
            params["artist[%d]" % i] = p["artist"]
            params["track[%d]" % i] = p["track"]
            params["timestamp[%d]" % i] = str(p["ts"])
            params["duration[%d]" % i] = str(p["duration"])
            params["chosenByUser[%d]" % i] = "1"
            if p["album"]:
                params["album[%d]" % i] = p["album"]
            if p["album_artist"] and p["album_artist"] != p["artist"]:
                params["albumArtist[%d]" % i] = p["album_artist"]
        items = call(params, secret)["scrobbles"]["scrobble"]
        items = items if isinstance(items, list) else [items]
        if len(items) != len(batch):
            raise RuntimeError("Last.fm answered %d of %d scrobbles" % (len(items), len(batch)))
        finished, retry = [], []
        for p, r in zip(batch, items):
            ignored = r.get("ignoredMessage") or {}
            code = str(ignored.get("code", "0"))
            if code in RETRY_LATER:
                retry.append(p)
            elif code != "0":
                print("ignored by Last.fm (%s): %s - %s" % (ignored.get("#text") or code, p["artist"], p["track"]))
            if code not in RETRY_LATER:
                finished.append(p)
        done(finished, retry)

# ---------- main ----------

def submit(folder, dry_run):
    log, library, marker, pulled = load_pull(folder)
    state = load_state()
    if pulled <= state.get("snapshot_time", 0):
        sys.exit("this pull is not newer than the last one used; run `pull` first")
    plays, snapshot, notes = plan(log, library, state, pulled, marker)
    show(plays, notes)
    if dry_run:
        print("dry run: nothing sent, state unchanged")
        return
    # Record the whole plan before sending anything. If sending stops part-way, the
    # rest stays in "pending" with the same times and goes first next run.
    state.update(pending=plays, snapshot=snapshot, snapshot_time=pulled, sync_marker=marker)
    save_state(state)
    counts = {"sent": 0, "later": 0}
    def done(finished, retry):
        gone = {key(p) for p in finished}
        # Keys hold the play's time; past Last.fm's 14 days they can never come back.
        state["submitted"] = sorted(k for k in set(state.get("submitted", [])) | gone
                                    if int(k.split(":")[1]) > pulled - MAX_AGE - 86400)
        state["pending"] = [p for p in state["pending"] if key(p) not in gone]
        save_state(state)
        counts["sent"] += len(finished)
        counts["later"] += len(retry)
    if plays:
        send(plays, done)
    print("sent %d%s" % (counts["sent"], ", %d kept to retry later" % counts["later"] if counts["later"] else ""))

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("auth")
    sub.add_parser("pull")
    for name in ["plan", "submit"]:
        p = sub.add_parser(name)
        p.add_argument("--from", dest="folder")
        if name == "submit":
            p.add_argument("--dry-run", action="store_true")
    sub.add_parser("sync").add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    if a.cmd == "auth":
        auth()
    elif a.cmd == "pull":
        pull()
    elif a.cmd == "plan":
        submit(a.folder or latest_pull(), True)
    elif a.cmd == "submit":
        submit(a.folder or latest_pull(), a.dry_run)
    elif a.cmd == "sync":
        submit(pull(), a.dry_run)

if __name__ == "__main__":
    main()
