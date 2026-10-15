# Quickshell Scratchpads

Persistent scratchpads for pasted thread output and custom notes. Each scratchpad
has a separate editable title at the top, followed by point cards. Click **+**
to add a point; use the arrows to reorder or **×** to remove one (clearing the
last point). Each point supports multiline text and Markdown. Editing a point
does not change the title. New notes get an untitled-N title, selected for quick
renaming; press Enter to move from the title into the first point.
A note with both an empty title and empty points is removed when you leave it
or hide the scratchpad. Sidebar titles have no hover tooltips.

Press **Super+A** from any application to add a point to **Global**, the permanent
container at the top of the sidebar. This shortcut was unassigned on this desktop.
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

Press **Ctrl+B** while the scratchpad has focus to hide or show the sidebar,
**Ctrl+N** to create a note, or **Ctrl+W** to delete the note you're editing.
Right-click a note in the sidebar to pin it or delete it. Pinned notes stay at
the top, marked with a dot. **Clear all** at the bottom of the sidebar removes
every individual note, including pinned ones, and empties Global; click it again to confirm.

Click **Copy** at the bottom right to copy all nonblank points as a numbered Markdown
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
and focuses the editor. Edits autosave after 300 ms and on Escape.

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
Run `./toggle prewarm` to preload without showing the window in an existing session.
The window floats on the right at 25% monitor width and 75% monitor height,
with 32 logical pixels of space on the right and 48 below it.

Notes live outside Git at `~/.local/share/quickshell-scratchpad/scratchpads.json`
(or under `$XDG_DATA_HOME`). The original `scratchpad.txt` is imported into the
first scratchpad on first launch and kept as a backup. The active scratchpad is
restored on launch. Existing notes automatically load as one point with their
original text intact. Saves use version 3 of the JSON format, storing an independent title in `name`
and a `points` array per scratchpad. The permanent container has `global: true`; older stores gain an empty Global without changing existing note contents. Version 1 and 2 notes keep all original
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

Run the Markdown, highlighting, migration, and export checks with
`node --test tests/*.test.cjs`. Run `python3 tests/qml-smoke.py` for an isolated,
offscreen QML check of editing, reordering, preview, switching, pinning, and
persistence (requires Quickshell). Run `python3 tests/capture.test.py` to check
selection capture and the empty-selection fallback without touching the clipboard.
Run `python3 tests/toggle.test.py` for isolated preload and startup recovery checks.
