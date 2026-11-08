import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

// Caelestia-style screen frame, adapted for a TOP bar.
//
// A solid frame (same colour as the bar) surrounds the output on the left,
// right and bottom, and the visible desktop area inside it has rounded
// corners on all four sides. The top edge of the frame *is* the bar, so the
// frame window starts right below it (`barHeight`) and only paints the two
// top inner corners plus the left / right / bottom strips.
//
// - `ScreenFrame` window : paints the frame, click-through everywhere except
//                          the frame itself.
// - Edge exclusion zones : reserve `thickness` px on left / right / bottom, and
//                          `barZone` px on top (`thickness` when the bar is
//                          hidden), so tiled windows never sit under the frame.
//                          The bar window must use ExclusionMode.Ignore so it
//                          spans the full width instead of being inset by the
//                          side zones.
// - Outline (optional)   : set `borderWidth` > 0 for a thin line along the whole
//                          inner edge. Off by default (flat, seamless look).
Scope {
    id: root

    required property var targetScreen
    // Height of the bar that owns the top edge. Pass 0 when the bar is hidden;
    // the frame then closes the top edge itself with a normal-thickness strip.
    property int barHeight: 0
    // Space reserved below the top edge while the bar is visible.
    property int barZone: barHeight
    property int thickness: 10
    property int radius: 25
    property color frameColor: "#1a1b26"
    property color borderColor: "#3b4261"
    property real borderWidth: 0     // 0 = flat frame (default); 1 = thin outline along the inner edge

    PanelWindow {
        id: frame

        screen: root.targetScreen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: false

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "senta-frame"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        // Start right below the bar so this surface never overlaps it.
        margins {
            top: root.barHeight
        }

        // Inner (visible) area, in this window's own coordinates.
        readonly property real holeX: root.thickness
        readonly property real holeY: root.barHeight > 0 ? 0 : root.thickness
        readonly property real holeW: Math.max(0, width - root.thickness * 2)
        readonly property real holeH: Math.max(0, height - holeY - root.thickness)
        readonly property real r: Math.max(0, Math.min(root.radius, holeW / 2, holeH / 2))

        // Only the frame ring takes input; the hole passes clicks to windows.
        mask: Region {
            x: frame.holeX
            y: frame.holeY
            width: frame.holeW
            height: frame.holeH
            intersection: Intersection.Xor
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.frameColor
                strokeColor: "transparent"
                fillRule: ShapePath.OddEvenFill

                // Outer rectangle (the whole window).
                startX: 0
                startY: 0
                PathLine { x: frame.width; y: 0 }
                PathLine { x: frame.width; y: frame.height }
                PathLine { x: 0; y: frame.height }
                PathLine { x: 0; y: 0 }

                // Inner rounded rectangle = the hole (odd-even fill cuts it out).
                PathMove { x: frame.holeX + frame.r; y: frame.holeY }
                PathLine { x: frame.holeX + frame.holeW - frame.r; y: frame.holeY }
                PathArc {
                    x: frame.holeX + frame.holeW
                    y: frame.holeY + frame.r
                    radiusX: frame.r
                    radiusY: frame.r
                    direction: PathArc.Clockwise
                }
                PathLine { x: frame.holeX + frame.holeW; y: frame.holeY + frame.holeH - frame.r }
                PathArc {
                    x: frame.holeX + frame.holeW - frame.r
                    y: frame.holeY + frame.holeH
                    radiusX: frame.r
                    radiusY: frame.r
                    direction: PathArc.Clockwise
                }
                PathLine { x: frame.holeX + frame.r; y: frame.holeY + frame.holeH }
                PathArc {
                    x: frame.holeX
                    y: frame.holeY + frame.holeH - frame.r
                    radiusX: frame.r
                    radiusY: frame.r
                    direction: PathArc.Clockwise
                }
                PathLine { x: frame.holeX; y: frame.holeY + frame.r }
                PathArc {
                    x: frame.holeX + frame.r
                    y: frame.holeY
                    radiusX: frame.r
                    radiusY: frame.r
                    direction: PathArc.Clockwise
                }
            }

            // Thin outline along the inner edge, inset by half its width so it
            // is never clipped at the window border.
            ShapePath {
                id: outline
                readonly property real i: root.borderWidth / 2
                readonly property real x0: frame.holeX + i
                readonly property real y0: frame.holeY + i
                readonly property real x1: frame.holeX + frame.holeW - i
                readonly property real y1: frame.holeY + frame.holeH - i
                readonly property real rr: Math.max(0, frame.r - i)

                fillColor: "transparent"
                strokeColor: root.borderWidth > 0 ? root.borderColor : "transparent"
                strokeWidth: Math.max(0, root.borderWidth)

                startX: x0 + rr
                startY: y0
                // Children cannot see the parent ShapePath's properties by bare
                // name, so everything goes through `outline.`.
                PathLine { x: outline.x1 - outline.rr; y: outline.y0 }
                PathArc { x: outline.x1; y: outline.y0 + outline.rr; radiusX: outline.rr; radiusY: outline.rr; direction: PathArc.Clockwise }
                PathLine { x: outline.x1; y: outline.y1 - outline.rr }
                PathArc { x: outline.x1 - outline.rr; y: outline.y1; radiusX: outline.rr; radiusY: outline.rr; direction: PathArc.Clockwise }
                PathLine { x: outline.x0 + outline.rr; y: outline.y1 }
                PathArc { x: outline.x0; y: outline.y1 - outline.rr; radiusX: outline.rr; radiusY: outline.rr; direction: PathArc.Clockwise }
                PathLine { x: outline.x0; y: outline.y0 + outline.rr }
                PathArc { x: outline.x0 + outline.rr; y: outline.y0; radiusX: outline.rr; radiusY: outline.rr; direction: PathArc.Clockwise }
            }
        }
    }

    // 1x1 invisible surfaces whose only job is to reserve screen edges.
    component EdgeZone: PanelWindow {
        screen: root.targetScreen
        color: "transparent"
        focusable: false
        implicitWidth: 1
        implicitHeight: 1
        mask: Region {}
        WlrLayershell.namespace: "senta-frame-exclusion"
    }

    EdgeZone { anchors.left: true;   exclusiveZone: root.thickness }
    EdgeZone { anchors.right: true;  exclusiveZone: root.thickness }
    EdgeZone { anchors.bottom: true; exclusiveZone: root.thickness }
    // Top edge: the bar's space while it is visible, a normal strip when hidden.
    EdgeZone { anchors.top: true; exclusiveZone: root.barHeight > 0 ? root.barZone : root.thickness }
}
