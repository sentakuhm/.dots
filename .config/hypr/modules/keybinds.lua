----------------------
---- KEYBINDINGS ----
---------------------

local programs = require("modules.variables")
local mainMod = programs.main_mod
local screenshot = programs.screenshot

----------------------------------------------------------------------
-- Apps and window management
----------------------------------------------------------------------

hl.bind(mainMod .. " + SHIFT + C", hl.dsp.exec_cmd("hyprctl reload"))

-- hl.bind(mainMod .. " + D", hl.dsp.exec_cmd('rofi -show drun -icon-theme "Papirus-Dark"'))
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd(programs.launcher))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + CTRL + F", hl.dsp.window.fullscreen_state({ internal = 2, client = 0, action = "toggle" }))

hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(programs.terminal))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(programs.file_manager))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(programs.browser))
--hl.bind(mainMod .. " + CTRL + W", hl.dsp.exec_cmd(wallpaper_switcher))
hl.bind("CTRL + ALT + L", hl.dsp.exec_cmd("hyprlock"))
--hl.bind("CTRL + ALT + P", hl.dsp.exec_cmd(home .. "/.config/wlogout/exec"))

-- Clipboard manager in a small floating kitty
hl.bind(
	mainMod .. " + V",
	hl.dsp.exec_cmd("kitty --class floating -e fish -c 'clipse'", { float = true, center = true, size = { 450, 590 } })
)

hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("hyprctl kill"))

-- Master layout
hl.bind(mainMod .. " + CTRL + D", hl.dsp.layout("removemaster"))
hl.bind(mainMod .. " + I", hl.dsp.layout("addmaster"))
hl.bind(mainMod .. " + J", hl.dsp.layout("cyclenext"))
hl.bind(mainMod .. " + K", hl.dsp.layout("cycleprev"))
hl.bind(mainMod .. " + CTRL + Return", hl.dsp.layout("swapwithmaster"))
hl.bind(mainMod .. " + M", hl.dsp.layout("mfact +0.3")) -- was: hyprctl dispatch splitratio 0.3

hl.bind(mainMod .. " + P", hl.dsp.window.pseudo()) -- dwindle

----------------------------------------------------------------------
-- Display rotation / lid switch (disabled, untested)
----------------------------------------------------------------------

-- local rotations = { up = 0, down = 1, left = 2, right = 3 }
-- for key, transform in pairs(rotations) do
--     hl.bind("CTRL + ALT + " .. key, function()
--         hl.monitor({ output = "DP-2", mode = "highrr", position = "auto", scale = 1, vrr = 0, transform = transform })
--     end)
-- end

-- From the manual but it did not work:
-- hl.bind("switch:off:Lid Switch", function()
--     hl.monitor({ output = "eDP-1", mode = "2560x1440@165", position = "0x0", scale = 1 })
-- end, { locked = true })
-- hl.bind("switch:on:Lid Switch", function()
--     hl.monitor({ output = "eDP-1", disabled = true })
-- end, { locked = true })

----------------------------------------------------------------------
-- Special keys / hot keys
----------------------------------------------------------------------

-- Audio
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true })
-- (add a notification here if you want one, e.g. dunstify "Volume: $(wpctl get-volume @DEFAULT_AUDIO_SINK@)")
-- hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(volume .. " --inc")) -- volume up
-- hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(volume .. " --dec")) -- volume down
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle")) -- mute mic
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")) -- FN+F1

-- Media
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"))
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"))
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"))
hl.bind("XF86AudioStop", hl.dsp.exec_cmd("playerctl stop"))

----------------------------------------------------------------------
-- Resize / move / focus
----------------------------------------------------------------------

-- Resize
hl.bind(mainMod .. " + SHIFT + H", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + L", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + K", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + J", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { repeating = true })

-- Move
hl.bind(mainMod .. " + CTRL + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mainMod .. " + CTRL + L", hl.dsp.window.move({ direction = "right" }))
hl.bind(mainMod .. " + CTRL + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mainMod .. " + CTRL + J", hl.dsp.window.move({ direction = "down" }))

-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mainMod .. " + G", hl.dsp.group.toggle())

----------------------------------------------------------------------
-- Workspaces
----------------------------------------------------------------------

-- Special workspace (scratchpad). It used to be the unnamed "special";
-- it is now named "magic", like in the stock config.
hl.bind(mainMod .. " + SHIFT + U", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(mainMod .. " + U", hl.dsp.workspace.toggle_special("magic"))

for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0

	-- Switch workspace:  mainMod + [0-9]
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	-- Move active window and follow:  mainMod + CTRL + [0-9]
	hl.bind(mainMod .. " + CTRL + " .. key, hl.dsp.window.move({ workspace = i, follow = true }))
	-- Move active window silently:  mainMod + SHIFT + [0-9]
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
end

hl.bind(mainMod .. " + CTRL + bracketleft", hl.dsp.window.move({ workspace = "-1", follow = true }))
hl.bind(mainMod .. " + CTRL + bracketright", hl.dsp.window.move({ workspace = "+1", follow = true }))
hl.bind(mainMod .. " + SHIFT + bracketleft", hl.dsp.window.move({ workspace = "-1", follow = false }))
hl.bind(mainMod .. " + SHIFT + bracketright", hl.dsp.window.move({ workspace = "+1", follow = false }))

-- Scroll through existing workspaces
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + period", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + comma", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + Tab", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mainMod .. " + SHIFT + Tab", hl.dsp.focus({ workspace = "m-1" }))

----------------------------------------------------------------------
-- Screenshots
----------------------------------------------------------------------

-- hl.bind("Print", hl.dsp.exec_cmd(screenshot .. " --now"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd(screenshot .. " --now"))
hl.bind(mainMod .. " + CTRL + SHIFT + Print", hl.dsp.exec_cmd(screenshot .. " --in5"))
-- hl.bind("CTRL + Print", hl.dsp.exec_cmd(screenshot .. " --win"))
-- hl.bind("SHIFT + Print", hl.dsp.exec_cmd(screenshot .. " --area"))
hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd(screenshot .. " --area"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd(screenshot .. " --satty"))

----------------------------------------------------------------------
-- Extras
----------------------------------------------------------------------

-- Short video record (pacman -S wf-recorder)
--hl.bind(
--    mainMod .. " + ALT + F8",
--    hl.dsp.exec_cmd([[wf-recorder -c h264_vaapi -d /dev/dri/renderD128 -g --"`slurp`" -f ~/Videos/recording.mp4 -D]])
--)
--hl.bind(mainMod .. " + ALT + F9", hl.dsp.exec_cmd("killall wf-recorder"))

-- Enable/disable saturation (paru hyprshade)
hl.bind(mainMod .. " + ALT + F6", hl.dsp.exec_cmd("hyprshade on vibrance"))
hl.bind(mainMod .. " + ALT + F7", hl.dsp.exec_cmd("hyprshade off"))

-- Color picker (paru -S hyprpicker-git)
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("hyprpicker -a"))
