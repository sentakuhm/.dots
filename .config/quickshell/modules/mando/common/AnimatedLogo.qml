import QtQuick
import qs.components

// Placeholder animated mark for the About page: the Logo scales and fades in.
// Replace it together with components/Logo.qml and assets/logo.svg. The About page only
// relies on the implicit size, `skipIntroAnimation` and the `animationCompleted` signal.
Item {
    id: root

    property bool skipIntroAnimation: false

    signal animationCompleted

    implicitWidth: 128
    implicitHeight: 128

    Logo {
        id: mark

        anchors.fill: parent
        transformOrigin: Item.Center
        scale: 0.6
        opacity: 0
    }

    ParallelAnimation {
        id: intro

        onFinished: root.animationCompleted()

        NumberAnimation {
            target: mark
            property: "scale"
            from: 0.6
            to: 1
            duration: 450
            easing.type: Easing.OutBack
        }
        NumberAnimation {
            target: mark
            property: "opacity"
            from: 0
            to: 1
            duration: 300
        }
    }

    Component.onCompleted: {
        if (root.skipIntroAnimation) {
            mark.scale = 1;
            mark.opacity = 1;
            root.animationCompleted();
        } else {
            intro.start();
        }
    }
}
