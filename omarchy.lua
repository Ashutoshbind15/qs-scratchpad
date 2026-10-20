-- Sourced by ~/.config/hypr/hyprland.lua via dofile("<repo>/omarchy.lua").
--
-- The window stays mapped and is parked on a silent special workspace while
-- hidden. Showing it is a single move + focus inside Hyprland: no process
-- spawn, no Qt surface creation, and no open animation.

-- The scripts live next to this file, wherever the repo was cloned.
local repo = debug.getinfo(1, "S").source:match("^@(.+)/[^/]+$")
assert(repo, "quickshell-scratchpad: load omarchy.lua with dofile() and an absolute path")

local hidden = "special:quickshell-scratchpad"
local window_match = { class = "org.quickshell", title = "Scratchpad" }

-- Fractions of the monitor, plus the gap to its right and bottom edges.
local layout = { width = 0.25, tall = 0.75, short = 0.3, right_gap = 32, bottom_gap = 48 }

local function find_scratchpad()
  return hl.get_windows(window_match)[1]
end

-- Pay Qt initialization and note loading at login, before the first shortcut.
o.exec_on_start(repo .. "/toggle prewarm")

function quickshell_scratchpad_toggle()
  local window = find_scratchpad()
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
  local window = find_scratchpad()
  if not window then return false end
  hl.dispatch(hl.dsp.window.move({ workspace = hl.get_active_workspace(), window = window, follow = false }))
  hl.dispatch(hl.dsp.focus({ window = window }))
  return true
end

-- Tall (the window rule's size) or short, keeping the bottom-right corner in
-- place. Called by the scratchpad when the mode changes and when it maps.
function quickshell_scratchpad_layout(short)
  local window = find_scratchpad()
  if not window then return end
  local monitor = hl.get_active_monitor()
  local width, height = monitor.width / monitor.scale, monitor.height / monitor.scale
  local size = {
    x = math.floor(width * layout.width),
    y = math.floor(height * (short and layout.short or layout.tall)),
  }
  hl.dispatch(hl.dsp.window.resize({ x = size.x, y = size.y, window = window }))
  hl.dispatch(hl.dsp.window.move({
    x = monitor.x + width - size.x - layout.right_gap,
    y = monitor.y + height - size.y - layout.bottom_gap,
    window = window,
  }))
end

-- Hyprland's directional focus never crosses between floating and tiled
-- windows, so Super+arrows could neither reach the floating scratchpad nor
-- leave it. These replace Omarchy's bindings and fall back to them whenever
-- the scratchpad isn't visible.
local function center(window)
  return window.at.x + window.size.x / 2, window.at.y + window.size.y / 2
end

-- How far `to` lies in `direction` from `from` (center to center), and how far
-- off to the side.
local function offset(from, to, direction)
  local fx, fy = center(from)
  local x, y = center(to)
  if direction == "l" then return fx - x, y - fy
  elseif direction == "r" then return x - fx, y - fy
  elseif direction == "u" then return fy - y, x - fx
  else return y - fy, x - fx end
end

-- Nearest window whose center lies in `direction` from `from`'s center, and
-- its score. Sideways offset counts double, so a window straight ahead beats
-- one at an angle.
local function nearest(from, candidates, direction)
  local best, best_score
  for _, window in ipairs(candidates) do
    if window.address ~= from.address and window.mapped and not window.hidden then
      local along, across = offset(from, window, direction)
      local score = along + 2 * math.abs(across)
      if along > 0 and (not best_score or score < best_score) then
        best, best_score = window, score
      end
    end
  end
  return best, best_score
end

-- Windows on every monitor's active workspace: what is on screen.
local function visible_windows()
  local shown = {}
  for _, monitor in ipairs(hl.get_monitors()) do
    if monitor.active_workspace then shown[monitor.active_workspace.id] = true end
  end
  local windows = {}
  for _, window in ipairs(hl.get_windows()) do
    if window.workspace and shown[window.workspace.id] then windows[#windows + 1] = window end
  end
  return windows
end

function quickshell_scratchpad_focus(direction)
  local pad = find_scratchpad()
  local active = hl.get_active_window()
  local windows = pad and active and visible_windows() or {}
  local pad_visible = false
  for _, window in ipairs(windows) do
    if window.address == pad.address then pad_visible = true end
  end
  if not pad_visible then
    hl.dispatch(hl.dsp.focus({ direction = direction }))
    return
  end
  if active.address == pad.address then
    -- Leave toward the nearest window on screen, on any monitor.
    local target = nearest(pad, windows, direction)
    if target then hl.dispatch(hl.dsp.focus({ window = target }))
    else hl.dispatch(hl.dsp.focus({ direction = direction })) end
    return
  end
  -- Prefer Hyprland's own choice unless the scratchpad is closer that way.
  -- Hyprland skips floating windows and jumps to the next monitor, so with a
  -- monitor beyond it the scratchpad was unreachable.
  local _, pad_score = nearest(active, { pad }, direction)
  hl.dispatch(hl.dsp.focus({ direction = direction }))
  if not pad_score then return end
  local now = hl.get_active_window()
  if now and now.address ~= active.address then
    local _, now_score = nearest(active, { now }, direction)
    if now_score and now_score <= pad_score then return end
  end
  hl.dispatch(hl.dsp.focus({ window = pad }))
end

for key, info in pairs({ LEFT = { "l", "left" }, RIGHT = { "r", "right" }, UP = { "u", "above" }, DOWN = { "d", "below" } }) do
  hl.unbind("SUPER + " .. key)
  o.bind("SUPER + " .. key, "Focus on " .. info[2] .. " window", function()
    quickshell_scratchpad_focus(info[1])
  end)
end

o.bind("SUPER + A", "Add point to Global scratchpad", repo .. "/capture")

o.bind("SUPER + N", "Notes scratchpad", quickshell_scratchpad_toggle)

-- Right side, one quarter wide and three quarters tall (see `layout` and
-- quickshell_scratchpad_layout for short mode).
o.window({ class = "^org.quickshell$", title = "^Scratchpad$" }, {
  float = true,
  size = { "monitor_w * " .. layout.width, "monitor_h * " .. layout.tall },
  move = {
    "monitor_w * " .. (1 - layout.width) .. " - " .. layout.right_gap,
    "monitor_h * " .. (1 - layout.tall) .. " - " .. layout.bottom_gap,
  },
  opacity = "1.0 1.0",
  no_anim = true,
})
