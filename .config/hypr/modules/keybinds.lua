---------------------
---- KEYBINDINGS ----
---------------------

local programs = require("modules.variables")
local mainMod = programs.main_mod
local screenshot = programs.screenshot

-- Shutdown gracefully when hyprshutdown is installed; otherwise use Hyprland's exit dispatcher.
hl.bind(
    "CTRL + ALT + P",
    hl.dsp.exec_cmd("if command -v hyprshutdown >/dev/null 2>&1; then hyprshutdown; else hyprctl dispatch exit; fi"),
    { description = "Power off the Hyprland session" }
)
-- Lockscreen
hl.bind("CTRL + ALT + L", hl.dsp.exec_cmd("hyprlock"), { description = "Lock the screen" })

-- Applications
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(programs.terminal), { description = "Open terminal" })
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(programs.file_manager), { description = "Open file manager" })
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(programs.launcher), { description = "Open application launcher" })

-- Window controls
hl.bind(mainMod .. " + Q", hl.dsp.window.close(), { description = "Close focused window" })
hl.bind("CTRL + ALT + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating" })
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo(), { description = "Toggle pseudotile" })
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"), { description = "Toggle dwindle split" })

-- Clipse clipboard UI: use the Lua window-rule table instead of the old [float ...] exec prefix.
hl.bind(
    mainMod .. " + V",
    hl.dsp.exec_cmd("kitty --class floating -e fish -c 'clipse'", {
        float = true,
        center = true,
        size = { 450, 590 },
    }),
    { description = "Open clipboard history" }
)

-- Move focus with mainMod + arrow keys.
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]. Move windows with mainMod + SHIFT + [0-9].
for i = 1, 10 do
    local key = i % 10 -- Workspace 10 is key 0.
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Special workspace (scratchpad).
hl.bind(mainMod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))

-- Scroll through workspaces.
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move / resize windows with mainMod + LMB/RMB drag.
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Volume. Repeating is only enabled for continuous up/down adjustment, not toggle actions.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })

-- Display brightness.
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

-- Media controls (requires playerctl).
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Screenshots.
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd(screenshot .. " --now"))
hl.bind(mainMod .. " + CTRL + SHIFT + Print", hl.dsp.exec_cmd(screenshot .. " --in5"))
hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd(screenshot .. " --area"))
-- This used to collide with SUPER + SHIFT + S (move window to the scratchpad).
hl.bind(mainMod .. " + CTRL + SHIFT + S", hl.dsp.exec_cmd(screenshot .. " --satty"))
