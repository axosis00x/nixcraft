import Quickshell.Services.Notifications
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../../components/material"
import "../../theme" as Palette

Surface {
    id: card
    required property var notification
    property bool compact: false
    property string iconSource: ""
    property string bodyText: ""
    property var actionTarget: notification
    property bool canDismiss: true
    property bool dismissOnActivate: true
    signal dismissed
    signal activated
    function actionLabel(action) {
        var label = action && action.text ? action.text.trim() : "";
        return /^(activate|default)$/i.test(label) ? "Open" : label;
    }
    function dismissNotification() {
        card.dismissed();
        if (card.canDismiss && card.actionTarget)
            card.actionTarget.dismiss();
    }
    // Notification history records carry a receivedAt (ms since epoch) set
    // when captured; the live toast passes the raw Notification object
    // instead, which has no such field, so it just shows nothing.
    function timeAgo(receivedAt) {
        if (!receivedAt)
            return "";
        var diffSec = Math.max(0, (Date.now() - receivedAt) / 1000);
        if (diffSec < 60)
            return "now";
        if (diffSec < 3600)
            return Math.floor(diffSec / 60) + "m ago";
        if (diffSec < 86400)
            return Math.floor(diffSec / 3600) + "h ago";
        return Math.floor(diffSec / 86400) + "d ago";
    }
    height: implicitHeight
    implicitHeight: content.implicitHeight + 22
    radius: Palette.Theme.radiusMedium
    color: Palette.Theme.surfaceContainer
    tint: notification && notification.urgency === NotificationUrgency.Critical ? Palette.Theme.accent : Palette.Theme.surfaceTint
    tintOpacity: notification && notification.urgency === NotificationUrgency.Critical ? 0.16 : 0.04

    // Keeps the "Xm ago" label advancing while the panel stays open, rather
    // than freezing at whatever it read on first render.
    Timer {
        interval: 30000
        running: card.notification && card.notification.receivedAt
        repeat: true
        triggeredOnStart: false
        onTriggered: timeAgoText.text = card.timeAgo(card.notification.receivedAt)
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Palette.Theme.surfaceTint
        opacity: cardMouse.containsMouse ? 0.06 : 0.025
        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }
    }
    MouseArea {
        id: cardMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            card.activated();
            if (card.dismissOnActivate)
                card.dismissNotification();
        }
    }
    RowLayout {
        id: content
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 11
            rightMargin: 50
        }
        spacing: 12
        Rectangle {
            implicitWidth: 56
            implicitHeight: 56
            radius: 16
            color: Palette.Theme.surfaceContainerHigh
            clip: true
            // Top-aligned rather than centered on the row: a bulky body
            // (long text, action chips) makes the text column taller than
            // the fixed 56px icon, and centering it against that height
            // would float the icon away from the app name/title it belongs
            // next to.
            Layout.alignment: Qt.AlignTop
            Image {
                id: icon
                anchors.fill: parent
                source: card.iconSource
                fillMode: Image.PreserveAspectCrop
                smooth: true
                mipmap: true
                asynchronous: true
                sourceSize.width: 128
                sourceSize.height: 128
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: icon.status !== Image.Ready
                text: ""
                color: Palette.Theme.textSecondary
                font.family: Palette.Theme.fontIcons
                font.pixelSize: 26
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                opacity: icon.status === Image.Null || icon.status === Image.Error ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    text: card.notification ? (card.notification.appName || "Application") : ""
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontMono
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    id: timeAgoText
                    text: card.notification ? card.timeAgo(card.notification.receivedAt) : ""
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontMono
                    font.pixelSize: 10
                    visible: text !== ""
                }
            }
            Text {
                text: card.notification ? (card.notification.summary || "Notification") : ""
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontMono
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                text: card.bodyText
                color: Palette.Theme.textSecondary
                font.family: Palette.Theme.fontMono
                font.pixelSize: 12
                lineHeight: 1.15
                wrapMode: Text.WordWrap
                maximumLineCount: card.compact ? 2 : 5
                elide: Text.ElideRight
                visible: text !== ""
                Layout.fillWidth: true
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 2
                spacing: 8
                visible: card.actionTarget && card.actionTarget.actions.length > 0
                Repeater {
                    model: card.actionTarget ? card.actionTarget.actions : []
                    delegate: ActionChip {
                        required property var modelData
                        label: card.actionLabel(modelData)
                        chipHeight: 22
                        fontPixelSize: 10
                        horizontalPadding: 14
                        onClicked: {
                            modelData.invoke();
                            card.activated();
                            if (card.canDismiss && card.actionTarget && !card.actionTarget.resident)
                                card.dismissNotification();
                        }
                    }
                }
            }
        }
    }
    IconButton {
        icon: "\u{e5cd}"
        implicitWidth: 28
        implicitHeight: 28
        anchors {
            right: parent.right
            rightMargin: 11
            verticalCenter: parent.verticalCenter
        }
        onClicked: card.dismissNotification()
    }
}
