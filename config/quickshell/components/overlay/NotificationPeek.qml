import Quickshell.Services.Notifications
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../material"
import "../../theme" as Palette

// A new notification, morphing out of the top notch (CenterOverlay puts it
// on the top stage while no top panel is open). Minimal: icon, title with
// the app beside it, one line of body. Hovering holds it open and unfolds
// the rest of the body and any actions; clicking runs its default action.
Item {
    id: root

    property var center: null

    readonly property var notification: center ? center.toastNotification : null
    // CenterOverlay shows this on the stage while true.
    readonly property bool wanted: center !== null && center.toastVisible && notification !== null
    readonly property bool critical: notification !== null && notification.urgency === NotificationUrgency.Critical
    readonly property bool open: hover.hovered
    readonly property var actions: notification ? Array.prototype.filter.call(notification.actions, a => a.identifier !== "default") : []

    implicitWidth: 360
    implicitHeight: content.implicitHeight + 28

    // Don't take clicks while faded out on the stage.
    enabled: wanted

    function hide() {
        if (center)
            center.toastVisible = false;
    }

    HoverHandler {
        id: hover
        onHoveredChanged: if (root.center)
            root.center.holdToast(hovered)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            var list = root.notification ? root.notification.actions : [];
            for (var i = 0; i < list.length; i++) {
                if (list[i].identifier === "default") {
                    list[i].invoke();
                    break;
                }
            }
            root.hide();
        }
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        anchors.leftMargin: 16
        anchors.rightMargin: 12
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // The app's image, or a bell on a tonal disc.
            ClippingRectangle {
                Layout.alignment: Qt.AlignTop
                implicitWidth: 36
                implicitHeight: 36
                radius: icon.status === Image.Ready ? Palette.Theme.radiusXs : width / 2
                color: icon.status === Image.Ready ? "transparent" : Qt.alpha(root.critical ? Palette.Theme.errorColor : Palette.Theme.hueFor(root.notification ? root.notification.appName : ""), Palette.Theme.stateSelected)

                Image {
                    id: icon
                    anchors.fill: parent
                    source: root.center && root.notification ? root.center.notificationIcon(root.notification) : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 64
                    sourceSize.height: 64
                    asynchronous: true
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: icon.status !== Image.Ready
                    text: root.critical ? "priority_high" : "notifications"
                    // Each app gets its own stable hue.
                    color: root.critical ? Palette.Theme.errorColor : Palette.Theme.hueFor(root.notification ? root.notification.appName : "")
                    font.family: Palette.Theme.fontIcons
                    font.weight: Palette.Theme.iconWeight
                    font.pixelSize: Palette.Theme.iconSizeSmall
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        Layout.maximumWidth: implicitWidth
                        text: root.notification ? (root.notification.summary || "Notification") : ""
                        color: Palette.Theme.textPrimary
                        font.family: Palette.Theme.fontSans
                        font.pixelSize: Palette.Theme.fontSizeBody
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: root.notification && root.notification.appName ? "·  " + root.notification.appName : ""
                        color: Palette.Theme.textMuted
                        font.family: Palette.Theme.fontSans
                        font.pixelSize: Palette.Theme.fontSizeXs
                        elide: Text.ElideRight
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.center && root.notification ? root.center.scrub(root.notification.body) : ""
                    color: Palette.Theme.textSecondary
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                    maximumLineCount: root.open ? 3 : 1
                    elide: Text.ElideRight
                }
            }

            IconButton {
                Layout.alignment: Qt.AlignVCenter
                icon: "close"
                implicitWidth: 24
                implicitHeight: 24
                iconSize: Palette.Theme.iconSizeSmall
                opacity: root.open ? 1 : 0
                onClicked: {
                    if (root.notification)
                        root.notification.dismiss();
                    root.hide();
                }

                Behavior on opacity {
                    EffectMotion {}
                }
            }
        }

        // Actions, unfolded while hovered.
        Row {
            Layout.leftMargin: 48
            visible: root.open && root.actions.length > 0
            spacing: 6

            Repeater {
                model: root.open ? root.actions : []

                ActionChip {
                    required property var modelData
                    label: modelData.text
                    chipHeight: 24
                    fontPixelSize: Palette.Theme.fontSizeXs
                    horizontalPadding: 12
                    // Hide first: invoking can close the notification,
                    // which destroys this chip mid-handler.
                    onClicked: {
                        var action = modelData;
                        root.hide();
                        action.invoke();
                    }
                }
            }
        }
    }
}
