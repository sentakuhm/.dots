# AGENTS.md

## Project overview

**Senta** is a modular dark desktop shell for **Quickshell 0.3.2** on **Arch Linux + Hyprland 0.57** (Lua config). It is a Qt/QML application, not a Waybar-style theme: a top bar + rounded screen frame, app launcher, notifications (toasts + center), workspace strip with hover thumbnails, and — hosted via a custom C++ QML plugin — a bottom-edge **dashboard** (Dashboard / Media / Performance / Weather), a **quick menu**, and the **Mando** settings window.

The repo *is* the live config directory (`~/.config/quickshell`). There is no separate source tree; `shell.qml` is the entry point.

## Repository layout

| Path | What |
| --- | --- |
| `shell.qml` | Shell root. First line is a pragma (see Pitfalls). "User settings" property block near the top is the main user-facing config surface. |
| `Theme.js` | `.pragma library` — TokyoNight Night palette, fonts, icon font. All colours come from here; do not hardcode hex colours in components. |
| `components/` | Shared QML: bar parts, `NotifStore`/`NotifPopups`/`NotifCard`/`NotifCenter`, `PopupSurface`, `ScreenFrame`, `controls/` (styled Quick Controls 2 items), `containers/`, `effects/`, `filedialog/`. `DashboardSlot.qml` / `UtilitiesSlot.qml` are the safe lazy-load wrappers for the plugin-backed hosts. |
| `services/` | Event-driven QML services: `Audio` (PipeWire), `Hypr` (Hyprland), `Nmcli` (NetworkManager), `Players` (MPRIS), `Weather`/`WeatherLocation`, `VPN`, `Wallpapers`, `Recorder`, `Time`, `Colours`. |
| `daemons/` | Long-running toggles: `GameMode.qml`, `IdleInhibit.qml` (behind quick-menu cards). |
| `modules/dashboard/` | The four dashboard tabs and their content (uses the `Sentaku.*` QML modules). |
| `modules/sentadash/` | Senta's hosts: hover zones, input masks, panels and backgrounds for dashboard + quick menu. |
| `modules/utilities/` | Quick menu cards (`cards/`), recording list, idle inhibit. |
| `modules/mando/` | Mando settings window: `PageRegistry`/`PageCompRegistry` + `pages/` + `common/` row controls + `navpane/`. |
| `utils/` | Helpers: `Icons.qml` (nerd-font glyphs), `Paths.qml`, `Strings.qml`, `SysInfo.qml`, `Searcher.qml`, `NetworkConnection.qml`, vendored `scripts/` JS (fzf/fuzzysort). |
| `plugin/` | C++20 QML plugin source (modules `Sentaku`, `Sentaku.Config`, `Sentaku.Services`, `Sentaku.Components`, ...). Derived from the Sentaku project (GPL v3, see `NOTICE`). |
| `CMakeLists.txt` | Build entry point for `plugin/` (normally driven by the script below). |
| `scripts/` | `build-sentaku-plugin.sh` (builds + installs `plugin/`), `install-sentaku-data.sh` (seeds `sentaku/` data, never overwrites), `dashboard-doctor.sh` (verifies everything), `apps.sh` (launcher app list, JSON via jq), `network-info.sh` (nmcli summary). |
| `sentaku/` | Data seeded into `~/.config/sentaku` (`shell.json`) and `~/.local/state/sentaku` (`scheme.json`). |
| `hyprland-*-snippet.lua` | Snippets to append into the user's Hyprland Lua modules (autostart, keybinds, blur layers, window rules). Not run by Quickshell. |
| `docs/` | `SENTAKU-DASHBOARD.md` (setup/tuning/troubleshooting for the plugin-backed panels), `COMMUNITY.md`. |
| `assets/` | Wallpaper, logo, fonts (Google Sans Flex, licensed), and the dashboard profile picture (`face`, `Paths.face`). |

## Stack & versions

- Quickshell 0.3.2 (`import Quickshell`, `Quickshell.Hyprland`, `.Wayland`, `.Io`, `.Services.Pipewire`, `.Services.SystemTray`).
- Qt 6.9+ for the C++ plugin (enforced by `scripts/build-sentaku-plugin.sh`; `qt_standard_project_setup(REQUIRES 6.9)`).
- Hyprland 0.57 with **Lua** configuration (`hl.*` API); Arch Linux; PipeWire; NetworkManager.
- Icons are **Symbols Nerd Font** glyphs (`Theme.iconFont`); UI font is **JetBrainsMono Nerd Font**. No icon files to manage.

## Build, run, debug

```bash
quickshell                      # run the shell (autostarted by Hyprland)
qs log                          # logs — check this first on any failure
qs list                        # running instances + loaded config
qs ipc show                    # IPC handlers
notify-send "t" "t"           # test notifications
~/.config/quickshell/scripts/apps.sh | jq length   # test launcher helper
```

- Most QML changes hot-reload. **Changes to `shell.qml`'s first-line pragma require a full restart** (`qs kill` then `qs`), not hot reload.
- QML type checking: `qmlls`. There is no automated test suite; verify with `qs log` + `qmlls`.
- C++ plugin (only when touching `plugin/`): `scripts/build-sentaku-plugin.sh` (cmake + ninja + g++/clang++; installs to `/usr/lib/qt6/qml/Sentaku`, sudo as needed). After plugin work: `scripts/dashboard-doctor.sh`, then restart Quickshell. Removing the plugin: `sudo rm -rf /usr/lib/qt6/qml/Sentaku`.
- Plugin build uses strict warning flags (`-Wall -Wextra -Wpedantic -Wshadow -Wconversion -Wold-style-cast ...`, C++20, `QT_NO_CAST_FROM_ASCII` etc.) — new C++ must compile clean under them.

## IPC

Target **`senta`**: `qs ipc call senta <fn>`. Handlers (in `shell.qml` `IpcHandler`): `toggleBar`, `toggleCalendar`, `toggleNotifications`, `toggleDnd`, `togglePower`, `toggleDashboard`, `openDashboard <0-3>`, `closeDashboard`, `toggleUtilities`, `closeUtilities`, `openSettings`, `closePopups`.

## Conventions

- **Per-screen model**: the shell instantiates bar/frame/popups per connected screen via `Variants { model: Quickshell.screens }` with one `Scope` per delegate. New screen-level UI goes inside that `Scope`; per-screen state via `targetScreen`.
- **Theme**: colours/opacity from `Theme.js` only (glass: translucent backgrounds, opaque text). Fonts/icons from `Theme.js`.
- **Popups**: all shell popups are drawn on `components/PopupSurface.qml` (concave fillets blending into the bar). Use it for new popups rather than custom backgrounds.
- **Services over polling**: prefer Quickshell's native integrations and the existing `services/`; poll only values with no event-driven service. Keep the shell light: one Quickshell process.
- **Hyprland calls**: use the 0.55+ Lua dispatch style — `hyprctl eval` with `hl.dispatch(hl.dsp.focus(...))`, not old `hyprctl dispatch workspace N`.
- **Hyprland Lua snippets**: the `hyprland-*-snippet.lua` files are appended at top level of the user's Hyprland Lua modules, never inside `hl.on("hyprland.start", ...)`.
- **Plugin-backed code is optional**: dashboard/quick menu/Mando load through `DashboardSlot`/`UtilitiesSlot`, which tolerate a missing plugin (rest of the shell still boots). Keep it that way.
- **Mando pages** register through `modules/mando/PageRegistry.qml` / `PageCompRegistry.qml`; new pages follow the existing `pages/` + `common/` row patterns.
- **Data**: `sentaku/` JSON is seeded once (`install-sentaku-data.sh`, never overwrites); runtime data lands in `~/.config/sentaku` and `~/.local/state/sentaku`.
- **Licensing**: code derived from the Sentaku project is GPL v3 (`NOTICE`, `LICENSE`). Keep derived files' provenance intact when editing.

## Pitfalls (learned, documented in code comments)

- Line 1 of `shell.qml` must stay `//@ pragma UseQApplication` — required for native StatusNotifier tray menus. Changing it needs a full Quickshell restart.
- `Hyprland.workspaces` (and toplevels) are `UntypedObjectModel`: iterate `.values`, never `.length`/`[i]` indexing.
- A QML object literal (`{}`) in a *property declaration* is not a JS object — property writes are silently lost and `Object.keys()` throws. Use `new Object()` (see `_wsSeen`/`_wsPending` in `shell.qml`).
- Only one notification daemon: Senta's `NotificationServer` owns `org.freedesktop.Notifications` while running. Don't enable SwayNC/Mako/Dunst autostarts alongside it.
- `scripts/apps.sh` output format (JSON array via jq) is consumed by the launcher; `scripts/network-info.sh` assumes NetworkManager — both are the extension points for non-NM setups.

## Docs to read before deeper work

- `README.md` — bar layout, interactions, install, Hyprland wiring, troubleshooting.
- `docs/SENTAKU-DASHBOARD.md` — everything about the plugin, dashboard, quick menu, Mando, and its doctor script.
