import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../Theme.js" as Theme

// One notification, styled after Caelestia's cards:
//   - round avatar: the sender's image with a small app-icon badge, or just
//     the app icon on a coloured disc,
//   - bold summary with a one-line body preview,
//   - click the card (or the chevron) to expand: app name, full text, actions
//     and (in the center) an inline reply field,
//   - swipe sideways to dismiss, middle-click to close.
// Used for the floating toasts and inside the notification center.
Rectangle {
    id: card

    required property var notif
    required property var store
    // false = floating toast (hover pauses its timer, swipe hides the toast)
    // true  = inside the center (swipe removes the notification)
    property bool inCenter: false
    property bool expanded: false
    readonly property bool dragging: area.drag.active

    readonly property int pad: 12
    readonly property string iconSource: store.iconPath(notif.appIcon)
    readonly property bool hasImage: notif.image.length > 0

    implicitWidth: 380
    implicitHeight: content.implicitHeight + pad * 2
    radius: 14
    clip: true
    color: notif.critical ? Qt.tint(Theme.surfaceRaised, "#33f7768e") : Theme.surfaceRaised
    border.width: 1
    border.color: notif.critical ? Theme.red : Theme.border

    Behavior on implicitHeight { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on x {
        enabled: !card.dragging
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    HoverHandler {
        enabled: !card.inCenter
        onHoveredChanged: card.notif.hovered = hovered
    }

    // Lowest layer: expand on click, swipe to dismiss, middle-click to close.
    MouseArea {
        id: area

        property bool moved: false

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        preventStealing: true
        drag.target: card
        drag.axis: Drag.XAxis

        onPressed: mouse => {
            moved = false
            if (mouse.button === Qt.MiddleButton) card.notif.close()
        }
        onPositionChanged: if (drag.active) moved = true
        onReleased: {
            if (Math.abs(card.x) > card.width * 0.35) {
                if (card.inCenter) card.notif.close()
                else card.notif.popup = false
            } else {
                card.x = 0
            }
        }
        onClicked: mouse => {
            if (!moved && mouse.button === Qt.LeftButton) card.expanded = !card.expanded
        }
    }

    RowLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.pad
        spacing: 12

        // ---- Avatar -----------------------------------------------------
        Item {
            id: avatar

            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40

            ClippingRectangle {
                anchors.fill: parent
                visible: card.hasImage
                radius: width / 2
                color: Theme.surface

                Image {
                    anchors.fill: parent
                    source: card.hasImage ? Qt.resolvedUrl(card.notif.image) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
            }

            // With an image the app icon becomes a small badge in the corner.
            Rectangle {
                id: badge

                readonly property int size: card.hasImage ? 18 : 40

                x: card.hasImage ? avatar.width - size : 0
                y: card.hasImage ? avatar.height - size : 0
                width: size
                height: size
                radius: size / 2
                color: card.notif.critical ? Theme.red : Theme.accentSoft
                border.width: card.hasImage ? 2 : 0
                border.color: Theme.surfaceRaised

                IconImage {
                    anchors.centerIn: parent
                    visible: card.iconSource.length > 0
                    implicitSize: Math.round(badge.width * 0.62)
                    source: card.iconSource
                }

                Text {
                    anchors.centerIn: parent
                    visible: card.iconSource.length === 0
                    text: "\uf0f3"
                    color: card.notif.critical ? Theme.surface : Theme.accent
                    font.family: Theme.iconFont
                    font.pixelSize: Math.round(badge.width * 0.45)
                }
            }
        }

        // ---- Text -------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 2

            // App name · time (expanded only)
            RowLayout {
                visible: card.expanded
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.maximumWidth: 200
                    text: card.notif.appName || "Notification"
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
                Text {
                    text: "\u2022"
                    color: Theme.muted
                    font.pixelSize: 10
                }
                Text {
                    text: card.store.timeAgo(card.notif.time, card.store.now)
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                }
            }

            // Summary (+ time and chevron while collapsed)
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: card.notif.summary
                    textFormat: Text.PlainText
                    color: Theme.text
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    wrapMode: card.expanded ? Text.Wrap : Text.NoWrap
                    maximumLineCount: card.expanded ? 4 : 1
                    elide: Text.ElideRight
                }
                Text {
                    visible: !card.expanded
                    text: card.store.timeAgo(card.notif.time, card.store.now)
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                }
                Text {
                    id: chevron
                    text: "\uf078"
                    color: Theme.muted
                    font.family: Theme.iconFont
                    font.pixelSize: 10
                    rotation: card.expanded ? 180 : 0
                    Behavior on rotation { NumberAnimation { duration: 180 } }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.expanded = !card.expanded
                    }
                }
            }

            // Body: one-line preview, or the full text when expanded.
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: card.notif.body
                textFormat: Text.StyledText
                color: Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 11
                wrapMode: card.expanded ? Text.Wrap : Text.NoWrap
                maximumLineCount: card.expanded ? 12 : 1
                elide: Text.ElideRight
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            // Actions (expanded only): Close plus whatever the app offers.
            Flow {
                visible: card.expanded
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 6

                ActionButton {
                    text: "Close"
                    muted: true
                    onClicked: card.notif.close()
                }

                Repeater {
                    model: card.notif.actions

                    ActionButton {
                        required property var modelData

                        text: modelData.text
                        onClicked: modelData.invoke()
                    }
                }
            }

            // Inline reply (center only: toasts cannot take keyboard focus).
            RowLayout {
                visible: card.expanded && card.inCenter && card.notif.hasInlineReply
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 6

                TextField {
                    id: replyField

                    Layout.fillWidth: true
                    implicitHeight: 30
                    placeholderText: card.notif.inlineReplyPlaceholder || "Reply\u2026"
                    color: Theme.text
                    placeholderTextColor: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 11
                    onAccepted: card.sendReply()

                    background: Rectangle {
                        radius: 8
                        color: Theme.surface
                        border.width: 1
                        border.color: replyField.activeFocus ? Theme.accent : Theme.border
                    }
                }

                ActionButton {
                    text: "Send"
                    onClicked: card.sendReply()
                }
            }
        }
    }

    function sendReply(): void {
        if (replyField.text.length === 0) return
        card.notif.reply(replyField.text)
        replyField.text = ""
    }

    component ActionButton: Rectangle {
        id: btn

        property string text: ""
        property bool muted: false
        signal clicked()

        implicitWidth: label.implicitWidth + 22
        implicitHeight: 26
        radius: 8
        color: btnMouse.containsMouse
               ? (muted ? Theme.border : Qt.lighter(Theme.accentSoft, 1.3))
               : (muted ? Theme.surface : Theme.accentSoft)

        Text {
            id: label
            anchors.centerIn: parent
            text: btn.text
            color: btn.muted ? Theme.muted : Theme.accent
            font.family: Theme.uiFont
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}
