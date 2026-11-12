# Device checks — 2026-11-10

Rewind 0.2.0 build 5 installed as an upgrade on iPod touch 4, iOS 5.1.1.

Observed on device through iPod Mirror:
- Original, Mini, Nano 3 and Classic each render their own wheel and display style.
- Original modest clockwise wheel turn advances three rows; Mini small turn advances one row, and reverse returns one row. No release-triggered button action observed after these turns.
- Mini Blue → Gold updates the shell, and returning to Settings shows Color: Gold.
- Classic persisted across an app upgrade; Skins opens with Classic selected. Nano was selected at the end.
- Color menu rows no longer show misleading disclosure arrows.
- Classic Cover Flow advances one album with a small turn, opens the selected album, plays its first song, and restores the same cover after backing out of Now Playing and the song list.
- Nano Cover Flow renders artwork/reflections/labels; Next advances one album.
- Classic Now Playing shows artwork, title, artist, album, elapsed and remaining time without overlapping progress labels in the tested track.
- Menu labels remain inside their content view, allowing UIKit's accessory spacing. Monochrome headings are centered independently of the battery.
- Final skin labels are shortened; skin/color pickers select the saved value on entry.

Checks passed: armv7/iOS 4.3 build, wheel accumulation/jitter tests, Clang static analysis, git diff whitespace check. Mirror's RFB 3.3/3.8 input/frame/cancellation and DES fixture tests also pass.

Limits: navigation and Cover Flow animations are implemented and settled states checked, but exact original-hardware timing has not been measured. Veency captures can show partial-frame tearing during transitions; direct video produced complete lower-resolution frames. This is not an Instruments allocation/leak audit. The Chicago font is a reconstruction, not the original firmware font.

No app uninstall or library/database reset was used.

## Build 6: transitions and long text

Installed as an upgrade. Replaced the generic layer transition with clipped old/new LCD snapshots sliding in opposite directions over 0.24 seconds. Rapid Menu presses return cleanly; overlays are cleared on inactivity and subsequent navigation. Exact original-hardware timing remains unmeasured.

Long labels pause 1.5 seconds, move at 24 logical pixels per second, and loop with a 28px gap. Selected menu rows, monochrome headers/metadata and color Now Playing share the scroll math. Mini selected “Tonight, Again - Demo Version” and Now Playing were observed advancing through the title; Nano Now Playing was observed wrapping from “Version” back to “Tonight”. Short titles remain still. Original and Classic were checked in build 5; the shared build 6 marquee path was physically exercised on Mini and Nano.

Scroll boundary/speed/reset tests and wheel tests pass. Fresh Nano Cover Flow and Now Playing screenshots saved for the website. App data retained.

## 0.3.0 (build 7): memory and motion — not yet checked on device

Built, unit-tested (wheel and scroll math, including uniform one-pixel monochrome steps), and run through Clang static analysis. Reviewed by Codex; its four findings were fixed:
- restore after a purge during an interruption;
- per-session background callbacks;
- snapshots keep marquees where they are shown, and rapid input continues the slide from where it is;
- Cover Flow releases the album list.

To check on device:
- the resident pages of a suspended Rewind in the next LowMemory report (0.2.0: 4808 pages);
- the switcher snapshot is not blank;
- wheel and artwork come back after Home → reopen and after a notification interruption;
- marquee smoothness;
- slide with rapid Menu presses;
- Cover Flow spin.
