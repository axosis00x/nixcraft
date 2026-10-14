import QtQuick
import QtQuick.Layouts
import "../../components/material"
import "../notification"
import "../../theme" as Palette

// The dashboard's notifications tab: a title with the count and a clear
// button, then the cards (newest in full, older ones compact until hovered),
// or a calm empty state.
Item {
    id: root

    // The control center, for its notification state and actions.
    required property var center

    readonly property var notificationCenter: center.notificationCenter
    readonly property int count: center.notificationCount

    implicitHeight: 380

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        anchors.topMargin: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            spacing: 8

            Text {
                text: "Notifications"
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeTitle
                font.weight: Font.DemiBold
            }

            Rectangle {
                visible: root.count > 0
                implicitWidth: Math.max(22, countText.implicitWidth + 12)
                implicitHeight: 22
                radius: height / 2
                color: Palette.Theme.accentTonal

                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: root.count
                    color: Palette.Theme.accent
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeXs
                    font.weight: Font.DemiBold
                }
            }

            Item {
                Layout.fillWidth: true
            }

            IconButton {
                icon: root.center.dndEnabled ? "notifications_off" : "notifications_active"
                implicitWidth: 32
                implicitHeight: 32
                iconSize: Palette.Theme.iconSizeSmall
                iconColor: root.center.dndEnabled ? Palette.Theme.accent : Palette.Theme.textSecondary
                onClicked: root.center.toggleDnd()
            }

            IconButton {
                icon: "delete_outline"
                implicitWidth: 32
                implicitHeight: 32
                iconSize: Palette.Theme.iconSizeSmall
                enabled: root.count > 0
                opacity: enabled ? 1 : 0.35
                onClicked: root.center.clearAllNotifications()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                anchors.fill: parent
                clip: true
                spacing: 8
                model: root.notificationCenter ? root.notificationCenter.groupedNotifications : []
                visible: root.count > 0
                reuseItems: true
                cacheBuffer: 320

                delegate: NotificationGroupCard {
                    required property var modelData
                    required property int index
                    featured: index === 0
                    width: ListView.view.width
                    notificationCenter: root.notificationCenter
                    group: modelData
                }
            }

            EmptyState {
                anchors.centerIn: parent
                visible: root.count === 0
                icon: root.center.dndEnabled ? "notifications_paused" : "notifications_none"
                text: root.center.dndEnabled ? "Do not disturb is on" : "You're all caught up"
            }
        }
    }
}
