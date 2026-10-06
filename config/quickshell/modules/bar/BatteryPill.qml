import Quickshell.Widgets
import QtQuick
import "../../components/material"
import "../../theme" as Palette

// Phone-style battery: a rounded body filled to the charge level with the
// percentage printed inside, a small terminal nub, and a bolt while
// charging. Accent while charging, the error colour when low.
Item {
    id: root

    required property var bar

    readonly property int percent: Math.max(0, Math.min(100, bar.batteryPercent))
    readonly property real level: percent / 100
    readonly property bool charging: bar.batteryCharging
    readonly property bool low: percent <= 15 && !charging
    readonly property color fillColor: charging ? Palette.Theme.accent : (low ? Palette.Theme.errorColor : Palette.Theme.textPrimary)

    visible: bar.batteryAvailable
    implicitWidth: body.width + 3
    implicitHeight: 12

    // ClippingRectangle (unlike clip: true) keeps the fill inside the
    // body's rounded corners.
    ClippingRectangle {
        id: body
        width: 28
        height: parent.height
        radius: 4
        color: Qt.alpha(Palette.Theme.textPrimary, 0.18)

        // Charge level.
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * root.level
            color: root.fillColor

            Behavior on width {
                SpatialMotion {}
            }
            Behavior on color {
                ColorMotion {}
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 0

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.charging
                text: "bolt"
                color: label.color
                font.family: Palette.Theme.fontIcons
                font.pixelSize: 9
            }

            Text {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                text: root.percent
                // Dark on a mostly-filled body, light on a mostly-empty one.
                color: root.level > 0.5 ? Palette.Theme.surfaceSolid : Palette.Theme.textPrimary
                font.family: Palette.Theme.fontSans
                font.pixelSize: 8
                font.weight: Font.Bold
            }
        }
    }

    // Terminal nub.
    Rectangle {
        anchors.left: body.right
        anchors.leftMargin: 1
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 5
        radius: 1
        color: Qt.alpha(Palette.Theme.textPrimary, 0.4)
    }
}
