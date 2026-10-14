# Quickshell Scratchpads

Persistent scratchpads for pasted thread output and custom notes. Use **+ New**
to create a scratchpad, select one in the sidebar, and edit its name above the editor.
Press **Ctrl+B** while the scratchpad has focus to hide or show the sidebar,
or **Ctrl+N** to create a new scratchpad and edit its name.

Run `./toggle`, or press **Super+N** on this machine. Press the hotkey again,
Escape, or the close button to hide it. If it is open on another workspace,
Super+N brings it to your current workspace and focuses the editor. Edits autosave after 300 ms and on hide.
The window floats on the right at 25% monitor width and 75% monitor height,
with 32 logical pixels of space on the right and 48 below it.

Notes live outside Git at `~/.local/share/quickshell-scratchpad/scratchpads.json`
(or under `$XDG_DATA_HOME`). The original `scratchpad.txt` is imported into the
first scratchpad on first launch and kept as a backup. The active scratchpad is
restored on launch. Requires Quickshell, Qt Quick Controls, Python 3, jq, Hyprland, and flock.

The installed Omarchy binding is in `~/.config/hypr/bindings.lua`; the window
rule is in `~/.config/hypr/hyprland.lua`. The installed settings are also recorded
in `omarchy.lua` for reference; avoid sourcing it alongside the existing settings.
T3 integration is future work; for now copy and paste into the editor.
