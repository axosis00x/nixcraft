import QtQuick
import "../../theme" as Palette

// Round icon button with a state layer and a springy press.
Item {
    id: root

    required property string icon
    property string iconSource: ""
    property color iconColor: Palette.Theme.textSecondary
    property color stateColor: Palette.Theme.textPrimary
    property int iconSize: Palette.Theme.iconSize
    signal clicked

    implicitWidth: Palette.Theme.iconButtonSize
    implicitHeight: Palette.Theme.iconButtonSize
    opacity: enabled ? 1 : 0.38

    scale: enabled && hover.pressed ? 0.88 : 1
    Behavior on scale {
        SpatialMotion {
            fast: true
            bouncy: true
        }
    }

    StateLayer {
        radius: width / 2
        tone: root.stateColor
        hovered: root.enabled && hover.containsMouse
        pressed: root.enabled && hover.pressed
    }

    Text {
        anchors.fill: parent
        visible: root.iconSource === ""
        text: root.icon
        color: hover.containsMouse ? Palette.Theme.textPrimary : root.iconColor
        font.family: Palette.Theme.fontIcons
        font.pixelSize: root.iconSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        Behavior on color {
            ColorMotion {}
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
        onClicked: if (root.enabled)
            root.clicked()
    }
}
