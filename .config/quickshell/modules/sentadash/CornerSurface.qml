import QtQuick
import QtQuick.Shapes

// Background for a panel docked in the BOTTOM-RIGHT corner of the screen, attached to both
// the bottom and the right frame strips (corner sibling of BottomSurface).
//
//            ,--------------------.      <- convex top-left corner (radius)
//           /                     |/     <- concave flare up along the right frame
//           |        body         |
//           |                     |
//   _______/                      |
//   ====== bottom frame ===========|     <- concave foot lands on the TOP edge of the bottom frame
//                                  ^ right frame strip
//
// The widget is `frame` px wider and taller than its body: the right/bottom `frame` px
// overlap the frame strips and are deliberately NOT painted (the frame draws them), except for
// `overlap` px that hide any seam. Dock the window to the screen's bottom-right corner and set
// `frame` to the frame thickness. Width/height must include `fillet` on the left/top for the
// flares.
Item {
    id: root

    property color color: "#1a1b26"
    // false: paint nothing here. The screen frame paints this panel's background instead
    // (see components/ScreenFrame.qml `cornerRing`), so it is exactly the colour of the frame.
    property bool fillVisible: true
    // Radius of the convex top-left corner.
    property real radius: 25
    // Radius of the concave flares into the frame strips.
    property real fillet: 14
    // Thickness of the frame strips (px).
    property real frame: 3
    // Rows/columns painted into the frame strips to hide any seam.
    property real overlap: 1

    default property alias content: body.data
    readonly property alias body: body

    // Inner edges of the frame strips = where the flares land.
    readonly property real bw: Math.max(0, width - frame)
    readonly property real bh: Math.max(0, height - frame)
    // Clamped so the path stays valid while the panel is tiny or animating.
    readonly property real f: Math.max(0, Math.min(fillet, bw / 2, bh / 2))
    readonly property real r: Math.max(0, Math.min(radius, bw - 2 * f, bh - 2 * f))

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.fillVisible ? root.color : "transparent"
            strokeColor: "transparent"

            // Left foot tip (1 px inside the bottom frame).
            startX: 0
            startY: root.bh + root.overlap
            PathLine { x: 0; y: root.bh }
            // Left foot: concave curve from the bottom frame up into the left side.
            PathArc {
                x: root.f
                y: root.bh - root.f
                radiusX: root.f
                radiusY: root.f
                direction: PathArc.Counterclockwise
            }
            PathLine { x: root.f; y: root.f + root.r }
            // Top-left convex corner.
            PathArc {
                x: root.f + root.r
                y: root.f
                radiusX: root.r
                radiusY: root.r
                direction: PathArc.Clockwise
            }
            PathLine { x: root.bw - root.f; y: root.f }
            // Top-right flare: concave curve from the top edge up along the right frame.
            PathArc {
                x: root.bw
                y: 0
                radiusX: root.f
                radiusY: root.f
                direction: PathArc.Counterclockwise
            }
            PathLine { x: root.bw + root.overlap; y: 0 }
            PathLine { x: root.bw + root.overlap; y: root.bh + root.overlap }
            PathLine { x: 0; y: root.bh + root.overlap }
        }
    }

    // Content area: inside both frames, right of the left foot, below the top flare.
    Item {
        id: body

        x: root.fillet
        y: root.fillet
        width: root.bw - root.fillet
        height: root.bh - root.fillet
    }
}
