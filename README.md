# Quickshell Scratchpad

A single, persistent plain text scratchpad for pasted thread output and custom notes.

Run `./toggle`, or press **Super+N** on this machine. Press the hotkey again,
Escape, or the close button to hide it. Edits autosave after 300 ms and on hide.
The window floats on the right at 25% monitor width and 75% monitor height.

Notes live outside Git at `~/.local/share/quickshell-scratchpad/scratchpad.txt`
(or under `$XDG_DATA_HOME`). Requires Quickshell, Qt Quick Controls, and flock.

The installed Omarchy binding is in `~/.config/hypr/bindings.lua`; the window
rule is in `~/.config/hypr/hyprland.lua`. T3 integration and multiple notes are
future work; for now copy and paste into the editor.
