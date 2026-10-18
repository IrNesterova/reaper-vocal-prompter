# Changelog

## 1.1.1

- Fixed: the search fields couldn't be cleared — the old title came back and "Search" used it. With `InputTextFlags_EnterReturnsTrue` ReaImGui only returns the edited text on Enter; the fields now update live and Enter is detected separately

## 1.1.0

- **Settings** tab: Dark / Midnight / Light themes, 8 accent colors and a custom color picker, current line in accent color, prompter options, interface language, reset
- "Aa" button renamed to **View**
- Fixed: time and the View button were pushed off the right edge by long song names; long names are now shortened with "…"
- Fixed: accent swatches showed the wrong colors
- Fixed: the floating window stayed a title-bar strip after collapsing and expanding (works around a ReaImGui resize issue by restoring the last size)
- Button rows wrap in narrow windows

## 1.0.0

- Prompter, Sync and Lyrics tabs
- Lyrics from text, `.txt` / `.lrc` files or LRCLIB search; artist-only search lists the artist's songs (LRCLIB + iTunes Search API)
- Tap timings, offset, "show early", lines to markers
- Lyrics, timings and song name stored per project; follows tab switches and File → Open
- Background search without freezing REAPER or flashing a console window
- Russian / English interface, text size, background opacity, prompter-only mode
