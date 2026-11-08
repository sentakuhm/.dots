import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import "../Theme.js" as Theme

// Notification center, Caelestia style: notifications grouped by app with a
// count, collapsible groups, a Do Not Disturb switch and Clear all.
// Fills the PopupSurface it is placed in (the surface draws the background).
Item {
    id: root

    required property var store

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // ---- Header -----------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: "Notifications"
                    color: Theme.text
                    font.family: Theme.uiFont
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Text {
                    text: root.store.count === 0
                          ? "Nothing new"
                          : root.store.count + (root.store.count === 1 ? " notification" : " notifications")
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 10
                }
            }

            HeaderButton {
                icon: root.store.dnd ? "\uf1f6" : "\uf0f3"
                text: "DND"
                active: root.store.dnd
                onClicked: root.store.dnd = !root.store.dnd
            }

            HeaderButton {
                icon: "\uf1f8"
                text: "Clear"
                opacity: root.store.count > 0 ? 1 : 0.4
                onClicked: if (root.store.count > 0) root.store.clearAll()
            }
        }

        // ---- Empty state ------------------------------------------------
        Item {
            visible: root.store.count === 0
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 10

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "\uf1f6"
                    color: Theme.border
                    font.family: Theme.iconFont
                    font.pixelSize: 34
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "You're all caught up."
                    color: Theme.muted
                    font.family: Theme.uiFont
                    font.pixelSize: 12
                }
            }
        }

        // ---- Groups -----------------------------------------------------
        ListView {
            id: groups

            visible: root.store.count > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 12
            boundsBehavior: Flickable.StopAtBounds

            model: ScriptModel {
                values: root.store.appNames
            }

            delegate: ColumnLayout {
                id: group

                required property string modelData

                readonly property var items: root.store.all.filter(n => n.group === group.modelData)
                readonly property string iconSource:
                    items.length > 0 ? root.store.iconPath(items[0].appIcon) : ""
                property bool collapsed: false

                width: ListView.view.width
                spacing: 6

                // Group header: icon, app name, count, clear, collapse.
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Rectangle {
                        implicitWidth: 22
                        implicitHeight: 22
                        radius: 11
                        color: Theme.accentSoft

                        IconImage {
                            anchors.centerIn: parent
                            visible: group.iconSource.length > 0
                            implicitSize: 14
                            source: group.iconSource
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: group.iconSource.length === 0
                            text: "\uf0f3"
                            color: Theme.accent
                            font.family: Theme.iconFont
                            font.pixelSize: 10
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: group.modelData
                        color: Theme.text
                        font.family: Theme.uiFont
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        implicitWidth: Math.max(18, countText.implicitWidth + 10)
                        implicitHeight: 18
                        radius: 9
                        color: Theme.surface

                        Text {
                            id: countText
                            anchors.centerIn: parent
                            text: group.items.length
                            color: Theme.muted
                            font.family: Theme.uiFont
                            font.pixelSize: 9
                            font.weight: Font.DemiBold
                        }
                    }

                    Text {
                        text: "\uf014"
                        color: clearMouse.containsMouse ? Theme.red : Theme.muted
                        font.family: Theme.iconFont
                        font.pixelSize: 11

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            anchors.margins: -5
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.store.clearGroup(group.modelData)
                        }
                    }

                    Text {
                        text: "\uf078"
                        color: Theme.muted
                        font.family: Theme.iconFont
                        font.pixelSize: 10
                        rotation: group.collapsed ? 0 : 180
                        Behavior on rotation { NumberAnimation { duration: 180 } }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -5
                            cursorShape: Qt.PointingHandCursor
                            onClicked: group.collapsed = !group.collapsed
                        }
                    }
                }

                Repeater {
                    model: ScriptModel {
                        values: group.collapsed ? [] : group.items
                    }

                    delegate: Item {
                        id: row

                        required property var modelData

                        Layout.fillWidth: true
                        implicitHeight: rowCard.height

                        NotifCard {
                            id: rowCard

                            notif: row.modelData
                            store: root.store
                            inCenter: true
                            width: row.width
                        }
                    }
                }
            }
        }
    }

    component HeaderButton: Rectangle {
        id: hb

        property string icon: ""
        property string text: ""
        property bool active: false
        signal clicked()

        implicitWidth: hbRow.implicitWidth + 20
        implicitHeight: 27
        radius: 8
        color: hb.active ? Theme.accentSoft : (hbMouse.containsMouse ? Theme.border : Theme.surface)

        Row {
            id: hbRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: hb.icon
                color: hb.active ? Theme.accent : Theme.muted
                font.family: Theme.iconFont
                font.pixelSize: 11
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: hb.text
                color: hb.active ? Theme.accent : Theme.muted
                font.family: Theme.uiFont
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }

        MouseArea {
            id: hbMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: hb.clicked()
        }
    }
}
