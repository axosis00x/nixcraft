import QtQuick
import "../../components/material"
import "../../theme" as Palette

BarSection {
    id: root

    required property var bar

    implicitWidth: 30
    implicitHeight: 30

    scale: launcherButtonHover.pressed ? 0.88 : (launcherButtonHover.containsMouse ? 1.08 : 1.0)
    Behavior on scale {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutBack
            easing.overshoot: 1.6
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Palette.Theme.textPrimary
        opacity: launcherButtonHover.pressed ? 0.22 : (launcherButtonHover.containsMouse ? 0.14 : 0.05)

        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }
    }

    Image {
        anchors.centerIn: parent
        width: 18
        height: 18
        source: Qt.resolvedUrl("../../assets/icons/nix-logo.png")
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    MouseArea {
        id: launcherButtonHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.bar.toggleLauncher()
    }
}
