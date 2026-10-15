-- Sourced by ~/.config/hypr/hyprland.lua via dofile().
--
-- The window stays mapped and is parked on a silent special workspace while
-- hidden. Showing it is a single move + focus inside Hyprland: no process
-- spawn, no Qt surface creation, and no open animation.
local repo = "/home/ash/projects/quickshell-scratchpad"
local hidden = "special:quickshell-scratchpad"

-- Pay Qt initialization and note loading at login, before the first shortcut.
o.exec_on_start(repo .. "/toggle prewarm")

function quickshell_scratchpad_toggle()
  local window = hl.get_windows({ class = "org.quickshell", title = "Scratchpad" })[1]
  if not window then
    -- Cold path: start (or recover) the instance; its window maps focused.
    hl.exec_cmd(repo .. "/toggle start")
    return
  end
  local workspace = hl.get_active_workspace()
  if window.workspace and window.workspace.id == workspace.id then
    hl.dispatch(hl.dsp.window.move({ workspace = hidden, window = window, follow = false }))
  else
    hl.dispatch(hl.dsp.window.move({ workspace = workspace, window = window, follow = false }))
    hl.dispatch(hl.dsp.focus({ window = window }))
  end
end

-- Capture always shows the window, including when it is already visible.
function quickshell_scratchpad_show()
  local window = hl.get_windows({ class = "org.quickshell", title = "Scratchpad" })[1]
  if not window then return false end
  hl.dispatch(hl.dsp.window.move({ workspace = hl.get_active_workspace(), window = window, follow = false }))
  hl.dispatch(hl.dsp.focus({ window = window }))
  return true
end

o.bind("SUPER + A", "Add point to Global scratchpad", repo .. "/capture")

o.bind("SUPER + N", "Notes scratchpad", quickshell_scratchpad_toggle)

-- Right side, one quarter wide and three quarters tall.
o.window({ class = "^org.quickshell$", title = "^Scratchpad$" }, {
  float = true,
  size = { "monitor_w * 0.25", "monitor_h * 0.75" },
  move = { "monitor_w * 0.75 - 32", "monitor_h * 0.25 - 48" },
  opacity = "1.0 1.0",
  no_anim = true,
})
