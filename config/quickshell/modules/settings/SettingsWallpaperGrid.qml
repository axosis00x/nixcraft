pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import "../../components/material"
import "../../theme" as Palette

// Thumbnails of the active theme's wallpapers (~/Pictures/wallpapers/<theme>),
// inline in the Appearance page; clicking one sets it. Follows theme
// switches, since each theme has its own folder.
Item {
    id: root

    required property var service

    readonly property string theme: service ? service.activeTheme : ""
    readonly property string dir: theme === "" ? "" : Quickshell.env("HOME") + "/Pictures/wallpapers/" + theme
    property var wallpapers: []

    readonly property int columns: 3
    readonly property real thumbWidth: (width - grid.spacing * (columns - 1)) / columns

    implicitHeight: wallpapers.length > 0 ? grid.implicitHeight : 48

    Component.onCompleted: refresh()
    onDirChanged: refresh()

    function refresh() {
        if (dir === "") {
            wallpapers = [];
            return;
        }
        listProcess.exec(["find", dir, "-maxdepth", "1", "-type", "f", "(", "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", "-o", "-iname", "*.gif", ")"]);
        service.refreshWallpaper();
    }

    Process {
        id: listProcess
        stdout: StdioCollector {
            onStreamFinished: root.wallpapers = text.trim() === "" ? [] : text.trim().split("\n").sort()
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.wallpapers.length === 0
        text: root.dir === "" ? "No active theme" : "No wallpapers in " + root.dir
        color: Palette.Theme.textMuted
        font.family: Palette.Theme.fontSans
        font.pixelSize: Palette.Theme.fontSizeSmall
    }

    Grid {
        id: grid
        width: parent.width
        columns: root.columns
        spacing: Palette.Theme.spacingSmall

        Repeater {
            model: root.wallpapers

            delegate: Item {
                id: thumb

                required property string modelData

                readonly property bool active: modelData === root.service.currentWallpaper

                width: root.thumbWidth
                height: Math.round(width * 9 / 16)
                scale: mouse.pressed ? 0.95 : 1

                Behavior on scale {
                    SpatialMotion {
                        fast: true
                    }
                }

                ClippingRectangle {
                    id: frame
                    anchors.fill: parent
                    radius: thumb.active ? Palette.Theme.radiusLarge : Palette.Theme.radiusMedium
                    color: Palette.Theme.surfaceContainer

                    Behavior on radius {
                        SpatialMotion {}
                    }

                    Image {
                        anchors.fill: parent
                        source: "file://" + thumb.modelData
                        sourceSize.width: 360
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        cache: true
                    }

                    StateLayer {
                        radius: frame.radius
                        hovered: mouse.containsMouse
                        pressed: mouse.pressed
                    }
                }

                // Selected: an accent ring and badge, on top of the photo.
                Rectangle {
                    anchors.fill: parent
                    radius: frame.radius
                    color: "transparent"
                    border.width: thumb.active ? 2 : 0
                    border.color: Palette.Theme.accent

                    Behavior on border.width {
                        EffectMotion {}
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 8
                    width: 22
                    height: 22
                    radius: 11
                    visible: thumb.active
                    color: Palette.Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: "check"
                        color: Palette.Theme.accentText
                        font.family: Palette.Theme.fontIcons
                        font.pixelSize: 16
                    }
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.service.setWallpaper(thumb.modelData)
                }
            }
        }
    }
}
