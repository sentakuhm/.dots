---------------
---- INPUT ----
---------------

hl.config({
    input = {
        kb_layout     = "us,ara",
        kb_options    = "caps:escape,grp:alt_shift_toggle",
        follow_mouse  = 1,
        accel_profile = "flat",   -- better replacement for force_no_accel
        -- numlock_by_default = true,
        -- sensitivity = 0,
    },
})

--hl.gesture({
--    fingers = 3,
--    direction = "horizontal",
--    action = "workspace"
--})

-- Example per-device config
-- See https://wiki.hypr.land/configuring/core/devices/ for more
--hl.device({
--    name        = "epic-mouse-v1",
--    sensitivity = -0.5,
--})