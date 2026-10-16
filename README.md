# Quickshell Scratchpad

A fast, keyboard-driven notes scratchpad that floats on the right side of your
screen. Press **Super+N** to show or hide it. Press **Super+A** in any app to
drop the text you've selected into it. Notes are made of separate **points**
(Markdown cards), and one shortcut copies them all as a clean numbered list
you can paste into an AI agent or a chat.

> [!IMPORTANT]
> **Who this is for:** people running **[Omarchy](https://omarchy.org)** on
> **Hyprland with the Lua config** (`~/.config/hypr/hyprland.lua`). It relies
> on Omarchy's Lua helpers (`o.bind`, `o.window`, `o.exec_on_start`), on
> Hyprland's `hl.*` Lua API, and on Omarchy's theme files. It won't work as-is
> on other compositors, on the older `hyprland.conf` config, or on Hyprland
> without Omarchy.

## Contents

- [Requirements](#requirements)
- [Install](#install)
- [Quick tour](#quick-tour)
- [Features](#features)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [Where your notes live](#where-your-notes-live)
- [Theme](#theme)
- [How it works](#how-it-works)
- [Development](#development)
- [Troubleshooting](#troubleshooting)

## Requirements

**Environment:** a Wayland session running Hyprland, set up by Omarchy and
using the Lua config.

| Dependency | Used for | Arch package |
| --- | --- | --- |
| [Quickshell](https://quickshell.org) (0.3+) with Qt 6 Quick Controls | The window and UI | `quickshell` |
| Hyprland with the Lua config, plus Omarchy | Shortcuts, window rule, show/hide | (comes with Omarchy) |
| `wl-paste` | Reading your selection for **Super+A** | `wl-clipboard` |
| `flock` | Making sure only one copy starts | `util-linux` |
| Python 3 | Creating the notes file on first launch | `python` |
| Node.js 18+ | Unit tests only | `nodejs` |

`timeout`, `pkill` and `hyprctl` come with a standard Omarchy install.

**Optional environment variables:**

| Variable | Effect |
| --- | --- |
| `XDG_DATA_HOME` | Where the notes are stored (default `~/.local/share`) |
| `XDG_RUNTIME_DIR` | Where the startup lock file goes (default `/tmp`) |
| `SCRATCHPAD_THEME_FILE` | Use a different `colors.toml` instead of the active Omarchy theme |

## Install

1. **Clone the repo** anywhere you like:

   ```bash
   git clone <repo-url> ~/projects/quickshell-scratchpad
   ```

2. **Load it from your Hyprland config.** Add this line to the end of
   `~/.config/hypr/hyprland.lua`, using the absolute path to your clone:

   ```lua
   -- Quickshell notes scratchpad: shortcuts and window rule.
   dofile(os.getenv("HOME") .. "/projects/quickshell-scratchpad/omarchy.lua")
   ```

   `omarchy.lua` works out the repo path from its own location, so nothing
   else needs editing.

3. **Reload Hyprland** with `hyprctl reload`, or log out and back in. From now
   on the scratchpad loads in the background when you log in.

4. **Press Super+N.**

> [!NOTE]
> The setup binds **Super+N** and **Super+A** and **replaces Omarchy's
> Super+Arrow** focus bindings with versions that can also reach the floating
> scratchpad. When the scratchpad isn't on the current workspace, Super+Arrow
> works exactly as before. If you already use Super+N or Super+A for something
> else, change the `o.bind` lines near the bottom of `omarchy.lua`.

## Quick tour

| Do this | Press |
| --- | --- |
| Show / hide the scratchpad | **Super+N** (or **Escape** to hide) |
| Send the selected text from any app to **Global** | **Super+A** |
| New note | **Ctrl+N** |
| New point in this note | **Ctrl+Shift+N** or **Ctrl+Enter** |
| Browse and search notes | **Ctrl+B** |
| Copy every point as a numbered list | **Ctrl+Shift+C** |
| Preview as Markdown | **Ctrl+Shift+M** |
| See every shortcut | **F1** or **Ctrl+/** |

Everything saves automatically.

## Features

### Notes and points

- Every note has an editable **title** and a list of **point cards**. Each
  point holds multiline text and Markdown. Editing a point never changes the
  title.
- New notes are named `untitled-N`, with the title selected so you can rename
  it straight away. Press **Enter** to move from the title to the first point.
- Use **Alt+Up** / **Alt+Down** to move between points and **Alt+Shift+Up** /
  **Alt+Shift+Down** to reorder them. **Ctrl+Shift+W** removes a point, or
  clears it if it's the only one. The **↑ ↓ ×** buttons on each card do the
  same.
- **Clear points** (bottom bar, or **Ctrl+Shift+Backspace**) empties a note and
  keeps its title. Press it twice within 2.5 seconds to confirm.
- A note with an empty title and no text is removed when you leave it or hide
  the scratchpad, so blank notes don't pile up.

### Global and Super+A capture

**Global** is a permanent note that always sits at the top of the list. Press
**Super+A** in any application:

- If you have text selected, it's added to Global as a new point. The text is
  read from the Wayland *primary selection*, so your clipboard is never
  touched. The app needs to support primary selection.
- With nothing selected, you get an empty point to type or paste into.
- Pressing it repeatedly reuses an empty last point instead of stacking blank
  ones.
- It always shows Global, even if another note was open or the scratchpad was
  already visible.
- If an app doesn't answer within 200 ms, you get an empty point. The shortcut
  never stalls and never inserts half the text.

You can't rename, unpin or delete Global. Run `./capture` from a terminal to do
the same thing as Super+A.

### Browsing notes

Press **Ctrl+B** (or click **Notes**) to open a full-window list of your notes.
Each row shows the title and the first line of the note's points.

- **Order:** Global first, then pinned notes, then everything else. Within
  each group the most recently edited note comes first. Just opening a note
  doesn't count as an edit.
- **Search:** type to filter by title. Every word must match, and results keep
  the newest-first order.
- **Navigate:** **Up/Down** to select, **Enter** to open, **Escape** to clear
  the search and then return to your note.
- **Pages or scroll:** 20 notes per page (**‹ ›** or **PageUp/PageDown**), or
  click **Scroll** for infinite scroll. Your choice is remembered.
- **Pin / delete:** right-click a row, or use **Ctrl+P** / **Ctrl+W** on the
  selected row. Pinned notes show a dot.
- **Rename:** **F2** opens the selected note and selects its title.
- **Clear all** removes every note, pinned ones included, and empties Global.
  Click it twice to confirm.

### Copy for agents

**Copy** (or **Ctrl+Shift+C**) puts every nonblank point on the clipboard as a
numbered Markdown list. Multiline text, nested lists and code blocks are
indented under their number, so an agent reads each point as a separate item.

### Markdown preview

**Preview** (or **Ctrl+Shift+M**) renders every point with Qt's built-in
Markdown support: headings, lists, links, quotes, tables, task lists and fenced
code. Nothing extra needs installing.

- You can select and copy preview text, and links open in your default app.
- Code blocks get their own panel with a language label and a **Copy** button.
  Long lines scroll sideways and keep their indentation.
- Basic syntax highlighting for common languages: `js`, `ts`, `python`,
  `bash`, `json`, `qml`, `rust`, `yaml`, `go`, `c`/`cpp`, `css` and others.
  Anything else stays plain text.
- Points are always saved as the original Markdown. New notes open in edit mode.

### Layout and focus

| Mode | Shortcut | What it does |
| --- | --- | --- |
| Point buttons | **Ctrl+Shift+H** / **⇅** | Hide the per-point **↑ ↓ ×** and **+** buttons |
| Zen | **Ctrl+H** / **Zen** | Also hide the bottom bar, leaving only the title and points. Actions show a short toast at the bottom instead |
| Short window | **Ctrl+Down** / **Short** | Shrink to 30% of the screen height for quick notes. **Ctrl+Up** restores full height |
| Text size | **Ctrl+=** / **Ctrl+-** / **Ctrl+0** | Text from 10 to 32 px (17 by default). Buttons and rows scale with it |

All four settings are remembered. The window floats on the right, 25% of the
monitor wide and 75% tall. **Super+Arrow** moves focus into and out of it like
any other window.

## Keyboard shortcuts

Shortcuts follow one pattern: **Ctrl+key** acts on the note, and
**Ctrl+Shift+key** does the same to the current point. Only **Super+N** and
**Super+A** work system-wide. The rest only work while the scratchpad is
focused, so they never override another app's keys.

Press **F1** in the app for a searchable version of this list. Type to
fuzzy-filter by action, key or initials (`ctrl shift c`, `mpd`), then press
**Enter** to run the selected entry.

| Section | Action | Keys |
| --- | --- | --- |
| **Notes** | New note | Ctrl+N |
| | Delete note | Ctrl+W |
| | Browse notes | Ctrl+B |
| | Rename note | F2 |
| | Pin or unpin note | Ctrl+P |
| | Open Global | Ctrl+G |
| **Points** | New point | Ctrl+Shift+N, Ctrl+Enter |
| | Delete point | Ctrl+Shift+W |
| | Clear all points (press twice) | Ctrl+Shift+Backspace |
| | Previous / next point | Alt+Up / Alt+Down |
| | Move point up / down | Alt+Shift+Up / Alt+Shift+Down |
| | Copy points for agents | Ctrl+Shift+C |
| | Preview as Markdown | Ctrl+Shift+M |
| **Window** | Hide scratchpad | Escape |
| | Zen mode | Ctrl+H |
| | Short / tall window | Ctrl+Down / Ctrl+Up |
| | Show or hide point buttons | Ctrl+Shift+H |
| | Larger / smaller / default text | Ctrl+= / Ctrl+- / Ctrl+0 |
| | Keyboard shortcuts | F1, Ctrl+/ |
| **Anywhere** | Show or hide scratchpad | Super+N |
| | Capture selection to Global | Super+A |
| | Move focus between windows | Super+Arrow |

All shortcuts are defined in [`Keybinds.js`](Keybinds.js).

## Where your notes live

Notes are kept outside the repo:

```
~/.local/share/quickshell-scratchpad/scratchpads.json
```

(`$XDG_DATA_HOME/quickshell-scratchpad/` if you've set `XDG_DATA_HOME`.) The
folder is created with `700` permissions and the file with `600`. Writes are
atomic, and edits save 300 ms after you stop typing, as well as when you hide
the window.

If there's a `scratchpad.txt` in the same folder on first launch, it's
imported as the first note and kept as a backup. The note you had open is
reopened next time.

<details>
<summary>File format (version 3)</summary>

```jsonc
{
  "version": 3,
  "activeIndex": 0,            // the note that was open
  "browseMode": "pages",       // or "scroll"
  "fontSize": 17,
  "pointControls": true,
  "zen": false,
  "shortWindow": false,
  "pads": [
    {
      "name": "Global",
      "points": ["…"],
      "pinned": true,
      "global": true,          // exactly one note has this
      "updated": 0             // last edit, ms since the epoch
    }
  ]
}
```

Version 1 (a single `text` per note) and version 2 files still load: every
point keeps its text, and the first line becomes the title. Notes without
`updated` count as the oldest and keep their order. A file without a Global
note gets an empty one added. If the file can't be parsed, the scratchpad shows
an error and won't overwrite it. Parsing and saving live in
[`NoteStore.js`](NoteStore.js).

</details>

## Theme

The scratchpad follows your active Omarchy theme, light themes and code
highlighting included. A theme change shows up within two seconds, with no
restart. It reads:

1. `$SCRATCHPAD_THEME_FILE`, if set
2. `~/.local/state/omarchy/current/theme/colors.toml`
3. `~/.config/omarchy/current/theme/colors.toml` (older Omarchy versions)

If none of these exist, it uses built-in colors. Selected text is drawn in the
background color on the theme's accent, because Omarchy's `selection` color is
too close to the card color to see. You don't need to change anything in
Omarchy.

## How it works

Showing and hiding is instant because no process starts:

- At login, `omarchy.lua` runs `./toggle prewarm`. This starts Quickshell,
  loads Qt and your notes, and doesn't show a window or take focus.
- While hidden, the window stays mapped on the silent
  `special:quickshell-scratchpad` workspace. **Super+N** is a Lua function
  inside Hyprland that just moves it to your workspace and focuses it, with no
  open animation.
- **Super+A** sends the capture straight to the running instance over
  Quickshell IPC. It only falls back to starting or recovering the instance
  when that's needed.
- If the window was closed through the window manager, the next shortcut
  remaps it without restarting. If the process exited or hung, the next
  shortcut restarts it.

| File | Role |
| --- | --- |
| `shell.qml` | The app: state, editing, browser, shortcuts, IPC |
| `NoteStore.js` | Reading, migrating and writing the notes file |
| `ScratchpadPoints.js` | Point helpers and the "copy for agents" format |
| `NoteList.js` | Browser ordering, search and paging |
| `Keybinds.js` | The shortcut list and its fuzzy search |
| `MarkdownBlocks.js`, `SyntaxHighlight.js` | Preview code blocks and highlighting |
| `ScratchpadTheme.qml` | Omarchy palette loading and derived colors |
| `PointCard.qml`, `MarkdownPreview.qml`, `ShortcutHelp.qml`, `Scratchpad*.qml`, `PointButton.qml` | UI components |
| `omarchy.lua` | Hyprland bindings, window rule, show/hide and layout |
| `toggle` | Show/hide, cold start, crash recovery, `prewarm` |
| `capture` | Super+A: reads the selection and sends it to Global |

## Development

```bash
# Markdown, highlighting, notes file, export, shortcut and note-list logic
node --test tests/*.test.cjs

# Offscreen QML run of editing, reordering, preview, browsing, pinning and saving
# (needs Quickshell; uses a temporary copy and never touches your notes)
python3 tests/qml-smoke.py

# Selection capture and the empty-selection fallback, without touching the clipboard
python3 tests/capture.test.py

# Hidden prewarm and startup recovery
python3 tests/toggle.test.py

# Inside a running Hyprland session: real window mapping after compositor
# closes. Briefly opens a test window with throwaway notes.
python3 tests/wayland-reopen.py
```

The offscreen tests don't cover the native close/reopen behavior. That's what
`wayland-reopen.py` is for.

## Troubleshooting

| Symptom | Try |
| --- | --- |
| Super+N does nothing | Check that `hyprland.lua` loads `omarchy.lua` with an absolute path, then run `hyprctl reload` |
| The window never appears | Run `./toggle start` in a terminal to see the error |
| Super+A adds an empty point | The app doesn't support primary selection, or it took longer than 200 ms to answer. Paste the text instead |
| "Unable to load notes" | The notes file is malformed and has been left untouched. Fix or move it, run `pkill -f 'quickshell -p .*quickshell-scratchpad'`, then press Super+N |
| Colors don't match the theme | Check that `~/.local/state/omarchy/current/theme/colors.toml` exists, or set `SCRATCHPAD_THEME_FILE` |
