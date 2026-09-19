import QtQuick
import "../../theme" as Palette

Item {
    id: root

    required property string icon
    property string iconSource: ""
    property color iconColor: Palette.Theme.textSecondary
    property color stateColor: Palette.Theme.textPrimary
    property real stateOpacity: hover.pressed ? 0.20 : (hover.containsMouse ? 0.12 : 0)
    signal clicked

    implicitWidth: Palette.Theme.iconButtonSize
    implicitHeight: Palette.Theme.iconButtonSize
    opacity: enabled ? 1 : 0.38

    // M3 Expressive responsive spring interaction
    scale: enabled && hover.pressed ? 0.88 : (enabled && hover.containsMouse ? 1.08 : 1.0)
    Behavior on scale {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutBack
            easing.overshoot: 1.8
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.stateColor
        opacity: root.stateOpacity

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }
    }

    Text {
        anchors.fill: parent
        visible: root.iconSource === ""
        text: root.icon
        color: hover.containsMouse ? Palette.Theme.textPrimary : root.iconColor
        font.family: Palette.Theme.fontIcons
        font.pixelSize: 17
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    Image {
        anchors.centerIn: parent
        visible: root.iconSource !== ""
        width: Math.min(parent.width, parent.height) * 0.46
        height: width
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.enabled) root.clicked()
    }
}
