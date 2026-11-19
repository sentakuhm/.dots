import QtQuick
import QtQuick.Shapes

// Background for a panel that rises out of the BOTTOM screen frame.
//
// This is the bottom-edge sibling of components/PopupSurface.qml (which hangs
// from the bar at the top): the free edge (top) has convex rounded corners and
// both sides flare out into small concave "feet" that blend into the frame
// strip, so the panel reads as an extension of the frame.
//
// Geometry (y grows downwards):
//
//        ,-----------------------.        <- convex corners (radius)
//        |                       |
//        |        body           |        <- children go here
//        |                       |
//   _____/                       \_____   <- concave feet (fillet), land on the
//   ============ frame strip ============     TOP edge of the frame strip
//
// The widget is `foot` px taller than its body: the bottom `foot` px overlap the
// frame strip and are deliberately NOT painted (the frame draws them), except for
// `overlap` px that hide any seam. Place the window's bottom edge on the screen's
// bottom edge and set `foot` to the frame thickness.
//
// Width must be 2 * fillet wider than the content (one fillet per side).
Item {
    id: root

    property color color: "#1a1b26"
    // false: paint nothing here. The screen frame paints this panel's background instead
    // (see components/ScreenFrame.qml `bottomRing`), so it is exactly the colour of the frame.
    property bool fillVisible: true
    // Radius of the two convex top corners.
    property real radius: 25
    // Radius of the concave feet that blend into the frame (0 = plain flush).
    property real fillet: 14
    // Thickness of the frame strip under the panel (px).
    property real foot: 3
    // Rows painted over the top of the frame strip to hide any seam.
    property real overlap: 1

    default property alias content: body.data
    readonly property alias body: body

    // Top edge of the frame strip = baseline the feet land on.
    readonly property real baseY: Math.max(0, height - foot)
    // Clamped so the path stays valid while the panel is tiny or animating.
    readonly property real f: Math.max(0, Math.min(fillet, width / 2, baseY / 2))
    readonly property real r: Math.max(0, Math.min(radius, (width - 2 * f) / 2, baseY - f))

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.fillVisible ? root.color : "transparent"
            strokeColor: "transparent"

            // Bottom-left tip of the left foot (1 px inside the frame strip).
            startX: 0
            startY: root.baseY + root.overlap
            PathLine { x: 0; y: root.baseY }
            // Left foot: concave curve from the frame up into the left side.
            PathArc {
                x: root.f
                y: root.baseY - root.f
                radiusX: root.f
                radiusY: root.f
                direction: PathArc.Counterclockwise
            }
            PathLine { x: root.f; y: root.r }
            // Top-left convex corner.
            PathArc {
                x: root.f + root.r
                y: 0
                radiusX: root.r
                radiusY: root.r
                direction: PathArc.Clockwise
            }
            PathLine { x: root.width - root.f - root.r; y: 0 }
            // Top-right convex corner.
            PathArc {
                x: root.width - root.f
                y: root.r
                radiusX: root.r
                radiusY: root.r
                direction: PathArc.Clockwise
            }
            PathLine { x: root.width - root.f; y: root.baseY - root.f }
            // Right foot: concave curve from the right side down into the frame.
            PathArc {
                x: root.width
                y: root.baseY
                radiusX: root.f
                radiusY: root.f
                direction: PathArc.Counterclockwise
            }
            PathLine { x: root.width; y: root.baseY + root.overlap }
            PathLine { x: 0; y: root.baseY + root.overlap }
        }
    }

    // Content area: between the feet, above the frame strip.
    Item {
        id: body

        x: root.fillet
        y: 0
        width: root.width - root.fillet * 2
        height: root.baseY
    }
}
