import QtQuick
import QtQuick.Controls
import "../Theme.js" as Theme

Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property string tooltip: ""
    property color iconColor: Theme.accent
    property bool compact: false
    // Extra clickable / hoverable area around the visible pill so the empty
    // padding of the bar still hits it: hitPadY covers the strip above and
    // below ((barHeight - pill height) / 2), hitPadLeft / hitPadRight let the
    // first / last pill reach the screen edge (cursor slammed into a corner).
    property int hitPadY: 5
    property int hitPadLeft: 0
    property int hitPadRight: 0

    signal activated(var mouse)
    signal scrolled(int delta)

    implicitHeight: 26
    implicitWidth: content.implicitWidth + (compact ? 18 : 20)
    radius: 9
    color: mouseArea.containsMouse ? Theme.surfaceRaised : Theme.surface
    border.width: 1
    border.color: mouseArea.containsMouse ? Theme.accentSoft : Theme.border

    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 7

        Text {
            visible: root.icon.length > 0
            text: root.icon
            color: root.iconColor
            font.family: Theme.iconFont
            font.pixelSize: 15
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            visible: root.label.length > 0
            text: root.label
            color: Theme.text
            font.family: Theme.uiFont
            font.pixelSize: 11
            font.weight: Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        anchors.topMargin: -root.hitPadY
        anchors.bottomMargin: -root.hitPadY
        anchors.leftMargin: -root.hitPadLeft
        anchors.rightMargin: -root.hitPadRight
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => root.activated(mouse)
        onWheel: wheel => root.scrolled(wheel.angleDelta.y)
    }

    ToolTip.visible: mouseArea.containsMouse && root.tooltip.length > 0
    ToolTip.text: root.tooltip
    ToolTip.delay: 500
}
