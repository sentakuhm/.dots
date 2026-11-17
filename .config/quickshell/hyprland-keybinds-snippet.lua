-- Add these to your existing modules/keybinds.lua.
-- Your current config already defines `programs` and `mainMod` near the top.

hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("qs ipc call senta toggleNotifications"), {
    description = "Toggle notification center",
})

hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("qs ipc call senta toggleDnd"), {
    description = "Toggle do not disturb",
})

hl.bind(mainMod .. " + C", hl.dsp.exec_cmd("qs ipc call senta toggleCalendar"), {
    description = "Toggle calendar",
})

hl.bind(mainMod .. " + ALT + P", hl.dsp.exec_cmd("qs ipc call senta togglePower"), {
    description = "Open session power menu",
})

hl.bind(mainMod .. " + ALT + B", hl.dsp.exec_cmd("qs ipc call senta toggleBar"), {
    description = "Toggle Quickshell bar",
})

-- Sentaku dashboard. Hovering the bottom centre of the screen opens it;
-- these open it from the keyboard (it then stays until toggled or until the
-- pointer has entered and left it). Tabs: 0 Dashboard, 1 Media, 2 Performance, 3 Weather.
hl.bind(mainMod .. " + ALT + D", hl.dsp.exec_cmd("qs ipc call senta toggleDashboard"), {
    description = "Toggle dashboard",
})

hl.bind(mainMod .. " + ALT + M", hl.dsp.exec_cmd("qs ipc call senta openDashboard 1"), {
    description = "Open dashboard on the Media tab",
})

-- Quick menu (Wi-Fi, Bluetooth, mic, settings, ...). Hovering the bottom-right of the screen
-- opens it; this opens it from the keyboard. Same pin rule as the dashboard.
hl.bind(mainMod .. " + ALT + U", hl.dsp.exec_cmd("qs ipc call senta toggleUtilities"), {
    description = "Toggle quick menu",
})

-- Mando settings window (also reachable from the settings button in the quick menu).
hl.bind(mainMod .. " + ALT + S", hl.dsp.exec_cmd("qs ipc call senta openSettings"), {
    description = "Open Mando settings",
})
