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
