-- Mando (settings window) is a normal window: without a rule Hyprland tiles it.
-- Add this at top level in a Hyprland Lua module loaded by your hyprland.lua
-- (for example ~/.config/hypr/modules/windowrules.lua). It floats and centres the window and
-- leaves its size alone, so Mando keeps the size it asks for.
--
-- Hyprland matches the window's INITIAL title, which is "Mando — <first page>",
-- so a prefix match is the right tool.
hl.window_rule({
    name = "mando-float",
    match = { title = "^Mando" },
    float = true,
    center = true,
})
