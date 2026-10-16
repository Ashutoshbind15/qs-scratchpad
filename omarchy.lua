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

-- Tall (the window rule's size) or short, keeping the bottom-right corner in
-- place. Called by the scratchpad when the mode changes and when it maps.
function quickshell_scratchpad_layout(short)
  local window = hl.get_windows({ class = "org.quickshell", title = "Scratchpad" })[1]
  if not window then return end
  local monitor = hl.get_active_monitor()
  local width, height = monitor.width / monitor.scale, monitor.height / monitor.scale
  local size = { x = math.floor(width * 0.25), y = math.floor(height * (short and 0.3 or 0.75)) }
  hl.dispatch(hl.dsp.window.resize({ x = size.x, y = size.y, window = window }))
  hl.dispatch(hl.dsp.window.move({ x = monitor.x + width - size.x - 32, y = monitor.y + height - size.y - 48, window = window }))
end

-- Hyprland's directional focus never crosses between floating and tiled
-- windows, so Super+arrows could neither reach the floating scratchpad nor
-- leave it. These replace Omarchy's bindings and fall back to them whenever
-- the scratchpad isn't on the active workspace.
local function center(window)
  return window.at.x + window.size.x / 2, window.at.y + window.size.y / 2
end

-- Nearest window whose center lies in `direction` from `from`'s center.
-- Sideways offset counts double, so a window straight ahead beats one at an angle.
local function nearest(from, candidates, direction)
  local fx, fy = center(from)
  local best, best_score
  for _, window in ipairs(candidates) do
    if window.address ~= from.address and window.mapped and not window.hidden then
      local x, y = center(window)
      local along, across
      if direction == "l" then along, across = fx - x, y - fy
      elseif direction == "r" then along, across = x - fx, y - fy
      elseif direction == "u" then along, across = fy - y, x - fx
      else along, across = y - fy, x - fx end
      local score = along + 2 * math.abs(across)
      if along > 0 and (not best_score or score < best_score) then
        best, best_score = window, score
      end
    end
  end
  return best
end

function quickshell_scratchpad_focus(direction)
  local pad = hl.get_windows({ class = "org.quickshell", title = "Scratchpad" })[1]
  local workspace = hl.get_active_workspace()
  local active = hl.get_active_window()
  if not (pad and active and pad.workspace and pad.workspace.id == workspace.id) then
    hl.dispatch(hl.dsp.focus({ direction = direction }))
    return
  end
  if active.address == pad.address then
    local others = {}
    for _, window in ipairs(hl.get_windows()) do
      if window.workspace and window.workspace.id == workspace.id then others[#others + 1] = window end
    end
    local target = nearest(pad, others, direction)
    if target then hl.dispatch(hl.dsp.focus({ window = target })) end
    return
  end
  -- Prefer Hyprland's own choice; enter the scratchpad only at the edge.
  hl.dispatch(hl.dsp.focus({ direction = direction }))
  local now = hl.get_active_window()
  if now and now.address ~= active.address then return end
  if nearest(active, { pad }, direction) then hl.dispatch(hl.dsp.focus({ window = pad })) end
end

for key, info in pairs({ LEFT = { "l", "left" }, RIGHT = { "r", "right" }, UP = { "u", "above" }, DOWN = { "d", "below" } }) do
  hl.unbind("SUPER + " .. key)
  o.bind("SUPER + " .. key, "Focus on " .. info[2] .. " window", function()
    quickshell_scratchpad_focus(info[1])
  end)
end

o.bind("SUPER + A", "Add point to Global scratchpad", repo .. "/capture")

o.bind("SUPER + N", "Notes scratchpad", quickshell_scratchpad_toggle)

-- Right side, one quarter wide and three quarters tall (see
-- quickshell_scratchpad_layout for short mode).
o.window({ class = "^org.quickshell$", title = "^Scratchpad$" }, {
  float = true,
  size = { "monitor_w * 0.25", "monitor_h * 0.75" },
  move = { "monitor_w * 0.75 - 32", "monitor_h * 0.25 - 48" },
  opacity = "1.0 1.0",
  no_anim = true,
})
