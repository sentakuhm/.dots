-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-------------------------
-- Desktop / Session
-------------------------
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-------------------------
-- Qt
-------------------------
-- This matches the hyprqt6engine.conf file shipped with this configuration.
hl.env("QT_QPA_PLATFORMTHEME", "kde")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")

-------------------------
-- GDK / GTK
-------------------------
hl.env("GDK_BACKEND", "wayland,x11,*")
-- hl.env("GDK_SCALE", "1.5")       -- Only set this if GTK apps need manual scaling.
-- hl.env("GDK_DPI_SCALE", "1")

-------------------------
-- Other Toolkits
-------------------------
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("SDL_VIDEODRIVER", "wayland")

-------------------------
-- Graphics
-------------------------
-- NVIDIA-specific Aquamarine override; set only if you know you need it.
-- hl.env("AQ_DRM_DEVICES", "/dev/dri/card1")

-------------------------
-- Mozilla
-------------------------
hl.env("MOZ_ENABLE_WAYLAND", "1")

-------------------------
-- Electron / Chromium
-------------------------
-- XDG_SESSION_TYPE=wayland above is the current session signal.
-- ELECTRON_OZONE_PLATFORM_HINT was removed in Electron 38; do not set it.
-- OZONE_PLATFORM is not a standard environment override for Electron/Chromium.

-------------------------
-- Cursor
-------------------------
--hl.env("XCURSOR_THEME", "oblique-cursor-light")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "oblique-cursor-light")
hl.env("HYPRCURSOR_SIZE", "24")

-------------------------
-- Other
-------------------------
-- hl.env("APPIMAGELAUNCHER_DISABLE", "1")
