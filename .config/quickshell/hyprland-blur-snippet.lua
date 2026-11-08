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
