import QtQuick
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
    readonly property real tabContentWidth: {
        var total = 0;
        for (var i = 0; i < repeater.count; i++) {
            var slot = repeater.itemAt(i);
            if (slot)
                total += slot.width;
        }
        return total;
    }
    readonly property real tabGap: Math.max(0, (row.width - tabContentWidth) / (tabs.length + 1))
    function tabContentWidthBefore(index) {
        var total = 0;
        for (var i = 0; i < index; i++) {
            var slot = repeater.itemAt(i);
            if (slot)
                total += slot.width;
        }
        return total;
    }

    // Position each tab using one shared gap, including both outer edges.
    Item {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: divider.top

        Repeater {
            id: repeater
            model: root.tabs

            Item {
                id: slot
                required property var modelData
                required property int index
                readonly property alias tab: tab

                x: root.tabGap * (index + 1) + root.tabContentWidthBefore(index)
                width: tab.implicitWidth
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                Item {
                    id: tab
                    readonly property bool selected: slot.index === root.current

                    implicitWidth: content.implicitWidth
                    anchors.fill: parent

                    Row {
                        id: content
                        anchors.centerIn: parent
                        spacing: 5

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: slot.modelData.icon
                            color: tab.selected ? Palette.Theme.accent : Palette.Theme.textMuted
                            font.family: Palette.Theme.fontIcons
                            font.weight: Palette.Theme.iconWeight
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
                        id: mouse
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.picked(slot.index)
                    }
                }
            }
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
