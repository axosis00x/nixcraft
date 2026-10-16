import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../theme" as Palette

// Desktop weather widget: the condition glyph and temperature up top with
// the place and today's high/low beside them, then a row of details (feels
// like, humidity, wind). Data comes from services/WeatherService.qml; the
// card matches the clock widget so the pair reads as one set.
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

    implicitWidth: 248
    implicitHeight: 128
    width: implicitWidth
    height: implicitHeight
    // Size from Settings → Customize, grown from the top-left corner so the
    // saved position stays put.
    scale: Palette.Theme.weatherScale
    transformOrigin: Item.TopLeft
    visible: available

    // Free-floating on the desktop layer (not laid out by a parent Layout),
    // so position has to be set explicitly — falls back to the caller's
    // default corner spot until the widget has been dragged at least once.
    // Clamped so a saved spot from a smaller layout stays on screen.
    x: Math.min(widgetsService && widgetsService.hasPosition(widgetId) ? widgetsService.positionX(widgetId) : defaultX, parent ? parent.width - width * scale : 0)
    y: Math.min(widgetsService && widgetsService.hasPosition(widgetId) ? widgetsService.positionY(widgetId) : defaultY, parent ? parent.height - height * scale : 0)

    Rectangle {
        anchors.fill: parent
        radius: Palette.Theme.radiusLarge
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
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10
        opacity: root.isStale ? 0.55 : 1.0

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: width / 2
                color: Qt.alpha(Palette.Theme.yellow, 0.18)

                Text {
                    anchors.centerIn: parent
                    text: root.glyph
                    color: Palette.Theme.yellow
                    font.family: Palette.Theme.fontIcons
                    font.weight: Palette.Theme.iconWeight
                    font.pixelSize: Palette.Theme.iconSizeLarge + 4
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    text: root.tempC + "°"
                    color: Palette.Theme.textPrimary
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeDisplay
                    font.weight: Font.Bold
                }

                Text {
                    Layout.fillWidth: true
                    text: root.service ? root.service.conditionText : ""
                    color: Palette.Theme.textSecondary
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                spacing: 2

                Text {
                    Layout.alignment: Qt.AlignRight
                    Layout.maximumWidth: 90
                    visible: text !== ""
                    text: root.service ? root.service.location : ""
                    color: Palette.Theme.textPrimary
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeSmall
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    Layout.alignment: Qt.AlignRight
                    visible: root.service && root.service.highC !== ""
                    text: root.service ? "↑" + root.service.highC + "°  ↓" + root.service.lowC + "°" : ""
                    color: Palette.Theme.textSecondary
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeXs
                }
            }
        }

        // Details, as three evenly spread chips.
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Detail {
                icon: "thermostat"
                hue: Palette.Theme.orange
                text: root.service && root.service.feelsLikeC !== "" ? root.service.feelsLikeC + "°" : "--"
            }
            Detail {
                icon: "humidity_percentage"
                hue: Palette.Theme.blue
                text: root.service && root.service.humidity !== "" ? root.service.humidity + "%" : "--"
            }
            Detail {
                icon: "air"
                hue: Palette.Theme.aqua
                text: root.service && root.service.windKmph !== "" ? root.service.windKmph + " km/h" : "--"
            }
        }
    }

    component Detail: Rectangle {
        property string icon: ""
        property string text: ""
        property color hue: Palette.Theme.accent

        Layout.fillWidth: true
        Layout.preferredHeight: 28
        radius: height / 2
        color: Palette.Theme.widgetChip

        Row {
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.icon
                color: parent.parent.hue
                font.family: Palette.Theme.fontIcons
                font.weight: Palette.Theme.iconWeight
                font.pixelSize: Palette.Theme.iconSizeSmall
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: parent.parent.text
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeXs
                font.weight: Font.Medium
            }
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
        drag.maximumX: root.parent ? root.parent.width - root.width * root.scale : 0
        drag.maximumY: root.parent ? root.parent.height - root.height * root.scale : 0

        onPressed: root.z = 1000
        onReleased: {
            root.z = 0;
            if (root.widgetsService)
                root.widgetsService.setPosition(root.widgetId, root.x, root.y);
        }
    }
}
