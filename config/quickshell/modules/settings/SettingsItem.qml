import QtQuick
import QtQuick.Layouts
import "../../components/material"
import "../../theme" as Palette

// One row of a settings group. Rows sit in "connected" groups: the first and
// last get large outer corners, the ones in between stay tight, and a pressed
// row morphs towards a rounder shape.
Item {
    id: root

    // nav | switch | slider | segment | info
    property string kind: "nav"
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string infoText: ""
    property color tint: Palette.Theme.accent
    property bool first: true
    property bool last: true
    property bool checked: false
    property real value: 0
    property var options: []
    property string current: ""

    signal activated
    signal toggled(bool value)
    signal moved(real value)
    signal picked(string id)

    readonly property bool interactive: kind === "nav" || kind === "switch"
    readonly property bool compactRow: kind === "nav" || kind === "switch" || kind === "info"

    implicitHeight: kind === "slider" ? 68 : (kind === "segment" ? 88 : 64)

    Rectangle {
        anchors.fill: parent

        readonly property real bigRadius: 26
        readonly property real smallRadius: 8
        readonly property bool morph: mouse.pressed && root.interactive

        topLeftRadius: morph ? 20 : (root.first ? bigRadius : smallRadius)
        topRightRadius: topLeftRadius
        bottomLeftRadius: morph ? 20 : (root.last ? bigRadius : smallRadius)
        bottomRightRadius: bottomLeftRadius
        color: mouse.containsMouse && root.interactive ? Palette.Theme.surfaceContainerHighest : Palette.Theme.surfaceContainerHigh

        Behavior on topLeftRadius {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
        Behavior on bottomLeftRadius {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.interactive
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.kind === "switch")
                root.toggled(!root.checked);
            else
                root.activated();
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 16
        spacing: 14
        visible: root.compactRow

        Rectangle {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: 20
            color: Qt.alpha(root.tint, 0.2)

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: root.tint
                font.family: Palette.Theme.fontIcons
                font.pixelSize: 21
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 1

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontSans
                font.pixelSize: 14
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.subtitle
                color: Palette.Theme.textMuted
                font.family: Palette.Theme.fontSans
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }

        Text {
            visible: root.kind === "nav"
            text: ""
            color: Palette.Theme.textMuted
            font.family: Palette.Theme.fontIcons
            font.pixelSize: 22
        }

        ToggleSwitch {
            visible: root.kind === "switch"
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 46
            implicitHeight: 27
            checked: root.checked
            accentColor: root.tint
            onToggled: value => root.toggled(value)
        }

        Text {
            visible: root.kind === "info"
            Layout.maximumWidth: 210
            text: root.infoText
            color: Palette.Theme.textSecondary
            font.family: Palette.Theme.fontSans
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 6
        visible: !root.compactRow

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontSans
                font.pixelSize: 14
                font.weight: Font.Medium
            }

            Text {
                visible: root.kind === "slider"
                text: Math.round(root.value * 100) + "%"
                color: Palette.Theme.textMuted
                font.family: Palette.Theme.fontSans
                font.pixelSize: 12
            }
        }

        SettingsSlider {
            visible: root.kind === "slider"
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            value: root.value
            icon: root.icon
            accent: root.tint
            onMoved: value => root.moved(value)
        }

        Row {
            id: segments
            visible: root.kind === "segment"
            Layout.fillWidth: true
            Layout.preferredHeight: 34
            spacing: 3

            Repeater {
                model: root.options

                delegate: Rectangle {
                    id: seg

                    required property var modelData
                    required property int index

                    readonly property bool selected: root.current === modelData.id

                    width: (segments.width - segments.spacing * (root.options.length - 1)) / root.options.length
                    height: segments.height
                    topLeftRadius: index === 0 || selected ? height / 2 : 8
                    bottomLeftRadius: topLeftRadius
                    topRightRadius: index === root.options.length - 1 || selected ? height / 2 : 8
                    bottomRightRadius: topRightRadius
                    color: selected ? root.tint : Palette.Theme.surfaceContainerHighest

                    Behavior on color {
                        ColorAnimation {
                            duration: 140
                        }
                    }
                    Behavior on topLeftRadius {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on topRightRadius {
                        NumberAnimation {
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: seg.modelData.label
                        color: seg.selected ? Palette.Theme.accentText : Palette.Theme.textSecondary
                        font.family: Palette.Theme.fontSans
                        font.pixelSize: 12
                        font.weight: seg.selected ? Font.DemiBold : Font.Medium
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.picked(seg.modelData.id)
                    }
                }
            }
        }
    }
}
