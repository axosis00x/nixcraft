import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../theme" as Palette

// Desktop weather widget: a pill holding the current temperature and
// condition glyph, sourced from services/WeatherService.qml. Shares the
// clock widget's translucent card styling so the pair reads as one set.
Item {
    id: root

    property var service: null
    property var widgetsService: null
    readonly property string widgetId: "weather"
    property real defaultX: 0
    property real defaultY: 0

    readonly property bool available: service ? service.available : false
    readonly property string tempC: service ? service.tempC : ""
    readonly property bool isStale: service ? service.isStale : false
    readonly property string glyph: service ? service.iconGlyph(service.weatherCode) : "cloud"

    implicitWidth: 148
    implicitHeight: 76
    width: implicitWidth
    height: implicitHeight
    visible: available

    // Free-floating on the desktop layer (not laid out by a parent Layout),
    // so position has to be set explicitly — falls back to the caller's
    // default corner spot until the widget has been dragged at least once.
    x: widgetsService && widgetsService.hasPosition(widgetId) ? widgetsService.positionX(widgetId) : defaultX
    y: widgetsService && widgetsService.hasPosition(widgetId) ? widgetsService.positionY(widgetId) : defaultY

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Qt.alpha(Palette.Theme.surfaceContainer, 0.8)
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

    RowLayout {
        anchors.centerIn: parent
        spacing: 10
        opacity: root.isStale ? 0.55 : 1.0

        Rectangle {
            implicitWidth: 40
            implicitHeight: 40
            radius: 20
            color: Qt.alpha(Palette.Theme.accent, 0.18)
            Layout.alignment: Qt.AlignVCenter

            Text {
                anchors.centerIn: parent
                text: root.glyph
                color: Palette.Theme.accent
                font.family: Palette.Theme.fontIcons
                font.pixelSize: Palette.Theme.iconSizeLarge
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: root.tempC + "°"
            color: Palette.Theme.textPrimary
            font.family: Palette.Theme.fontMono
            font.pixelSize: Palette.Theme.fontSizeDisplay
            font.weight: Font.Bold
        }
    }

    // Drag-to-reposition. Position is persisted on release rather than on
    // every move, to avoid hammering the state file.
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
