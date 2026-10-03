import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../theme" as Palette

// Desktop clock on a translucent theme-colored card, so it stays readable
// regardless of how bright or busy the wallpaper behind it is.
Item {
    id: root

    property var widgetsService: null
    readonly property string widgetId: "clock"
    property real defaultX: 0
    property real defaultY: 0

    implicitWidth: mainColumn.implicitWidth + 56
    implicitHeight: mainColumn.implicitHeight + 32
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

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Palette.Theme.radiusExtraLarge
        color: Qt.alpha(Palette.Theme.surfaceContainer, 0.8)
        border.width: 1
        border.color: Qt.alpha(Palette.Theme.outlineVariant, 0.6)

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
        anchors.centerIn: parent
        spacing: 2

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4

            Text {
                Layout.alignment: Qt.AlignBaseline
                text: root.pad(root.hours12) + ":" + root.pad(root.minutes)
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontMono
                font.pixelSize: 56
                font.weight: Font.Bold
                font.letterSpacing: -1
            }

            Text {
                Layout.alignment: Qt.AlignBaseline
                text: root.pad(root.seconds)
                color: Palette.Theme.accent
                font.family: Palette.Theme.fontMono
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.weekdayNames[clock.date.getDay()] + ", " + root.dayOfMonth + " " + root.monthNames[clock.date.getMonth()]
            color: Palette.Theme.textSecondary
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeBody
            font.weight: Font.Medium
            font.letterSpacing: 1.5
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
