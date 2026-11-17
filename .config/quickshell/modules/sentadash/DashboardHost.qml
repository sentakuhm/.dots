pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Sentaku.Config
import qs.components
import qs.services

// One bottom-centre hover host per screen.
//
//   closed : the window only accepts input on a thin strip at the bottom
//            centre of the screen (the hot zone); everything else passes
//            through to the windows below.
//   opening: hovering the hot zone for `openDelay` ms opens the dashboard.
//   open   : the window accepts input on the panel only. Leaving the panel
//            closes it after `closeDelay` ms.
//
// A dashboard opened from the keyboard / IPC (`open()`, `toggle()`) is "pinned":
// it stays until toggled or until the pointer has entered it once and left
// again (same rule as upstream's dashboardShortcutActive).
Scope {
    id: root

    required property var targetScreen
    // Thickness of the screen frame strip along the bottom edge (px).
    property int frameThickness: 3
    // Concave foot radius where the panel blends into the frame.
    property int fillet: 14
    // Hot zone at the bottom centre of the screen.
    property int triggerWidth: 420
    property int triggerHeight: 8
    property int openDelay: 120
    property int closeDelay: 250
    // Upper bound of the (transparent) host window. The dashboard animates inside it.
    property int maxWidth: 1200
    property int maxHeight: 820

    readonly property alias screenState: screenStateObj
    readonly property bool isOpen: screenStateObj.dashboard
    property bool pinned: false
    // The window is mapped slightly after the rest of the shell so that it is
    // stacked above the screen frame (same layer, newest surface wins), which
    // lets the hot zone reach the very last pixel row of the screen.
    property bool ready: false

    signal opened

    function open(): void {
        openTimer.stop();
        closeTimer.stop();
        pinned = !hover.containsMouse;
        screenStateObj.dashboard = true;
    }

    function close(): void {
        openTimer.stop();
        closeTimer.stop();
        pinned = false;
        screenStateObj.dashboard = false;
    }

    function toggle(): void {
        if (screenStateObj.dashboard)
            close();
        else
            open();
    }

    // tab: 0 Dashboard, 1 Media, 2 Performance, 3 Weather (disabled tabs are skipped by upstream).
    function showTab(tab: int): void {
        screenStateObj.dashboardTab = tab;
        open();
    }

    Component.onCompleted: {
        // Upstream forces these on shell start instead of lazily.
        Players;
        Weather.reload();
    }

    ScreenState {
        id: screenStateObj

        modelData: root.targetScreen
    }

    Connections {
        function onDashboardChanged(): void {
            if (screenStateObj.dashboard)
                root.opened();
        }

        target: screenStateObj
    }

    FontLoader {
        source: Quickshell.shellPath("assets/google-sans-flex/GoogleSansFlex-VariableFont_GRAD,ROND,opsz,slnt,wdth,wght.ttf")
    }

    Timer {
        interval: 700
        running: true
        onTriggered: root.ready = true
    }

    Timer {
        id: openTimer

        interval: root.openDelay
        onTriggered: {
            root.pinned = false;
            screenStateObj.dashboard = true;
        }
    }

    Timer {
        id: closeTimer

        interval: root.closeDelay
        onTriggered: {
            if (!root.pinned && !hover.containsMouse)
                screenStateObj.dashboard = false;
        }
    }

    PanelWindow {
        id: win

        screen: root.targetScreen
        visible: root.ready
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: false

        // Only the bottom edge is anchored: the compositor centres the surface horizontally.
        anchors.bottom: true
        implicitWidth: Math.min(root.maxWidth, root.targetScreen.width)
        implicitHeight: Math.min(root.maxHeight, Math.round(root.targetScreen.height * 0.85))

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "senta-dashboard"

        // Popup menus inside the dashboard (player / disk selector) parent themselves to
        // this item so hover tracking keeps working while a menu is open
        // (see the Senta patch in components/controls/Menu.qml).
        property Item interactionWrapper: hover

        // Same two lines as upstream's StyledWindow: lets Config / Tokens resolve per screen.
        contentItem.Config.screen: root.targetScreen.name
        contentItem.Tokens.screen: root.targetScreen.name

        // Closed: only the hot zone takes input. Open: only the panel does.
        mask: Region {
            x: panel.visible ? panel.x : (win.width - root.triggerWidth) / 2
            y: panel.visible ? panel.y : win.height - root.triggerHeight
            width: panel.visible ? panel.width : root.triggerWidth
            height: panel.visible ? panel.height : root.triggerHeight
        }

        // Same structure as upstream's Interactions.qml: a hover-tracking
        // MouseArea that is the PARENT of the panel, so hovering widgets inside
        // the panel does not count as leaving it.
        MouseArea {
            id: hover

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton

            onContainsMouseChanged: {
                if (containsMouse) {
                    closeTimer.stop();
                    if (root.screenState.dashboard)
                        root.pinned = false; // the pointer took over from a shortcut
                    else
                        openTimer.restart();
                } else {
                    openTimer.stop();
                    if (root.screenState.dashboard && !root.pinned)
                        closeTimer.restart();
                }
            }

            DashboardPanel {
                id: panel

                screenState: root.screenState
                fillet: root.fillet
                foot: root.frameThickness
            }
        }
    }
}
