import QtQuick
import "../../theme" as Palette

// A scrolling stack of titled sections. A section is either a connected
// group of rows or (layout: "tiles") a grid of quick-settings tiles.
Flickable {
    id: root

    required property var panel
    property var sections: []

    contentWidth: width
    contentHeight: column.implicitHeight + 10
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
        id: column
        width: root.width
        spacing: 18

        Repeater {
            model: root.sections

            delegate: Column {
                id: section

                required property var modelData
                readonly property bool tiles: modelData.layout === "tiles"

                width: column.width
                spacing: 8

                Text {
                    visible: text !== ""
                    leftPadding: 6
                    text: section.modelData.title || ""
                    color: Palette.Theme.accent
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                Column {
                    visible: !section.tiles
                    width: section.width
                    spacing: 3

                    Repeater {
                        model: section.tiles ? [] : section.modelData.rows

                        delegate: SettingsEntry {
                            required property var modelData
                            required property int index

                            width: parent.width
                            panel: root.panel
                            spec: modelData
                            isFirst: index === 0
                            isLast: index === section.modelData.rows.length - 1
                        }
                    }
                }

                Flow {
                    id: tileFlow
                    visible: section.tiles
                    width: section.width
                    spacing: 8

                    readonly property int columns: 3

                    Repeater {
                        model: section.tiles ? section.modelData.rows : []

                        delegate: SettingsTileEntry {
                            required property var modelData

                            width: (tileFlow.width - tileFlow.spacing * (tileFlow.columns - 1)) / tileFlow.columns
                            panel: root.panel
                            spec: modelData
                        }
                    }
                }
            }
        }
    }
}
