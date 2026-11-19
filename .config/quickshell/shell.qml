//@ pragma UseQApplication
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import "components"
// Registers the dashboard host files with Quickshell (they are instantiated lazily by
// components/DashboardSlot.qml, so a missing plugin only disables the dashboard).
import "modules/sentadash"
import "Theme.js" as Theme

ShellRoot {
    id: root

    // ---------------------------------------------------------------------
    // User settings — edit these first.
    // ---------------------------------------------------------------------
    property string shellName: "Senta"
    property int barHeight: 36
    property int barSidePadding: 5       // gap from the screen edge to the first / last bar item
    property int frameThickness: 3         // frame width on left / right / bottom (2-6 = barely visible)
    // Top zone = bar + the same extra as the frame strips, so the gap between the
    // window and the bar equals the gaps on the left / right / bottom.
    property int barExclusiveZone: barHeight + frameThickness
    property int popupFillet: 14          // concave corners where popups blend into the bar (0 = plain flush)
    property int screenCornerRadius: 14   // inner corner radius of the frame (smaller = tighter into the corners)
    readonly property int popupRightInset: Math.max(0, frameThickness - 1)   // right-attached popups overlap the frame by 1 px
    readonly property int popupLeftInset: Math.max(0, frameThickness - 1)    // left-attached popups overlap the frame by 1 px
    // Frame-attached popups (app launcher, power menu, notification center) are drawn this many px
    // PAST the screen edge, underneath the frame, so there is never a sliver of wallpaper between a
    // popup and the frame even if the compositor places the popup a pixel or two off. Off-screen, so
    // it costs nothing; raise it if you still see a hairline, 0 gives the old behaviour.
    property int popupEdgeBleed: 8
    // The outer ring of every bar popup is painted by the screen frame (see ScreenFrame `rings`)
    // instead of by the popup itself. A popup is drawn after the bar and frame, so the compositor
    // blurs those dark neighbours into the popup's background and its ring comes out darker than
    // the bar. The frame is drawn before the bar, so its rings match the bar exactly. Set to false
    // to go back to each popup drawing its own ring. The same switch covers the bottom panels
    // (dashboard, quick menu): the frame paints their whole background instead of them.
    property bool frameDrawsPopupRings: true
    // Size of the two bottom panels (dashboard, quick menu) relative to their original size: the
    // whole content is scaled, so 0.7 brings them down to the size of the bar popups. 1 = original
    // size; try 0.6 for smaller or 0.8 for larger.
    property real bottomPanelScale: 0.7
    property real frameBorderWidth: 0      // 0 = flat frame, 1 = thin outline along the inner edge
    property bool showWindowTitle: true
    property bool showTray: true
    property bool showPowerButton: true
    // App launcher (opens from the Arch logo on the left).
    property var apps: []
    property bool appsOpen: false
    property string appsQuery: ""

    // Workspace strip. Baseline 1..maxWorkspaces; any workspace beyond that with
    // open windows is auto-appended (so you always see the active ones).
    property int maxWorkspaces: 6
    property bool showActiveWorkspace: true   // lighter highlight for workspaces with open windows
    property bool showActiveWindow: true      // hover a workspace to see its open window(s)
    property string activeWorkspaceIcon: "\u{eb7f}"   // nf-cod-window (U+EB7F); swap to any glyph you prefer
    // "Needs attention" marker: when a window opens on a workspace you are not
    // on (e.g. a link in the terminal opens Firefox on another workspace),
    // that workspace is painted purple until you switch to it or close the
    // window.
    property bool showWorkspaceActivity: true
    property string workspaceActivityColor: Theme.activity
    property string workspaceActivitySoft: Theme.activitySoft

    // Shared state for all panels and their popups.
    property bool barVisible: true
    property bool calendarOpen: false
    property bool notificationsOpen: false
    property bool powerOpen: false
    property date now: new Date()
    property var networkData: ({ kind: "offline", label: "Offline", name: "Disconnected" })
    property string keyboardLayout: "EN"

    // Live list of workspace slots to show: baseline 1..maxWorkspaces, plus any
    // workspace beyond that which currently has open windows (auto-appended).
    // Each entry carries focused/active state, the open window titles and the
    // toplevel objects (used for the hover preview thumbnails).
    //
    // Hyprland.workspaces is an UntypedObjectModel: iterate .values, not .length.
    // The model is recomputed on workspace/focus changes plus a short poll as a
    // safety net (per-workspace toplevels changes are not all surfaced as events
    // on the workspaces model itself).
    property var workspaceModel: []
    property string _wsSig: ""
    property int wsHoverId: 0
    property real wsHoverX: 0
    property var wsPreview: []
    // Silent-open tracking: previous per-workspace window keys, and the
    // workspaces currently marked as "needs attention".
    // NOTE: must be `new Object()`, not a `{}` literal — a QML object literal in a
    // property declaration is not a JS object: property writes are silently lost and
    // Object.keys()/for-in throw "Value is undefined and could not be converted".
    property var _wsSeen: new Object()
    property var _wsPending: new Object()

    function _wsWindowKey(t) {
        const addr = t.address
        if (addr && String(addr).length > 0) return String(addr)
        // Toplevels without a reported address (rare) fall back to title + monitor.
        return "~" + (t.title || "") + "@" + ((t.monitor && t.monitor.name) || "")
    }

    function recomputeWorkspaceModel() {
        const focusId = (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1)
        const wss = (Hyprland.workspaces && Hyprland.workspaces.values) ? Hyprland.workspaces.values : []
        const byId = {}
        for (let i = 0; i < wss.length; ++i) byId[wss[i].id] = wss[i]
        const ids = []
        for (let i = 1; i <= maxWorkspaces; ++i) ids.push(i)
        for (let i = 0; i < wss.length; ++i) {
            const ws = wss[i]
            const tl = (ws.toplevels && ws.toplevels.values) ? ws.toplevels.values : []
            if (ws.id > maxWorkspaces && tl.length > 0) ids.push(ws.id)
        }
        ids.sort((a, b) => a - b)
        // Silent-open detection: a window key that is new to a workspace marks
        // that workspace, unless that workspace is the one you are currently
        // on. A marker survives until you focus the workspace or the new
        // window(s) close. The first pass only seeds the key snapshots, so
        // starting the shell never paints every workspace with open windows
        // purple.
        const seen = root._wsSeen
        const pending = root._wsPending
        const firstPass = Object.keys(seen).length === 0
        for (const id of ids) {
            const ws = byId[id]
            const tl = (ws && ws.toplevels && ws.toplevels.values) ? ws.toplevels.values : []
            const keys = []
            for (let j = 0; j < tl.length; ++j) keys.push(root._wsWindowKey(tl[j]))
            if (!firstPass) {
                const prev = seen[id] || []
                // Keep only the markers whose window is still open...
                const unseen = (pending[id] || []).filter(function (k) { return keys.indexOf(k) !== -1 })
                // ...and add windows that just appeared on this workspace.
                if (id !== focusId) {
                    for (let j = 0; j < keys.length; ++j) {
                        const k = keys[j]
                        if (prev.indexOf(k) === -1 && unseen.indexOf(k) === -1) unseen.push(k)
                    }
                }
                if (unseen.length > 0) pending[id] = unseen
                else delete pending[id]
            }
            seen[id] = keys
        }
        // Looking at a workspace makes all its new windows seen.
        if (pending[focusId]) delete pending[focusId]
        for (const id in seen) {
            if (ids.indexOf(Number(id)) === -1) {
                delete seen[id]
                delete pending[id]
            }
        }
        const items = []
        for (const id of ids) {
            const ws = byId[id]
            const tl = (ws && ws.toplevels && ws.toplevels.values) ? ws.toplevels.values : []
            const titles = []
            for (let j = 0; j < tl.length; ++j) {
                const t = tl[j].title
                if (t && t.length > 0) titles.push(t)
            }
            // Workspaces with an urgent client (requested attention) count too.
            items.push({ id: id, focused: id === focusId, active: titles.length > 0,
                         pending: !!pending[id] || !!(ws && ws.urgent), titles: titles, toplevels: tl })
        }
        const sig = items.map(function (i) {
            return i.id + (i.focused ? "F" : "") + (i.active ? "A" : "") + (i.pending ? "P" : "") + "][" + i.titles.join("\u0000")
        }).join("|")
        if (sig !== root._wsSig) {
            root._wsSig = sig
            root.workspaceModel = items
        }
        // Keep the hover preview in sync when the hovered workspace changes contents.
        if (root.wsHoverId > 0) {
            for (const item of items) {
                if (item.id === root.wsHoverId) {
                    root.wsPreview = item.toplevels.map(function (t) { return { title: t.title || "", toplevel: t } })
                    break
                }
            }
        }
    }

    Connections {
        target: Hyprland
        function onFocusedWorkspaceChanged() { root.recomputeWorkspaceModel() }
        function onActiveToplevelChanged() { root.recomputeWorkspaceModel() }
    }
    Connections {
        target: Hyprland.workspaces
        function onDataChanged() { root.recomputeWorkspaceModel() }
        function onLayoutChanged() { root.recomputeWorkspaceModel() }
        function onValuesChanged() { root.recomputeWorkspaceModel() }
    }
    // The global toplevel model fires the moment any window opens or closes,
    // so silent opens get marked without waiting for the poll timer.
    Connections {
        target: Hyprland.toplevels
        function onDataChanged() { root.recomputeWorkspaceModel() }
        function onLayoutChanged() { root.recomputeWorkspaceModel() }
        function onValuesChanged() { root.recomputeWorkspaceModel() }
    }
    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: root.recomputeWorkspaceModel()
    }

    // Hyprland 0.55+ uses the Lua configuration API. For workspace clicks,
    // evaluate a Lua dispatcher object rather than sending the legacy
    // "workspace N" dispatcher string.
    function focusWorkspace(id) {
        const target = String(id)
        Quickshell.execDetached([
            "hyprctl", "eval",
            'hl.dispatch(hl.dsp.focus({ workspace = "' + target + '" }))'
        ])
    }

    function logoutSession() {
        Quickshell.execDetached([
            "sh", "-c",
            "if command -v hyprshutdown >/dev/null 2>&1; then hyprshutdown; else hyprctl eval 'hl.dispatch(hl.dsp.exit())'; fi"
        ])
    }

    // ---------------------------------------------------------------------
    // Quickshell-native services.
    // NotifStore is the notification daemon (replaces mako/dunst/swaync) and the
    // single source of truth for toasts, the notification center and DND.
    // ---------------------------------------------------------------------
    NotifStore {
        id: notifs
    }

    // Bind the current output/input nodes so Pipewire exposes writable volume
    // and mute properties. This follows the active default devices.
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }

    // ---------------------------------------------------------------------
    // Lightweight polling for small helper scripts.
    // The compositor, tray, notifications and audio stay event-driven/native.
    // ---------------------------------------------------------------------
    Process {
        id: appsProcess
        command: [Quickshell.shellDir + "/scripts/apps.sh"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.apps = JSON.parse(text); }
                catch (error) { console.warn("Senta: could not parse app list:", error); }
            }
        }
    }
    Timer {
        interval: 10 * 60 * 1000
        repeat: true
        running: true
        onTriggered: if (!appsProcess.running) appsProcess.running = true
    }


    // Launcher helpers: filter the desktop-entry list by the search query and
    // launch an entry (Terminal=true entries go through kitty).
    readonly property var appResults: filteredApps()
    readonly property int appsRows: Math.max(1, Math.min(7, appResults.length))

    function filteredApps() {
        const q = root.appsQuery.trim().toLowerCase()
        const out = []
        for (const app of root.apps) {
            if (q !== "" ) {
                const hay = (app.name + " " + (app.generic || "") + " " +
                             (app.comment || "") + " " + (app.keywords || "") + " " +
                             (app.categories || "") + " " + (app.id || "")).toLowerCase()
                if (!hay.includes(q)) continue
            }
            out.push(app)
        }
        return out
    }

    // apps.sh already resolves desktop-entry icons to absolute file paths
    // (scripts/apps.sh follows the icon theme chain itself, because this
    // Quickshell build's image://icon/ provider returns no icons). Pass file
    // paths straight through; anything that still arrives as a theme name is
    // handed to the icon provider as a last resort.
    function appIconSource(iconName) {
        const name = String(iconName || "").trim()
        if (name === "") return ""
        if (name.startsWith("/")) return name
        return Quickshell.iconPath(name, "application-x-executable")
    }

    function launchApp(app) {
        if (!app || !app.exec) return
        root.appsOpen = false
        if (app.terminal) Quickshell.execDetached(["kitty", "-e", "sh", "-c", app.exec])
        else Quickshell.execDetached(["sh", "-c", app.exec])
    }

    Process {
        id: networkProcess
        command: [Quickshell.shellDir + "/scripts/network-info.sh"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.networkData = JSON.parse(text); }
                catch (error) { console.warn("Senta: could not parse network status:", error); }
            }
        }
    }
    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: if (!networkProcess.running) networkProcess.running = true
    }

    // Reads the active Hyprland keymap directly (no external script); the pill
    // only shows the short language code (EN / ARA). Layout switching is handled
    // by your Hyprland keybind config, not by this shell.
    Process {
        id: keyboardProcess
        command: ["bash", "-c", "hyprctl devices -j 2>/dev/null | jq -r '[.keyboards[]? | select(.main == true) | .active_keymap][0] // \"English (US)\"'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const layout = text.trim().toLowerCase()
                root.keyboardLayout = layout.includes("arab") ? "ARA" : "EN"
            }
        }
    }
    // ~250 ms so an ALT+SHIFT group switch shows EN/ARA on the bar within a few
    // hundred ms (each hyprctl read takes ~3 ms, so this is negligible CPU).
    Timer {
        interval: 250
        repeat: true
        running: true
        onTriggered: if (!keyboardProcess.running) keyboardProcess.running = true
    }

    Timer {
        id: clockTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: root.now = new Date()
    }

    // Bottom-centre Sentaku dashboard (hover the bottom centre of a screen).
    // One DashboardSlot per screen registers itself here; see modules/sentadash
    // and docs/SENTAKU-DASHBOARD.md.
    property var dashboardSlots: ({})
    function activeDashboard() {
        const mon = Hyprland.focusedMonitor
        const slot = mon ? root.dashboardSlots[mon.name] : null
        if (slot) return slot
        const names = Object.keys(root.dashboardSlots)
        return names.length > 0 ? root.dashboardSlots[names[0]] : null
    }
    function closeDashboards() {
        for (const name in root.dashboardSlots)
            root.dashboardSlots[name].close()
    }

    // Bottom-right quick menu (Wi-Fi, Bluetooth, ... and the Mando settings button).
    // Same registry pattern; see modules/sentadash and docs/SENTAKU-DASHBOARD.md.
    property var utilitiesSlots: ({})
    function activeUtilities() {
        const mon = Hyprland.focusedMonitor
        const slot = mon ? root.utilitiesSlots[mon.name] : null
        if (slot) return slot
        const names = Object.keys(root.utilitiesSlots)
        return names.length > 0 ? root.utilitiesSlots[names[0]] : null
    }
    function closeUtilities() {
        for (const name in root.utilitiesSlots)
            root.utilitiesSlots[name].close()
    }

    // Keep the bar menus mutually exclusive so a second popup never opens
    // behind or on top of the first one.
    function closeMenuPopups() {
        root.calendarOpen = false
        root.notificationsOpen = false
        root.powerOpen = false
        root.appsOpen = false
    }
    function toggleApps() {
        const open = !root.appsOpen
        root.closeMenuPopups()
        root.appsOpen = open
    }
    function toggleCalendar() {
        const open = !root.calendarOpen
        root.closeMenuPopups()
        root.calendarOpen = open
    }
    function toggleNotifications() {
        const open = !root.notificationsOpen
        root.closeMenuPopups()
        root.notificationsOpen = open
    }
    function togglePower() {
        const open = !root.powerOpen
        root.closeMenuPopups()
        root.powerOpen = open
    }

    IpcHandler {
        target: "senta"
        function toggleBar(): void { root.barVisible = !root.barVisible; }
        function toggleCalendar(): void { root.toggleCalendar(); }
        function toggleNotifications(): void { root.toggleNotifications(); }
        function toggleDnd(): void { notifs.dnd = !notifs.dnd; }
        function togglePower(): void { root.togglePower(); }
        function toggleApps(): void { root.toggleApps(); }
        // Dashboard tabs: 0 Dashboard, 1 Media, 2 Performance, 3 Weather.
        function toggleDashboard(): void { root.activeDashboard()?.toggle() }
        function openDashboard(tab: int): void { root.activeDashboard()?.showTab(tab) }
        function closeDashboard(): void { root.closeDashboards() }
        // Quick menu (Wi-Fi, Bluetooth, ...) and the Mando settings window.
        function toggleUtilities(): void { root.activeUtilities()?.toggle() }
        function closeUtilities(): void { root.closeUtilities() }
        function openSettings(): void { root.activeUtilities()?.openSettings() }
        function closePopups(): void {
            root.closeMenuPopups()
            root.closeDashboards()
            root.closeUtilities()
            notifs.hidePopups()
        }
    }

    // A panel and its popups are instantiated on every connected screen.
    // Variants needs exactly ONE root object per delegate, so the frame and
    // the bar live together inside a Scope.
    Variants {
        model: Quickshell.screens

        Scope {
            id: screenScope
            required property var modelData

            // Outer rings of the bar popups that are open on this screen, handed to the screen
            // frame, which paints them. Same geometry as the popup windows, in frame coordinates
            // (the frame window starts at the bottom edge of the bar, popups start 1 px above it).
            readonly property var popupRings: {
                const out = [];
                if (!root.frameDrawsPopupRings)
                    return out;
                const top = root.barVisible ? root.barHeight : 0;
                const add = (popup, kind, x, bleed) => out.push({
                    kind: kind,
                    x: x,
                    y: popup.anchor.rect.y - top,
                    w: popup.width,
                    h: popup.height,
                    bleed: bleed,
                    fillet: root.popupFillet
                });
                if (notificationsPopup.visible)
                    add(notificationsPopup, "right", notificationsPopup.anchor.rect.x, root.popupRightInset + root.popupEdgeBleed);
                if (powerPopup.visible)
                    add(powerPopup, "right", powerPopup.anchor.rect.x, root.popupRightInset + root.popupEdgeBleed);
                // The app launcher is anchored by its top-right corner (see appsPopup).
                if (appsPopup.visible)
                    add(appsPopup, "left", appsPopup.anchor.rect.x + 1 - appsPopup.width, root.popupLeftInset + root.popupEdgeBleed);
                if (calendarPopup.visible)
                    add(calendarPopup, "tab", calendarPopup.anchor.rect.x, 0);
                if (wsPreviewPopup.visible)
                    add(wsPreviewPopup, "tab", wsPreviewPopup.anchor.rect.x, 0);
                return out;
            }

            // Wallpaper: drawn by the shell on the bottom layer, behind the
            // frame, bar and panels (see components/WallpaperBackground.qml).
            WallpaperBackground {
                targetScreen: screenScope.modelData
            }

            // Screen frame: rounded inner corners on all four sides,
            // bar stays on top. See components/ScreenFrame.qml.
            ScreenFrame {
                targetScreen: screenScope.modelData
                barHeight: root.barVisible ? root.barHeight : 0
                barZone: root.barExclusiveZone
                borderColor: Theme.border
                borderWidth: root.frameBorderWidth
                thickness: root.frameThickness
                radius: root.screenCornerRadius
                frameColor: Theme.bg
                rings: screenScope.popupRings
                bottomRing: dashboardSlot.ring
                cornerRing: utilitiesSlot.ring
            }

            // Toast stack: slides in from the right edge.
            NotifPopups {
                targetScreen: screenScope.modelData
                store: notifs
                topInset: root.barVisible ? root.barHeight : root.frameThickness
                edgeGap: root.popupRightInset
                fillet: root.popupFillet
            }

            // Sentaku dashboard (Dashboard / Media / Performance / Weather):
            // pops up when the pointer rests at the bottom centre of the screen.
            DashboardSlot {
                id: dashboardSlot
                targetScreen: screenScope.modelData
                frameThickness: root.frameThickness
                fillet: root.popupFillet
                frameDrawsFill: root.frameDrawsPopupRings   // the screen frame paints the panel background
                uiScale: Math.max(0.4, Math.min(1.25, root.bottomPanelScale))
                Component.onCompleted: root.dashboardSlots[screenScope.modelData.name] = dashboardSlot
                Component.onDestruction: delete root.dashboardSlots[screenScope.modelData.name]
            }

            // Quick menu (Wi-Fi, Bluetooth, mic, settings, ...): pops up when the pointer rests
            // at the bottom-right of the screen. Only the first screen also runs the background
            // behaviour (keep awake, game mode, do-not-disturb bridge).
            UtilitiesSlot {
                id: utilitiesSlot
                targetScreen: screenScope.modelData
                notifStore: notifs
                frameThickness: root.frameThickness
                fillet: root.popupFillet
                frameDrawsFill: root.frameDrawsPopupRings   // the screen frame paints the panel background
                uiScale: Math.max(0.4, Math.min(1.25, root.bottomPanelScale))
                primary: Quickshell.screens.length > 0 && Quickshell.screens[0].name === screenScope.modelData.name
                Component.onCompleted: root.utilitiesSlots[screenScope.modelData.name] = utilitiesSlot
                Component.onDestruction: delete root.utilitiesSlots[screenScope.modelData.name]
            }

            // The two bottom panels never show at once.
            Connections {
                target: dashboardSlot
                function onOpened() { utilitiesSlot.close() }
            }
            Connections {
                target: utilitiesSlot
                function onOpened() { dashboardSlot.close() }
            }

            PanelWindow {
                id: barWindow
                screen: screenScope.modelData
                visible: root.barVisible
                color: "transparent"
                anchors {
                    top: true
                    left: true
                    right: true
                }
                // The bar stays edge-to-edge and square; it forms the top edge of
                // the frame (see ScreenFrame), whose inner corners are rounded.
                implicitHeight: root.barHeight
                // Full width: ignore the frame's left/right reservations, otherwise
                // the compositor insets the bar and the corners show wallpaper.
                // The frame's top edge-zone reserves the space below the bar instead.
                exclusionMode: ExclusionMode.Ignore
                focusable: false
                // Explicit namespace lets Hyprland target this bar and its anchored popups.
                WlrLayershell.namespace: "senta-bar"

                Rectangle {
                    anchors.fill: parent
                    radius: 0
                    color: Theme.bg
                }

                RowLayout {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: root.barHeight
                    anchors.leftMargin: root.barSidePadding
                    anchors.rightMargin: root.barSidePadding
                    spacing: 8

                    // LEFT — Arch logo (opens the app launcher) + workspace strip.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        spacing: 6

                        // Arch logo: click to open the app launcher popup.
                        Rectangle {
                            width: 26
                            height: 24
                            radius: 7
                            color: root.appsOpen ? Theme.accentSoft : "transparent"

                            // Arch mark: linux-archlinux glyph (U+F303) from the bar icon font.
                            Text {
                                anchors.centerIn: parent
                                text: "\uF303"
                                font.family: Theme.iconFont
                                font.pixelSize: 16
                                color: Theme.cyan
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.leftMargin: -root.barSidePadding   // click area reaches the screen edge
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleApps()
                            }
                        }
                        Row {
                            spacing: 3
                        
                            Repeater {
                                model: root.workspaceModel
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 30
                                    height: 24
                                    radius: 7
                                    property bool focused: modelData.focused
                                    property bool active: modelData.active
                                    property bool pending: modelData.pending && root.showWorkspaceActivity
                                    color: focused ? Theme.accentSoft
                                           : (pending ? root.workspaceActivitySoft
                                                  : (active && root.showActiveWorkspace ? Theme.accentActive : "transparent"))
                                    border.width: (focused || pending || (active && root.showActiveWorkspace)) ? 1 : 0
                                    border.color: focused ? Theme.accent
                                               : (pending ? root.workspaceActivityColor : Theme.accentActive)
                        
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 2
                                        // Active workspaces show the icon only; inactive ones the number.
                                        // A pending workspace is painted purple so silent opens stand out.
                                        Text {
                                            visible: active && root.showActiveWorkspace
                                            text: root.activeWorkspaceIcon
                                            font.family: Theme.iconFont
                                            font.pixelSize: 11
                                            color: focused ? Theme.accent
                                                   : (pending ? root.workspaceActivityColor : Theme.accentActiveText)
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            visible: !(active && root.showActiveWorkspace)
                                            text: String(modelData.id)
                                            color: focused ? Theme.accent
                                                   : (pending ? root.workspaceActivityColor : Theme.muted)
                                            font.family: Theme.uiFont
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                        
                                    MouseArea {
                                        id: wsMouse
                                        anchors.fill: parent
                                        anchors.topMargin: -Math.floor((root.barHeight - parent.height) / 2)
                                        anchors.bottomMargin: -Math.floor((root.barHeight - parent.height) / 2)
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onEntered: {
                                            root.wsHoverId = modelData.id
                                            root.wsHoverX = mapToItem(barWindow.contentItem, 0, 0).x
                                            root.wsPreview = modelData.toplevels.map(function (t) {
                                                return { title: t.title || "", toplevel: t }
                                            })
                                        }
                                        onExited: {
                                            root.wsHoverId = 0
                                            root.wsPreview = []
                                        }
                                        onClicked: root.focusWorkspace(modelData.id)
                                    }
                                }
                            }
                        }
                    }
                    // CENTER — focused window title, centred in the bar.
                    Text {
                        visible: root.showWindowTitle
                        Layout.fillWidth: true
                        Layout.minimumWidth: 30
                        text: (function () {
                            const ws = Hyprland.focusedWorkspace
                            const tls = (ws && ws.toplevels && ws.toplevels.values) ? ws.toplevels.values : []
                            let title
                            for (let i = 0; i < tls.length; ++i) {
                                if (tls[i].activated) { title = tls[i].title || "Desktop"; break }
                            }
                            title = title || "Desktop"
                            // Keep the bar tidy: show the start of long titles, the ellipsis
                            // hints the title continues. Tune the 44 to taste.
                            return title.length > 44 ? title.slice(0, 44) + "…" : title
                        })()
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }

                    // RIGHT — follows your Waybar module order.
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.alignment: Qt.AlignRight
                        spacing: 5

                        // System tray: item activation + native StatusNotifier menus.
                        Row {
                            visible: root.showTray
                            spacing: 3
                            Repeater {
                                model: SystemTray.items
                                delegate: Item {
                                    required property var modelData
                                    width: 23
                                    height: 24

                                    Image {
                                        anchors.centerIn: parent
                                        width: 17
                                        height: 17
                                        source: modelData.icon
                                        sourceSize.width: 32
                                        sourceSize.height: 32
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.topMargin: -Math.floor((root.barHeight - parent.height) / 2)
                                        anchors.bottomMargin: -Math.floor((root.barHeight - parent.height) / 2)
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                        cursorShape: Qt.PointingHandCursor
                                        id: trayMouse
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.RightButton || modelData.onlyMenu) {
                                                if (modelData.hasMenu) {
                                                    // mapToItem needs an Item, not the window itself: use the
                                                    // window's content item. The menu opens just below the bar,
                                                    // at the cursor's x position.
                                                    try {
                                                        const point = trayMouse.mapToItem(barWindow.contentItem, mouse.x, 0)
                                                        modelData.display(barWindow, Math.round(point.x), barWindow.height)
                                                    } catch (e) {
                                                        console.warn("Tray menu failed to open:", e)
                                                    }
                                                }
                                            } else if (mouse.button === Qt.MiddleButton) {
                                                modelData.secondaryActivate()
                                            } else {
                                                modelData.activate()
                                            }
                                        }
                                        onWheel: wheel => modelData.scroll(wheel.angleDelta.y, wheel.angleDelta.x !== 0)
                                        //ToolTip.visible: containsMouse
                                        //ToolTip.text: (modelData.tooltipTitle || modelData.title) +
                                        //              (modelData.tooltipDescription ? "\n" + modelData.tooltipDescription : "")
                                    }
                                }
                            }
                        }

                        Pill {
                            icon: notifs.dnd ? "󰂛" : ""
                            label: notifs.dnd ? "DND" :
                                   (notifs.count > 0
                                    ? String(notifs.count) : "")
                            //tooltip: notifs.dnd ? "Do not disturb · right-click to disable" : "Notifications · right-click for DND"
                            iconColor: notifs.dnd ? Theme.yellow : Theme.accent
                            onActivated: mouse => {
                                if (mouse.button === Qt.RightButton) notifs.dnd = !notifs.dnd
                                else root.toggleNotifications()
                            }
                        }

                        // Combined status pill: layout · network · audio · clock
                        // in one pill. The sections are separated by invisible
                        // separators — each keeps its own mouse area and
                        // behaviour; the whole pill highlights when any section
                        // is hovered.
                        Item {
                            id: statusPill
                            height: 26
                            implicitWidth: statusRow.implicitWidth
                            readonly property bool hovered: kbMouse.containsMouse ||
                                                           netMouse.containsMouse ||
                                                           audMouse.containsMouse ||
                                                           clockMouse.containsMouse

                            Rectangle {
                                anchors.fill: parent
                                radius: 9
                                color: statusPill.hovered ? Theme.surfaceRaised : Theme.surface
                                border.width: 1
                                border.color: statusPill.hovered ? Theme.accentSoft : Theme.border
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            Row {
                                id: statusRow
                                anchors.centerIn: parent
                                spacing: 0

                                // Layout section: text only (EN / ARA), read from
                                // the active Hyprland keymap. Hover only — switching
                                // is your Hyprland keybind, not this pill.
                                Item {
                                    implicitWidth: kbContent.implicitWidth + 18
                                    implicitHeight: 26

                                    Row {
                                        id: kbContent
                                        anchors.centerIn: parent
                                        spacing: 5

                                        Text {
                                            text: root.keyboardLayout
                                            color: Theme.text
                                            font.family: Theme.uiFont
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: kbMouse
                                        anchors.fill: parent
                                        anchors.topMargin: -5
                                        anchors.bottomMargin: -5
                                        hoverEnabled: true
                                    }
                                }

                                // Network section.
                                Item {
                                    implicitWidth: netContent.implicitWidth + 18
                                    implicitHeight: 26

                                    Row {
                                        id: netContent
                                        anchors.centerIn: parent
                                        spacing: 5

                                        Text {
                                            text: root.networkData.kind === "wifi" ? "" :
                                                  (root.networkData.kind === "ethernet" ? "󰈀" : "󰤭")
                                            color: root.networkData.kind === "offline" ? Theme.red : Theme.green
                                            font.family: Theme.iconFont
                                            font.pixelSize: 15
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            visible: root.networkData.kind !== "ethernet"
                                            text: root.networkData.label || "Offline"
                                            color: Theme.text
                                            font.family: Theme.uiFont
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: netMouse
                                        anchors.fill: parent
                                        anchors.topMargin: -5
                                        anchors.bottomMargin: -5
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.RightButton) {
                                                root.activeUtilities()?.openSettingsPage("network")
                                                return
                                            }
                                            Quickshell.execDetached(["kitty", "-e", "nmtui"])
                                        }
                                    }
                                }

                                // Audio section.
                                Item {
                                    implicitWidth: audContent.implicitWidth + 18
                                    implicitHeight: 26

                                    Row {
                                        id: audContent
                                        anchors.centerIn: parent
                                        spacing: 5

                                        Text {
                                            text: !Pipewire.defaultAudioSink || !Pipewire.defaultAudioSink.audio ? "" :
                                                  (Pipewire.defaultAudioSink.audio.muted ? "󰝟" :
                                                   (Pipewire.defaultAudioSink.audio.volume > 0.65 ? "" : ""))
                                            color: Theme.accent
                                            font.family: Theme.iconFont
                                            font.pixelSize: 15
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            text: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio
                                                   ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%" : "—"
                                            color: Theme.text
                                            font.family: Theme.uiFont
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: audMouse
                                        anchors.fill: parent
                                        anchors.topMargin: -5
                                        anchors.bottomMargin: -5
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: mouse => {
                                            if (mouse.button === Qt.RightButton) {
                                                root.activeUtilities()?.openSettingsPage("audio")
                                                return
                                            }
                                            if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio)
                                                Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
                                        }
                                        onWheel: wheel => {
                                            if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                                                const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05
                                                Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(1.5, Pipewire.defaultAudioSink.audio.volume + step))
                                            }
                                        }
                                    }
                                }

                                // Clock section (the calendar popup centres on it).
                                Item {
                                    id: clockSeg
                                    implicitWidth: clockContent.implicitWidth + 18
                                    implicitHeight: 26

                                    Row {
                                        id: clockContent
                                        anchors.centerIn: parent
                                        Text {
                                            text: Qt.formatDateTime(root.now, "HH:mm")
                                            color: Theme.text
                                            font.family: Theme.uiFont
                                            font.pixelSize: 11
                                            font.weight: Font.Medium
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }

                                    MouseArea {
                                        id: clockMouse
                                        anchors.fill: parent
                                        anchors.topMargin: -5
                                        anchors.bottomMargin: -5
                                        hoverEnabled: true
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleCalendar()
                                    }
                                }
                            }
                        }

                        Pill {
                            visible: root.showPowerButton
                            icon: ""
                            //tooltip: "Power menu"
                            iconColor: Theme.red
                            compact: true
                            hitPadRight: root.barSidePadding   // click area reaches the screen edge
                            onActivated: root.togglePower()
                        }
                    }
                }

                // Workspace hover preview: live window thumbnails (wlr-screencopy)
                // for the workspace under the cursor, centred below its number.
                PopupWindow {
                    id: wsPreviewPopup
                    anchor.window: barWindow
                    anchor.rect.x: {
                        // Re-evaluate when the hover target or bar size changes.
                        root.wsHoverId; root.wsHoverX; barWindow.width
                        const center = root.wsHoverX + 15   // half of the 30 px cell
                        return Math.max(8, Math.min(barWindow.width - width - root.popupRightInset,
                                                    Math.round(center - width / 2)))
                    }
                    anchor.rect.y: barWindow.height - 1
                    // Content is exactly the thumbnail row (n * 200 + (n-1) * 8), so
                    // the left/right padding is the equal 10 px content margin on
                    // both sides. No fillet added to the height: tab popups only
                    // widen the window, the fillet never adds height.
                    implicitWidth: 20 + 2 * root.popupFillet
                               + Math.min(root.wsPreview.length, 3) * 200
                               + (Math.min(root.wsPreview.length, 3) - 1) * 8
                    implicitHeight: 16 + 8 + 100 + 4 + 16 + 20 + 1
                    visible: root.wsHoverId > 0 && root.showActiveWindow && root.wsPreview.length > 0
                    color: "transparent"
                    onVisibleChanged: if (!visible) { root.wsHoverId = 0; root.wsPreview = [] }

                    PopupSurface {
                        anchors.fill: parent
                        ringVisible: !root.frameDrawsPopupRings   // the screen frame paints the outer ring
                        fillet: root.popupFillet
                        color: Theme.bg               // dark outer frame, same colour as the bar
                        innerMargin: 8                // dashboard-style frame ring
                        innerColor: Theme.popupBg     // lighter inner panel

                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8

                            Text {
                                text: "Workspace " + root.wsHoverId
                                color: Theme.accent
                                font.family: Theme.uiFont
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }

                            Row {
                                spacing: 8
                                Repeater {
                                    model: root.wsPreview.length > 3
                                           ? root.wsPreview.slice(0, 3)
                                           : root.wsPreview
                                    delegate: Column {
                                        required property var modelData
                                        spacing: 4
                                        Rectangle {
                                            width: 200
                                            height: 100
                                            radius: 6
                                            color: Theme.surface
                                            border.width: 1
                                            border.color: Theme.border
                                            clip: true
                                            ScreencopyView {
                                                anchors.fill: parent
                                                anchors.margins: 2
                                                captureSource: modelData.toplevel.wayland
                                                live: true
                                                paintCursor: false
                                                constraintSize: Qt.size(196, 96)
                                            }
                                        }
                                        Text {
                                            width: 200
                                            text: modelData.title
                                            elide: Text.ElideRight
                                            color: Theme.text
                                            font.family: Theme.uiFont
                                            font.pixelSize: 11
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Calendar dropdown, opened by clicking the clock.
                PopupWindow {
                    id: calendarPopup
                    anchor.window: barWindow
                    // Flush with the bar (1 px overlap hides seams); the fillets live in the extra width.
                    // Centred exactly under the clock pill: the popup is symmetric (fillet on both
                    // sides), so centring the window centres the visible body too.
                    anchor.rect.x: {
                        // Not reactive on its own: re-evaluate when it opens or the bar changes.
                        root.calendarOpen; barWindow.width; clockSeg.width
                        const center = clockSeg.mapToItem(barWindow.contentItem, clockSeg.width / 2, 0).x
                        return Math.max(8, Math.min(barWindow.width - width - root.popupRightInset,
                                                    Math.round(center - width / 2)))
                    }
                    anchor.rect.y: barWindow.height - 1
                    // PopupWindow dimensions are implicit to avoid deprecated size overrides.
                    implicitWidth: 306 + 2 * root.popupFillet
                    implicitHeight: 354
                    visible: root.calendarOpen
                    grabFocus: true
                    color: "transparent"
                    onVisibleChanged: if (!visible) root.calendarOpen = false

                    PopupSurface {
                        anchors.fill: parent
                        ringVisible: !root.frameDrawsPopupRings   // the screen frame paints the outer ring
                        fillet: root.popupFillet
                        color: Theme.bg               // dark outer frame, same colour as the bar
                        innerMargin: 8                // dashboard-style frame ring
                        innerColor: Theme.popupBg     // lighter inner panel

                        Column {
                            anchors.fill: parent
                            anchors.margins: 15
                            spacing: 11

                            Row {
                                width: parent.width
                                height: 28
                                spacing: 8
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Qt.formatDate(new Date(calendarPopup.year, calendarPopup.month, 1), "MMMM yyyy")
                                    color: Theme.text
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                    width: parent.width - 74
                                }
                                Rectangle {
                                    width: 29; height: 27; radius: 7; color: Theme.surface
                                    Text { anchors.centerIn: parent; text: "‹"; color: Theme.text; font.pixelSize: 20 }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: calendarPopup.shiftMonth(-1) }
                                }
                                Rectangle {
                                    width: 29; height: 27; radius: 7; color: Theme.surface
                                    Text { anchors.centerIn: parent; text: "›"; color: Theme.text; font.pixelSize: 20 }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: calendarPopup.shiftMonth(1) }
                                }
                            }

                            Row {
                                width: parent.width
                                spacing: 0
                                Repeater {
                                    model: ["M", "T", "W", "T", "F", "S", "S"]
                                    delegate: Text {
                                        required property var modelData
                                        width: 38
                                        horizontalAlignment: Text.AlignHCenter
                                        text: modelData
                                        color: Theme.muted
                                        font.pixelSize: 10
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }

                            Grid {
                                columns: 7
                                spacing: 2
                                Repeater {
                                    model: calendarPopup.days
                                    delegate: Rectangle {
                                        required property var modelData
                                        width: 37
                                        height: 34
                                        radius: 8
                                        property bool sameMonth: modelData.getMonth() === calendarPopup.month
                                        property bool isToday: modelData.getFullYear() === root.now.getFullYear() &&
                                                                modelData.getMonth() === root.now.getMonth() &&
                                                                modelData.getDate() === root.now.getDate()
                                        color: isToday ? Theme.accentSoft : "transparent"
                                        border.width: isToday ? 1 : 0
                                        border.color: Theme.accent
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.getDate()
                                            color: parent.sameMonth ? Theme.text : "#626d82"
                                            font.pixelSize: 11
                                            font.weight: parent.isToday ? Font.Bold : Font.Normal
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: 1
                                color: Theme.border
                            }

                            Row {
                                width: parent.width
                                Text {
                                    text: Qt.formatDate(root.now, "dddd, dd MMMM yyyy")
                                    color: Theme.muted
                                    font.pixelSize: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }

                    property int year: root.now.getFullYear()
                    property int month: root.now.getMonth()
                    property var days: {
                        const first = new Date(year, month, 1)
                        const offset = (first.getDay() + 6) % 7
                        const start = new Date(year, month, 1 - offset)
                        const values = []
                        for (let i = 0; i < 42; ++i)
                            values.push(new Date(start.getFullYear(), start.getMonth(), start.getDate() + i))
                        return values
                    }
                    function shiftMonth(amount) {
                        const d = new Date(year, month + amount, 1)
                        year = d.getFullYear()
                        month = d.getMonth()
                    }
                }

                // Notification center: grouped by app, DND switch, Clear all.
                PopupWindow {
                    id: notificationsPopup
                    anchor.window: barWindow
                    // The window runs popupEdgeBleed px past the screen edge (see PopupSurface `bleed`);
                    // no adjustment, so the compositor does not slide it back and re-open the seam.
                    anchor.rect.x: Math.max(8, barWindow.width - width + root.popupEdgeBleed)
                    anchor.rect.y: barWindow.height - 1
                    anchor.adjustment: PopupAdjustment.None
                    implicitWidth: 400 + root.popupFillet + root.popupRightInset + root.popupEdgeBleed   // left fillet only: the right side meets the frame
                    implicitHeight: 520 + root.popupFillet       // + the concave foot into the frame
                    visible: root.notificationsOpen
                    grabFocus: true
                    color: "transparent"
                    onVisibleChanged: if (!visible) root.notificationsOpen = false

                    PopupSurface {
                        anchors.fill: parent
                        ringVisible: !root.frameDrawsPopupRings   // the screen frame paints the outer ring
                        fillet: root.popupFillet
                        attachRight: true
                        bleed: root.popupRightInset + root.popupEdgeBleed
                        color: Theme.bg               // dark outer frame, same colour as the bar
                        innerMargin: 8                // dashboard-style frame ring
                        innerColor: Theme.popupBg     // lighter inner panel

                        NotifCenter {
                            anchors.fill: parent
                            store: notifs
                        }
                    }
                }

                // Power dropdown. Lock depends on the hyprlock binary you already use.
                PopupWindow {
                    id: powerPopup
                    anchor.window: barWindow
                    // Same seamless-frame setup as the notification center above.
                    anchor.rect.x: Math.max(8, barWindow.width - width + root.popupEdgeBleed)
                    anchor.rect.y: barWindow.height - 1
                    anchor.adjustment: PopupAdjustment.None
                    implicitWidth: 224 + root.popupFillet + root.popupRightInset + root.popupEdgeBleed   // left fillet only: the right side meets the frame
                    implicitHeight: 224 + root.popupFillet       // + the concave foot into the frame
                    visible: root.powerOpen
                    grabFocus: true
                    color: "transparent"
                    onVisibleChanged: if (!visible) root.powerOpen = false

                    PopupSurface {
                        anchors.fill: parent
                        ringVisible: !root.frameDrawsPopupRings   // the screen frame paints the outer ring
                        fillet: root.popupFillet
                        attachRight: true
                        bleed: root.popupRightInset + root.popupEdgeBleed
                        color: Theme.bg               // dark outer frame, same colour as the bar
                        innerMargin: 8                // dashboard-style frame ring
                        innerColor: Theme.popupBg     // lighter inner panel

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 6

                            Text {
                                text: "Session"
                                color: Theme.text
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }

                            Repeater {
                                model: [
                                    { icon: "", label: "Lock", command: ["hyprlock"] },
                                    { icon: "󰤄", label: "Suspend", command: ["systemctl", "suspend"] },
                                    { icon: "󰗼", label: "Log out", action: "logout" },
                                    { icon: "󰜉", label: "Restart", command: ["systemctl", "reboot"] },
                                    { icon: "", label: "Shut down", command: ["systemctl", "poweroff"] }
                                ]
                                delegate: Rectangle {
                                    required property var modelData
                                    width: parent.width
                                    height: 29
                                    radius: 7
                                    color: powerMouse.containsMouse ? Theme.surfaceRaised : "transparent"
                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 8
                                        spacing: 10
                                        Text { text: modelData.icon; color: Theme.accent; font.family: Theme.iconFont; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: modelData.label; color: Theme.text; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    MouseArea {
                                        id: powerMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            root.powerOpen = false
                                            if (modelData.action === "logout") root.logoutSession()
                                            else Quickshell.execDetached(modelData.command)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // App launcher. It stays attached beneath
                // the Arch logo and flush to the left frame; search is kept at
                // the top as requested. The result list supports keyboard
                // selection, scrolling, and a name + description row layout.
                PopupWindow {
                    id: appsPopup
                    anchor.window: barWindow
                    // PopupSurface overlaps the bar by one pixel so there is no seam
                    // or gap at the join. On the left the window runs popupEdgeBleed px
                    // past the screen edge (see PopupSurface `bleed`), so the popup is
                    // anchored by its top-RIGHT corner and grows leftwards: that keeps the
                    // anchor point inside the bar window. No adjustment, so the compositor
                    // does not slide it back and re-open the seam.
                    anchor.edges: Edges.Top | Edges.Right
                    anchor.gravity: Edges.Bottom | Edges.Left
                    anchor.rect.x: root.popupLeftInset + 420 + root.popupFillet - 1
                    anchor.rect.y: barWindow.height - 1
                    anchor.adjustment: PopupAdjustment.None
                    implicitWidth: 420 + root.popupFillet + root.popupLeftInset + root.popupEdgeBleed
                    implicitHeight: 1 + root.popupFillet + 28 + 40 + 10 + 18 + 10
                                   + (root.appsRows * 56 + (root.appsRows - 1) * 5) + 10 + 16
                    visible: root.appsOpen
                    grabFocus: true
                    color: "transparent"
                    onVisibleChanged: {
                        if (!visible) {
                            root.appsOpen = false
                            root.appsQuery = ""
                            Qt.callLater(function() {
                                appsSearch.text = ""
                                appsList.currentIndex = 0
                            })
                        } else {
                            Qt.callLater(function() {
                                if (appsPopup.visible) {
                                    appsList.currentIndex = 0
                                    appsSearch.forceActiveFocus()
                                }
                            })
                        }
                    }

                    PopupSurface {
                        anchors.fill: parent
                        ringVisible: !root.frameDrawsPopupRings   // the screen frame paints the outer ring
                        fillet: root.popupFillet
                        attachLeft: true
                        bleed: root.popupLeftInset + root.popupEdgeBleed
                        color: Theme.bg               // dark outer frame, same colour as the bar
                        innerMargin: 8                // dashboard-style frame ring
                        innerColor: Theme.popupBg     // lighter inner panel

                        Column {
                            anchors.fill: parent
                            anchors.margins: 14
                            spacing: 10

                            // Search stays first, directly below the bar.
                            Rectangle {
                                id: searchSurface
                                width: parent.width
                                height: 40
                                radius: 10
                                color: Theme.surface
                                border.width: 1
                                border.color: appsSearch.activeFocus ? Theme.accent : Theme.popupBorder

                                Behavior on border.color {
                                    ColorAnimation { duration: 140 }
                                }

                                Text {
                                    x: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "\uF002"
                                    font.family: Theme.iconFont
                                    font.pixelSize: 14
                                    color: appsSearch.activeFocus ? Theme.accent : Theme.muted
                                }

                                TextField {
                                    id: appsSearch
                                    anchors.fill: parent
                                    anchors.leftMargin: 36
                                    anchors.rightMargin: 12
                                    background: null
                                    color: Theme.text
                                    selectionColor: Theme.accentSoft
                                    selectedTextColor: Theme.text
                                    placeholderText: "Search applications…"
                                    placeholderTextColor: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 12
                                    selectByMouse: true
                                    onTextChanged: {
                                        root.appsQuery = text
                                        appsList.currentIndex = 0
                                    }
                                    Keys.onPressed: event => {
                                        if (event.key === Qt.Key_Escape) {
                                            root.appsOpen = false
                                            event.accepted = true
                                        } else if (event.key === Qt.Key_Down) {
                                            if (root.appResults.length > 0) {
                                                appsList.currentIndex = Math.min(root.appResults.length - 1, appsList.currentIndex + 1)
                                                appsList.positionViewAtIndex(appsList.currentIndex, ListView.Contain)
                                            }
                                            event.accepted = true
                                        } else if (event.key === Qt.Key_Up) {
                                            if (root.appResults.length > 0) {
                                                appsList.currentIndex = Math.max(0, appsList.currentIndex - 1)
                                                appsList.positionViewAtIndex(appsList.currentIndex, ListView.Contain)
                                            }
                                            event.accepted = true
                                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                            if (root.appResults.length > 0) {
                                                const selected = Math.max(0, Math.min(appsList.currentIndex, root.appResults.length - 1))
                                                root.launchApp(root.appResults[selected])
                                            }
                                            event.accepted = true
                                        }
                                    }
                                }
                            }

                            // Small section label, keeping the search as the
                            // first and most prominent control in the popup.
                            Row {
                                width: parent.width
                                height: 18
                                spacing: 0

                                Text {
                                    id: appsSectionTitle
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "APPLICATIONS"
                                    color: Theme.accentActiveText
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 1.1
                                }

                                // Row owns horizontal placement. This spacer
                                // pushes the result count to the right edge
                                // without using conflicting horizontal anchors.
                                Item {
                                    width: Math.max(0, parent.width - appsSectionTitle.implicitWidth - appsResultCount.implicitWidth)
                                    height: 1
                                }

                                Text {
                                    id: appsResultCount
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.appResults.length + " FOUND"
                                    color: Theme.muted
                                    font.family: Theme.uiFont
                                    font.pixelSize: 9
                                }
                            }

                            // Rows: icon, app name, and a muted
                            // generic name/comment. Only seven rows are visible;
                            // the rest remain available through scrolling.
                            Item {
                                width: parent.width
                                height: root.appsRows * 56 + (root.appsRows - 1) * 5

                                ListView {
                                    id: appsList
                                    anchors.fill: parent
                                    clip: true
                                    spacing: 5
                                    model: root.appResults
                                    currentIndex: 0
                                    boundsBehavior: Flickable.StopAtBounds
                                    interactive: contentHeight > height

                                    delegate: Rectangle {
                                        required property var modelData
                                        required property int index
                                        width: ListView.view.width
                                        height: 56
                                        radius: 9
                                        color: appsRowMouse.containsMouse
                                               ? Theme.accentActive
                                               : (ListView.isCurrentItem ? Theme.surfaceRaised : "transparent")

                                        Behavior on color {
                                            ColorAnimation { duration: 120 }
                                        }

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 12
                                            spacing: 11

                                            Rectangle {
                                                width: 36
                                                height: 36
                                                radius: 9
                                                anchors.verticalCenter: parent.verticalCenter
                                                // Only the no-icon fallback (initial letter) needs a tile;
                                                // a real icon sits directly on the glass surface.
                                                color: modelData.icon === "" ? Theme.accentSoft : "transparent"

                                                Image {
                                                    visible: modelData.icon !== ""
                                                    anchors.centerIn: parent
                                                    width: 29
                                                    height: 29
                                                    source: root.appIconSource(modelData.icon)
                                                    sourceSize.width: 48
                                                    sourceSize.height: 48
                                                    fillMode: Image.PreserveAspectFit
                                                    asynchronous: false
                                                    smooth: true
                                                    // Note: in this build status may report Loading(1) even
                                                    // after the image decoded; rendering is driven by the
                                                    // pixmap data, not the status, so don't chase it.
                                                }
                                                Text {
                                                    visible: modelData.icon === ""
                                                    anchors.centerIn: parent
                                                    text: (modelData.name.charAt(0) || "?").toUpperCase()
                                                    color: Theme.accent
                                                    font.family: Theme.uiFont
                                                    font.pixelSize: 15
                                                    font.weight: Font.Bold
                                                }
                                            }

                                            Column {
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width - 58
                                                spacing: 2

                                                Text {
                                                    width: parent.width
                                                    text: modelData.name
                                                    elide: Text.ElideRight
                                                    color: Theme.text
                                                    font.family: Theme.uiFont
                                                    font.pixelSize: 12
                                                    font.weight: Font.DemiBold
                                                }
                                                Text {
                                                    width: parent.width
                                                    text: modelData.comment || modelData.generic || "Application"
                                                    elide: Text.ElideRight
                                                    color: Theme.muted
                                                    font.family: Theme.uiFont
                                                    font.pixelSize: 10
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: appsRowMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onEntered: appsList.currentIndex = index
                                            onClicked: root.launchApp(modelData)
                                        }
                                    }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 5
                                    visible: root.appResults.length === 0

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "\uF002"
                                        color: Theme.muted
                                        font.family: Theme.iconFont
                                        font.pixelSize: 22
                                    }
                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: "No matching applications"
                                        color: Theme.text
                                        font.family: Theme.uiFont
                                        font.pixelSize: 11
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                height: 16
                                text: "↑ ↓  Navigate     ↵  Launch     Esc  Close"
                                color: Theme.muted
                                font.family: Theme.uiFont
                                font.pixelSize: 9
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }
    }
}
