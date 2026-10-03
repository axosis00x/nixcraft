import Quickshell
import Quickshell.Wayland
import QtQuick
import "../../components/material"
import "../../theme" as Palette

// A separate overlay layer keeps system feedback visible above fullscreen
// clients without reserving space or accepting pointer/keyboard input.
PanelWindow {
    id: root

    anchors {
        top: true
        right: true
        bottom: true
        left: true
    }
    color: "transparent"
    exclusiveZone: -1
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    property string kind: "volume"
    property real value: 0
    property string label: "0%"
    property bool lockEnabled: false
    property bool presented: false
    readonly property bool isMeter: kind === "volume" || kind === "brightness"

    // The visual is purely informational: an empty input region lets all
    // clicks and gestures pass straight through to the fullscreen client.
    mask: Region {}

    function showMeter(nextKind, nextValue, nextLabel) {
        kind = nextKind;
        value = Math.max(0, Math.min(1, nextValue));
        label = nextLabel !== undefined ? nextLabel : (Math.round(value * 100) + "%");
        presented = true;
        dismissTimer.restart();
    }

    function showLock(nextKind, enabled) {
        kind = nextKind;
        lockEnabled = enabled;
        presented = true;
        dismissTimer.restart();
    }

    Timer {
        id: dismissTimer
        interval: 1100
        onTriggered: root.presented = false
    }

    Surface {
        id: hud
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 72
        width: root.isMeter ? 272 : lockContent.implicitWidth + 28
        height: 42
        radius: Palette.Theme.radiusSmall
        color: Palette.Theme.surfaceContainer
        outlineWidth: 1
        opacity: root.presented ? 1 : 0
        scale: root.presented ? 1 : 0.96
        visible: opacity > 0

        Behavior on opacity {
            EffectMotion {}
        }
        Behavior on scale {
            SpatialMotion {
                fast: true
            }
        }

        Meter {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            visible: root.isMeter
            value: root.value
            label: root.label
            iconGlyph: root.kind === "brightness"
                ? (root.value < 0.5 ? "\ue1ab" : "\ue1ac")
                : (root.label === "Muted" || root.value <= 0.01 ? "\ue04f" : root.value < 0.5 ? "\ue04d" : "\ue050")
        }

        Lock {
            id: lockContent
            anchors.centerIn: parent
            visible: !root.isMeter
            title: root.kind === "capsLock" ? "Caps Lock" : "Num Lock"
            iconGlyph: root.kind === "capsLock" ? "\ue897" : "\ue3d0"
            enabled: root.lockEnabled
        }
    }
}
