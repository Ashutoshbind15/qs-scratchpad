-- Reference for the settings installed in ~/.config/hypr/ on this machine.
o.bind("SUPER + N", "Notes scratchpad", "/home/ash/projects/quickshell-scratchpad/toggle")

o.window({ class = "^org.quickshell$", title = "^Scratchpad$" }, {
  float = true,
  size = { "monitor_w * 0.25", "monitor_h * 0.75" },
  move = { "monitor_w * 0.75 - 32", "monitor_h * 0.25 - 48" },
  opacity = "1.0 1.0",
})
