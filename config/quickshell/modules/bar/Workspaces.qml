import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import "../../theme" as Palette
import "../../components/material"

// Workspace dots with one accent indicator that travels between them. When
// the focused workspace changes, the indicator's leading edge springs ahead
// and its trailing edge follows, so it stretches toward the destination and
// settles into shape there — the same gliding language as the launcher's
// selection. The active slot opens up underneath it at the same time.
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

    readonly property int count: 10
    readonly property real dotSize: 10
    readonly property real activeLength: 45
    readonly property real gap: 3

    readonly property int activeIndex: {
        var id = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1;
        return id >= 1 && id <= count ? id - 1 : -1;
    }

    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight

    GridLayout {
        id: grid

        columns: root.vertical ? 1 : 999
        rowSpacing: root.gap
        columnSpacing: root.gap

        Repeater {
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
                // The active slot is left empty for the indicator to fill.
                color: isActive ? "transparent" : (dotMouse.containsMouse ? Palette.Theme.textSecondary : Palette.Theme.textMuted)
                scale: isActive ? 1 : 0.9

                Behavior on Layout.preferredWidth {
                    SpatialMotion {}
                }
                Behavior on Layout.preferredHeight {
                    SpatialMotion {}
                }
                Behavior on color {
                    ColorMotion {}
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

    // The indicator's resting span along the main axis, computed from the
    // final layout (every slot before the active one is a plain dot) rather
    // than read from the animating slots, so each edge springs exactly once
    // per switch instead of chasing a moving target.
    Rectangle {
        id: indicator

        readonly property real targetStart: Math.max(0, root.activeIndex) * (root.dotSize + root.gap)
        readonly property real targetEnd: targetStart + root.activeLength

        property real leadStart: targetStart
        property real leadEnd: targetEnd

        // Whichever edge points the way the indicator is travelling moves
        // fast; the other trails, stretching the pill mid-flight.
        Behavior on leadStart {
            SpatialMotion {
                fast: indicator.targetStart < indicator.leadStart
            }
        }
        Behavior on leadEnd {
            SpatialMotion {
                fast: indicator.targetEnd > indicator.leadEnd
            }
        }
        onTargetStartChanged: leadStart = targetStart
        onTargetEndChanged: leadEnd = targetEnd

        x: root.vertical ? 0 : leadStart
        y: root.vertical ? leadStart : 0
        width: root.vertical ? root.dotSize : Math.max(root.dotSize, leadEnd - leadStart)
        height: root.vertical ? Math.max(root.dotSize, leadEnd - leadStart) : root.dotSize
        radius: root.dotSize / 2
        color: Palette.Theme.accent
        opacity: root.activeIndex >= 0 ? 1 : 0

        Behavior on opacity {
            EffectMotion {}
        }
    }
}
