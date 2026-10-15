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
        // A handler of `dismissed` (the notification center's record
        // removal) may already have closed it; dismissing a closed
        // notification again logs "Cannot close destroyed notification".
        if (card.canDismiss && card.actionTarget && card.actionTarget.tracked)
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
    // Compact cards morph open on hover: the full text springs into view
    // and the corners round out, then they settle back when the pointer
    // leaves. Full cards always show everything.
    readonly property bool open: !compact || cardHover.hovered
    readonly property bool critical: notification && notification.urgency === NotificationUrgency.Critical
    // How many notifications this card stands for (a stacked group), shown
    // as a pill beside the app name.
    property int count: 1

    height: implicitHeight
    implicitHeight: content.implicitHeight + 24
    radius: open && compact ? Palette.Theme.radiusLarge : Palette.Theme.radiusMedium
    color: Palette.Theme.surfaceContainer
    tint: critical ? Palette.Theme.errorColor : Palette.Theme.surfaceTint
    tintOpacity: critical ? 0.12 : 0.03
    outlineWidth: critical ? 1 : 0
    outlineColor: Qt.alpha(Palette.Theme.errorColor, 0.5)

    Behavior on height {
        SpatialMotion {
            fast: true
        }
    }
    Behavior on radius {
        SpatialMotion {}
    }

    // Keeps the "Xm ago" label advancing while the panel stays open, rather
    // than freezing at whatever it read on first render.
    Timer {
        interval: 30000
        running: !!(card.notification && card.notification.receivedAt)
        repeat: true
        triggeredOnStart: false
        onTriggered: timeAgoText.text = card.timeAgo(card.notification.receivedAt)
    }

    // Hover over the whole card, including its buttons.
    HoverHandler {
        id: cardHover
    }

    StateLayer {
        radius: card.radius
        hovered: cardHover.hovered
        pressed: cardMouse.pressed
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
            margins: 12
        }
        spacing: 12

        // The app's image, or a bell on a tonal circle when there is none.
        ClippingRectangle {
            Layout.alignment: Qt.AlignTop
            implicitWidth: 36
            implicitHeight: 36
            radius: icon.status === Image.Ready ? Palette.Theme.radiusXs + 2 : width / 2
            color: icon.status === Image.Ready ? "transparent" : (card.critical ? Qt.alpha(Palette.Theme.errorColor, 0.18) : Palette.Theme.accentTonal)

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
                    EffectMotion {
                        fast: false
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: icon.status !== Image.Ready
                text: card.critical ? "priority_high" : "notifications"
                color: card.critical ? Palette.Theme.errorColor : Palette.Theme.accent
                font.family: Palette.Theme.fontIcons
                font.weight: Palette.Theme.iconWeight
                font.pixelSize: Palette.Theme.iconSize
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            // Title · app ..........  time  [count]  ✕
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    Layout.maximumWidth: implicitWidth
                    text: card.notification ? (card.notification.summary || "Notification") : ""
                    color: Palette.Theme.textPrimary
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeBody
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: card.notification ? "·  " + (card.notification.appName || "Application") : ""
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeXs
                    elide: Text.ElideRight
                }

                Text {
                    id: timeAgoText
                    visible: text !== ""
                    text: card.notification ? card.timeAgo(card.notification.receivedAt) : ""
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeXs
                }

                Rectangle {
                    visible: card.count > 1
                    implicitWidth: Math.max(20, countText.implicitWidth + 10)
                    implicitHeight: 18
                    radius: height / 2
                    color: Palette.Theme.accentTonal

                    Text {
                        id: countText
                        anchors.centerIn: parent
                        text: card.count
                        color: Palette.Theme.accent
                        font.family: Palette.Theme.fontSans
                        font.pixelSize: Palette.Theme.fontSizeXs
                        font.weight: Font.DemiBold
                    }
                }

                IconButton {
                    icon: "close"
                    implicitWidth: 22
                    implicitHeight: 22
                    iconSize: Palette.Theme.iconSizeSmall
                    // Faded, not hidden, so the time doesn't shift on hover.
                    opacity: cardHover.hovered ? 1 : 0
                    onClicked: card.dismissNotification()

                    Behavior on opacity {
                        EffectMotion {}
                    }
                }
            }

            Text {
                text: card.bodyText
                color: Palette.Theme.textSecondary
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeSmall
                lineHeight: 1.15
                wrapMode: Text.WordWrap
                maximumLineCount: card.open ? 5 : 2
                elide: Text.ElideRight
                visible: text !== ""
                Layout.fillWidth: true
                Layout.rightMargin: 4
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                spacing: 8
                visible: card.actionTarget && card.actionTarget.actions.length > 0
                Repeater {
                    model: card.actionTarget ? card.actionTarget.actions : []
                    delegate: ActionChip {
                        required property var modelData
                        label: card.actionLabel(modelData)
                        chipHeight: 24
                        fontPixelSize: Palette.Theme.fontSizeXs
                        horizontalPadding: 14
                        // The action goes first (an app expects it before
                        // the close), and it may destroy this chip by closing
                        // the notification, so only plain references are
                        // used after it.
                        onClicked: {
                            var c = card;
                            var dismiss = c.canDismiss && c.actionTarget && !c.actionTarget.resident;
                            modelData.invoke();
                            c.activated();
                            if (dismiss)
                                c.dismissNotification();
                        }
                    }
                }
            }
        }
    }
}
