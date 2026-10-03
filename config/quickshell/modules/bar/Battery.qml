import QtQuick
import QtQuick.Layouts
import "../../theme" as Palette
import "../../components/material"

Item {
    id: root
    required property var bar
    property bool vertical: false
    property bool showPercent: true
    readonly property int percent: bar ? bar.batteryPercent : 0
    readonly property bool charging: bar ? bar.batteryCharging : false
    readonly property bool available: bar ? bar.batteryAvailable : false
    readonly property string iconFontFamily: Palette.Theme.fontIcons || "Material Symbols Outlined"

    // Neutral by default; color only signals something worth noticing.
    readonly property color colorCritical: Palette.Theme.errorColor
    readonly property color colorLow: Palette.Theme.warning
    readonly property color colorMedium: Palette.Theme.textSecondary
    readonly property color colorGood: Palette.Theme.textSecondary
    readonly property color colorCharging: Palette.Theme.accent

    readonly property string iconGlyph: {
        if (!available)
            return "";
        if (charging)
            return "battery_charging_full";
        if (percent <= 15)
            return "battery_alert";
        if (percent <= 30)
            return "battery_30";
        if (percent <= 60)
            return "battery_60";
        if (percent <= 90)
            return "battery_90";
        return "battery_std";
    }

    readonly property color iconColor: {
        if (charging)
            return colorCharging;
        if (percent <= 15)
            return colorCritical;
        if (percent <= 30)
            return colorLow;
        if (percent <= 60)
            return colorMedium;
        return colorGood;
    }

    visible: available
    implicitWidth: root.vertical ? Math.max(24, row.implicitWidth) : row.implicitWidth
    implicitHeight: root.vertical ? row.implicitHeight : 30

    GridLayout {
        id: row
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 999
        rowSpacing: 3
        columnSpacing: 5

        Text {
            text: root.iconGlyph
            font.family: root.iconFontFamily
            font.pixelSize: Palette.Theme.fontSizeBody
            color: root.iconColor
            verticalAlignment: Text.AlignVCenter
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            Behavior on color {
                ColorMotion {
                    fast: false
                }
            }
        }
        Text {
            visible: root.showPercent
            text: root.percent + "%"
            color: root.iconColor
            font.family: Palette.Theme.fontMono
            font.pixelSize: Palette.Theme.fontSizeBody
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            Behavior on color {
                ColorMotion {
                    fast: false
                }
            }
        }
    }
}
