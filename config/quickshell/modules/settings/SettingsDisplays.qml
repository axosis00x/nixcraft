pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../components/material"
import "../../theme" as Palette

// One card per connected output with its resolution and scale as chips,
// plus a confirm banner while a change is still provisional (it reverts on
// its own unless kept — see DisplayService).
ColumnLayout {
    id: root

    required property var service

    spacing: Palette.Theme.spacingSmall

    Component.onCompleted: service.refresh()

    // ── confirm banner ──────────────────────────────────────────────
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        visible: root.service.pending
        radius: Palette.Theme.radiusMedium
        color: Palette.Theme.accentTonal

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Palette.Theme.spacingLarge
            anchors.rightMargin: Palette.Theme.spacingMedium
            spacing: Palette.Theme.spacingMedium

            Text {
                text: "timer"
                color: Palette.Theme.accent
                font.family: Palette.Theme.fontIcons
                font.pixelSize: Palette.Theme.iconSize
            }

            Text {
                Layout.fillWidth: true
                text: "Keep these display settings? Reverting in " + root.service.secondsLeft + " s"
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeBody
                elide: Text.ElideRight
            }

            ActionChip {
                label: "Revert"
                onClicked: root.service.revert()
            }

            ActionChip {
                label: "Keep"
                active: true
                onClicked: root.service.keep()
            }
        }
    }

    // ── one card per output ─────────────────────────────────────────
    Repeater {
        model: root.service.monitors

        delegate: Rectangle {
            id: card

            required property var modelData

            readonly property bool builtIn: root.service.isBuiltIn(modelData.name)
            readonly property bool mirroring: modelData.mirrorOf && modelData.mirrorOf !== "none"
            readonly property var modes: root.service.modesFor(modelData)

            Layout.fillWidth: true
            implicitHeight: body.implicitHeight + Palette.Theme.spacingLarge * 2
            radius: Palette.Theme.radiusMedium
            color: Palette.Theme.surfaceContainer

            ColumnLayout {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Palette.Theme.spacingLarge
                spacing: Palette.Theme.spacingMedium

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 40
                        radius: 20
                        color: Palette.Theme.accentTonal

                        Text {
                            anchors.centerIn: parent
                            text: card.builtIn ? "laptop" : "desktop_windows"
                            color: Palette.Theme.accent
                            font.family: Palette.Theme.fontIcons
                            font.pixelSize: Palette.Theme.iconSizeLarge
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: card.builtIn ? "Built-in display" : (card.modelData.make && card.modelData.model ? card.modelData.make + " " + card.modelData.model : card.modelData.name)
                            color: Palette.Theme.textPrimary
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: Palette.Theme.fontSizeBody
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: card.modelData.name + "  ·  " + card.modelData.width + "×" + card.modelData.height + " @ " + Math.round(card.modelData.refreshRate) + " Hz  ·  " + Math.round(card.modelData.scale * 100) + "%" + (card.mirroring ? "  ·  mirroring " + card.modelData.mirrorOf : "")
                            color: Palette.Theme.textMuted
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: Palette.Theme.fontSizeXs
                            elide: Text.ElideRight
                        }
                    }
                }

                Text {
                    text: "Resolution"
                    color: Palette.Theme.textSecondary
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeSmall
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: card.modes

                        delegate: ActionChip {
                            required property var modelData

                            label: modelData.res.replace("x", "×") + "  ·  " + Math.round(modelData.hz) + " Hz"
                            active: root.service.isCurrentMode(card.modelData, modelData)
                            onClicked: {
                                if (!active)
                                    root.service.setMode(card.modelData.name, modelData.id);
                            }
                        }
                    }
                }

                Text {
                    text: "Scale"
                    color: Palette.Theme.textSecondary
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeSmall
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: root.service.scalesFor(card.modelData)

                        delegate: ActionChip {
                            required property real modelData

                            label: Math.round(modelData * 100) + "%"
                            active: Math.abs(card.modelData.scale - modelData) < 0.01
                            onClicked: {
                                if (!active)
                                    root.service.setScale(card.modelData.name, modelData);
                            }
                        }
                    }
                }
            }
        }
    }
}
