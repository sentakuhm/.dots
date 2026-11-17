import QtQuick
import Quickshell

// Per-screen entry point for the quick menu, used by shell.qml (twin of DashboardSlot).
//
// The menu needs the Sentaku QML plugin, M3Shapes and the Mando settings window. If any is
// missing, a plain `UtilitiesHost {}` in shell.qml would make the WHOLE shell (bar included)
// fail to load. This slot compiles the host at runtime and, on failure, just logs why.
// This file deliberately imports nothing from Sentaku.
Scope {
    id: root

    required property var targetScreen
    // Senta's NotifStore: the quick menu's "do not disturb" toggle drives its `dnd`.
    required property var notifStore
    property int frameThickness: 3
    property int fillet: 14
    // True on exactly one screen: the background behaviour (keep awake, game mode, DND
    // bridge) is created once, not per screen.
    property bool primary: false

    property var host: null
    property var runtime: null
    readonly property bool available: host !== null

    signal opened

    function open(): void { host?.open(); }
    function close(): void { host?.close(); }
    function toggle(): void { host?.toggle(); }
    function openSettings(): void { host?.openSettings(); }
    function openSettingsPage(id: string): void { host?.openSettingsPage(id); }

    function load(file: string, props: var): var {
        const component = Qt.createComponent(Qt.resolvedUrl("../modules/sentadash/" + file));
        if (component.status !== Component.Ready) {
            console.warn("[senta] Quick menu disabled (the rest of the shell is unaffected): " + file + "\n" + component.errorString());
            return null;
        }
        const obj = component.createObject(root, props);
        if (!obj)
            console.warn("[senta] " + file + " could not be created: " + component.errorString());
        return obj;
    }

    Component.onCompleted: {
        const obj = root.load("UtilitiesHost.qml", {
            targetScreen: root.targetScreen,
            frameThickness: root.frameThickness,
            fillet: root.fillet
        });
        if (!obj)
            return;
        obj.frameThickness = Qt.binding(() => root.frameThickness);
        obj.fillet = Qt.binding(() => root.fillet);
        obj.opened.connect(root.opened);
        root.host = obj;

        if (root.primary)
            root.runtime = root.load("UtilitiesRuntime.qml", {
                notifs: root.notifStore
            });
    }
}
