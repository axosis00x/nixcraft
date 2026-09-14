import QtQuick
import QtQuick.Layouts
import "../../theme" as Palette

Item {
    id: root

    property string title: ""
    property string subtitle: ""
    property string iconSource: ""
    property string iconGlyph: ""
    property int iconSize: 26
    property bool active: false
    property bool compact: false
    property bool iconOnly: false
    property color accentColor: Palette.Theme.accent
    property color activeIconColor: "#000000"
    // Optional per-instance shape override for icon-only tiles (e.g. a
    // toggle that cycles between multiple states can morph its silhouette
    // per state — circle / rounded-square — instead of just swapping
    // color). -1 means "use the normal default radius".
    property real shapeRadius: -1
    // Bind this to whatever value identifies the tile's current state (e.g.
    // a cycling toggle's mode name) to get the bounce below on every state
    // change — `active` alone doesn't cover toggles that stay active while
    // cycling between several non-boolean states.
    property var pulseKey: undefined
    signal clicked()
    signal rightClicked()

    implicitWidth: root.iconOnly ? 54 : 180
    implicitHeight: root.iconOnly ? 54 : (root.compact ? 76 : 82)

    SequentialAnimation {
        id: toggleBounce
        NumberAnimation {
            target: root
            property: "scale"
            to: 1.08
            duration: 100
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "scale"
            to: 1
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 3
        }
    }

    onActiveChanged: toggleBounce.restart()
    onPulseKeyChanged: toggleBounce.restart()

    Rectangle {
        anchors.fill: parent
        radius: root.shapeRadius >= 0 ? root.shapeRadius : Palette.Theme.radiusMedium
        color: root.iconOnly && root.active ? root.accentColor : Palette.Theme.surfaceContainerHighest
        border.width: 0

        Behavior on radius {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutBack
                easing.overshoot: 1.6
            }
        }

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    Rectangle {
        visible: !root.iconOnly
        anchors.fill: parent
        radius: root.shapeRadius >= 0 ? root.shapeRadius : Palette.Theme.radiusMedium
        color: root.accentColor
        opacity: root.active ? 0.12 : 0

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }
    }

    Text {
        visible: root.iconOnly
        anchors.centerIn: parent
        text: root.iconGlyph
        color: root.active ? root.activeIconColor : Palette.Theme.textMuted
        font.family: Palette.Theme.fontIcons
        font.pixelSize: 19
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    Rectangle {
        id: iconContainer
        visible: !root.iconOnly
        width: 40
        height: 40
        radius: width / 2

        anchors {
            left: parent.left
            leftMargin: root.compact ? 14 : 11
            top: root.compact ? undefined : parent.top
            topMargin: root.compact ? 0 : 11
            verticalCenter: root.compact ? parent.verticalCenter : undefined
        }
        color: root.active ? root.accentColor : Palette.Theme.surfaceContainer
        border.width: 0

        Behavior on color {
            ColorAnimation { duration: 120 }
        }

        Image {
            anchors.centerIn: parent
            width: 28
            height: 28
            source: root.iconSource
            visible: root.iconSource !== ""
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }

        Text {
            anchors.centerIn: parent
            visible: root.iconSource === "" && root.iconGlyph !== ""
            text: root.iconGlyph
            color: root.active ? root.activeIconColor : Palette.Theme.textPrimary
            font.family: Palette.Theme.fontIcons
            font.pixelSize: root.iconSize

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    ColumnLayout {
        visible: !root.iconOnly
        anchors {
            // In compact mode, anchor to the icon itself. This avoids any
            // overlap when the tile is resized by the right-side column.
            left: root.compact ? iconContainer.right : parent.left
            right: parent.right
            leftMargin: root.compact ? 10 : 13
            rightMargin: root.compact ? 14 : 12
            top: root.compact ? undefined : iconContainer.bottom
            topMargin: root.compact ? 0 : 8
            verticalCenter: root.compact ? parent.verticalCenter : undefined
        }
        spacing: 1

        Text {
            text: root.title
            color: root.active ? "#ffffff" : Palette.Theme.textPrimary
            font.family: Palette.Theme.fontMono
            font.pixelSize: 13
            font.weight: root.active ? Font.DemiBold : Font.Medium
            elide: Text.ElideRight
            Layout.fillWidth: true

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }

        Text {
            visible: root.subtitle !== ""
            text: root.subtitle
            color: root.active ? Qt.lighter(root.accentColor, 1.35) : Palette.Theme.textMuted
            font.family: Palette.Theme.fontMono
            font.pixelSize: 10
            elide: Text.ElideRight
            Layout.fillWidth: true

            Behavior on color {
                ColorAnimation { duration: 120 }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.shapeRadius >= 0 ? root.shapeRadius : Palette.Theme.radiusMedium
        color: "#ffffff"
        opacity: tileMouse.containsMouse ? 0.04 : 0

        Behavior on opacity {
            NumberAnimation { duration: 100 }
        }
    }

    MouseArea {
        id: tileMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                root.rightClicked()
            else
                root.clicked()
        }
    }
}
