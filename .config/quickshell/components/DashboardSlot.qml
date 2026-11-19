import QtQuick
import Quickshell

// Per-screen entry point used by shell.qml.
//
// The dashboard needs Sentaku's C++ QML plugin and M3Shapes. If either is
// missing, a plain `DashboardHost {}` in shell.qml would make the WHOLE shell
// (bar included) fail to load. This slot therefore compiles the host at runtime
// and, on failure, just logs why and leaves the rest of Senta untouched.
// This file deliberately imports nothing from Sentaku.
Scope {
    id: root

    required property var targetScreen
    property int frameThickness: 3
    property int fillet: 14
    // The screen frame paints the panel's background (see ScreenFrame `bottomRing`).
    property bool frameDrawsFill: false
    // Scale of the panel content (1 = original size), see shell.qml `bottomPanelScale`.
    property real uiScale: 1

    property var host: null
    // Live description of where the panel is (null while the dashboard is not loaded);
    // shell.qml hands it to the screen frame.
    readonly property var ring: host ? host.ring : null
    readonly property bool available: host !== null

    signal opened

    function open(): void { host?.open(); }
    function close(): void { host?.close(); }
    function toggle(): void { host?.toggle(); }
    function showTab(tab: int): void { host?.showTab(tab); }

    Component.onCompleted: {
        const component = Qt.createComponent(Qt.resolvedUrl("../modules/sentadash/DashboardHost.qml"));
        if (component.status !== Component.Ready) {
            console.warn("[senta] Dashboard disabled (the rest of the shell is unaffected). " + "Run scripts/dashboard-doctor.sh to see what is missing.\n" + component.errorString());
            return;
        }

        const obj = component.createObject(root, {
            targetScreen: root.targetScreen,
            frameThickness: root.frameThickness,
            fillet: root.fillet
        });
        if (!obj) {
            console.warn("[senta] Dashboard host could not be created: " + component.errorString());
            return;
        }
        obj.frameThickness = Qt.binding(() => root.frameThickness);
        obj.fillet = Qt.binding(() => root.fillet);
        obj.frameDrawsFill = Qt.binding(() => root.frameDrawsFill);
        obj.uiScale = Qt.binding(() => root.uiScale);
        obj.opened.connect(root.opened);
        root.host = obj;
    }
}
