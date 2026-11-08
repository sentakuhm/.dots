--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------

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
})

-- Discord / Vesktop silently belong on workspace 6.
hl.window_rule({
	name = "discord-workspace",
	match = { class = "^(discord|Discord|vesktop)$" },
	workspace = "6 silent",
})

-- Keep the shell's settings (Nexus) window floating and centered on open.
hl.window_rule({
	name = "nexus-float-centered",
	match = { class = "^org\\.quickshell$", title = "^Nexus.*$" },
	float = true,
	center = true,
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

-- Main bar + its anchored xdg popups (app launcher, calendar, power,
-- notification center, and workspace preview).
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
