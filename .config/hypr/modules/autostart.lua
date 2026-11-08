-------------------
---- AUTOSTART ----
-------------------

-- The hyprland.start event runs once for the compositor session, not on every config reload.
local programs = require("modules.variables")

hl.on("hyprland.start", function()
	-------------------------
	-- Session / DBus
	-------------------------
	-- --systemd also imports the environment into the user systemd manager.
	hl.exec_cmd("dbus-update-activation-environment --systemd --all && systemctl --user start hyprpolkitagent")
	hl.exec_cmd("quickshell -d")

	-------------------------
	-- Wallpaper / Idle / Color temperature
	-------------------------
	hl.exec_cmd("hyprpaper")
	--hl.exec_cmd("hypridle")
	-- hl.exec_cmd("hyprsunset")

	-------------------------
	-- UI / Launcher
	-------------------------
	-- -d starts the hyprlauncher daemon without opening the launcher immediately.
	hl.exec_cmd("hyprlauncher -d")
	-- hl.exec_cmd("waybar -c $HOME/.config/hypr/waybar/config -s $HOME/.config/hypr/waybar/style.css")
	-- hl.exec_cmd("swaync -s $HOME/.config/swaync/style.css")

	-------------------------
	-- Utilities
	-------------------------
	--hl.exec_cmd("kwalletd6") -- Used by some KDE / VS Code integrations.
	hl.exec_cmd("udiskie")
	hl.exec_cmd("clipse -listen")

	-------------------------
	-- Applications on specific workspaces
	-------------------------
	-- Use Lua dispatchers/window rules instead of legacy [workspace ...] exec prefixes.
	hl.dispatch(hl.dsp.exec_cmd(programs.terminal, { workspace = "1 silent" }))
	hl.exec_cmd(programs.browser) -- Placed on workspace 2 by modules/rules.lua.
	hl.exec_cmd(programs.chat) -- Placed on workspace 6 by modules/rules.lua.
end)
