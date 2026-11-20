pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Sentaku.Config
import Sentaku.I18n
import qs.components
import qs.modules.mando

// One bottom-right hover host per screen for the quick menu (Wi-Fi, Bluetooth, mic,
// settings, ...). Same behaviour as DashboardHost, docked in the bottom-right corner:
//
//   closed : the window only accepts input on a thin strip at the bottom-right of the screen
//   opening: hovering the hot zone for `openDelay` ms opens the menu
//   open   : the window accepts input on the panel only; leaving it closes it after `closeDelay` ms
//
// A menu opened from the keyboard / IPC is "pinned": it stays until toggled or until the
// pointer has entered it once and left again.
Scope {
    id: root

    required property var targetScreen
    // Thickness of the screen frame strips (bottom and right) the panel sits on (px).
    property int frameThickness: 3
    // Concave flare radius where the panel blends into the frame.
    property int fillet: 14
    // Hot zone at the bottom-right of the screen.
    property int triggerWidth: 300
    property int triggerHeight: 8
    property int openDelay: 120
    property int closeDelay: 250
    // Upper bound of the (transparent) host window. The menu animates inside it.
    property int maxWidth: 560
    property int maxHeight: 720

    // When true the screen frame paints this panel's background (see ScreenFrame `cornerRing`)
    // so it is exactly the colour of the frame and the bar; the panel then paints none itself.
    property bool frameDrawsFill: false
    // Scale of the panel content (1 = original size); see shell.qml `bottomPanelScale`.
    property real uiScale: 1
    // The Mando settings window (opened from this menu) is scaled by the same factor.
    Binding {
        target: WindowFactory
        property: "uiScale"
        value: root.uiScale
    }
    // Where the panel is right now, in screen coordinates, for the screen frame. Live: it
    // follows the open / close animation. The window is docked to the bottom-right corner.
    readonly property QtObject ring: QtObject {
        readonly property bool active: root.frameDrawsFill && panel.visible
        readonly property real x: root.targetScreen.width - win.width + panel.x
        readonly property real y: root.targetScreen.height - win.height + panel.y
        readonly property real w: panel.width
        readonly property real h: panel.height
        readonly property real o: panel.opacity
        readonly property real radius: panel.cornerRadius
        readonly property real fillet: panel.fillet
        readonly property real frame: panel.frame
    }

    readonly property alias screenState: screenStateObj
    readonly property bool isOpen: screenStateObj.utilities
    property bool pinned: false
    // Mapped slightly after the rest of the shell so the window is stacked above the
    // screen frame (see DashboardHost).
    property bool ready: false

    signal opened

    function open(): void {
        openTimer.stop();
        closeTimer.stop();
        pinned = !hover.containsMouse;
        screenStateObj.utilities = true;
    }

    function close(): void {
        openTimer.stop();
        closeTimer.stop();
        pinned = false;
        screenStateObj.utilities = false;
    }

    function toggle(): void {
        if (screenStateObj.utilities)
            close();
        else
            open();
    }

    // Opens the Mando settings window (same as the settings button in the menu).
    function openSettings(): void {
        close();
        WindowFactory.create();
    }

    // Opens the Mando settings window on a specific page.
    // Known ids: "network", "audio"; anything else falls back to the default page.
    function openSettingsPage(id: string): void {
        close();
        const wanted = ({
            "network": Tr.tr("Network"),
            "audio": Tr.tr("Audio")
        })[id];
        if (!wanted) {
            WindowFactory.create();
            return;
        }
        const pages = PageRegistry.pages;
        for (let i = 0; i < pages.length; i++) {
            if (pages[i].label === wanted) {
                WindowFactory.create(null, undefined, i);
                return;
            }
        }
        WindowFactory.create();
    }

    ScreenState {
        id: screenStateObj

        modelData: root.targetScreen
    }

    Connections {
        function onUtilitiesChanged(): void {
            if (screenStateObj.utilities)
                root.opened();
        }

        target: screenStateObj
    }

    Timer {
        interval: 800
        running: true
        onTriggered: root.ready = true
    }

    Timer {
        id: openTimer

        interval: root.openDelay
        onTriggered: {
            root.pinned = false;
            screenStateObj.utilities = true;
        }
    }

    Timer {
        id: closeTimer

        interval: root.closeDelay
        onTriggered: {
            if (!root.pinned && !hover.containsMouse)
                screenStateObj.utilities = false;
        }
    }

    PanelWindow {
        id: win

        screen: root.targetScreen
        visible: root.ready
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: false

        // Docked to the bottom-right corner.
        anchors.bottom: true
        anchors.right: true
        implicitWidth: Math.min(root.maxWidth, root.targetScreen.width)
        implicitHeight: Math.min(root.maxHeight, Math.round(root.targetScreen.height * 0.85))

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "senta-utilities"

        // Popup menus inside the cards (e.g. recording mode) parent themselves to this item so
        // hover tracking keeps working while a menu is open (see the Senta patch in
        // components/controls/Menu.qml).
        property Item interactionWrapper: hover

        // Lets Config / Tokens resolve per screen.
        contentItem.Config.screen: root.targetScreen.name
        contentItem.Tokens.screen: root.targetScreen.name

        // Closed: only the hot zone takes input. Open: only the panel does.
        mask: Region {
            x: panel.visible ? panel.x : win.width - root.triggerWidth
            y: panel.visible ? panel.y : win.height - root.triggerHeight
            width: panel.visible ? panel.width : root.triggerWidth
            height: panel.visible ? panel.height : root.triggerHeight
        }

        // The hover-tracking MouseArea is the PARENT of the panel so hovering widgets
        // inside the panel does not count as leaving it.
        MouseArea {
            id: hover

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton

            onContainsMouseChanged: {
                if (containsMouse) {
                    closeTimer.stop();
                    if (root.screenState.utilities)
                        root.pinned = false;
                    else
                        openTimer.restart();
                } else {
                    openTimer.stop();
                    if (root.screenState.utilities && !root.pinned)
                        closeTimer.restart();
                }
            }

            UtilitiesPanel {
                id: panel

                screenState: root.screenState
                frameDrawsFill: root.frameDrawsFill
                uiScale: root.uiScale
                fillet: root.fillet
                frame: root.frameThickness
            }
        }
    }
}
