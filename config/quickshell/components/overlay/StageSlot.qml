import QtQuick
import "../../theme" as Palette

// One panel's place on a stage (a Notch): pinned to the stage's edge so
// the slab's clip reveals it, and crossfaded when panels switch.
Item {
    id: slot

    required property Item panel
    // The Notch the panel sits in; its `panel` property names the one shown.
    required property Item stage
    // Bottom-stage panels rise from the bottom screen edge, top-stage ones
    // drop from the top.
    property bool fromBottom: false
    // How far a panel travels from the edge as it fades.
    property real drift: 14

    property bool leaving: false
    readonly property bool shown: stage.panel === panel && !leaving

    property real reveal: shown ? 1 : 0
    Behavior on reveal {
        SequentialAnimation {
            // The incoming panel waits for the outgoing one to clear.
            PauseAnimation {
                duration: slot.shown ? Palette.Theme.effectFast / 2 : 0
            }
            NumberAnimation {
                // Closing fades a little quicker than opening, in step
                // with the slab easing back to rest.
                duration: slot.shown ? Palette.Theme.effectDefault : (Palette.Theme.effectFast + Palette.Theme.effectDefault) / 2
                easing.type: Easing.OutCubic
            }
        }
    }

    Connections {
        target: slot.panel
        ignoreUnknownSignals: true
        function onAboutToOpen() { slot.leaving = false; }
        function onAboutToClose() { slot.leaving = true; }
        function onVisibleChanged() {
            if (!slot.panel.visible)
                slot.leaving = false;
        }
    }

    Binding { target: slot.panel; property: "width"; value: slot.panel.implicitWidth }
    Binding { target: slot.panel; property: "height"; value: slot.panel.implicitHeight }
    Binding {
        target: slot.panel
        property: "x"
        value: slot.panel.parent ? Math.round((slot.panel.parent.width - slot.panel.width) / 2) : 0
    }
    Binding {
        target: slot.panel
        property: "y"
        value: {
            const travel = slot.drift * (1 - slot.reveal);
            if (!slot.fromBottom)
                return -travel;
            return (slot.panel.parent ? slot.panel.parent.height - slot.panel.height : 0) + travel;
        }
    }
    Binding { target: slot.panel; property: "opacity"; value: slot.reveal }
    Binding { target: slot.panel; property: "scale"; value: 0.96 + 0.04 * slot.reveal }
    Binding {
        target: slot.panel
        property: "transformOrigin"
        value: slot.fromBottom ? Item.Bottom : Item.Top
    }
}
