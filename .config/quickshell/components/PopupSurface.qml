import QtQuick
import QtQuick.Shapes
import "../Theme.js" as Theme

// Background for every popup that hangs from the bar (calendar, power,
// notification center, toasts). It uses a subtly lifted TokyoNight surface,
// keeps a seamless one-pixel overlap with the bar, and flares out into small
// concave corners where it meets the bar, so the popup reads as an extension
// of the bar (Caelestia
// style) instead of a floating box.
//
// Three shapes:
//   - tab (default): hangs from the bar with a concave corner on both sides.
//     The popup window must be `2 * fillet` wider than the content.
//   - attachRight: the right side is flush against the right screen frame
//     (no gap, square top-right) and the bottom edge flares down into the
//     frame with a concave foot. The window must be `fillet` wider than the
//     content (left fillet only) and `fillet` taller (the foot).
//   - attachLeft: mirror of attachRight; the left side is flush against the
//     left screen frame and the foot flares down into the left frame
//     (right fillet only; `fillet` wider and `fillet` taller).
//
// Children go into `body`, the content rectangle, and are laid out as usual.
//
//   PopupWindow { implicitWidth: 306 + 2 * fillet; anchor.rect.y: bar.height - topOverlap
//       PopupSurface { anchors.fill: parent; Column { anchors.fill: parent } } }
Item {
    id: root

    property color color: Theme.popupBg
    // Radius of the convex bottom-left corner (and bottom-right in tab mode).
    property real radius: 14
    // Radius of the concave corners that blend into the bar / frame (0 = plain flush).
    property real fillet: 14
    // Rows drawn over the bar's last pixel row to hide any seam; position the
    // window `topOverlap` px above the bar's bottom edge.
    property real topOverlap: 1
    // Flush against the right frame instead of hanging free on the right.
    property bool attachRight: false
    // Flush against the left frame instead of hanging free on the left.
    property bool attachLeft: false

    default property alias content: body.data
    readonly property alias body: body

    // Clamped so the path stays valid while the popup is tiny or animating.
    readonly property real o: topOverlap
    readonly property real f: Math.max(0, Math.min(fillet, width / 2, (height - o) / ((attachRight || attachLeft) ? 2 : 1)))
    readonly property real foot: (attachRight || attachLeft) ? f : 0
    readonly property real rightF: attachRight ? 0 : f
    readonly property real r: Math.max(0, Math.min(radius, (width - f - rightF) / 2, height - foot - o - f))
    // Bottom edge of the content (the foot hangs below it in attachRight mode).
    readonly property real bodyBottom: height - foot

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // ---- Tab: concave corners on both sides, rounded bottom ----------
        ShapePath {
            fillColor: (root.attachRight || root.attachLeft) ? "transparent" : root.color
            strokeColor: "transparent"

            startX: 0
            startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.o }
            // Right fillet: concave curve from the bar down into the right side.
            PathArc {
                x: root.width - root.f
                y: root.o + root.f
                radiusX: root.f
                radiusY: root.f
                direction: PathArc.Counterclockwise
            }
            PathLine { x: root.width - root.f; y: root.height - root.r }
            // Bottom-right corner.
            PathArc {
                x: root.width - root.f - root.r
                y: root.height
                radiusX: root.r
                radiusY: root.r
                direction: PathArc.Clockwise
            }
            PathLine { x: root.f + root.r; y: root.height }
            // Bottom-left corner.
            PathArc {
                x: root.f
                y: root.height - root.r
                radiusX: root.r
                radiusY: root.r
                direction: PathArc.Clockwise
            }
            PathLine { x: root.f; y: root.o + root.f }
            // Left fillet: concave curve from the left side back up into the bar.
            PathArc {
                x: 0
                y: root.o
                radiusX: root.f
                radiusY: root.f
                direction: PathArc.Counterclockwise
            }
            PathLine { x: 0; y: 0 }
        }

        // ---- attachRight: flush with the right frame, concave foot -------
        ShapePath {
            fillColor: root.attachRight ? root.color : "transparent"
            strokeColor: "transparent"

            startX: 0
            startY: 0
            // Top edge along the bar, then straight down the frame to the tip of the foot.
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            // Concave foot: the bottom edge flares down into the frame.
            PathArc {
                x: root.width - root.f
                y: root.bodyBottom
                radiusX: root.f
                radiusY: root.f
                direction: PathArc.Counterclockwise
            }
            PathLine { x: root.f + root.r; y: root.bodyBottom }
            // Bottom-left corner.
            PathArc {
                x: root.f
                y: root.bodyBottom - root.r
                radiusX: root.r
                radiusY: root.r
                direction: PathArc.Clockwise
            }
            PathLine { x: root.f; y: root.o + root.f }
            // Left fillet: concave curve from the left side back up into the bar.
            PathArc {
                x: 0
                y: root.o
                radiusX: root.f
                radiusY: root.f
                direction: PathArc.Counterclockwise
            }
            PathLine { x: 0; y: 0 }
        }

        // ---- attachLeft: flush with the left frame, concave foot ----------
        ShapePath {
            fillColor: root.attachLeft ? root.color : "transparent"
            strokeColor: "transparent"

            startX: 0
            startY: 0
            // Top edge along the bar, then straight down the right side under the fillet.
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.o }
            // Right fillet: concave curve from the bar down into the right side.
            PathArc {
                x: root.width - root.f
                y: root.o + root.f
                radiusX: root.f
                radiusY: root.f
                direction: PathArc.Counterclockwise
            }
            PathLine { x: root.width - root.f; y: root.bodyBottom - root.r }
            // Bottom-right corner.
            PathArc {
                x: root.width - root.f - root.r
                y: root.bodyBottom
                radiusX: root.r
                radiusY: root.r
                direction: PathArc.Clockwise
            }
            PathLine { x: root.f; y: root.bodyBottom }
            // Concave foot: the bottom edge flares down into the left frame.
            PathArc {
                x: 0
                y: root.height
                radiusX: root.f
                radiusY: root.f
                direction: PathArc.Counterclockwise
            }
            PathLine { x: 0; y: 0 }
        }
    }

    // Content area: right of the left fillet, below the overlap row, above the foot.
    Item {
        id: body

        x: root.attachLeft ? 0 : root.fillet
        y: root.topOverlap
        width: root.width - root.fillet * ((root.attachRight || root.attachLeft) ? 1 : 2)
        height: root.height - root.topOverlap - root.foot
    }
}
