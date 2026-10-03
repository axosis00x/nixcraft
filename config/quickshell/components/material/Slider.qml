import QtQuick
import "../../theme" as Palette

// Material 3 Expressive slider: a thick track split by a slim vertical
// handle, with a small gap on either side of it. The active part carries an
// optional inset icon; a stop dot marks the end of the inactive part. While
// dragging, the handle thins and a value bubble rises above it.
//
// Set `interactive: false` for a read-only meter (OSD).
Item {
    id: root

    property real value: 0
    property string icon: ""
    property bool interactive: true
    // Lowest value the slider can show or be dragged to. The minimum sits
    // just past the inset icon, so the icon always stays on the filled part.
    property real minimum: 0
    // Shows the value bubble above the handle while dragging.
    property bool showValue: true
    property int trackHeight: 16
    property color accent: Palette.Theme.accent
    signal moved(real value)

    // True only once the first drag position is known, so the slider never
    // flashes a stale drag value at the moment of the press.
    readonly property bool pressed: dragging
    property bool dragging: false
    property real dragValue: 0

    // External value changes spring into place; the drag position is shown
    // raw. Keeping the spring off the dragged value means no animation is
    // ever left running underneath the pointer to fight it.
    // While dragging it follows the value directly, so releasing hands
    // over to exactly where the handle already is.
    property real settledValue: value
    Behavior on settledValue {
        enabled: !root.dragging
        SpatialMotion {}
    }

    readonly property real shown: Math.max(minimum, Math.min(1, dragging ? dragValue : settledValue))
    readonly property real progress: (shown - minimum) / Math.max(0.0001, 1 - minimum)

    readonly property real handleGap: interactive ? 5 : 0
    readonly property real handleWidth: interactive ? (dragging ? 2 : 4) : 0
    readonly property real handleSpan: handleWidth + handleGap * 2
    readonly property real innerRadius: 3
    // Width reserved at the start of the track for the inset icon.
    readonly property real iconZone: icon !== "" ? trackHeight + 4 : 0

    implicitWidth: 200
    implicitHeight: interactive ? trackHeight + 14 : trackHeight

    // Handle center; both track halves and the handle hang off it.
    readonly property real handleX: iconZone + handleSpan / 2 + (width - iconZone - handleSpan) * progress

    Rectangle {
        id: active
        anchors.verticalCenter: parent.verticalCenter
        x: 0
        width: Math.max(0, root.handleX - root.handleSpan / 2)
        height: root.trackHeight
        topLeftRadius: height / 2
        bottomLeftRadius: height / 2
        topRightRadius: root.interactive ? root.innerRadius : height / 2
        bottomRightRadius: topRightRadius
        color: root.accent
        visible: width > 0.5
    }

    Rectangle {
        id: inactive
        anchors.verticalCenter: parent.verticalCenter
        x: root.handleX + root.handleSpan / 2
        width: Math.max(0, root.width - x)
        height: root.trackHeight
        topRightRadius: height / 2
        bottomRightRadius: height / 2
        topLeftRadius: root.interactive ? root.innerRadius : 0
        bottomLeftRadius: topLeftRadius
        color: Palette.Theme.surfaceContainerHighest
        visible: width > 0.5

        // Stop indicator.
        Rectangle {
            visible: root.interactive && parent.width > root.trackHeight
            width: 4
            height: 4
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: (root.trackHeight - width) / 2
            color: root.accent
        }
    }

    // Inset icon: lives in the reserved zone at the start of the active
    // track, so it is visible at every value including the minimum.
    Text {
        id: iconText
        visible: root.icon !== ""
        anchors.verticalCenter: parent.verticalCenter
        x: (root.trackHeight - width) / 2 + 2
        readonly property bool onActive: active.width >= root.iconZone - 1
        text: root.icon
        color: onActive ? Palette.Theme.accentText : Palette.Theme.textMuted
        font.family: Palette.Theme.fontIcons
        font.pixelSize: Math.min(Palette.Theme.iconSize, root.trackHeight - 4)

        Behavior on color {
            ColorMotion {}
        }
    }

    Rectangle {
        id: handle
        visible: root.interactive
        anchors.verticalCenter: parent.verticalCenter
        x: root.handleX - width / 2
        width: root.handleWidth
        height: root.trackHeight + 12
        radius: width / 2
        color: root.accent

        Behavior on width {
            SpatialMotion {
                fast: true
            }
        }
    }

    // Value bubble while dragging.
    Rectangle {
        id: bubble
        visible: root.interactive && root.showValue
        width: bubbleText.implicitWidth + 16
        height: 26
        radius: height / 2
        x: root.handleX - width / 2
        y: -height - 6
        color: Palette.Theme.textPrimary
        opacity: root.dragging ? 1 : 0
        scale: root.dragging ? 1 : 0.6
        transformOrigin: Item.Bottom

        Behavior on opacity {
            EffectMotion {}
        }
        Behavior on scale {
            SpatialMotion {
                fast: true
                bouncy: true
            }
        }

        Text {
            id: bubbleText
            anchors.centerIn: parent
            text: Math.round(root.shown * 100)
            color: Palette.Theme.surfaceSolid
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeSmall
            font.weight: Font.DemiBold
        }
    }

    MouseArea {
        id: mouse
        enabled: root.interactive
        anchors.fill: parent
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        function apply(px) {
            var p = Math.max(0, Math.min(1, (px - root.iconZone - root.handleSpan / 2) / Math.max(1, root.width - root.iconZone - root.handleSpan)));
            root.dragValue = root.minimum + p * (1 - root.minimum);
            root.moved(root.dragValue);
        }

        onPressed: event => {
            apply(event.x);
            root.dragging = true;
        }
        onPositionChanged: event => {
            if (root.dragging)
                apply(event.x);
        }
        onReleased: root.dragging = false
        onCanceled: root.dragging = false
    }
}
