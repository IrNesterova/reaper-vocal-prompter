# Vocal Prompter for REAPER

**[Русская версия →](README.ru.md)**

A lyrics teleprompter for recording vocals in REAPER. While you record or play back, it shows the current line in big text, with the next lines underneath — so you never have to look away to another window or a phone.

- Paste lyrics, open a `.txt` / `.lrc` file, or **search online** ([LRCLIB](https://lrclib.net)) — often with ready-made timings
- **Browse an artist's songs**: type only the artist, pick a song from the list, pick a lyrics version
- **Tap timings** to your backing track (Enter / T at the start of each line), then fine-tune by dragging
- Lyrics, song name and timings are **saved inside each project** — open another project and its lyrics load automatically
- Big centered text, adjustable size, **semi-transparent window**, "prompter only" compact mode
- **Russian / English** interface

## Requirements

- REAPER (Windows or macOS)
- [ReaImGui](https://forum.cockos.com/showthread.php?t=250419) 0.9 or newer
- `curl` for online search — built into Windows 10+ and macOS

## Installation

### 1. Install ReaPack (if you don't have the *Extensions* menu)

1. Download ReaPack for your system from [reapack.com](https://reapack.com) (Windows: `reaper_reapack-x64.dll`).
2. In REAPER: **Options → Show REAPER resource path in explorer/finder…**
3. Put the downloaded file into the **UserPlugins** folder and restart REAPER.

### 2. Install ReaImGui

1. **Extensions → ReaPack → Browse packages…**
2. Search for `ReaImGui`, right-click **"ReaImGui: ReaScript binding for Dear ImGui"** (by cfillion) → **Install** → **Apply**.
3. Restart REAPER.

### 3. Add the script

1. Download [`Vocal_Prompter.lua`](Vocal_Prompter.lua).
2. **Actions → Show action list → New action… → Load ReaScript…** and select the file.
3. Optionally assign it a shortcut or a toolbar button.

To update, replace the file with a new version and restart the script.

## Usage

The window has three tabs.

### Lyrics

- **Song** — the song name shown at the top of the prompter. Filled in automatically from search results, LRC `[ar:]`/`[ti:]` tags, or the file name.
- **Lyrics box** — paste plain text or LRC with `[mm:ss.xx]` timings and press **Apply**. Empty lines are skipped. **Open file…** loads `.txt` / `.lrc`.
- **Search online**
  - *Artist + Title* → list of lyrics versions. `[synced]` means timings are included.
  - *Artist only* → the artist's songs (from LRCLIB and the iTunes Search API), alphabetically, with a filter. Click a song → versions → click a version to load it. **← back to songs** returns to the list.

### Sync

- **Song start in project** — where the song begins on the timeline. Use it if the backing track doesn't start at 0, or if downloaded timings are slightly off.
- **Show early by** — how far ahead a line appears (default 0.3 s), so you have time to breathe.
- **TAP** (or **Enter** / **T**) — play the backing track and tap at the start of each line. Click a line in the list to re-tap from it. Drag a time value to fine-tune it; **>** jumps the edit cursor to that line.
- **To markers** — puts every line on the timeline as a project marker.

### Prompter

Shows the song name, a REC indicator and the time; in the middle — the previous line (faint), **the current line** (large), a progress bar to the next line, and two upcoming lines.

**Aa** button or **right-click anywhere** → view settings:

- **Text size** — 4 steps
- **Background opacity** — transparency is visible when the window is undocked
- **Prompter only** — hides the tabs; handy as a small floating window over REAPER while recording

The **RU · EN** button to the right of the tabs switches the interface language.

## Where data is stored

- Lyrics, song name, timings and offset are stored in the project (`.rpp`) via project ExtState. Save the project (Ctrl+S) after loading lyrics.
- Language and view settings are stored globally in REAPER's ExtState.
- Online search sends only the artist/title you typed to `lrclib.net` and `itunes.apple.com`. Temporary files are kept in `<REAPER resource path>/Data/VocalPrompter`.

## Troubleshooting

| Problem | Fix |
|---|---|
| No *Extensions* menu | ReaPack isn't installed — see step 1 |
| "Vocal Prompter needs ReaImGui" | Install ReaImGui (step 2) and restart REAPER |
| Search: "no response" / network error | lrclib.net may be unreachable from your network — check it in a browser; a VPN may help. You can always paste lyrics manually |
| Lines appear too early/late | Adjust **Song start in project** or **Show early by** on the Sync tab |
| Transparency doesn't show | Undock the window (Sync tab → **Undock**) |

## Credits

- Lyrics: [LRCLIB](https://lrclib.net) — free, open lyrics database
- Song lists: [iTunes Search API](https://performance-partners.apple.com/search-api)
- UI: [ReaImGui](https://github.com/cfillion/reaimgui) by cfillion

## License

[MIT](LICENSE)
