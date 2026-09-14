import QtQuick
import "../../theme" as Palette

Item {
    id: root

    required property string icon
    property string iconSource: ""
    property color iconColor: Palette.Theme.textSecondary
    property color stateColor: Palette.Theme.textPrimary
    property real stateOpacity: hover.containsMouse ? 0.10 : 0
    signal clicked

    implicitWidth: Palette.Theme.iconButtonSize
    implicitHeight: Palette.Theme.iconButtonSize
    opacity: enabled ? 1 : 0.38

    SequentialAnimation {
        id: pressBounce
        NumberAnimation {
            target: root
            property: "scale"
            to: 0.85
            duration: 80
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "scale"
            to: 1
            duration: 200
            easing.type: Easing.OutBack
            easing.overshoot: 3
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: root.stateColor
        opacity: root.stateOpacity
        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }
    }

    Text {
        anchors.fill: parent
        visible: root.iconSource === ""
        text: root.icon
        color: root.iconColor
        font.family: Palette.Theme.fontIcons
        font.pixelSize: 17
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
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
        onClicked: if (root.enabled) {
            pressBounce.restart();
            root.clicked();
        }
    }
}
