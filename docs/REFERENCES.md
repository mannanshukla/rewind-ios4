# Design references

Nano 3rd generation physical reference: the user's supplied Apple product image showing the short 2007 body, large black screen bezel, and compact click wheel. Body width:height is approximately 52:69, preserved rather than stretched to fill the touch screen.

Original 2007 UI photographs consulted (reference only, not bundled artwork):
- https://archive.worldofapple.com/review-3g-ipodnano/
- https://archive.worldofapple.com/media/images/ipodnano_3g_red_005.jpg — Music split menu
- https://archive.worldofapple.com/media/images/ipodnano_3g_red_008.jpg — Now Playing
- https://www.theregister.com/on-prem/2007/09/28/apple-ipod-nano-third-generation/365717 — menu and Cover Flow screenshots

Implemented cues: logical 320×240 color LCD, left-aligned gradient title strip, battery indicator, 50/50 split menus, full-bleed cropped album artwork, glossy blue selection, full-width song lists with artist subtitles, album art plus reflection on Now Playing, elapsed and remaining time around the progress bar. Music-only functionality deliberately omits nonfunctional video/photo/games menu entries.

This is an original UIKit recreation, not original Apple firmware. Original and Mini currently use a bundled-system monochrome font approximation, not an extracted Chicago bitmap font. Cover Flow is not yet implemented.
