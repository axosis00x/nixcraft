import QtQuick
import "../../components/material"
import "../../theme" as Palette

BarSection {
    id: root

    required property var bar

    implicitWidth: 30
    implicitHeight: 30

    scale: launcherButtonHover.pressed ? 0.88 : 1
    Behavior on scale {
        SpatialMotion {
            fast: true
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Palette.Theme.textPrimary
        opacity: launcherButtonHover.pressed ? 0.22 : (launcherButtonHover.containsMouse ? 0.14 : 0.05)

        Behavior on opacity {
            EffectMotion {}
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
