------------------
---- MONITORS ----
------------------

-- Verify the connector and exact mode with: hyprctl monitors all
-- Keep this rule specific to the display whose 180 Hz mode was in your original config.
hl.monitor({
	output = "DP-1",
	mode = "2560x1440@180",
	position = "auto",
	scale = 1.60,
	vrr = 2, -- Adaptive Sync in fullscreen only; requires monitor/driver support.
})

-- Fallback for any other connected display, including a differently named main monitor.
hl.monitor({
	output = "HDMI-A-2",
	mode = "2560x1440@144",
	position = "auto",
	scale = 1.6,
})

hl.monitor({
	output = "",
	mode = "preferred",
	position = "auto",
	scale = 1,
})
