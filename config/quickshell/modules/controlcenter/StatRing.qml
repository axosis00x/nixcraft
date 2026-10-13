import QtQuick
import QtQuick.Shapes
import "../../components/material"
import "../../theme" as Palette

// A circular gauge: a quiet track with an accent arc sweeping clockwise
// from the top, the value in the middle and a label underneath.
Item {
    id: root

    property real value: 0
    property string label: ""
    // What's printed in the middle; defaults to the percentage.
    property string text: Math.round(value * 100) + "%"
    property string caption: ""
    property real size: 72
    property real thickness: 7
    property color accent: Palette.Theme.accent

    implicitWidth: Math.max(size, labelColumn.implicitWidth)
    implicitHeight: size + labelColumn.implicitHeight + 8

    // Eases to new readings rather than jumping.
    property real shown: Math.max(0, Math.min(1, value))
    Behavior on shown {
        NumberAnimation {
            duration: Palette.Theme.motionDefault
            easing.type: Easing.OutCubic
        }
    }

    Item {
        id: dial
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.size
        height: root.size

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.alpha(Palette.Theme.textPrimary, 0.1)
                strokeWidth: root.thickness
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: root.size / 2
                    centerY: root.size / 2
                    radiusX: (root.size - root.thickness) / 2
                    radiusY: radiusX
                    startAngle: 0
                    sweepAngle: 360
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.accent
                strokeWidth: root.thickness
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: root.size / 2
                    centerY: root.size / 2
                    radiusX: (root.size - root.thickness) / 2
                    radiusY: radiusX
                    startAngle: -90
                    sweepAngle: Math.max(0.5, root.shown * 360)
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.text
            color: Palette.Theme.textPrimary
            font.family: Palette.Theme.fontSans
            font.pixelSize: root.size > 80 ? Palette.Theme.fontSizeTitle : Palette.Theme.fontSizeBody
            font.weight: Font.DemiBold
        }
    }

    Column {
        id: labelColumn
        anchors.top: dial.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 1

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            color: Palette.Theme.textSecondary
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeSmall
            font.weight: Font.Medium
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.caption !== ""
            text: root.caption
            color: Palette.Theme.textMuted
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeXs
        }
    }
}
