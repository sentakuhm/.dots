# Senta — Quickshell starter for Hyprland

A modular, dark starter shell for **Quickshell 0.3.2** on Arch Linux + Hyprland 0.57.
It keeps the same left / center / right organisation as your Waybar config.


## Rounded screen frame (Caelestia style, bar on top)

Senta draws a solid frame around the output, in the same colour as the bar, so the visible desktop area has rounded corners on all four sides, like [caelestia-dots/shell](https://github.com/caelestia-dots/shell). The bar stays on top and forms the top edge of the frame; `components/ScreenFrame.qml` adds the left / right / bottom strips and the rounded inner corners (including the two directly under the bar).

- `screenCornerRadius` (default `14`) sets the inner corner radius. Smaller values push the curve tighter into the screen corners and make the corner pieces of the frame thinner; larger values (caelestia uses `25`) give a softer, bulkier corner.
- `frameThickness` (default `3`) sets the width of the left / right / bottom strips. Three tiny 1×1 exclusion surfaces reserve that space so tiled windows never sit under the frame.
- The frame uses `Theme.bg`, so it always matches the bar and the two read as one flat piece. For a thin `Theme.border` outline along the whole inner edge, set `frameBorderWidth: 1` in `shell.qml` (default `0`).
- The bar uses `ExclusionMode.Ignore` so it spans the full screen width; the frame's top edge-zone reserves `barExclusiveZone` (default `48`) below it.
- Clicks pass straight through the desktop area; only the frame ring itself takes input.
- Hiding the bar (`SUPER + ALT + B`) closes the top edge with a normal-thickness strip, so the frame stays complete.
- The frame is on the Top layer, so fullscreen windows (video, games) cover it.
- Bar items sit `barSidePadding` (default `5`) px from the screen edges. Every pill, workspace button and tray icon also accepts clicks across the full bar height, and the first (Arch logo) and last (power) hit areas extend to the screen edge, so slamming the cursor into a corner or the top edge still hits them instead of empty bar.
- Every shell popup (app launcher, calendar, power, workspace hover preview, notification center and notification toasts) is drawn by `components/PopupSurface.qml`: a subtly lifted TokyoNight blue-violet surface (`Theme.popupBg`), no gap (it overlaps the bar by 1 px to hide seams), rounded bottom corners and small concave corners where it joins the bar. The calendar is centred under the clock; the app launcher is attached beneath the Arch logo at the left frame; power, notifications and toast panels attach to the right frame. `popupFillet` (default `14`) sets the concave radius; `0` gives a plain flush box. Native menus (tray right-click menus) and tooltips are drawn by the toolkit and cannot be restyled this way.
- For the cleanest look, keep Hyprland's `gaps_out` small (roughly 5-10 px).

## What is included

### Bar layout

- **Left:** Arch logo (click opens the app launcher popup), then the workspace strip — always workspaces 1–`maxWorkspaces` (default 6), plus any workspace beyond that which currently has open windows (auto-appended in id order), so the active ones are always visible. The focused workspace keeps its accent highlight; workspaces with open windows get a lighter highlight plus a nerd-font icon (`activeWorkspaceIcon`), and hovering one opens a popup with live thumbnails of its open windows (wlr-screencopy) and their titles.
- **Center:** focused window title, centred in the bar (`"Desktop"` when no window is focused).
- **Right:** StatusNotifier system tray, keyboard layout, notifications, network, output volume, microphone volume, clock, power.

### Interactions

- Click the Arch logo to open the app launcher, attached directly below the bar and flush with the left frame. The search field stays at the top; results use Caelestia-inspired icon/name/description rows, a highlighted selection, and a compact no-results state. Type to filter by name, generic name, comment, keywords, category or desktop-entry id; Up/Down changes the selection, Enter launches it, Esc closes the popup, and clicking a row launches it. The list scrolls when there are more than seven results. Entries with `Terminal=true` open in Kitty. The list comes from `scripts/apps.sh`, which parses `~/.local/share/applications`, `/usr/local/share/applications` and `/usr/share/applications` (local entries win on duplicate ids) and refreshes every 10 minutes. Application icon names are resolved at runtime with `Quickshell.iconPath()`, so they follow the active Qt platform icon theme. With `QT_QPA_PLATFORMTHEME=kde`, the launcher uses the icon theme selected in KDE (Papirus-Dark on this setup); absolute icon paths in desktop entries are preserved. No `IconTheme` pragma is set, so the shell does not override the system choice.
- The clock shows the time only; click it to open a month calendar (which shows the date); use the arrows to change months.
- Click a workspace number to switch to it. The workspace click calls `hyprctl eval` with `hl.dispatch(hl.dsp.focus(...))`, matching Hyprland 0.55+ Lua configuration. It intentionally does not use the old `hyprctl dispatch workspace N` syntax.
- Click the notification icon to open the notification center; right-click it to toggle DND.
- Notifications follow Caelestia's design (`NotifStore`, `NotifPopups`, `NotifCard`, `NotifCenter` in `components/`):
  - New notifications appear as a stack of toasts at the top-right that slides in from the screen edge, newest on top (max 5). Hovering a toast pauses its timer, and critical notifications stay until dismissed.
  - Click a card (or its chevron) to expand it: app name, full text, the app's actions and a Close button. Swipe a toast sideways to hide it (it stays in the center), middle-click to close it for good.
  - The center (bell icon) groups notifications by app with a count, collapsible groups, per-group clear, DND, Clear all and inline replies when the app offers them.
  - DND suppresses toasts but still collects notifications in the center.
  - Tweak the toast width / count in `NotifPopups.qml` (`cardWidth`, `maxToasts`) and the default toast time (5 s, used when the app sets none) in `NotifStore.qml`.
- Tray icons activate on left-click; right-click opens the app's StatusNotifier menu; middle-click invokes its secondary action.
  Native tray menus need Quickshell in QApplication mode, which `shell.qml` enables with `//@ pragma UseQApplication` on its first line. Keep it there, and restart Quickshell (not just hot-reload) after changing it.
- Click output or microphone to mute; scroll over either to adjust volume.
- Click the network pill to open `nmtui` in Kitty. On wired connections the pill shows the icon only (no "Ethernet" text).
- The keyboard pill only shows the active layout as `EN` / `ARA`; it does not switch layouts. Layout switching is handled by your existing Hyprland keybind config.
- Click the power icon for lock, suspend, logout, reboot, and shutdown.

The tray, notifications, Hyprland workspaces and PipeWire controls use Quickshell's built-in integrations. The app list and the network summary are read by small helper scripts; the active keyboard label is read inline from `hyprctl` (no external script).

## Install

Install the official Quickshell release and the optional helpers used by this starter:

```bash
sudo pacman -S quickshell ttf-nerd-fonts-symbols jq networkmanager
```

The icon glyphs come from **Symbols Nerd Font**; no separate SVG downloads are needed. Refresh the font cache after installing it:

```bash
fc-cache -f
```

You already use Kitty and Hyprlock. The audio widgets expect a working PipeWire session (normally `pipewire`, `pipewire-pulse`, and `wireplumber` on Arch). For the network pill, use NetworkManager and make sure its service is running:

```bash
sudo systemctl enable --now NetworkManager
```

Skip that service command if you use a different network stack; in that case, adapt `scripts/network-info.sh` to your setup.

Install the config:

```bash
unzip senta-quickshell.zip
cd senta-quickshell
./install.sh
```

The installer backs up an existing `~/.config/quickshell` before replacing it.

Then launch it once to test:

```bash
quickshell
```

To inspect errors:

```bash
qs log
qs ipc show
```

## Glass opacity and blur (TokyoNight Night)

The shell backgrounds use translucent TokyoNight colours (bar about 85% opaque, popups about 86%, inner surfaces about 80–85%). Foreground text and icons remain fully opaque. Hyprland supplies the background blur; the QML opacity alone does not create blur.

1. Add the contents of `hyprland-blur-snippet.lua` at top level in a Hyprland Lua module loaded by your `hyprland.lua` (for example, append it to `~/.config/hypr/modules/settings.lua`). Do not put it inside `hl.on("hyprland.start", ...)`.
2. Reload Hyprland with `hyprctl reload` and restart Quickshell (`qs kill` then `qs`).
3. If you already have a `decoration.blur` block, merge the values from the snippet into it rather than duplicating the same settings.

The layer rules target `senta-bar` (including its anchored app/calendar/power popups), `senta-notifications`, and `senta-frame`. The screen-edge exclusion layers are intentionally excluded. If blur does not appear, run `hyprctl layers` and confirm those three namespaces are listed; the `senta-bar` rule also enables `blur_popups` for the bar's child popups.

## Connect it to your existing Hyprland Lua config

### 1. Autostart

Open `~/.config/hypr/modules/autostart.lua` and add this line inside your existing `hl.on("hyprland.start", function() ... end)` callback:

```lua
hl.exec_cmd("quickshell")
```

Do not add a second `hl.on("hyprland.start", ...)` callback just for Quickshell. Also remove/disable any Waybar autostart command so you do not get two bars.

### 2. Keybindings

Append the contents of `hyprland-keybinds-snippet.lua` to your existing `~/.config/hypr/modules/keybinds.lua`, then reload Hyprland.

| Binding | Action |
|---|---|
| `SUPER + N` | Notification center |
| `SUPER + SHIFT + N` | Do not disturb |
| `SUPER + C` | Calendar |
| `SUPER + ALT + P` | Power menu |
| `SUPER + ALT + B` | Hide/show bar |

These are additive bindings; check that you have not assigned the same combinations elsewhere.

## Settings to customise

Open `~/.config/quickshell/shell.qml` and edit the settings block near the top:

```qml
property int barHeight: 36
property int barSidePadding: 5
property int popupFillet: 14
property int screenCornerRadius: 14
property int frameThickness: 3
property bool showWindowTitle: true
property bool showTray: true
property bool showPowerButton: true
property var apps: []            // populated by scripts/apps.sh
property bool appsOpen: false    // app launcher popup state
property string appsQuery: ""    // launcher search query
property int maxWorkspaces: 6            // baseline workspace slots always shown
property bool showActiveWorkspace: true  // lighter highlight + icon on workspaces with open windows
property bool showActiveWindow: true     // hover a workspace to see its open window(s)
property string activeWorkspaceIcon: "\u{eb7f}"  // nerd-font glyph on active workspaces (nf-cod-window; swap to any glyph)
```

Workspace strip: the bar always shows workspaces 1–`maxWorkspaces`, and appends any workspace beyond that which has open windows, in id order. The focused workspace keeps the strong accent highlight; the other workspaces with open windows get the lighter `Theme.accentActive` highlight and the icon. Set `showActiveWorkspace: false` to disable the active highlighting, `showActiveWindow: false` to disable the hover popup.

The colour palette and fonts live in `Theme.js`. The icons use the **Symbols Nerd Font** font installed by `ttf-nerd-fonts-symbols`; you do not need to download individual icon files.

## Notifications: important

Quickshell's `NotificationServer` owns `org.freedesktop.Notifications` while this config is running. Do not run multiple notification daemons at once. If you currently autostart SwayNC, Mako, Dunst, or another notification daemon, disable that autostart entry before using this notification module.

The notification center keeps tracked notifications in the running shell and across Quickshell hot reloads. This starter does **not** write a permanent on-disk notification archive; dismissed notifications are removed.

## Hardware notes

- Network status uses NetworkManager's `nmcli`. If you use iwd/systemd-networkd without NetworkManager, replace `scripts/network-info.sh` with a helper for your network stack; the rest of the bar still works.
- The network pill opens `nmtui` in Kitty; `nmtui` is provided by the `networkmanager` package itself.

## Useful community directions

Quickshell is closer to a small Qt/QML desktop shell than a drop-in Waybar theme. It is intentionally more programmable, and the upstream docs recommend studying the QML guide and examples before building large systems.

Good projects to inspect for ideas:

- **HyprQuick** — a HyprPanel-inspired modular bar with a left/center/right layout, calendar/weather, Wi-Fi and notification popups.
- **fbuedding/quickshell** — useful examples of a polished bar, PipeWire controls, MPRIS media, calendar and DBusMenu tray handling.
- **doannc2212/quickshell-config** — a modular bar, launcher, notification daemon, OSD and wallpaper manager; good for studying reusable modules.
- **hyprbar** — a lean top bar with configurable metrics, input/output volume controls and practical notes about Hyprland Lua mode.
- **Caelestia** and **Illogical Impulse** — larger, preconfigured desktop shells that the Quickshell project itself points to as examples of complete setups.

Do not copy a whole config blindly: Quickshell APIs evolve, and many public dotfiles target different release versions. Prefer current docs for your installed version.

## Good next additions

These are the community-style modules I recommend growing this starter into, in this order:

1. **Control center:** Wi-Fi, Bluetooth, DND, audio output/input selectors, brightness and power-profile tiles. This is the most useful next popup.
2. **MPRIS media popover:** now-playing card with album art and play/pause/previous/next; Quickshell already provides a native MPRIS integration.
3. **Battery module:** UPower-based percentage, charging state and low-battery notifications (only relevant on a laptop).
4. **Clipboard history:** keep using Clipse from your current Hyprland setup, or switch to cliphist + wl-clipboard; avoid running two clipboard managers.
5. **Brightness OSD:** brightnessctl + a small overlay when hardware brightness changes.
6. **Wallpaper / theme picker:** integrate your existing wallpaper selector and optionally generate palette changes with Matugen or Wallust.
7. **Notification polish:** urgency styling, per-app filters, notification expiry controls and optional on-disk history.
8. **Settings window:** theme selector, bar density, font scale, monitor-specific visibility and module toggles.

Keep the initial shell light: one Quickshell process, native integrations where available, and polling only for values that do not have an event-driven Quickshell service.

## Troubleshooting

```bash
# See the running Quickshell instance and loaded config
qs list

# Show the shell's IPC handlers
qs ipc show

# Test the notification service
notify-send "Senta test" "Notifications are connected"

# Test the app-list helper directly
~/.config/quickshell/scripts/apps.sh | jq length
```

If `quickshell` fails to load, check `qs log` first. The QML Language Server (`qmlls`) is also useful for catching QML property/type mistakes in an editor.
