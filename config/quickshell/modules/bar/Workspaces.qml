import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../../theme" as Palette
import "../../components/material"

// Workspace dots. The focused workspace's dot stretches into an accent pill
// while the previous one eases back down to a dot.
Item {
    id: root

    // Stacks the dots top-to-bottom instead of left-to-right, and grows the
    // active slot vertically instead of horizontally — matching the
    // vertical workspace-switch animation used at the Hyprland compositor
    // level.
    property bool vertical: false
    // Set by Bar.qml so each dot can open the overview parked on the
    // workspace it represents instead of one relative to whatever's focused.
    property var service: null

    // Compact use (the compact bar's status notch) shows only as many dots
    // as are in use — up to the highest occupied or active workspace — but
    // never fewer than three.
    property bool trimToUsed: false
    readonly property int count: {
        if (!trimToUsed)
            return 10;
        var highest = Math.max(3, activeIndex + 1);
        var list = Hyprland.workspaces.values;
        for (var i = 0; i < list.length; i++) {
            if (list[i].id >= 1 && list[i].id <= 10)
                highest = Math.max(highest, list[i].id);
        }
        return highest;
    }
    property real dotSize: 10
    property real activeLength: 45
    property real gap: 3

    readonly property int activeIndex: {
        var id = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1;
        return id >= 1 && id <= 10 ? id - 1 : -1;
    }

    // Opens the overview at the dot under (px, py) in this item's
    // coordinates, or at the current workspace when between dots — for
    // hosts whose own mouse area sits on top (the compact status notch).
    function openAtPosition(px, py) {
        if (!service)
            return;
        for (var i = 0; i < dots.count; i++) {
            var d = dots.itemAt(i);
            if (!d)
                continue;
            var p = d.mapToItem(root, 0, 0);
            if (px >= p.x - 4 && px <= p.x + d.width + 4 && py >= p.y - 6 && py <= p.y + d.height + 6) {
                service.openAt(i);
                return;
            }
        }
        service.openAt(Math.max(0, activeIndex));
    }

    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight

    GridLayout {
        id: grid

        columns: root.vertical ? 1 : 999
        rowSpacing: root.gap
        columnSpacing: root.gap

        Repeater {
            id: dots
            model: root.count

            Rectangle {
                id: dot

                required property int index
                readonly property bool isActive: root.activeIndex === index
                readonly property real length: isActive ? root.activeLength : root.dotSize

                // Layout.preferredWidth/Height (not implicitWidth/Height) is
                // what GridLayout re-lays out on every animation frame.
                Layout.preferredWidth: root.vertical ? root.dotSize : length
                Layout.preferredHeight: root.vertical ? length : root.dotSize
                radius: root.dotSize / 2
                // Text-muted is opaque in every palette, unlike transparent
                // surface outlines used by AMOLED themes such as Ryo.
                color: isActive ? Palette.Theme.accent : (dotMouse.containsMouse ? Palette.Theme.textSecondary : Palette.Theme.textMuted)
                scale: isActive ? 1 : 0.9

                Behavior on Layout.preferredWidth {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on Layout.preferredHeight {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on color {
                    ColorMotion {
                        fast: false
                    }
                }
                Behavior on scale {
                    SpatialMotion {}
                }

                MouseArea {
                    id: dotMouse
                    anchors.fill: parent
                    // Dots are small (10-45px); grow the hit area so they're
                    // easy to click without touching the surrounding capsule.
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.service)
                            root.service.openAt(dot.index);
                    }
                }
            }
        }
    }
}
