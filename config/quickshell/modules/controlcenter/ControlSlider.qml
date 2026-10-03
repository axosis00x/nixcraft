import QtQuick
import "../../components/material"
import "../../theme" as Palette

// Control-center level slider: the shared Slider atom, with its inset icon
// doubling as a button (e.g. click to mute, right-click for the mixer).
Item {
    id: root

    property string iconGlyph: ""
    property real value: 0

    signal iconClicked
    signal iconRightClicked
    signal valueRequested(real value)

    implicitWidth: 1
    implicitHeight: 40

    Slider {
        id: slider
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        trackHeight: 24
        showValue: false
        // Matches ControlCenter.minLevel: levels never go below 5%.
        minimum: 0.05
        icon: root.iconGlyph
        value: root.value
        onMoved: value => root.valueRequested(value)
    }

    MouseArea {
        // The icon zone never overlaps the handle (the minimum sits just
        // past it), so clicking the icon always toggles.
        x: slider.x
        width: slider.iconZone
        enabled: !slider.pressed
        height: slider.trackHeight
        anchors.verticalCenter: parent.verticalCenter
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.iconRightClicked();
            else
                root.iconClicked();
        }
    }
}
