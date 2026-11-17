pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Sentaku.Config
import qs.components
import qs.services
import qs.modules.utilities as Utilities

// The quick menu (quick toggles, keep awake, screen recorder), rising out of the
// bottom-right corner of the screen frame.
//
// Adapted from `modules/utilities/Wrapper.qml` (kept in the original project, not shipped
// here; GPL-3.0, see LICENSE and NOTICE). That wrapper is built around a sidebar and a bar
// popout manager; this one only needs the cards, so it keeps the same sizing and slide-in
// behaviour and draws its own corner background (CornerSurface). Everything inside
// (`Utilities.Content` and the cards) is used as-is, apart from two marked lines.
Item {
    id: root

    required property ScreenState screenState
    // Radius of the concave flares into the frame strips.
    property real fillet: 14
    // Thickness of the frame strips the panel sits on.
    property real frame: 3

    readonly property PersistentProperties props: PersistentProperties {
        property bool recordingListExpanded: false
        property string recordingConfirmDelete
        property string recordingMode

        reloadableId: "utilities"
    }

    readonly property bool shouldBeActive: screenState.utilities && Config.utilities.enabled
    property real offsetScale: shouldBeActive ? 0 : 1
    property color surfaceColour: Colours.tPalette.m3surface
    readonly property real pad: Tokens.padding.large

    visible: offsetScale < 1
    anchors.bottom: parent.bottom
    anchors.right: parent.right
    anchors.bottomMargin: (-implicitHeight - 5) * offsetScale
    implicitWidth: fillet + pad + Tokens.sizes.utilities.width + pad + frame
    implicitHeight: fillet + pad + content.implicitHeight + pad + frame
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {}
    }

    Behavior on surfaceColour {
        CAnim {}
    }

    CornerSurface {
        anchors.fill: parent

        color: root.surfaceColour
        radius: Tokens.rounding.extraLarge
        fillet: root.fillet
        frame: root.frame
    }

    Loader {
        id: content

        x: root.fillet + root.pad
        y: root.fillet + root.pad

        active: root.shouldBeActive || root.visible

        sourceComponent: Utilities.Content {
            implicitWidth: Tokens.sizes.utilities.width
            props: root.props
            screenState: root.screenState
            // The original drives this from its drawer's jelly deformation; identity here.
            deformMatrix: Qt.matrix4x4()
        }
    }
}
