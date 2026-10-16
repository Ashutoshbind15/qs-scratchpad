# Quickshell Scratchpads

Persistent scratchpads for pasted thread output and custom notes. Each scratchpad
has a separate editable title at the top, followed by point cards. Click **+**
or press **Ctrl+Shift+N** (or **Ctrl+Enter**) to add a point. **Alt+Up** and **Alt+Down** move between
points. **Alt+Shift+Up** and **Alt+Shift+Down** reorder the current point, and
**Ctrl+Shift+W** removes it (clearing it when it is the only one). The arrow and
**×** buttons do the same. Press **Ctrl+Shift+H** (or click **⇅** at the bottom) to hide
the per-point **↑**/**↓**/**×** and **+** buttons, and **Ctrl+H** (or **Zen**) for zen
mode, which also hides the bottom bar so only the title and points remain;
press it again to bring them back. Both choices are saved. In zen mode, actions whose confirmation
would normally appear on a hidden button (copying, pinning, deleting a note, changing
the text size) show a brief toast at the bottom of the window instead. Each point supports multiline text and Markdown. Editing a point
does not change the title. New notes get an untitled-N title, selected for quick
renaming; press Enter to move from the title into the first point.
A note with both an empty title and empty points is removed when you leave it
or hide the scratchpad.

Press **Super+A** from any application to add a point to **Global**, the permanent
container at the top of the note list. This shortcut was unassigned on this desktop.
It shows and focuses Global even if another note was selected or the scratchpad
was already visible. Selected text is inserted automatically from the Wayland primary selection before
focus changes. With no text selection, the point starts empty. Applications must
support primary selection; the regular clipboard is left untouched. You can also
type or paste into the new point; edits autosave. Repeated
presses reuse an empty last point. Global cannot be renamed, unpinned, or deleted.
Run `./capture` for the same behavior from a terminal.
Selection reads have a 200 ms deadline: an unresponsive application opens an
empty point instead of delaying the shortcut or inserting partial text.

Every container has a **Clear points** button at the bottom. Click it twice within
2.5 seconds to remove its points while retaining its title and container.

Press **F1** or **Ctrl+/** (or click **?** at the bottom) to list every shortcut.
Like Omarchy's keybindings menu, type to fuzzy-filter by action, key, or initials
(`ctrl shift c`, `mpd`), use Up/Down to pick, and press Enter to run it. Escape
clears the search, then closes the list. Shortcuts are grouped into Notes, Points,
Window, and Anywhere (system-wide) sections, with paired shortcuts side by side;
they are defined in `Keybinds.js`. Ctrl+key acts on the note and Ctrl+Shift+key
does the same to the current point: **Ctrl+N**/**Ctrl+Shift+N** create, and
**Ctrl+W**/**Ctrl+Shift+W** delete. Only **Super+N** and **Super+A** are system-wide;
every other shortcut works only while the scratchpad window is focused, so it
never overrides another application's keys.

Press **Ctrl+B** (or click **Notes** at the bottom left) to browse your notes: a
full-window list of titles, each followed by the first line of its points, with
the open note selected. Notes are listed from the most recently edited to the
oldest (editing the title or any point counts; just opening a note doesn't), after
Global and pinned notes. Type to filter by title; every word must appear, and
matches keep the same newest-first order. Up/Down move the selection,
Enter opens it, and Escape clears the search, then returns to the note.
The list shows 20 notes per page; **‹**/**›** or PageUp/PageDown turn pages,
and Up/Down continue onto the next or previous page. Click **Scroll** to switch
to infinite scroll, which loads 20 more notes as you reach the end (click
**Pages** to switch back); the choice is saved. **Ctrl+N** creates a note, and
**Ctrl+W** deletes the note you're editing, or the selected one while browsing.
Right-click a note in the list (or press **Ctrl+P**) to pin it, or right-click to
delete it. Pinned notes stay at the top, newest edit first, marked with a dot.
**Ctrl+P** pins the open note, or the selected one while browsing. **F2** selects
the title for renaming (opening the selected note first while browsing), and
**Ctrl+G** jumps to Global. **Clear all** at the bottom of the list removes
every individual note, including pinned ones, and empties Global; click it again to confirm.

Click **Copy** at the bottom right, or press **Ctrl+Shift+C**, to copy all nonblank points as a numbered Markdown
list. Multiline text, nested lists, and code are indented under their point so
agents can distinguish the separate items. The button briefly shows **Copied!**.

Click **Preview** at the bottom right or press **Ctrl+Shift+M** to view each point as Markdown;
click **Edit** or use the same shortcut to return to the source. The preview
supports headings, lists, links, quotes, fenced code, tables, and task lists
using Qt's built-in Markdown renderer, with no additional dependencies. Preview
text can be selected and copied, and links open in your default application.
Fenced code blocks have a separate panel, a language label, and a **Copy**
button. Long code lines scroll horizontally while keeping their indentation.
Code fences with common language labels (such as `js`, `ts`, `python`, `bash`,
`json`, `qml`, `rust`, and `yaml`) get basic highlighting for strings, comments,
numbers, keywords, and literals. Other languages remain plain text.
Points are always saved as the original Markdown. New notes open in edit mode.

Press **Super+N** (or run `./toggle`) to show it; press it again, or Escape, to hide it.
If it is open on another workspace, Super+N brings it to your current workspace
and focuses the editor. **Super+Arrow** moves focus into and out of the scratchpad
like any other window. Hyprland's directional focus doesn't cross between floating and
tiled windows, so `omarchy.lua` replaces Omarchy's Super+Arrow bindings with
a version that includes the scratchpad. It behaves exactly like the default
when the scratchpad isn't on the current workspace. Edits autosave after 300 ms and on Escape.

Press **Ctrl+=** / **Ctrl+-** to make all text larger or smaller (10–32 px point
text, 17 px by default); **Ctrl+0** restores the default. Buttons and rows scale
with the text, and the size is saved with your notes as `fontSize`.

The UI uses square corners, thin borders, 4 px outer padding, and compact point
cards and controls. Markdown previews are created only on first use and retained
for reuse. Notes load asynchronously so disk reads do not block window creation.

Toggling is instant: the window stays mapped and is parked on the silent
`special:quickshell-scratchpad` workspace while hidden, and the toggle is a Lua
function that runs inside Hyprland, so no process starts and no open animation
plays. Quickshell preloads Qt and the active note at login without showing a
window or taking focus. The first shortcut creates its surface; subsequent
toggles only move the mapped window. Super+A sends capture directly to the running
instance and only runs startup/recovery if needed. After an application exit,
the next shortcut restarts it. A manual cold launch still includes Qt initialization.
Closing the window with the window manager keeps the process running; the next
shortcut resets Quickshell's visibility state and remaps it without restarting.
Run `./toggle prewarm` to preload without showing the window in an existing session.
The window floats on the right at 25% monitor width and 75% monitor height,
with 32 logical pixels of space on the right and 48 below it.

Notes live outside Git at `~/.local/share/quickshell-scratchpad/scratchpads.json`
(or under `$XDG_DATA_HOME`). The original `scratchpad.txt` is imported into the
first scratchpad on first launch and kept as a backup. The active scratchpad is
restored on launch. Existing notes automatically load as one point with their
original text intact. Saves use version 3 of the JSON format, storing an independent title in `name`
and a `points` array per scratchpad, plus the note list's `browseMode` (`pages` or `scroll`), the text `fontSize`, and the `pointControls` and `zen` toggles. Each scratchpad records its last edit as `updated` (milliseconds since the epoch); notes saved before this field existed count as oldest and keep their previous order. The permanent container has `global: true`; older stores gain an empty Global without changing existing note contents. Version 1 and 2 notes keep all original
point text when loaded, with their existing first-line title as the initial title. Requires Quickshell, Qt Quick Controls, Python 3, Hyprland
(Lua config), and flock.

The binding and window rule live in `omarchy.lua`, which
`~/.config/hypr/hyprland.lua` loads with
`dofile("/home/ash/projects/quickshell-scratchpad/omarchy.lua")`.
T3 integration is future work; for now copy and paste into the editor.

The scratchpad automatically follows the active Omarchy theme, including light
themes and code highlighting. Palette changes are picked up within two seconds,
without restarting. It reads `~/.local/state/omarchy/current/theme/colors.toml`
(with support for the older `~/.config/omarchy/current/theme` location) and falls
back to built-in colors when no palette is available. Set `SCRATCHPAD_THEME_FILE`
to use a different palette file. No Omarchy configuration changes are required.

Run the Markdown, highlighting, migration, export, and note-search checks with
`node --test tests/*.test.cjs`. Run `python3 tests/qml-smoke.py` for an isolated,
offscreen QML check of editing, reordering, preview, switching, browsing, pinning, and
persistence (requires Quickshell). Run `python3 tests/capture.test.py` to check
selection capture and the empty-selection fallback without touching the clipboard.
Run `python3 tests/toggle.test.py` for isolated preload and startup recovery checks.
Run `python3 tests/wayland-reopen.py` inside Hyprland to check real window mapping
after compositor closes, including capture and persistence without restarting.
It briefly opens a test window and uses isolated notes. Offscreen tests do not
exercise this native close/reopen behavior.
