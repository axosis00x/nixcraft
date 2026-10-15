import QtQuick
import QtQuick.Layouts
import "../../components/material"
import "../../theme" as Palette

// A compact month grid: month title with previous/next buttons, weekday
// initials, and the days, today in an accent circle. Opens on the current
// month; `reset()` jumps back to it.
Item {
    id: root

    property date today: new Date()
    property int year: today.getFullYear()
    property int month: today.getMonth()

    function reset() {
        today = new Date();
        year = today.getFullYear();
        month = today.getMonth();
    }

    function step(delta) {
        var m = month + delta;
        year += Math.floor(m / 12);
        month = ((m % 12) + 12) % 12;
    }

    // Monday-first grid of 42 cells; days outside the month are 0.
    readonly property var cells: {
        var first = new Date(year, month, 1);
        var offset = (first.getDay() + 6) % 7;
        var days = new Date(year, month + 1, 0).getDate();
        var out = [];
        for (var i = 0; i < 42; i++) {
            var d = i - offset + 1;
            out.push(d >= 1 && d <= days ? d : 0);
        }
        // Drop a trailing empty week.
        return out.slice(35).every(v => v === 0) ? out.slice(0, 35) : out;
    }

    implicitHeight: column.implicitHeight

    ColumnLayout {
        id: column
        anchors.fill: parent
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: Qt.locale().standaloneMonthName(root.month) + " " + root.year
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeBody
                font.weight: Font.DemiBold
            }

            IconButton {
                icon: "chevron_left"
                implicitWidth: 24
                implicitHeight: 24
                iconSize: Palette.Theme.iconSizeSmall
                onClicked: root.step(-1)
            }

            IconButton {
                icon: "chevron_right"
                implicitWidth: 24
                implicitHeight: 24
                iconSize: Palette.Theme.iconSizeSmall
                onClicked: root.step(1)
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 7
            columnSpacing: 0
            rowSpacing: 0

            Repeater {
                model: ["M", "T", "W", "T", "F", "S", "S"]

                Text {
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: 18
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    // Weekends (the last two columns) in the theme's purple.
                    color: index >= 5 ? Palette.Theme.purple : Palette.Theme.textMuted
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeXs
                    font.weight: Font.DemiBold
                }
            }

            Repeater {
                model: root.cells

                Item {
                    id: cell
                    required property int modelData
                    required property int index
                    readonly property bool weekend: index % 7 >= 5
                    readonly property bool isToday: modelData === root.today.getDate() && root.month === root.today.getMonth() && root.year === root.today.getFullYear()

                    Layout.fillWidth: true
                    Layout.preferredHeight: 22

                    Rectangle {
                        anchors.centerIn: parent
                        width: 22
                        height: 22
                        radius: width / 2
                        color: Palette.Theme.accent
                        visible: cell.isToday
                    }

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData > 0 ? cell.modelData : ""
                        color: cell.isToday ? Palette.Theme.accentText : (cell.weekend ? Palette.Theme.purple : Palette.Theme.textSecondary)
                        font.family: Palette.Theme.fontSans
                        font.pixelSize: Palette.Theme.fontSizeXs
                        font.weight: cell.isToday ? Font.DemiBold : Font.Normal
                    }
                }
            }
        }
    }
}
