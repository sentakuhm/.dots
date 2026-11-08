import QtQuick
import QtQuick.Shapes
import "../Theme.js" as Theme

// Arch Linux mark, drawn from the official logo path (archlinux.org artwork),
// normalised into a 100x100 coordinate box so the component scales with its
// width / height. Fill colour is configurable via `color`.
Item {
    id: root

    property color color: Theme.accent

    implicitWidth: 20
    implicitHeight: 20

    Shape {
        // Path coordinates live in a 100x100 box; the Shape is scaled to fit
        // the component's width / height (uniform, square box).
        x: 0
        y: 0
        width: 100
        height: 100
        scale: root.width / 100
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.color
            fillRule: ShapePath.OddEvenFill

            startX: 49.9812
            startY: 0.0000
            PathCubic { control1X: 45.5303; control1Y: 10.9125; control2X: 42.8457; control2Y: 18.0505; x: 37.8902; y: 28.6386 }
            PathCubic { control1X: 40.9285; control1Y: 31.8592; control2X: 44.6580; control2Y: 35.6098; x: 50.7146; y: 39.8458 }
            PathCubic { control1X: 44.2031; control1Y: 37.1664; control2X: 39.7615; control2Y: 34.4763; x: 36.4423; y: 31.6848 }
            PathCubic { control1X: 30.1002; control1Y: 44.9186; control2X: 20.1639; control2Y: 63.7696; x: 0.0000; y: 100.0000 }
            PathCubic { control1X: 15.8481; control1Y: 90.8506; control2X: 28.1333; control2Y: 85.2099; x: 39.5825; y: 83.0575 }
            PathCubic { control1X: 39.0909; control1Y: 80.9430; control2X: 38.8114; control2Y: 78.6558; x: 38.8304; y: 76.2693 }
            PathLine { x: 38.8492; y: 75.7616 }
            PathCubic { control1X: 39.1007; control1Y: 65.6081; control2X: 44.3825; control2Y: 57.8001; x: 50.6393; y: 58.3302 }
            PathCubic { control1X: 56.8962; control1Y: 58.8603; control2X: 61.7596; control2Y: 67.5261; x: 61.5081; y: 77.6796 }
            PathCubic { control1X: 61.4608; control1Y: 79.5901; control2X: 61.2453; control2Y: 81.4281; x: 60.8687; y: 83.1328 }
            PathCubic { control1X: 72.1937; control1Y: 85.3481; control2X: 84.3475; control2Y: 90.9744; x: 99.9812; y: 100.0000 }
            PathCubic { control1X: 96.8985; control1Y: 94.3246; control2X: 94.1470; control2Y: 89.2086; x: 91.5194; y: 84.3362 }
            PathCubic { control1X: 87.3804; control1Y: 81.1283; control2X: 83.0633; control2Y: 76.9531; x: 74.2572; y: 72.4332 }
            PathCubic { control1X: 80.3100; control1Y: 74.0060; control2X: 84.6438; control2Y: 75.8206; x: 88.0218; y: 77.8488 }
            PathCubic { control1X: 61.3060; control1Y: 28.1087; control2X: 59.1426; control2Y: 21.4993; x: 49.9812; y: 0.0000 }
        }
    }
}
