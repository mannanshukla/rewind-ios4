# Rewind

A native iOS 4.3+ music-library player with Nano 3rd generation, Original, Mini, and Classic skins. Uses `MPMusicPlayerController.iPodMusicPlayer`: playback and queue are shared with the built-in Music app. No separate decoder, imported library, server, or account.

The default is Nano. Settings → Skins changes the vector wheel and native LCD styling. The LCD fills the upper half, using the iPod touch as its enclosure. Settings → Color saves a separate historical finish for each color-capable model. Nano uses the short 2007 body proportions and split menus; song lists are full width. Forward/back navigation slides within the LCD. See docs/REFERENCES.md for original UI references and remaining fidelity limits. Spin the wheel to scroll; center selects; Menu goes back. Play/Pause and Previous/Next work from every screen. In Now Playing, spin to adjust volume; press center to toggle seeking. Direct screen taps also work in the color skins; monochrome skins use the wheel. Nano and Classic offer Music → Cover Flow: browse real albums with the wheel or skip buttons, then press center to open one. Settings offers clicker sounds, shuffle, and repeat. Skin and clicker choices are saved locally.

The app reads the existing music library. It does not delete or modify songs, playlists, or other apps' databases. Playing a selection replaces the shared system playback queue.

Build with `./build.sh`, a local iPhoneOS 4.3 SDK, clang, and ldid. Set IPOD_SDK to override the SDK path. Output: build/Rewind.ipa. Requires a device capable of installing ad-hoc signed legacy apps. The SDK is not distributed.

Wheel math checks: `clang tests/wheel.c -o build/wheel-tests && build/wheel-tests`.

Memory: the body is two Core Animation layers rather than a full-screen bitmap. The wheel is drawn once per skin and color; a press shows a small shape layer. Artwork is fetched at display size and only when the song changes. Cover Flow keeps at most 11 recent covers, and it releases them and the album list when you leave. One second after the app leaves the screen, it releases artwork, covers, marquee strips and the drawn wheel. They are rebuilt on return. A LowMemory report from 2026-11-11 showed version 0.2.0 at about 19 MB resident. No new on-device measurement yet; no Instruments leak audit.

Motion: color marquees are pre-drawn strips moved by Core Animation at display rate, with no timer. Monochrome marquees step one LCD pixel per tick at 20 Hz, only while text overflows. Menu slides animate the live LCD against one snapshot of the old screen, in the same run-loop turn, so the new screen never flashes first. The progress clock ticks at 2 Hz.

Long selected titles and Now Playing metadata pause, then scroll. Lists longer than the screen show the period scroll bar. Now Playing uses an iPod-style bar: a diamond while seeking, speakers while setting volume. Cover Flow is on black, as on the classic and nano 3G. Menu transitions slide within the LCD while the wheel stays fixed. See `docs/DEVICE_QA.md` for physical-device checks and fidelity limits.
