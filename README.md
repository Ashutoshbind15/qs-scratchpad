# Quickshell Scratchpads

Persistent scratchpads for pasted thread output and custom notes. The first line
of a note becomes its title in the sidebar; empty notes appear as Untitled.
Press **Ctrl+B** while the scratchpad has focus to hide or show the sidebar,
or **Ctrl+N** to create a new scratchpad and start writing.

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
