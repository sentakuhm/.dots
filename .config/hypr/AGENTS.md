# AGENTS.md

Guidance for AI agents (and humans) editing this Hyprland configuration.

## What this is

This directory is the user `sentaku`'s **Hyprland** (Wayland compositor)
configuration, located at `~/.config/hypr`. It is not a buildable software
project: there is no build step, package manifest, or test suite. Changes are
applied by reloading the running compositor.

There are two config languages in play:

- **Lua** (`hyprland.lua` + `modules/*.lua`) — Hyprland's Lua config API.
  All compositor settings are expressed via the `hl.*` API
  (`hl.config`, `hl.bind`, `hl.monitor`, `hl.window_rule`, `hl.layer_rule`,
  `hl.animation`, `hl.curve`, `hl.env`, `hl.on`, `hl.dispatch`, `hl.exec_cmd`,
  `hl.dsp.*`), **not** via the legacy `hyprland.conf` `key = value` syntax.
- **`*.conf`** files — plain configs for the hypr-ecosystem tools (hypridle,
  hyprlock, hyprpaper, etc.), each with its own format.

## Directory layout

| Path | Purpose |
| --- | --- |
| `hyprland.lua` | Lua entry point. Only job is to `require()` the modules in load order. |
| `modules/variables.lua` | Data-only module. Returns a table of program names/paths. |
| `modules/env.lua` | Environment variables (`hl.env`). |
| `modules/monitors.lua` | Per-display modes, scale, VRR (`hl.monitor`). |
| `modules/input.lua` | Keyboard layout, mouse (`hl.config` input, `hl.device`). |
| `modules/autostart.lua` | Launches services on `hyprland.start`. |
| `modules/rules.lua` | Window/layer rules (`hl.window_rule`, `hl.layer_rule`). |
| `modules/animations.lua` | Gaps, borders, blur, layout, animations (`hl.config`, `hl.animation`). |
| `modules/keybinds.lua` | All keybindings (`hl.bind`, `hl.dsp.*`). |
| `scripts/screenshot` | Bash screenshot helper (see below). |
| `shaders/*.glsl` | GLSL shaders used by hyprshade (`vibrance`, `blue-light-filter`). |

### Ecosystem tools (`*.conf`)

| File | Tool |
| --- | --- |
| `hypridle.conf` | Idle/lock/DPM listener timeouts. |
| `hyprlock.conf` | Lock screen UI (background, labels, input field). |
| `hyprpaper.conf` | Wallpaper (current 0.55+ format, `wallpaper { }` block). |
| `hyprsunset.conf` | Color-temperature profile schedule. |
| `hyprlauncher.conf` | App launcher (finder, UI size). |
| `hyprtoolkit.conf` | hyprtoolkit theming (colors, fonts). |
| `application-style.conf` | Small shared app-style overrides. |
| `hyprqt6engine.conf` | Qt platform theme (Breeze dark, Papirus icons). |

## How the config loads

`hyprland.lua` requires the modules in this order:

```lua
require("modules.env")
require("modules.monitors")
require("modules.input")
require("modules.autostart")
require("modules.rules")
require("modules.animations")
require("modules.keybinds")
```

Rules that matter when editing:

- **`modules/variables.lua` is intentionally NOT in the entry-point require
  list.** It is a pure data table pulled in by the modules that need it via
  `local programs = require("modules.variables")` (currently `autostart.lua`
  and `keybinds.lua`). Keep it that way: add shared program names there and
  `require` it in the modules that use them — do not duplicate globals into
  `keybinds.lua`.
- **`modules/rules.lua` rules are evaluated top to bottom; later rules
  override earlier ones.** Order is meaningful. Don't reorder casually.
- Adding a new module = create `modules/<name>.lua` AND add a `require` line
  in `hyprland.lua`. The file does nothing unless required.

## How to test changes

There is no build/test step. To apply changes to a running session:

- **Reload** (hot-reloads the config): `SUPER + SHIFT + C`
  → `hyprctl reload`. Use this after editing any `.lua` or `*.conf`.
- **`hl.permission` / ecosystem permission changes** (the commented
  `hl.config({ ecosystem = { enforce_permissions = true } })` block in
  `hyprland.lua`) require a **full Hyprland restart**, not a reload.

## Conventions to follow

- **Main modifier is `SUPER`** (`modules/variables.lua` → `main_mod`), set via
  `hl.bind(mainMod .. " + ...", ...)` string concatenation, not literal keys.
  Keep new binds going through `mainMod`/`programs.*` rather than hard-coding.
- **Program names live in `modules/variables.lua`**
  (`terminal=ghostty`, `file_manager=dolphin`, `launcher=hyprlauncher`,
  `browser=firefox`, `chat=discord`, `screenshot=<script path>`). Reference
  them, don't re-type the strings.
- **Window placement of known apps is done with window rules in
  `modules/rules.lua`** (e.g. firefox→ws2, discord→ws6, qBittorrent→ws8), not
  by attaching exec prefixes in autostart. Add new "always-on-workspace-N"
  apps there.
- **Blur for the shell panels** (`senta-*` layer namespaces) is configured via
  `hl.layer_rule` in `modules/rules.lua` with `ignore_alpha = 0.12` so blur
  stays confined to painted regions.
- **`scripts/screenshot`** is a standalone bash script with
  `set -euo pipefail`. It is intentionally environment-overridable:
  `SCREENSHOT_DIR`, `SCREENSHOT_FREEZE`, `SCREENSHOT_NOTIFY_MS`. Required
  deps: `grim`, `wl-copy`; per-mode deps: `slurp`, `hyprctl`+`jq`, `satty`.
  Preserve the env-var override behavior and the "never overwrite an existing
  screenshot" logic in `new_path()`.
- **`hl.monitor` entries are per-physical-connector** (e.g. `DP-1`,
  `HDMI-A-2`) plus an empty-`output` fallback. Verify real connector names
  with `hyprctl monitors all` before editing; don't assume names.
- **`hl.env` graphics/tweaks** are commented out deliberately (e.g.
  `ELECTRON_OZONE_PLATFORM_HINT` removed in Electron 38, NVIDIA
  `AQ_DRM_DEVICES` override) — leave comments explaining why they're off.

## Known stale bits (flag if touching)

- `modules/rules.lua` top comment says `~/.config/hypr/windowrules.lua` /
  `require("windowrules")` — it actually lives at `modules/rules.lua` and is
  loaded as `modules.rules`. The comment is out of date.
- `modules/monitors.lua` references a "180 Hz mode ... in your original
  config" — monitor modes (`2560x1440@180`, `@144`) are hardware-specific and
  must be re-verified on any hardware change.

## Do / Don't quick list

- ✅ Add shared programs to `variables.lua`; require the module in consumers.
- ✅ New module → add the `require` in `hyprland.lua`.
- ✅ Order matters in `rules.lua`; treat it as append-mostly.
- ❌ Don't re-introduce legacy `hyprland.conf` `key = value` syntax — this is
  the Lua config.
- ❌ Don't reorder `rules.lua` to "tidy up" without checking for overrides.
- ❌ Don't assume monitor connector names — verify with `hyprctl monitors all`.
