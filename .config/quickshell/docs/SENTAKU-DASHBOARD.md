# Sentaku dashboard, quick menu and Mando settings

Three pieces, all hosted by Senta:

- the **dashboard** (Dashboard / Media / Performance / Weather): rest the pointer on the
  bottom centre of the screen and it rises out of the bottom frame; leave it and it slides away;
- the **quick menu** (Wi-Fi, Bluetooth, mic, settings, ...): same idea, from the bottom-right
  corner (see "Quick menu and Mando settings" below);
- **Mando**, the settings window the quick menu opens.

Everything it needs is in this folder, including the source of its C++ QML plugin
(`plugin/`). Nothing is downloaded and no other shell is required.

> **Status: written without being able to run it.** I had no Quickshell, Qt, Hyprland or
> C++ toolchain in my sandbox. What I did verify: the rename is complete and consistent
> (every file equals the original with only the name substitution, apart from five
> deliberate edits), every `import` resolves, every `Sentaku.*` module imported by QML is
> built by the plugin's CMake files, the scripts behave correctly in a throwaway `$HOME`,
> and the panel shape renders correctly. What I could **not** verify: that the plugin
> compiles on your machine, or that the dashboard loads and looks right. The doctor script
> and `qs log` are how you find out; see Troubleshooting.

## Where things are

| Path | What |
| --- | --- |
| `plugin/` | C++ QML plugin source (modules `Sentaku`, `Sentaku.Config`, `.Services`, ...) |
| `CMakeLists.txt` | build entry point for `plugin/` |
| `modules/dashboard/` | the four tabs |
| `modules/sentadash/` | Senta's hosts: hover zones, input masks, panels and backgrounds for the dashboard and the quick menu |
| `modules/utilities/` | the quick menu's cards |
| `modules/mando/` | the Mando settings window |
| `daemons/` | keep-awake and game-mode behaviour behind two quick toggles |
| `components/`, `services/`, `utils/` | shared QML the tabs use (merged next to Senta's own files) |
| `components/DashboardSlot.qml`, `UtilitiesSlot.qml` | the pieces `shell.qml` uses; they load the hosts safely |
| `sentaku/` | data seeded into `~/.config/sentaku` and `~/.local/state/sentaku` |
| `scripts/` | `build-sentaku-plugin.sh`, `install-sentaku-data.sh`, `dashboard-doctor.sh` |
| `NOTICE`, `LICENSE` | origin and licence of the derived code (GPL v3) |

## What you need

| Needed | Why | How |
| --- | --- | --- |
| **Sentaku QML plugin** | Config, tokens, cava/aubio audio analysis, system stats, animations. Needs Qt 6.9+. | `scripts/build-sentaku-plugin.sh` |
| **M3Shapes** | Shape morphing used in six dashboard files | AUR `qt6-m3shapes-git` |
| **Material Symbols Rounded** font | Every dashboard icon is a ligature name (`queue_music`, `speed`, ...). Without the font you see the words. **Symbols Nerd Font cannot replace it.** | package `ttf-material-symbols-variable` |
| `qt6-multimedia`, `qt6-imageformats` | Image/media handling | official repos |
| Build tools + libs | `cmake ninja qt6-base qt6-declarative qt6-shadertools lm_sensors libqalculate aubio pipewire` + **libcava** | you already have libcava and aubio |
| **Quickshell** | The dashboard code targets a recent Quickshell (the git version). Senta targets the 0.3.2 release; if the log shows unknown types or properties, switch to `quickshell-git`. | AUR `quickshell-git` |

**JetBrainsMono Nerd Font** is used for the clock and monospace text (set in
`sentaku/shell.json`), and Symbols Nerd Font keeps serving the rest of Senta. *Google Sans
Flex* (the UI font) is bundled in `assets/`.

## Install

```bash
# 1. Packages (Arch). libcava / aubio you already have.
sudo pacman -S --needed cmake ninja qt6-base qt6-declarative qt6-shadertools \
    qt6-multimedia qt6-imageformats lm_sensors libqalculate aubio pipewire
paru -S qt6-m3shapes-git ttf-material-symbols-variable      # AUR; add quickshell-git if needed

# 2. Build + install the plugin from ./plugin (needs sudo for the install step).
scripts/build-sentaku-plugin.sh

# 3. Seed the colour scheme, wallpaper pointer and settings (never overwrites).
scripts/install-sentaku-data.sh

# 4. Hyprland: add the layer rule from hyprland-blur-snippet.lua (glass blur) and,
#    optionally, the binds from hyprland-keybinds-snippet.lua.

# 5. Check everything, then restart Quickshell.
scripts/dashboard-doctor.sh
```

The compiled plugin installs into Qt's QML directory (`/usr/lib/qt6/qml/Sentaku`), like any
QML module; everything else stays in this folder. To install elsewhere, use
`PREFIX=$HOME/.local scripts/build-sentaku-plugin.sh` and start Quickshell with
`QML_IMPORT_PATH=$HOME/.local/lib/qt6/qml`.

If the plugin or M3Shapes is missing, **the rest of Senta still starts**: only the
dashboard is disabled and `qs log` prints a `[senta] Dashboard disabled` warning with the
exact QML error.

## Using it

- **Hover:** rest the pointer on the strip at the bottom centre of the screen
  (420 x 8 px, ~120 ms delay). Move away and it closes after ~250 ms.
- **Keyboard / IPC:** `qs ipc call senta toggleDashboard`, `openDashboard <tab>`
  (0 Dashboard, 1 Media, 2 Performance, 3 Weather), `closeDashboard`. A panel opened this
  way stays until toggled, or until the pointer has entered and left it. `closePopups`
  also closes it. Suggested binds: `SUPER+ALT+D`, `SUPER+ALT+M`. Opening the dashboard closes the
  quick menu and vice versa.
- **Inside:** click or scroll the tab strip, or swipe horizontally. The Media tab controls
  whichever MPRIS player is active; lyrics and the visualiser come from the plugin.

## Quick menu and Mando settings

Rest the pointer on the strip at the bottom-right of the screen (300 x 8 px) and the menu rises out
of the corner, attached to both the bottom and the right frame. IPC: `qs ipc call senta toggleUtilities`,
`closeUtilities`, `openSettings` (opens Mando directly). Suggested binds: `SUPER+ALT+U`, `SUPER+ALT+S`.

**What is in it, and what it talks to**

| Item | Backend |
| --- | --- |
| Wi-Fi toggle | NetworkManager (`nmcli`) |
| Bluetooth toggle | BlueZ, through Quickshell's Bluetooth module |
| Mic toggle | PipeWire |
| Settings button | opens Mando |
| Game mode toggle | `daemons/GameMode.qml` applies the Hyprland options in `utilities.gameMode.options` and restores them by reloading Hyprland's config |
| Keep awake card | `daemons/IdleInhibit.qml` (Wayland idle inhibitor; also `qs ipc call idleInhibitor toggle`) |
| Do not disturb toggle | bridged both ways with your `NotifStore` (`SUPER+SHIFT+N` and the toggle stay in sync). Senta's state wins at startup, so a stale "on" from the last session never hides notifications |

Hidden by default (`utilities` in `shell.json`), because nothing in Senta can make them work: the
**screen recorder card** (it runs an external recorder command that does not exist), the
**wallpaper-playing toggle** (nothing consumes it) and the **VPN toggle** (needs a provider in the config).
The small status toasts ("Game mode enabled", ...) are not shown: there is no toast surface.

**Mando** is a normal window, so Hyprland needs the rule in `hyprland-windowrules-snippet.lua` to float it
(it matches the initial title, `Mando - <page>`). Its pages:

| Page | State in Senta |
| --- | --- |
| Network, Connected devices, Audio | work: NetworkManager, BlueZ and PipeWire |
| Language & region | works: UI language, weather location, units |
| Services | the settings the dashboard and its services read (poll intervals, lyrics) work; the notification options do not affect Senta's own notification center |
| Panels | Dashboard and Utilities settings work; Taskbar, Launcher and Sidebar edit sections that nothing in Senta reads |
| Apps | edits default apps and launcher favourites; only the default apps are read by anything here |
| Wallpaper & style | changing wallpaper or colour scheme calls an external tool that is not included, so those controls do nothing |
| Updates, Plugins | placeholders |
| About | works |

Settings made in Mando are written to `~/.config/sentaku/shell.json`.

## Tuning

Hot zone, timing and size are properties at the top of `modules/sentadash/DashboardHost.qml` (and the
same set in `UtilitiesHost.qml` for the quick menu):
`triggerWidth`, `triggerHeight`, `openDelay`, `closeDelay`, `maxWidth` (1200), `maxHeight` (820;
also capped at 85 % of the screen height). If the tallest tab gets clipped on a small screen,
raise `maxHeight`.

Everything configurable lives in `~/.config/sentaku/shell.json`, for example:

```json
{
  "dashboard": { "showWeather": false, "performance": { "showGpu": false } },
  "services": { "weatherLocation": "Paris" },
  "general": { "logo": "sentaku" }
}
```

- **Weather privacy:** with no `services.weatherLocation`, the weather service looks up your
  location from your IP address (ip-api.com), then queries open-meteo / OpenStreetMap
  Nominatim. Set `weatherLocation` (a city name or `"lat,lon"`) to avoid the IP lookup (the
  place is still geocoded online). Its requests identify themselves as `sentaku-shell`
  with no contact URL; add one in `services/Weather.qml` and
  `plugin/src/Sentaku/Services/lyrics.cpp` if a service you use requires it.
- **Colours:** `~/.local/state/sentaku/scheme.json` is a Tokyo Night palette. Delete it to
  get the built-in pink palette.
- **Glass:** `shell.json` enables transparency (`base 0.85`, the same alpha as Senta's bar
  and frame, so the panel joins the frame seamlessly). Set
  `appearance.transparency.enabled` to `false` for an opaque panel.
- **Logo:** the profile card shows your distro's logo. `"general": {"logo": "sentaku"}`
  shows the placeholder mark in `components/Logo.qml` + `assets/logo.svg`; replace both with
  your own artwork (only the `topColour` / `bottomColour` interface matters).

## Notes

- **Host.** The panel is hosted by `modules/sentadash`: `DashboardHost` (hot zone, input
  mask, hover logic), `DashboardPanel` (an adapted copy of `modules/dashboard/Wrapper.qml`
  that slides from the bottom; the original is kept beside it, unused) and `BottomSurface`
  (the background, a bottom-edge sibling of `PopupSurface`).
- **One edited tab-side file:** `components/controls/Menu.qml` (the dropdown used by the
  player and disk selectors) has a marked `SENTA PATCH` that replaces a cast to a window
  type that isn't part of this config with an `interactionWrapper` lookup.
- **No external CLI.** The wallpaper, scheme-switching and recording services call a
  `sentaku` command that does not exist; nothing in the dashboard calls them. `install-sentaku-data.sh`
  pre-seeds `wallpaper/path.txt` so the wallpaper service doesn't try at startup.
- **Side effects of the bundled services:** `qs ipc` targets `mpris`, `audio`, `hypr` and
  `wallpaper`, and global shortcuts under the `sentaku` app id. None are bound unless you
  bind them, and none clash with Senta's `senta` target.
- **Environment variables:** `SENTAKU_WALLPAPERS_DIR`, `SENTAKU_RECORDINGS_DIR`,
  `SENTAKU_LIB_DIR` and `SENTAKU_XKB_RULES_PATH` override the matching paths.

## Troubleshooting

- **Bar works, no dashboard:** `qs log | grep -i -A8 "Dashboard disabled"` shows the QML error
  (usually a missing module). `scripts/dashboard-doctor.sh` lists what is missing.
- **Icons appear as words** (`dashboard`, `queue_music`): Material Symbols Rounded is not
  installed (`fc-list | grep -i "material symbols"`).
- **Pink instead of Tokyo Night:** `~/.local/state/sentaku/scheme.json` is missing or invalid.
- **Hot zone does nothing:** confirm the layer exists with `hyprctl layers` (look for
  `senta-dashboard`). Fullscreen windows cover the Top layer, same as the frame.
- **Panel not blurred:** the `senta-dashboard` layer rule is missing from your Hyprland config.
- **Quick menu missing, bar fine:** `qs log | grep -i "Quick menu disabled"` shows the QML error.
- **Mando opens tiled:** add `hyprland-windowrules-snippet.lua` to your Hyprland config.
- **Wi-Fi / Bluetooth toggles do nothing:** NetworkManager (`nmcli`) / BlueZ must be running;
  `scripts/dashboard-doctor.sh` checks for both tools.
- **Errors about unknown types/properties:** try `quickshell-git`.
- **Plugin build fails:** the script names a missing dependency; Qt older than 6.9 is the
  usual cause. The build directory is `~/.cache/sentaku-plugin-build`.
- **Config problems:** the plugin logs under the `sentaku.*` categories, e.g.
  `QT_LOGGING_RULES="sentaku.*=true" quickshell`.
