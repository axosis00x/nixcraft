pragma ComponentBehavior: Bound

import QtQuick
import "../../components/material"
import "../../theme" as Palette

// Every theme as a card with its palette as a strip, inline in the
// Appearance page; clicking a card applies that theme.
Grid {
    id: root

    required property var service

    columns: 4
    spacing: Palette.Theme.spacingSmall

    readonly property real cardWidth: (width - spacing * (columns - 1)) / columns

    Repeater {
        model: root.service ? root.service.themes : []

        delegate: Item {
            id: card

            required property string modelData

            readonly property bool active: modelData === root.service.activeTheme

            width: root.cardWidth
            height: 66
            scale: mouse.pressed ? 0.95 : 1

            Behavior on scale {
                SpatialMotion {
                    fast: true
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: card.active ? Palette.Theme.radiusLarge : Palette.Theme.radiusMedium
                color: card.active ? Palette.Theme.accentTonal : Palette.Theme.surfaceContainer

                Behavior on radius {
                    SpatialMotion {}
                }
                Behavior on color {
                    ColorMotion {}
                }

                StateLayer {
                    radius: parent.radius
                    hovered: mouse.containsMouse
                    pressed: mouse.pressed
                }
            }

            Text {
                anchors.left: parent.left
                anchors.right: check.left
                anchors.top: parent.top
                anchors.leftMargin: 14
                anchors.rightMargin: 4
                anchors.topMargin: 12
                text: card.modelData.charAt(0).toUpperCase() + card.modelData.slice(1).replace(/-/g, " ")
                color: card.active ? Palette.Theme.accent : Palette.Theme.textPrimary
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeSmall
                font.weight: card.active ? Font.DemiBold : Font.Medium
                elide: Text.ElideRight
            }

            Text {
                id: check
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 10
                anchors.topMargin: 10
                visible: card.active
                text: "check"
                color: Palette.Theme.accent
                font.family: Palette.Theme.fontIcons
                font.pixelSize: Palette.Theme.iconSizeSmall
            }

            // The theme's palette as one segmented strip.
            Row {
                id: strip
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                anchors.bottomMargin: 13
                height: 8
                spacing: 2

                readonly property var colors: root.service.swatchesFor(card.modelData)

                Repeater {
                    model: strip.colors

                    delegate: Rectangle {
                        required property var modelData
                        required property int index

                        width: (strip.width - strip.spacing * (strip.colors.length - 1)) / Math.max(1, strip.colors.length)
                        height: strip.height
                        topLeftRadius: index === 0 ? height / 2 : 2
                        bottomLeftRadius: topLeftRadius
                        topRightRadius: index === strip.colors.length - 1 ? height / 2 : 2
                        bottomRightRadius: topRightRadius
                        color: modelData
                    }
                }
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.service.apply(card.modelData)
            }
        }
    }
}
