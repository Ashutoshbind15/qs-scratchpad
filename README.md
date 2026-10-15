# Quickshell Scratchpads

Persistent scratchpads for pasted thread output and custom notes. The first line
of a note becomes its title in the sidebar. A new note is named untitled-1,
untitled-2, and so on. That name is the first line, and it is selected so
typing replaces it. A note with no text is removed when you leave it or hide
the scratchpad.

Press **Ctrl+B** while the scratchpad has focus to hide or show the sidebar,
**Ctrl+N** to create a note, or **Ctrl+W** to delete the note you're editing.
Right-click a note in the sidebar to pin it or delete it. Pinned notes stay at
the top, marked with a dot. **Clear all** at the bottom of the sidebar removes
every note, including pinned ones; click it again to confirm.

Click **Preview** or press **Ctrl+Shift+M** to view the current note as Markdown;
click **Edit** or use the same shortcut to return to the source. The preview
supports headings, lists, links, quotes, fenced code, tables, and task lists
using Qt's built-in Markdown renderer, with no additional dependencies. Preview
text can be selected and copied, and links open in your default application.
Fenced code blocks have a separate dark panel, a language label, and a **Copy**
button. Long code lines scroll horizontally while keeping their indentation.
Notes are always saved as the original Markdown. New notes open in edit mode.

Press **Super+N** (or run `./toggle`) to show it; press it again, or Escape, to hide it.
If it is open on another workspace, Super+N brings it to your current workspace
and focuses the editor. Edits autosave after 300 ms and on Escape.

Toggling is instant: the window stays mapped and is parked on the silent
`special:quickshell-scratchpad` workspace while hidden, and the toggle is a Lua
function that runs inside Hyprland, so no process starts and no open animation
plays. Only the first press after login starts Quickshell (about 0.4 s).
The window floats on the right at 25% monitor width and 75% monitor height,
with 32 logical pixels of space on the right and 48 below it.

Notes live outside Git at `~/.local/share/quickshell-scratchpad/scratchpads.json`
(or under `$XDG_DATA_HOME`). The original `scratchpad.txt` is imported into the
first scratchpad on first launch and kept as a backup. The active scratchpad is
restored on launch. Requires Quickshell, Qt Quick Controls, Python 3, Hyprland
(Lua config), and flock.

The binding and window rule live in `omarchy.lua`, which
`~/.config/hypr/hyprland.lua` loads with
`dofile("/home/ash/projects/quickshell-scratchpad/omarchy.lua")`.
T3 integration is future work; for now copy and paste into the editor.
