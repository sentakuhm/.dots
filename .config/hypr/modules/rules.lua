-- ~/.config/hypr/windowrules.lua
-- Load it from hyprland.lua with:  require("windowrules")
-- Rules are evaluated top to bottom, so later rules override earlier ones.

-- Small helpers so each app stays on one line
local function class_rule(class, effects)
	effects.match = { class = class }
	hl.window_rule(effects)
end

local function title_rule(title, effects)
	effects.match = { title = title }
	hl.window_rule(effects)
end

----------------------------------------------------------------------
-- Stock rules
----------------------------------------------------------------------

-- Ignore maximize requests from all apps. You'll probably like this.
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

-- Games (disabled)
-- class_rule("cs2", { suppress_event = "maximize fullscreen" })
-- title_rule("Euro Truck Simulator 2", { fullscreen = true })

----------------------------------------------------------------------
-- Floating apps (float / size / center / opacity)
----------------------------------------------------------------------

class_rule("org.gnome.DiskUtility", { float = true, size = { 1004, 644 }, center = true, opacity = "0.90 0.70" })
class_rule("io.missioncenter.MissionCenter", { float = true, size = { 1004, 644 }, center = true })
class_rule("mediainfo-gui", { float = true, size = { 630, 570 }, center = true })
class_rule("io.github.Qalculate.qalculate-qt", { float = true, size = { 480, 410 }, center = true })
class_rule("org.kde.gwenview", { float = true, size = { 964, 647 }, center = true })

class_rule("org.kde.haruna", { float = true, center = true })
class_rule("org.kde.kmines", { float = true, center = true })
class_rule("imv", { float = true, center = true })
class_rule("mpv", { float = true, center = true, idle_inhibit = "focus" })
class_rule("net.davidotek.pupgui2", { float = true, center = true })
class_rule("btrfs-assistant-bin", { float = true, center = true })
class_rule("org.kde.ark", { float = true, center = true })

class_rule("hyprpwcenter", { float = true, center = true, opacity = "0.80 0.70" })
class_rule("org.pulseaudio.pwvucontrol", { float = true, center = true, opacity = "0.80 0.70" })
class_rule("blueman-manager", { float = true, center = true, opacity = "0.80 0.70" })

----------------------------------------------------------------------
-- Dialogs
----------------------------------------------------------------------

-- Note: in your old config "Open File" was first set to 901x629 and then
-- overridden to 800x600 further down, so 800x600 is what was actually applied.
title_rule("Open File", { float = true, size = { 800, 600 }, center = true })
title_rule("branchdialog", { float = true })
title_rule("Confirm to replace files", { float = true })
title_rule("File Operation Progress", { float = true })
title_rule("Choose Files", { float = true })
title_rule("Save As", { float = true })

-- Dolphin
title_rule("Progress Dialog — Dolphin", { float = true, center = true })
title_rule("Open Files", { float = true, size = { 901, 629 }, center = true })
title_rule("Copying — Dolphin", { float = true, center = true })

-- Size only (size has no effect unless the window is floating)
class_rule("download", { size = { 800, 600 } })
title_rule("Save File", { size = { 800, 600 } })
title_rule("Volume Control", { size = { 800, 600 } })

----------------------------------------------------------------------
-- Browser Picture-in-Picture
----------------------------------------------------------------------

hl.window_rule({
	name = "browser-pip",
	match = { title = "Picture-in-Picture" },
	float = true,
	pin = true,
	-- was "move 69.5% 4%"
	move = { "monitor_w * 0.695", "monitor_h * 0.04" },
})

----------------------------------------------------------------------
-- Opacity (apps that only need transparency)
----------------------------------------------------------------------

-- class_rule("firefox",                { opacity = "0.97 0.97" })
-- class_rule("org.mozilla.Thunderbird", { opacity = "0.97 0.97" })
class_rule("kitty", { opacity = "0.90 0.90" })
class_rule("foot", { opacity = "0.90 0.90" })
class_rule("hyprpolkitagent", { opacity = "0.90 0.90" })
class_rule("org.kde.kate", { opacity = "0.90 0.90" })
--class_rule("nm-applet",       { opacity = "0.80 0.70" })

----------------------------------------------------------------------
-- Disable animations for specific windows
----------------------------------------------------------------------

hl.window_rule({
	match = { class = "cs2|wine|[Ss]team|mpv" },
	no_anim = true,
})

--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------
-- class_rule("kitty", { workspace = "1" })
class_rule("org.kde.dolphin", { workspace = "3", opacity = "0.90 0.70" })
class_rule("org.gnome.Nautilus", { workspace = "3", opacity = "0.90 0.70" })
class_rule("org.mozilla.Thunderbird", { workspace = "4 silent" })
class_rule("[Ss]team", { workspace = "5 silent" })
class_rule("code", { workspace = "7" })
class_rule("org.qbittorrent.qBittorrent", { workspace = "8 silent", float = true, size = { 1373, 736 }, center = true })

-- Rules are evaluated in order; later matching effects take precedence.

-- Ignore application maximize requests. Remove this rule if you prefer apps to control
-- their own maximize state.
hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },
	suppress_event = "maximize",
})

-- Work around focus/drag issues with certain XWayland utility windows.
hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},
	no_focus = true,
})

-- Start Firefox silently on workspace 2. This also handles Firefox's single-instance
-- behavior more reliably than attaching an exec rule to its launcher process.
hl.window_rule({
	name = "firefox-workspace",
	match = { class = "^(firefox|Firefox)$" },
	workspace = "2 silent",
	idle_inhibit = "fullscreen",
})

-- Discord / Vesktop silently belong on workspace 6.
hl.window_rule({
	name = "discord-workspace",
	match = { class = "^(discord|Discord|vesktop)$" },
	workspace = "6 silent",
	opacity = "0.90 0.80",
})

-- Keep the shell's settings (Mando) window floating and centered on open.
hl.window_rule({
	name = "mando-float-centered",
	match = { class = "^org\\.quickshell", title = "^Mando.*$" },
	float = true,
	center = true,
	size = { 1021, 621 },
})

-- Enable compositor blur. Other blur tuning can remain in your existing settings;
-- these values are deliberately modest for a clean TokyoNight glass effect.
-- Popup blur is scoped by the senta-bar layer rule below, not enabled globally.
hl.config({
	decoration = {
		blur = {
			enabled = true,
			size = 8,
			passes = 2,
			new_optimizations = true,
		},
	},
})

----------------------------------------------------------------------
-- Layer rules
----------------------------------------------------------------------
hl.layer_rule({
	name = "senta-bar-glass-blur",
	match = { namespace = "^senta-bar$" },
	blur = true,
	blur_popups = true,
	ignore_alpha = 0.12,
})

-- Floating notification toast panel (a separate PanelWindow).
hl.layer_rule({
	name = "senta-notifications-glass-blur",
	match = { namespace = "^senta-notifications$" },
	blur = true,
	ignore_alpha = 0.12,
})

-- Screen frame border: glassy frame with blur behind it.
hl.layer_rule({
	name = "senta-frame-glass-blur",
	match = { namespace = "^senta-frame$" },
	blur = true,
	ignore_alpha = 0.12,
})

-- Sentaku dashboard (bottom-centre hover panel, modules/sentadash).
-- The host window is large but almost entirely transparent; ignore_alpha keeps
-- the blur confined to the painted panel.
hl.layer_rule({
	name = "senta-dashboard-glass-blur",
	match = { namespace = "^senta-dashboard$" },
	blur = true,
	ignore_alpha = 0.12,
})

-- Quick menu (bottom-right hover panel with Wi-Fi / Bluetooth / settings).
-- Same glass treatment as the dashboard: host window is mostly transparent.
hl.layer_rule({
	name = "senta-utilities-glass-blur",
	match = { namespace = "^senta-utilities$" },
	blur = true,
	ignore_alpha = 0.12,
})

-- Satty
hl.window_rule({
	name = "satty",
	match = { class = "com.gabm.satty$" },
	size = { 1000, 600 },
	float = true,
	center = true,
})
