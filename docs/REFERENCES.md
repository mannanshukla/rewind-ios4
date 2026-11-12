# Rewind reference audit

Research date: 2026-11-10. The first implementation incorrectly treated four devices as color themes. This revision separates the physical shell, native LCD canvas, wheel hit regions, and monochrome/color rendering.

## Physical references

Apple's [Identify your iPod model](https://support.apple.com/en-us/103823) supplies the front-facing product photographs in `docs/reference`. The app now draws the wheels with vector paths, using the photographs to measure the rings, center buttons and printed controls. A live full-width LCD sits above the wheel. The iPod touch supplies the physical enclosure; there is no second device bezel. The front photographs remain research references, not enlarged runtime wheel textures. The LCD keeps its native aspect ratio and fills roughly the upper half. The remaining space holds a comfortably sized wheel on a matching material. Full-device physical proportions are deliberately not preserved, per the user’s updated direction.

| Skin | Reference | Native LCD | Important differences |
| --- | --- | --- | --- |
| Nano | Black 3rd generation, 2007 | 320×240 | Squat body, compact black click wheel, 4:3 screen, split color menus |
| Original | Early white scroll-wheel iPod | 160×128 | Separate outer transport buttons, center select, inner scrolling wheel, monochrome full-width lists |
| Mini | Blue 1st generation, 2004 | 138×110 | Tall aluminum body, gray wheel labels, smaller monochrome canvas |
| Classic | Silver 6th generation family | 320×240 | Taller metal body, white click wheel, larger color display |

Apple reuses `ipod-2nd-gen.png` in its first-generation section and `ipod-6th-classic-gen.png` across Classic revisions. These are useful frontal references, but do not establish generation-specific side/top details. Rewind does not claim to recreate those unseen details.

Source images:
- https://cdsassets.apple.com/live/7WUAS350/images/ipod/ipod-nano/ipod-nano-3rd-gen.png
- https://cdsassets.apple.com/live/7WUAS350/images/ipod/ipod-classic/ipod-mini-1st-gen.png
- https://cdsassets.apple.com/live/7WUAS350/images/ipod/ipod-classic/ipod-6th-classic-gen.png
- https://cdsassets.apple.com/live/7WUAS350/images/ipod/ipod-classic/ipod-2nd-gen.png

Primary specifications:
- [Apple Presents iPod, 2001](https://www.apple.com/newsroom/2001/10/23Apple-Presents-iPod/): monochrome display, scroll wheel and acceleration.
- [Apple Introduces iPod mini, 2004](https://www.apple.com/newsroom/2004/01/06Apple-Introduces-iPod-mini/): first-generation colors, aluminum body and integrated Click Wheel.
- [Mini specifications](https://support.apple.com/en-jo/112317): 138×110 LCD, 3.6×2-inch body.
- [Apple Introduces All New iPod nano, 2007](https://www.apple.com/newsroom/2007/09/05Apple-Introduces-All-New-iPod-nano/): 320×240, 2-inch LCD, Cover Flow.

## Interface references

Period photographs (reference only, not bundled as fake live UI):
- [World of Apple, 2007 Nano review](https://archive.worldofapple.com/review-3g-ipodnano/)
- [Music menu photograph](https://archive.worldofapple.com/media/images/ipodnano_3g_red_005.jpg)
- [Now Playing photograph](https://archive.worldofapple.com/media/images/ipodnano_3g_red_008.jpg)
- [The Register, September 2007](https://www.theregister.com/on-prem/2007/09/28/apple-ipod-nano-third-generation/365717)
- [ITmedia hands-on, September 2007](https://www.itmedia.co.jp/news/article/0709/10/1070910016/2): split menu artwork, perspective/reflection on Now Playing, center-button mode sequence.

Observed color interface: left menu/right artwork at the top levels; full-width detailed song lists; gray title strip; blue selection; small disclosure arrows; Now Playing art on the left, metadata on the right, elapsed/remaining time at the bottom. Mono menus use centered titles, a single divider, solid inverse selection, one-line rows, and black/blue-gray battery/play symbols without a color progress control.

The monochrome font is the Chicago reconstruction from [nikdog/chicago-font](https://github.com/nikdog/chicago-font), `Chicago v0.5.5.ttf`, PostScript name `Chicago`. It is closer than Courier, but is not asserted to be a byte-identical extraction of iPod firmware. Apple/Susan Kare are credited for the original design. Color menus explicitly use Helvetica Bold, matching the later Nano 3 / Classic interface rather than applying the older color iPods’ Podium Sans design. Exact firmware rasterization is not claimed.

## Navigation and motion

Forward navigation pushes the LCD content from the right; Menu reverses the direction. The hardware remains stationary. Selection changes, settings toggles, playback notifications, and progress ticks do not initiate a navigation animation. Leaving the app cancels the transition. Animation uses a stable key so repeated input replaces the visual transition instead of accumulating retained snapshots or delayed completion callbacks.

The 220 ms ease-in/ease-out duration is an implementation tuning value, **not a measured firmware timing**. Still photos establish layout but cannot prove transition cadence. Compare against original-device footage before calling motion exact. Cover Flow is implemented on Nano 3 and Classic with perspective covers, reflections, wheel/skip-button browsing, album selection and the real music queue. Artwork panning and the full center-button ratings/shuffle/lyrics sequence remain fidelity gaps. Wheel sensitivity intentionally differs from the first prototype: 0.32 radians per step, no speed multiplier (about 20 items per turn).

## iPhone OS 1 app icon

The icon is a 57×57 crop of the original orange/yellow iPod icon in the archived iPhone OS 1 home screen, not a generated reinterpretation. The 114×114 variant is a nearest-neighbor enlargement because the source is pre-Retina. Rounded transparency removes surrounding dock pixels; `UIPrerenderedIcon` prevents double gloss.

- [Screenshot provenance](https://commons.wikimedia.org/wiki/File:IPhoneOS1-screenshot.png)
- [Source PNG](https://upload.wikimedia.org/wikipedia/commons/b/bd/IPhoneOS1-screenshot.png)
- [Independent OS 1 screenshot archive](https://941archive.com/os/iPhone%20OS/1/iPhone%20%281st%20generation%29)

Original artwork is credited to Apple. The Commons listing identifies CC BY-SA 4.0; retain that attribution and source provenance. The crop and scale are the modifications. Do not describe these assets as original Rewind artwork or imply Apple endorsement.

Historical shell crops are retained only as references. Regenerate reference crops and the icon with `swift res/extract-reference-assets.swift` from the repository root.

## Colors and Cover Flow

- [Apple’s 2007 Classic announcement](https://www.apple.com/newsroom/2007/09/05Apple-Introduces-New-iPod-classic/) confirms Cover Flow and silver/black finishes.
- [Apple’s Classic guide](https://cdsassets.apple.com/live/6GJYWVAV/user/ma630_ipod_classic_120gb_en.pdf), page 7, documents wheel/Previous/Next album browsing, Center to open, then song selection.
- Nano offers black, silver, blue, green, red, and [pink added in January 2008](https://www.apple.com/newsroom/2008/01/22Apple-Adds-Pink-to-the-iPod-nano-Lineup/).
- First-generation Mini offers silver, blue, green, pink and gold. Its wheel labels remain gray; colored labels belong to the second generation.
- Choices are saved separately for each skin. Original remains white.

Vector wheel previews can be rendered from the production drawing method on macOS with `python3 tools/preview-wheels.py`. These are drawing checks, not substitute device screenshots.
