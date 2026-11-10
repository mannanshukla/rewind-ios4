# Rewind

A native iOS 4.3+ music-library player with Nano 3rd generation, Original, Mini, and Classic skins. Uses `MPMusicPlayerController.iPodMusicPlayer`: playback and queue are shared with the built-in Music app. No separate decoder, imported library, server, or account.

The default is Nano. Settings → Skins changes the physical shell and screen styling. Nano uses the short 2007 body proportions and split menus; song lists are full width. See docs/REFERENCES.md for original UI references and remaining fidelity limits. Spin the wheel to scroll; center selects; Menu goes back. Play/Pause and Previous/Next work from every screen. In Now Playing, spin to adjust volume; press center to toggle seeking. Direct screen taps also work. Settings offers clicker sounds, shuffle, and repeat. Skin and clicker choices are saved locally.

The app reads the existing music library. It does not delete or modify songs, playlists, or other apps' databases. Playing a selection replaces the shared system playback queue.

Build with `./build.sh`, a local iPhoneOS 4.3 SDK, clang, and ldid. Set IPOD_SDK to override the SDK path. Output: build/Rewind.ipa. Requires a device capable of installing ad-hoc signed legacy apps. The SDK is not distributed.

Wheel math checks: `clang tests/wheel.c -o build/wheel-tests && build/wheel-tests`.

Artwork thumbnails are requested at display size. The progress timer runs only while the app is active; native playback continues independently. Notification observers and owned objects are released on teardown. No claim of an Instruments memory-leak audit.
