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
    // Slider label; empty shows the value as a percentage.
    property string valueText: ""
    signal entered(string text)
    // Slider tick at the default value (0–1), or -1 for none.
    property real defaultValue: -1
    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property string infoText: ""
    property bool first: true
    property bool last: true
    property bool checked: false
    property bool dangerous: false
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

    // Sliders need less vertical room than segmented controls: an 8px inset,
    // one label, a 38px track and a small gap fit comfortably in 82px.
    implicitHeight: kind === "slider" ? 82 : (kind === "segment" ? 98 : (subtitle !== "" ? 58 : 48))

    Rectangle {
        id: shape
        anchors.fill: parent
        anchors.margins: root.dangerous && !root.morph ? 4 : (root.morph ? 3 : 0)
        topLeftRadius: root.dangerous || root.morph ? Palette.Theme.radiusMedium : (root.first ? root.groupRadius : 0)
        topRightRadius: topLeftRadius
        bottomLeftRadius: root.dangerous || root.morph ? Palette.Theme.radiusMedium : (root.last ? root.groupRadius : 0)
        bottomRightRadius: bottomLeftRadius
        color: root.dangerous ? Qt.alpha(Palette.Theme.errorColor, mouse.containsMouse ? 0.14 : 0.07) : (root.morph ? Palette.Theme.surfaceContainerHigh : "transparent")
        border.width: root.dangerous ? (mouse.containsMouse ? 1.5 : 1) : 0
        border.color: Qt.alpha(Palette.Theme.errorColor, mouse.containsMouse ? 0.58 : 0.3)

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
        Behavior on border.color {
            ColorMotion {}
        }
        Behavior on border.width {
            NumberAnimation {
                duration: Palette.Theme.effectDefault
                easing.type: Easing.OutCubic
            }
        }

        StateLayer {
            topLeftRadius: parent.topLeftRadius
            topRightRadius: parent.topRightRadius
            bottomLeftRadius: parent.bottomLeftRadius
            bottomRightRadius: parent.bottomRightRadius
            tone: root.dangerous ? Palette.Theme.errorColor : Palette.Theme.textPrimary
            hovered: mouse.containsMouse && root.interactive
        }
    }

    Rectangle {
        visible: !root.last
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        // A thin gap in the window colour splits the group into segments
        // (as in the control center) rather than an outlined hairline.
        height: 2
        color: Palette.Theme.bg
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
            visible: root.icon !== "" && !root.dangerous
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: Palette.Theme.iconSize
            text: root.icon
            color: root.dangerous ? Palette.Theme.errorColor : Palette.Theme.textMuted
            font.family: Palette.Theme.fontIcons
            font.weight: Palette.Theme.iconWeight
            font.pixelSize: Palette.Theme.iconSize
        }

        Rectangle {
            visible: root.dangerous && root.icon !== ""
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: height / 2
            color: Qt.alpha(Palette.Theme.errorColor, mouse.containsMouse ? 0.2 : 0.13)
            border.width: 1
            border.color: Qt.alpha(Palette.Theme.errorColor, mouse.containsMouse ? 0.38 : 0.22)
            scale: mouse.containsMouse ? 1.04 : 1

            Behavior on color {
                ColorMotion {}
            }
            Behavior on border.color {
                ColorMotion {}
            }
            Behavior on scale {
                SpatialMotion {
                    fast: true
                }
            }

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: Palette.Theme.errorColor
                font.family: Palette.Theme.fontIcons
                font.weight: Palette.Theme.iconWeight
                font.pixelSize: Palette.Theme.iconSize
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: root.title
                color: root.dangerous ? Palette.Theme.errorColor : Palette.Theme.textPrimary
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeBody
                elide: Text.ElideRight

                Behavior on color {
                    ColorMotion {}
                }
            }

            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.subtitle
                color: root.dangerous ? Qt.alpha(Palette.Theme.errorColor, 0.82) : Palette.Theme.textMuted
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeXs
                elide: Text.ElideRight

                Behavior on color {
                    ColorMotion {}
                }
            }
        }

        Text {
            visible: root.kind === "nav"
            text: "chevron_right"
            color: root.dangerous ? Palette.Theme.errorColor : Palette.Theme.textMuted
            font.family: Palette.Theme.fontIcons
            font.weight: Palette.Theme.iconWeight
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
        anchors.topMargin: root.kind === "slider" ? Palette.Theme.spacingSmall : Palette.Theme.spacingMedium
        anchors.bottomMargin: root.kind === "slider" ? Palette.Theme.spacingSmall : Palette.Theme.spacingMedium
        spacing: root.kind === "slider" ? 6 : Palette.Theme.spacingSmall
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

            // Plain value for sliders that don't take typed input.
            Text {
                visible: root.kind === "slider" && root.defaultValue < 0
                text: root.valueText !== "" ? root.valueText : Math.round(root.value * 100) + "%"
                color: Palette.Theme.textMuted
                font.family: Palette.Theme.fontMono
                font.pixelSize: Palette.Theme.fontSizeXs
            }

            // A small field for typing an exact value; Enter applies it.
            Rectangle {
                id: valueField
                visible: root.kind === "slider" && root.defaultValue >= 0
                implicitWidth: Math.max(76, valueInput.contentWidth + 36)
                implicitHeight: 28
                radius: Math.min(height / 2, Palette.Theme.radiusSmall)
                color: Palette.Theme.surfaceContainerHighest
                border.width: valueInput.activeFocus ? 2 : 1
                border.color: valueInput.activeFocus ? Palette.Theme.accent : Palette.Theme.outlineSoft

                Behavior on border.color {
                    ColorMotion {}
                }

                StateLayer {
                    radius: parent.radius
                    hovered: fieldMouse.containsMouse && !valueInput.activeFocus
                }

                TextInput {
                    id: valueInput
                    anchors.left: parent.left
                    anchors.right: pencil.left
                    anchors.leftMargin: 10
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: TextInput.AlignRight
                    text: activeFocus ? text : (root.valueText !== "" ? root.valueText : Math.round(root.value * 100) + "%")
                    color: Palette.Theme.textPrimary
                    selectionColor: Palette.Theme.accentTonal
                    selectedTextColor: Palette.Theme.textPrimary
                    font.family: Palette.Theme.fontMono
                    font.pixelSize: Palette.Theme.fontSizeSmall
                    selectByMouse: true
                    clip: true
                    onAccepted: {
                        root.entered(text);
                        focus = false;
                    }
                    Keys.onEscapePressed: focus = false
                }

                Text {
                    id: pencil
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: valueInput.activeFocus ? "keyboard_return" : "edit"
                    color: valueInput.activeFocus ? Palette.Theme.accent : Palette.Theme.textMuted
                    font.family: Palette.Theme.fontIcons
                    font.weight: Palette.Theme.iconWeight
                    font.pixelSize: Palette.Theme.iconSizeSmall - 2
                }

                MouseArea {
                    id: fieldMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.IBeamCursor
                    visible: !valueInput.activeFocus
                    onClicked: {
                        valueInput.forceActiveFocus();
                        valueInput.selectAll();
                    }
                }
            }
        }

        Slider {
            visible: root.kind === "slider"
            Layout.fillWidth: true
            trackHeight: 24
            icon: root.icon
            value: root.value
            valueText: root.valueText
            mark: root.defaultValue
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
