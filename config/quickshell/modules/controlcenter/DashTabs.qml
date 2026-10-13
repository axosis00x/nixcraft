import QtQuick
import QtQuick.Layouts
import "../../components/material"
import "../../theme" as Palette

// The dashboard's tabs, Caelestia-style and compact: icon and name per tab,
// the current one in accent, a thin indicator sliding under it, and a
// hairline dividing the tabs from the page.
Item {
    id: root

    // [{ id, icon, label }]
    property var tabs: []
    property int current: 0
    signal picked(int index)

    implicitHeight: 38

    // Each tab is as wide as its icon and name; equal gaps go before,
    // between and after them, so the spacing looks even whatever the labels.
    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.top: parent.top
        anchors.bottom: divider.top
        spacing: 0

        Repeater {
            id: repeater
            model: root.tabs

            // A flexible gap, then the tab; one more gap closes the row, so
            // every gap (outer ones included) gets the same width.
            RowLayout {
                id: slot
                required property var modelData
                required property int index
                readonly property alias tab: tab

                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Item {
                    Layout.fillWidth: true
                }

                Item {
                    id: tab
                    readonly property bool selected: slot.index === root.current

                    Layout.fillHeight: true
                    implicitWidth: content.implicitWidth

                    Row {
                        id: content
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: slot.modelData.icon
                            color: tab.selected ? Palette.Theme.accent : Palette.Theme.textMuted
                            font.family: Palette.Theme.fontIcons
                            font.pixelSize: Palette.Theme.iconSizeSmall

                            Behavior on color {
                                ColorMotion {}
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: slot.modelData.label
                            color: tab.selected ? Palette.Theme.accent : Palette.Theme.textMuted
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: Palette.Theme.fontSizeSmall
                            font.weight: tab.selected ? Font.DemiBold : Font.Medium

                            Behavior on color {
                                ColorMotion {}
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.picked(slot.index)
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }
    }

    Rectangle {
        id: divider
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottom: parent.bottom
        height: 1
        color: Palette.Theme.outlineSoft
    }

    // Leading edge fast, trailing edge following: it stretches as it moves.
    Rectangle {
        id: indicator

        readonly property Item target: repeater.count > root.current ? repeater.itemAt(root.current) : null
        property real targetL: target ? row.x + target.x + target.tab.x : 0
        property real targetR: target ? targetL + target.tab.width : 0
        property real leadL: targetL
        property real leadR: targetR

        x: leadL
        width: Math.max(height, leadR - leadL)
        height: 3
        radius: height / 2
        anchors.bottom: parent.bottom
        anchors.bottomMargin: -1
        color: Palette.Theme.accent

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
}
