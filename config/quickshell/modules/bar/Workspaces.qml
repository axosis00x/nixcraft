import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../../theme" as Palette

GridLayout {
    id: root

    // Stacks the dots top-to-bottom instead of left-to-right, and grows the
    // active pill vertically instead of horizontally — matching the
    // vertical workspace-switch animation already used at the Hyprland
    // compositor level (config/hypr/modules/vertAni.lua's "slidevert").
    property bool vertical: false
    // Set by Bar.qml so each dot can open the overview parked on the
    // workspace it represents instead of one relative to whatever's focused.
    property var service: null

    columns: vertical ? 1 : 999
    rowSpacing: 3
    columnSpacing: 3

    Repeater {
        model: 10

        Rectangle {
            property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)

            // Layout.preferredWidth/Height (not implicitWidth/Height) is
            // what GridLayout actually watches for live re-layout — driving
            // the pill's grow/shrink through implicit sizing left it static
            // in vertical mode since GridLayout only re-read it on the next
            // unrelated relayout, not on every animation frame.
            Layout.preferredWidth: root.vertical ? 10 : (isActive ? 45 : 10)
            Layout.preferredHeight: root.vertical ? (isActive ? 45 : 10) : 10
            radius: Math.min(width, height) / 2
            // Text-muted is opaque in every palette, unlike transparent
            // surface outlines used by AMOLED themes such as Ryo.
            color: isActive ? Palette.Theme.accent : Palette.Theme.textMuted
            border.width: 0
            scale: isActive ? 1.0 : 0.9

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
                ColorAnimation {
                    duration: 300
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
                // Dots are small (10-45px); grow the hit area so they're
                // easy to click without touching the surrounding capsule.
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.service)
                        root.service.openAt(index);
                }
            }
        }
    }
}
