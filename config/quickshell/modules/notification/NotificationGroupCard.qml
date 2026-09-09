import QtQuick
import QtQuick.Layouts
import "../../components/material"
import "../../theme" as Palette

ColumnLayout {
    id: root

    required property var notificationCenter
    required property var group // { appName, items: [...] }
    readonly property bool expanded: notificationCenter ? notificationCenter.isExpanded(group.appName) : false
    readonly property bool hasStack: group.items.length > 1

    spacing: 8

    Item {
        Layout.fillWidth: true
        implicitHeight: topCard.implicitHeight

        Repeater {
            model: root.expanded ? 0 : Math.min(2, root.group.items.length - 1)
            delegate: Rectangle {
                required property int index
                property int depth: index + 1
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    leftMargin: depth * 6
                    rightMargin: depth * 6
                    topMargin: depth * 6
                }
                height: topCard.implicitHeight
                radius: Palette.Theme.radiusMedium
                color: Palette.Theme.surfaceContainer
                opacity: 0.5 - depth * 0.15
                z: -depth
            }
        }

        NotificationCard {
            id: topCard
            width: parent.width
            notification: root.group.items[0]
            iconSource: root.notificationCenter ? root.notificationCenter.notificationIcon(root.group.items[0]) : ""
            bodyText: root.notificationCenter ? root.notificationCenter.scrub(root.group.items[0].body) : ""
            actionTarget: root.notificationCenter ? root.notificationCenter.liveNotification(root.group.items[0]) : null
            canDismiss: root.group.items[0].live
            dismissOnActivate: false
            onDismissed: root.notificationCenter.dismissRecord(root.group.items[0])
            compact: root.hasStack
            onActivated: {
                if (root.hasStack)
                    root.notificationCenter.toggleGroup(root.group.appName);
            }
        }

        Rectangle {
            visible: root.hasStack
            width: 22
            height: 22
            radius: 11
            color: Palette.Theme.accent
            anchors {
                right: topCard.right
                top: topCard.top
                rightMargin: 6
                topMargin: 6
            }

            Text {
                anchors.centerIn: parent
                text: String(root.group.items.length)
                color: Palette.Theme.surface
                font.family: Palette.Theme.fontMono
                font.pixelSize: 10
                font.weight: Font.Bold
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: root.expanded && root.hasStack

        Repeater {
            model: root.expanded ? root.group.items.slice(1) : []
            delegate: NotificationCard {
                required property var modelData
                Layout.fillWidth: true
                notification: modelData
                iconSource: root.notificationCenter ? root.notificationCenter.notificationIcon(modelData) : ""
                bodyText: root.notificationCenter ? root.notificationCenter.scrub(modelData.body) : ""
                actionTarget: root.notificationCenter ? root.notificationCenter.liveNotification(modelData) : null
                canDismiss: modelData.live
                dismissOnActivate: false
                onDismissed: root.notificationCenter.dismissRecord(modelData)
            }
        }
    }

    ActionChip {
        visible: root.hasStack
        Layout.alignment: Qt.AlignHCenter
        label: root.expanded ? "Collapse" : "View all (" + root.group.items.length + ")"
        active: root.expanded
        onClicked: root.notificationCenter.toggleGroup(root.group.appName)
    }
}
