# python3 tests/test_scrobble.py
import importlib.util, os, unittest
spec = importlib.util.spec_from_file_location("scrobble", os.path.join(os.path.dirname(__file__), "..", "tools", "scrobble.py"))
s = importlib.util.module_from_spec(spec); spec.loader.exec_module(s)
NOW = 2_000_000_000

def item(recent, played, duration=200, music=True):
    return {"track": "T", "artist": "A", "album": "", "album_artist": "", "duration": duration,
            "music": music, "count": recent, "recent": recent, "played": played}

def logged(pid, ts):
    return {"ts": ts, "pid": pid, "artist": "A", "track": "T", "album": "", "album_artist": "", "duration": 200, "source": "rewind"}

class Plan(unittest.TestCase):
    def test_library_only(self):
        plays, _, _ = s.plan([], {1: item(2, NOW - 100)}, {}, NOW)
        self.assertEqual([p["ts"] for p in plays], [NOW - 100 - 200 - 202, NOW - 300])
        self.assertEqual([p["source"] for p in plays], ["estimated", "library"])

    def test_rewind_play_not_doubled(self):
        plays, _, _ = s.plan([logged(1, NOW - 300)], {1: item(1, NOW - 100)}, {}, NOW)
        self.assertEqual([(p["ts"], p["source"]) for p in plays], [(NOW - 300, "rewind")])

    def test_rewind_covers_latest_play_only(self):
        plays, _, _ = s.plan([logged(1, NOW - 300)], {1: item(2, NOW - 100)}, {}, NOW)
        self.assertEqual([p["source"] for p in plays], ["estimated", "rewind"])

    def test_snapshot_delta_and_sync_reset(self):
        state = {"snapshot": {"1": {"recent": 3}, "2": {"recent": 5}}, "snapshot_time": NOW - 1000}
        lib = {1: item(4, NOW - 50), 2: item(1, NOW - 500)}   # 2 was reset by an iTunes sync
        plays, snap, _ = s.plan([], lib, state, NOW)
        self.assertEqual(sorted(p["pid"] for p in plays), [1, 1, 1, 1, 2])   # a sync resets every counter
        self.assertEqual(snap["1"]["recent"], 4)

    def test_already_sent_and_filters(self):
        state = {"submitted": ["1:%d" % (NOW - 300)]}
        lib = {2: item(1, NOW - 100, music=False), 3: item(1, NOW - 100, duration=20), 4: item(1, NOW - 20 * 86400)}
        plays, _, notes = s.plan([logged(1, NOW - 300), logged(5, NOW - 15 * 86400)], lib, state, NOW)
        self.assertEqual(plays, [])
        self.assertEqual(len(notes), 1)   # the 15-day-old Rewind play

    def test_logged_play_still_playing_does_not_cancel_a_finished_one(self):
        # A finished, unobserved play (ended NOW-500), then a logged play started at NOW-100, still playing.
        plays, _, _ = s.plan([logged(1, NOW - 100)], {1: item(1, NOW - 500)}, {}, NOW)
        self.assertEqual(sorted(p["source"] for p in plays), ["library", "rewind"])

    def test_logged_play_after_the_newest_library_play_does_not_cancel_it(self):
        # Library play ended at NOW-1500; a logged play started NOW-1400 and was paused (never finished).
        plays, _, _ = s.plan([logged(1, NOW - 1400)], {1: item(1, NOW - 1500)}, {}, NOW)
        self.assertEqual(sorted(p["source"] for p in plays), ["library", "rewind"])

    def test_sync_reset_that_climbs_back(self):
        state = {"snapshot": {"1": {"recent": 3}}, "snapshot_time": NOW - 5000, "sync_marker": "10/1"}
        plays, _, _ = s.plan([], {1: item(3, NOW - 100)}, state, NOW, marker="11/1")
        self.assertEqual(len(plays), 3)
        plays, _, _ = s.plan([], {1: item(3, NOW - 100)}, state, NOW, marker="10/1")
        self.assertEqual(plays, [])

    def test_pending_kept_with_original_times(self):
        old = dict(logged(9, NOW - 1000), source="estimated")
        state = {"pending": [old], "snapshot": {"9": {"recent": 2}}, "snapshot_time": NOW - 900, "sync_marker": "m"}
        plays, _, _ = s.plan([], {9: item(2, NOW - 50)}, state, NOW, marker="m")
        self.assertEqual([(p["ts"], p["source"]) for p in plays], [(NOW - 1000, "estimated")])

    def test_log_parsing(self):
        import tempfile
        with tempfile.NamedTemporaryFile("w", delete=False, suffix=".tsv") as f:
            f.write("1\t100\t-5\tArtist\tTitle\tAlbum\t\t180\nbroken line\n2\tfuture\tformat\n")
        self.assertEqual(s.read_log(f.name), [{"ts": 100, "pid": -5, "artist": "Artist", "track": "Title",
                                               "album": "Album", "album_artist": "", "duration": 180, "source": "rewind"}])

unittest.main()
