-- Senta glass / blur support for Hyprland 0.57+ Lua config.
-- Add this at top level in a module loaded by hyprland.lua (for example
-- ~/.config/hypr/modules/settings.lua). Do NOT put it inside an hl.on() callback.

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

-- About `xray = true` (used on every rule below): the blur then only samples the wallpaper.
-- The outer ring of the bar popups is painted by the screen frame (see ScreenFrame `rings`), so
-- it is already the same colour as the bar; xray additionally keeps it (and the bar and frame)
-- that colour when a window happens to sit behind it, instead of tinting it with that window.
-- Trade-off: a popup no longer blurs a window behind it; it frosts the wallpaper instead.
-- It is optional: drop the `xray` lines if you prefer the blur to see windows.

-- Main bar + its anchored xdg popups (app launcher, calendar, power,
-- notification center, and workspace preview).
hl.layer_rule({
    name = "senta-bar-glass-blur",
    match = { namespace = "^senta-bar$" },
    blur = true,
    xray = true,
    -- Frosts the anchored popups (calendar, power, apps, notifs, ws preview)
    -- including their outer frames. Verified on 0.57: this layer rule alone
    -- is enough; global decoration:blur:popups is not required.
    blur_popups = true,
    ignore_alpha = 0.12,
})

-- Floating notification toast panel (a separate PanelWindow).
hl.layer_rule({
    name = "senta-notifications-glass-blur",
    match = { namespace = "^senta-notifications$" },
    blur = true,
    xray = true,
    ignore_alpha = 0.12,
})

-- Screen frame border: glassy frame with blur behind it.
hl.layer_rule({
    name = "senta-frame-glass-blur",
    match = { namespace = "^senta-frame$" },
    blur = true,
    xray = true,
    ignore_alpha = 0.12,
})

-- Sentaku dashboard (bottom-centre hover panel, modules/sentadash).
-- The host window is large but almost entirely transparent; ignore_alpha keeps
-- the blur confined to the painted panel.
hl.layer_rule({
    name = "senta-dashboard-glass-blur",
    match = { namespace = "^senta-dashboard$" },
    blur = true,
    xray = true,
    ignore_alpha = 0.12,
})

-- Quick menu (bottom-right hover panel with Wi-Fi / Bluetooth / settings, modules/sentadash).
-- Same reasoning as the dashboard rule: the host window is mostly transparent.
hl.layer_rule({
    name = "senta-utilities-glass-blur",
    match = { namespace = "^senta-utilities$" },
    blur = true,
    xray = true,
    ignore_alpha = 0.12,
})
