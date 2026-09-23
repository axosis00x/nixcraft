import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../theme" as Palette

// Immersive desktop clock: bold text sitting straight on the wallpaper —
// no dial, no badges, no background shape. A soft drop shadow is the only
// thing keeping it readable over busy wallpaper content.
Item {
    id: root

    property var widgetsService: null
    readonly property string widgetId: "clock"
    property real defaultX: 0
    property real defaultY: 0

    implicitWidth: mainColumn.implicitWidth
    implicitHeight: mainColumn.implicitHeight
    width: implicitWidth
    height: implicitHeight

    // Free-floating on the desktop layer (not laid out by a parent Layout),
    // so position has to be set explicitly — falls back to the caller's
    // default corner spot until the widget has been dragged at least once.
    x: widgetsService && widgetsService.hasPosition(widgetId) ? widgetsService.positionX(widgetId) : defaultX
    y: widgetsService && widgetsService.hasPosition(widgetId) ? widgetsService.positionY(widgetId) : defaultY

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    readonly property int hours24: clock.date.getHours()
    readonly property int hours12: (hours24 % 12) === 0 ? 12 : (hours24 % 12)
    readonly property int minutes: clock.date.getMinutes()
    readonly property int seconds: clock.date.getSeconds()
    readonly property int dayOfMonth: clock.date.getDate()
    readonly property var weekdayNames: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    readonly property var monthNames: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    function pad(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    ColumnLayout {
        id: mainColumn
        spacing: 0

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.55)
            shadowBlur: 0.7
            shadowVerticalOffset: 2
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.pad(root.hours12) + ":" + root.pad(root.minutes)
            color: Palette.Theme.textPrimary
            font.family: Palette.Theme.fontMono
            font.pixelSize: 64
            font.weight: Font.Black
            font.letterSpacing: -1
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.weekdayNames[clock.date.getDay()] + " " + root.dayOfMonth + " " + root.monthNames[clock.date.getMonth()] + "  ·  " + root.pad(root.seconds)
            color: Palette.Theme.textSecondary
            font.family: Palette.Theme.fontMono
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.letterSpacing: 2
            font.capitalization: Font.AllUppercase
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
