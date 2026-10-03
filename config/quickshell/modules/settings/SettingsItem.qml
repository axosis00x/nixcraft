import QtQuick
import QtQuick.Layouts
import "../../components/material"
import "../../theme" as Palette

// One row of a settings group. The group card (SettingsPage) draws the
// container; a row draws its state layer, rounded to match the card on the
// first and last row, and a hairline below every row but the last. Pressing
// an interactive row morphs it into a free-standing rounded card.
Item {
    id: root

    // nav | switch | slider | segment | info
    property string kind: "nav"
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string infoText: ""
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
    readonly property real groupRadius: Palette.Theme.radiusMedium
    readonly property bool morph: mouse.pressed && interactive

    implicitHeight: kind === "slider" ? 72 : (kind === "segment" ? 80 : (subtitle !== "" ? 58 : 48))

    Rectangle {
        id: shape
        anchors.fill: parent
        anchors.margins: root.morph ? 3 : 0
        topLeftRadius: root.morph ? Palette.Theme.radiusMedium : (root.first ? root.groupRadius : 0)
        topRightRadius: topLeftRadius
        bottomLeftRadius: root.morph ? Palette.Theme.radiusMedium : (root.last ? root.groupRadius : 0)
        bottomRightRadius: bottomLeftRadius
        color: root.morph ? Palette.Theme.surfaceContainerHigh : "transparent"

        Behavior on anchors.margins {
            SpatialMotion {
                fast: true
            }
        }
        Behavior on topLeftRadius {
            SpatialMotion {}
        }
        Behavior on bottomLeftRadius {
            SpatialMotion {}
        }
        Behavior on color {
            ColorMotion {}
        }

        StateLayer {
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius
            hovered: mouse.containsMouse && root.interactive
        }
    }

    Rectangle {
        visible: !root.last
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.icon !== "" ? 48 : Palette.Theme.spacingLarge
        height: 1
        color: Palette.Theme.outlineSoft
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
        anchors.leftMargin: Palette.Theme.spacingLarge
        anchors.rightMargin: Palette.Theme.spacingLarge
        spacing: 14
        visible: root.compactRow

        Text {
            visible: root.icon !== ""
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Palette.Theme.iconSize
            text: root.icon
            color: Palette.Theme.textMuted
            font.family: Palette.Theme.fontIcons
            font.pixelSize: Palette.Theme.iconSize
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeBody
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.subtitle
                color: Palette.Theme.textMuted
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeXs
                elide: Text.ElideRight
            }
        }

        Text {
            visible: root.kind === "nav"
            text: "chevron_right"
            color: Palette.Theme.textMuted
            font.family: Palette.Theme.fontIcons
            font.pixelSize: Palette.Theme.iconSize
            // Nudges toward the pointer on hover.
            Layout.rightMargin: mouse.containsMouse ? -3 : 0

            Behavior on Layout.rightMargin {
                SpatialMotion {
                    fast: true
                }
            }
        }

        ToggleSwitch {
            visible: root.kind === "switch"
            Layout.alignment: Qt.AlignVCenter
            checked: root.checked
            onToggled: value => root.toggled(value)
        }

        Text {
            visible: root.kind === "info"
            Layout.maximumWidth: 260
            text: root.infoText
            color: Palette.Theme.textSecondary
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeSmall
            elide: Text.ElideRight
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Palette.Theme.spacingLarge
        anchors.rightMargin: Palette.Theme.spacingLarge
        anchors.topMargin: Palette.Theme.spacingMedium
        anchors.bottomMargin: Palette.Theme.spacingMedium
        spacing: Palette.Theme.spacingSmall
        visible: !root.compactRow

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeBody
            }

            Text {
                visible: root.kind === "slider"
                text: Math.round(root.value * 100) + "%"
                color: Palette.Theme.textMuted
                font.family: Palette.Theme.fontMono
                font.pixelSize: Palette.Theme.fontSizeXs
            }
        }

        Slider {
            visible: root.kind === "slider"
            Layout.fillWidth: true
            trackHeight: 24
            icon: root.icon
            value: root.value
            onMoved: value => root.moved(value)
        }

        // Segmented control: one track with a single indicator that springs
        // between options and stretches as it travels.
        Rectangle {
            id: segTrack
            visible: root.kind === "segment"
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: height / 2
            color: Palette.Theme.surfaceContainerHigh

            readonly property int count: Math.max(1, root.options.length)
            readonly property real segWidth: (width - 8) / count
            readonly property int currentIndex: {
                for (var i = 0; i < root.options.length; i++) {
                    if (root.options[i].id === root.current)
                        return i;
                }
                return -1;
            }

            Rectangle {
                id: indicator
                visible: segTrack.currentIndex >= 0
                y: 4
                height: parent.height - 8
                radius: height / 2
                color: Palette.Theme.accent

                // Leading edge moves fast and trailing edge follows, so the
                // pill visibly stretches toward its destination.
                property real targetL: 4 + segTrack.segWidth * segTrack.currentIndex
                property real targetR: targetL + segTrack.segWidth
                property real leadL: targetL
                property real leadR: targetR
                x: leadL
                width: Math.max(height, leadR - leadL)

                Behavior on leadL {
                    SpatialMotion {
                        fast: indicator.targetL < indicator.leadL
                    }
                }
                Behavior on leadR {
                    SpatialMotion {
                        fast: indicator.targetR > indicator.leadR
                    }
                }
                onTargetLChanged: leadL = targetL
                onTargetRChanged: leadR = targetR
            }

            Row {
                anchors.fill: parent
                anchors.margins: 4

                Repeater {
                    model: root.options

                    delegate: Item {
                        id: seg

                        required property var modelData
                        required property int index

                        readonly property bool selected: segTrack.currentIndex === index

                        width: segTrack.segWidth
                        height: parent.height

                        StateLayer {
                            radius: height / 2
                            hovered: segMouse.containsMouse && !seg.selected
                            pressed: segMouse.pressed
                        }

                        Text {
                            anchors.centerIn: parent
                            text: seg.modelData.label
                            color: seg.selected ? Palette.Theme.accentText : Palette.Theme.textSecondary
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: Palette.Theme.fontSizeSmall
                            font.weight: seg.selected ? Font.DemiBold : Font.Normal

                            Behavior on color {
                                ColorMotion {}
                            }
                        }

                        MouseArea {
                            id: segMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.picked(seg.modelData.id)
                        }
                    }
                }
            }
        }
    }
}
