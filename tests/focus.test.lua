-- Super+Arrow focus across two monitors, with Hyprland mocked: its own
-- directional focus skips floating windows and crosses to the next monitor.
-- Run: lua tests/focus.test.lua
local repo = arg[0]:match("^(.*)/tests/[^/]+$") or "."

local function window(address, workspace, x, y, w, h, floating)
  return { address = address, workspace = { id = workspace }, at = { x = x, y = y },
           size = { x = w, y = h }, floating = floating, mapped = true, hidden = false,
           class = floating and "org.quickshell" or "app", title = floating and "Scratchpad" or "" }
end

local windows, active
local monitors = {
  { x = 1536, width = 1920, active_workspace = { id = 3 } },
  { x = 3456, width = 1920, active_workspace = { id = 2 } },
}

-- Hyprland's directional focus: tiled windows on the same workspace first,
-- then the adjacent monitor's tiled window, never a floating one.
local function hyprland_focus(direction)
  local ax = active.at.x + active.size.x / 2
  local best, best_distance
  for _, candidate in ipairs(windows) do
    local cx = candidate.at.x + candidate.size.x / 2
    local ahead = (direction == "r" and cx > ax) or (direction == "l" and cx < ax)
    if not candidate.floating and candidate ~= active and ahead then
      local shown = false
      for _, monitor in ipairs(monitors) do
        if monitor.active_workspace.id == candidate.workspace.id then shown = true end
      end
      local distance = math.abs(cx - ax)
      if shown and (not best_distance or distance < best_distance) then best, best_distance = candidate, distance end
    end
  end
  if best then active = best end
end

hl = {
  get_windows = function(match)
    if not match then return windows end
    local found = {}
    for _, w in ipairs(windows) do
      if w.class == match.class and w.title == match.title then found[#found + 1] = w end
    end
    return found
  end,
  get_monitors = function() return monitors end,
  get_active_window = function() return active end,
  get_active_workspace = function() return active.workspace end,
  dispatch = function(action) action() end,
  dsp = {
    focus = function(options)
      return function()
        if options.window then active = options.window else hyprland_focus(options.direction) end
      end
    end,
    window = {},
  },
  unbind = function() end,
}
o = { exec_on_start = function() end, bind = function() end, window = function() end }
dofile(repo .. "/omarchy.lua")

local left = window("left", 3, 1548, 38, 1896, 1030, false)
local right = window("right", 2, 3468, 38, 1896, 1030, false)
local failures = 0
local function check(name, start, direction, pad, expected)
  windows = { left, right, pad }
  active = start
  quickshell_scratchpad_focus(direction)
  if active ~= expected then
    failures = failures + 1
    print("FAIL " .. name .. ": focused " .. active.address .. ", expected " .. expected.address)
  end
end

-- Scratchpad on the middle monitor, which has another monitor to its right.
local middle_pad = window("pad", 3, 2944, 543, 480, 489, true)
check("enter pad before crossing monitors", left, "r", middle_pad, middle_pad)
check("leave pad to the next monitor", middle_pad, "r", middle_pad, right)
check("leave pad back to its own monitor", middle_pad, "l", middle_pad, left)
check("left from the tiled window still crosses", left, "l", middle_pad, left)

-- Scratchpad on the right monitor.
local right_pad = window("pad", 2, 4864, 543, 480, 489, true)
check("the next monitor's window beats a farther pad", left, "r", right_pad, right)
check("enter pad at the screen edge", right, "r", right_pad, right_pad)
check("leave pad across to the other monitor", right_pad, "l", right_pad, right)

-- Hidden scratchpad: plain Hyprland behavior.
local hidden_pad = window("pad", -98, 4864, 543, 480, 489, true)
check("hidden pad is ignored", left, "r", hidden_pad, right)

if failures > 0 then os.exit(1) end
print("Super+Arrow reaches and leaves the scratchpad on either monitor")
