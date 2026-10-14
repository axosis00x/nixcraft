import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../theme" as Palette

// Desktop clock: the weekday in accent, a large time with an accent colon,
// and the date. Same card and width as the weather widget, so the two stack
// as a set.
Item {
    id: root

    property var widgetsService: null
    readonly property string widgetId: "clock"
    property real defaultX: 0
    property real defaultY: 0

    implicitWidth: 248
    implicitHeight: mainColumn.implicitHeight + 28
    width: implicitWidth
    height: implicitHeight

    // Free-floating on the desktop layer (not laid out by a parent Layout),
    // so position has to be set explicitly — falls back to the caller's
    // default corner spot until the widget has been dragged at least once.
    x: widgetsService && widgetsService.hasPosition(widgetId) ? widgetsService.positionX(widgetId) : defaultX
    y: widgetsService && widgetsService.hasPosition(widgetId) ? widgetsService.positionY(widgetId) : defaultY

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property int hours24: clock.date.getHours()
    readonly property int hours12: (hours24 % 12) === 0 ? 12 : (hours24 % 12)
    readonly property int minutes: clock.date.getMinutes()
    readonly property int dayOfMonth: clock.date.getDate()
    readonly property var weekdayNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

    function pad(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Palette.Theme.radiusLarge
        // Same language as the rest of the shell: a light glassy surface with a hairline.
        color: Palette.Theme.widgetSurface
        border.width: 1
        border.color: Palette.Theme.outlineSoft

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.45)
            shadowBlur: 0.8
            shadowVerticalOffset: 4
        }
    }

    ColumnLayout {
        id: mainColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 0

        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: root.weekdayNames[clock.date.getDay()]
                color: Palette.Theme.accent
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeBody
                font.weight: Font.DemiBold
            }

            Text {
                text: root.hours24 < 12 ? "AM" : "PM"
                color: Palette.Theme.textSecondary
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeXs
                font.weight: Font.DemiBold
                font.letterSpacing: 1
            }
        }

        Text {
            Layout.topMargin: -4
            textFormat: Text.StyledText
            text: root.pad(root.hours12) + "<font color='" + Palette.Theme.accent + "'>:</font>" + root.pad(root.minutes)
            color: Palette.Theme.textPrimary
            font.family: Palette.Theme.fontSans
            font.pixelSize: 64
            font.weight: Font.DemiBold
            font.letterSpacing: -2
            font.features: {
                "tnum": 1
            }
        }

        Text {
            Layout.topMargin: -4
            text: root.dayOfMonth + " " + root.monthNames[clock.date.getMonth()]
            color: Palette.Theme.textSecondary
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeBody
        }
    }

    // Drag-to-reposition — covers the whole widget. Position is persisted
    // on release rather than on every move, to avoid hammering the state
    // file.
    MouseArea {
        anchors.fill: parent
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: root
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: root.parent ? root.parent.width - root.width : 0
        drag.maximumY: root.parent ? root.parent.height - root.height : 0

        onPressed: root.z = 1000
        onReleased: {
            root.z = 0;
            if (root.widgetsService)
                root.widgetsService.setPosition(root.widgetId, root.x, root.y);
        }
    }
}
