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
import "Theme.js" as Theme

ShellRoot {
    id: root

    // ---------------------------------------------------------------------
    // User settings — edit these first.
    // ---------------------------------------------------------------------
    property string shellName: "Senta"
    property int barHeight: 36
    property int barSidePadding: 5       // gap from the screen edge to the first / last bar item
    property int barExclusiveZone: barHeight + 6   // space tiled windows keep clear below the bar
    property int popupFillet: 14          // concave corners where popups blend into the bar (0 = plain flush)
    property int screenCornerRadius: 14   // inner corner radius of the frame (smaller = tighter into the corners)
    property int frameThickness: 3         // frame width on left / right / bottom (2-6 = barely visible)
    readonly property int popupRightInset: Math.max(0, frameThickness - 1)   // right-attached popups overlap the frame by 1 px
    readonly property int popupLeftInset: Math.max(0, frameThickness - 1)    // left-attached popups overlap the frame by 1 px
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
        const items = []
        for (const id of ids) {
            const ws = byId[id]
            const tl = (ws && ws.toplevels && ws.toplevels.values) ? ws.toplevels.values : []
            const titles = []
            for (let j = 0; j < tl.length; ++j) {
                const t = tl[j].title
                if (t && t.length > 0) titles.push(t)
            }
            items.push({ id: id, focused: id === focusId, active: titles.length > 0, titles: titles, toplevels: tl })
        }
        const sig = items.map(function (i) {
            return i.id + (i.focused ? "F" : "") + (i.active ? "A" : "") + "][" + i.titles.join("\u0000")
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

    // Resolve application icons at runtime through Qt's active platform theme.
    // With QT_QPA_PLATFORMTHEME=kde, this follows the icon theme selected in KDE
    // (Papirus-Dark on this setup). Absolute desktop-entry icon paths are kept.
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
        function closePopups(): void {
            root.closeMenuPopups()
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

            // Caelestia-style frame: rounded inner corners on all four sides,
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
            }

            // Caelestia-style toast stack: slides in from the right edge.
            NotifPopups {
                targetScreen: screenScope.modelData
                store: notifs
                topInset: root.barVisible ? root.barHeight : root.frameThickness
                edgeGap: root.popupRightInset
                fillet: root.popupFillet
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
                                    color: focused ? Theme.accentSoft
                                           : (active && root.showActiveWorkspace ? Theme.accentActive : "transparent")
                                    border.width: (focused || (active && root.showActiveWorkspace)) ? 1 : 0
                                    border.color: focused ? Theme.accent : Theme.accentActive
                        
                                    Row {
                                        anchors.centerIn: parent
                                        spacing: 2
                                        // Active workspaces show the icon only; inactive ones the number.
                                        Text {
                                            visible: active && root.showActiveWorkspace
                                            text: root.activeWorkspaceIcon
                                            font.family: Theme.iconFont
                                            font.pixelSize: 11
                                            color: focused ? Theme.accent : Theme.accentActiveText
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        Text {
                                            visible: !(active && root.showActiveWorkspace)
                                            text: String(modelData.id)
                                            color: focused ? Theme.accent
                                                   : Theme.muted
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
                            for (let i = 0; i < tls.length; ++i) {
                                if (tls[i].activated) return tls[i].title || "Desktop"
                            }
                            return "Desktop"
                        })()
                        color: Theme.muted
                        font.family: Theme.uiFont
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideMiddle
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
                            icon: "󰌌"
                            label: root.keyboardLayout
                            //tooltip: "Keyboard layout (EN / ARA) · switched by your Hyprland keybind"
                            iconColor: Theme.lavender
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

                        Pill {
                            icon: root.networkData.kind === "wifi" ? "" :
                                  (root.networkData.kind === "ethernet" ? "󰈀" : "󰤭")
                            label: root.networkData.kind === "ethernet" ? "" : (root.networkData.label || "Offline")
                            //tooltip: root.networkData.name || "Network status"
                            iconColor: root.networkData.kind === "offline" ? Theme.red : Theme.green
                            onActivated: Quickshell.execDetached(["kitty", "-e", "nmtui"])
                        }

                        Pill {
                            icon: !Pipewire.defaultAudioSink || !Pipewire.defaultAudioSink.audio ? "" :
                                  (Pipewire.defaultAudioSink.audio.muted ? "󰝟" :
                                   (Pipewire.defaultAudioSink.audio.volume > 0.65 ? "" : ""))
                            label: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio
                                   ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%" : "—"
                            //tooltip: "Output volume · click to mute · scroll to change"
                            onActivated: {
                                if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio)
                                    Pipewire.defaultAudioSink.audio.muted = !Pipewire.defaultAudioSink.audio.muted
                            }
                            onScrolled: delta => {
                                if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio) {
                                    const step = delta > 0 ? 0.05 : -0.05
                                    Pipewire.defaultAudioSink.audio.volume = Math.max(0, Math.min(1.5, Pipewire.defaultAudioSink.audio.volume + step))
                                }
                            }
                        }

                        Pill {
                            icon: !Pipewire.defaultAudioSource || !Pipewire.defaultAudioSource.audio ? "" :
                                  (Pipewire.defaultAudioSource.audio.muted ? "󰍭" : "")
                            label: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio
                                   ? Math.round(Pipewire.defaultAudioSource.audio.volume * 100) + "%" : "—"
                            //tooltip: "Microphone · click to mute · scroll to change"
                            iconColor: Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio && Pipewire.defaultAudioSource.audio.muted
                                       ? Theme.red : Theme.lavender
                            onActivated: {
                                if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio)
                                    Pipewire.defaultAudioSource.audio.muted = !Pipewire.defaultAudioSource.audio.muted
                            }
                            onScrolled: delta => {
                                if (Pipewire.defaultAudioSource && Pipewire.defaultAudioSource.audio) {
                                    const step = delta > 0 ? 0.05 : -0.05
                                    Pipewire.defaultAudioSource.audio.volume = Math.max(0, Math.min(1.5, Pipewire.defaultAudioSource.audio.volume + step))
                                }
                            }
                        }

                        Pill {
                            icon: ""
                            id: clockPill
                            label: Qt.formatDateTime(root.now, "HH:mm")
                            //tooltip: "Open calendar"
                            iconColor: Theme.accent
                            onActivated: root.toggleCalendar()
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
                        fillet: root.popupFillet

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
                        root.calendarOpen; barWindow.width; clockPill.width
                        const center = clockPill.mapToItem(barWindow.contentItem, clockPill.width / 2, 0).x
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
                        fillet: root.popupFillet

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
                    anchor.rect.x: Math.max(8, barWindow.width - width - root.popupRightInset)
                    anchor.rect.y: barWindow.height - 1
                    implicitWidth: 400 + root.popupFillet        // left fillet only: the right side meets the frame
                    implicitHeight: 520 + root.popupFillet       // + the concave foot into the frame
                    visible: root.notificationsOpen
                    grabFocus: true
                    color: "transparent"
                    onVisibleChanged: if (!visible) root.notificationsOpen = false

                    PopupSurface {
                        anchors.fill: parent
                        fillet: root.popupFillet
                        attachRight: true

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
                    anchor.rect.x: Math.max(8, barWindow.width - width - root.popupRightInset)
                    anchor.rect.y: barWindow.height - 1
                    implicitWidth: 224 + root.popupFillet        // left fillet only: the right side meets the frame
                    implicitHeight: 224 + root.popupFillet       // + the concave foot into the frame
                    visible: root.powerOpen
                    grabFocus: true
                    color: "transparent"
                    onVisibleChanged: if (!visible) root.powerOpen = false

                    PopupSurface {
                        anchors.fill: parent
                        fillet: root.popupFillet
                        attachRight: true

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

                // Caelestia-inspired app launcher. It stays attached beneath
                // the Arch logo and flush to the left frame; search is kept at
                // the top as requested. The result list supports keyboard
                // selection, scrolling, and a name + description row layout.
                PopupWindow {
                    id: appsPopup
                    anchor.window: barWindow
                    // Match the left frame edge; PopupSurface overlaps the bar
                    // by one pixel so there is no seam or gap at the join.
                    anchor.rect.x: root.popupLeftInset
                    anchor.rect.y: barWindow.height - 1
                    implicitWidth: 420 + root.popupFillet
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
                        fillet: root.popupFillet
                        attachLeft: true

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

                            // Caelestia-like rows: icon, app name, and a muted
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
                                                color: modelData.icon === "" ? Theme.accentSoft : Theme.surface

                                                Image {
                                                    visible: modelData.icon !== ""
                                                    anchors.centerIn: parent
                                                    width: 29
                                                    height: 29
                                                    source: root.appIconSource(modelData.icon)
                                                    sourceSize.width: 48
                                                    sourceSize.height: 48
                                                    fillMode: Image.PreserveAspectFit
                                                    asynchronous: true
                                                    smooth: true
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
