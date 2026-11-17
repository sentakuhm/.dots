import QtQuick
import QtQuick.Shapes
import qs.services

// Placeholder Sentaku mark: four selection brackets around a dot.
// Swap this file and assets/logo.svg for your own artwork. The dashboard only relies on
// the interface below (topColour, bottomColour, implicit size). The mark is shown when
// `general.logo` is set to "sentaku" in ~/.config/sentaku/shell.json; by default the
// dashboard shows your distro's logo instead.
Item {
    id: root

    readonly property real designWidth: 128
    readonly property real designHeight: 128

    property color topColour: Colours.palette.m3primary
    property color bottomColour: Colours.palette.m3onSurface

    implicitWidth: designWidth
    implicitHeight: designHeight

    Shape {
        anchors.centerIn: parent
        width: root.designWidth
        height: root.designHeight
        scale: Math.min(root.width / width, root.height / height)
        transformOrigin: Item.Center
        preferredRendererType: Shape.CurveRenderer

        // Selection brackets.
        ShapePath {
            fillColor: "transparent"
            strokeColor: root.topColour
            strokeWidth: 9
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathSvg {
                path: "M14 42V26Q14 14 26 14H42 M86 14H102Q114 14 114 26V42 M114 86V102Q114 114 102 114H86 M42 114H26Q14 114 14 102V86"
            }
        }

        // Selected item.
        ShapePath {
            fillColor: root.bottomColour
            strokeColor: "transparent"

            PathSvg {
                path: "M64 44A20 20 0 1 1 64 84A20 20 0 1 1 64 44Z"
            }
        }
    }
}
