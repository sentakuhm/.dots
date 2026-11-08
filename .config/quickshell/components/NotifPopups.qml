import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Theme.js" as Theme

// Floating notification toasts, Caelestia style: one panel hangs from the bar
// at the top-right (lifted popup colour, no gap, concave corner into the bar,
// flush against the right frame) and the toasts stack inside it, newest on top,
// sliding in from its right edge.
// Hovering a toast pauses its timer, swiping it sideways hides it (it stays in
// the notification center). The panel grows and shrinks with its contents.
//
// One transparent full-height surface hosts the panel and is hidden whenever
// there is nothing to show. Its input mask covers only the panel, so clicks
// everywhere else reach the windows underneath.
Scope {
    id: root

    required property var targetScreen
    required property var store
    // Height of the bar (or frame strip) the panel hangs from.
    property int topInset: 36
    // Distance from the right screen edge to the panel (the frame thickness
    // minus 1 px, so the panel overlaps the frame and no seam shows).
    property int edgeGap: 2
    property int cardWidth: 380
    property int maxToasts: 5
    // Padding between the panel edge and the cards.
    property int pad: 10
    // Concave corner radius where the panel meets the bar (0 = plain flush).
    property int fillet: 14
    // Rows drawn over the bar's last pixel row to hide seams.
    property int overlap: 1

    // Left fillet only: the right side is flush against the frame.
    readonly property int panelWidth: cardWidth + pad * 2 + fillet
    readonly property int popupCount: root.store.popups.length
    property bool shown: false

    onPopupCountChanged: {
        if (popupCount > 0) {
            shown = true
            hideTimer.stop()
        } else {
            // Keep the surface alive until the last card has slid out.
            hideTimer.restart()
        }
    }

    Timer {
        id: hideTimer
        interval: 700
        onTriggered: root.shown = false
    }

    PanelWindow {
        id: win

        screen: root.targetScreen
        visible: root.shown
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        focusable: false
        implicitWidth: root.panelWidth + root.edgeGap

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "senta-notifications"

        anchors {
            top: true
            right: true
            bottom: true
        }
        margins {
            top: root.topInset - root.overlap
        }

        // Input only on the panel: the whole window XOR (window minus panel).
        mask: Region {
            x: 0
            y: 0
            width: win.width
            height: win.height
            intersection: Intersection.Xor

            regions: [
                Region {
                    x: panel.x
                    y: panel.y
                    width: panel.width
                    height: panel.height
                    intersection: Intersection.Subtract
                }
            ]
        }

        Item {
            id: panel

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.rightMargin: root.edgeGap
            width: root.panelWidth
            // + fillet: the concave foot that flares into the right frame.
            height: list.height > 0 ? list.height + root.pad * 2 + root.overlap + root.fillet : 0

            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            PopupSurface {
                anchors.fill: parent
                color: Theme.popupBg
                fillet: root.fillet
                topOverlap: root.overlap
                attachRight: true

                ListView {
                    id: list

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: root.pad
                    height: Math.max(0, Math.min(contentHeight, win.height - root.pad * 2 - root.overlap - 16))
                    // Cards slide in from beyond the panel edge, so clip to the list.
                    clip: true
                    // Realise every toast even before the surface has its final size,
                    // otherwise contentHeight (and with it the height) could stay at 0.
                    cacheBuffer: 2000
                    interactive: false
                    spacing: 0

                    model: ScriptModel {
                        values: root.store.popups.slice(0, root.maxToasts)
                    }

                    delegate: Item {
                        id: wrapper

                        required property var modelData
                        required property int index

                        // `index` turns -1 while the delegate is being removed.
                        property int idx: 0
                        onIndexChanged: if (index !== -1) idx = index

                        width: ListView.view ? ListView.view.width : root.cardWidth
                        implicitHeight: card.implicitHeight + (idx === 0 ? 0 : 8)

                        ListView.onRemove: removeAnim.start()

                        SequentialAnimation {
                            id: removeAnim

                            PropertyAction { target: wrapper; property: "ListView.delayRemove"; value: true }
                            PropertyAction { target: wrapper; property: "enabled"; value: false }
                            // Slide out the way it was swiped (right by default), then close the gap.
                            NumberAnimation {
                                target: card
                                property: "x"
                                to: (card.x >= 0 ? 1 : -1) * (wrapper.width + 20)
                                duration: 250
                                easing.type: Easing.InCubic
                            }
                            NumberAnimation {
                                target: wrapper
                                property: "implicitHeight"
                                to: 0
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                            PropertyAction { target: wrapper; property: "ListView.delayRemove"; value: false }
                        }

                        NotifCard {
                            id: card

                            notif: wrapper.modelData
                            store: root.store
                            y: wrapper.idx === 0 ? 0 : 8
                            width: wrapper.width

                            // Start just beyond the list's clip edge, then slide in.
                            x: wrapper.width + 20
                            Component.onCompleted: x = 0
                        }
                    }
                }
            }
        }
    }
}
