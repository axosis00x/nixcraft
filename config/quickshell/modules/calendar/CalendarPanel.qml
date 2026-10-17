import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../components/material"
import "../../theme" as Palette

// Small interactive month calendar, hosted in the shared bottom stage
// (components/overlay/CenterOverlay.qml) alongside Clipboard/ThemePicker/etc.
Item {
    id: root
    visible: false
    // Still visible while the close delay runs, but on its way out.
    readonly property bool closing: closeTimer.running
    focus: visible

    property real maxWidth: 4000
    property real maxHeight: 4000

    // Same width as the launcher/clipboard/theme picker; height fits the
    // month (5 or 6 weeks) rather than a fixed box.
    implicitWidth: Math.min(maxWidth - 32, Palette.Theme.listPanelWidth)
    implicitHeight: Math.min(maxHeight - 12, content.implicitHeight + 28)

    signal aboutToOpen
    signal aboutToClose

    IpcHandler {
        target: "calendar"
        function toggle(): void {
            root.visible && !root.closing ? root.close() : root.open();
        }
        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
    }

    function open() {
        closeTimer.stop();
        aboutToOpen();
        visible = true;
        goToday();
    }

    function close(immediate) {
        if (!visible)
            return;
        if (!closing)
            aboutToClose();
        if (immediate) {
            closeTimer.stop();
            visible = false;
            return;
        }
        if (!closing)
            closeTimer.start();
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            close();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            prevMonth();
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            nextMonth();
            event.accepted = true;
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property date today: clock.date
    property int viewYear: today.getFullYear()
    property int viewMonth: today.getMonth()
    property int selectedDay: today.getDate()
    property int selectedMonth: viewMonth
    property int selectedYear: viewYear

    readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    readonly property var weekdayShort: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    readonly property var weekdayNames: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

    function daysInMonth(year, month) {
        return new Date(year, month + 1, 0).getDate();
    }

    function firstWeekday(year, month) {
        return new Date(year, month, 1).getDay();
    }

    function isToday(day) {
        return day === root.today.getDate() && root.viewMonth === root.today.getMonth() && root.viewYear === root.today.getFullYear();
    }

    function isSelected(day) {
        return day === root.selectedDay && root.viewMonth === root.selectedMonth && root.viewYear === root.selectedYear;
    }

    function selectDay(day) {
        root.selectedDay = day;
        root.selectedMonth = root.viewMonth;
        root.selectedYear = root.viewYear;
    }

    function prevMonth() {
        if (root.viewMonth === 0) {
            root.viewMonth = 11;
            root.viewYear -= 1;
        } else {
            root.viewMonth -= 1;
        }
    }

    function nextMonth() {
        if (root.viewMonth === 11) {
            root.viewMonth = 0;
            root.viewYear += 1;
        } else {
            root.viewMonth += 1;
        }
    }

    function goToday() {
        root.viewYear = root.today.getFullYear();
        root.viewMonth = root.today.getMonth();
        root.selectDay(root.today.getDate());
    }

    // Only as many weeks as the month spans (4–6). Slots outside the month
    // show the neighbouring months' days, dimmed; their `day` is 0.
    readonly property var dayModel: {
        var lead = firstWeekday(viewYear, viewMonth);
        var total = daysInMonth(viewYear, viewMonth);
        var prevTotal = daysInMonth(viewMonth === 0 ? viewYear - 1 : viewYear, (viewMonth + 11) % 12);
        var slots = Math.ceil((lead + total) / 7) * 7;
        var out = [];
        for (var i = 0; i < slots; i++) {
            var day = i - lead + 1;
            if (day < 1)
                out.push({ day: 0, label: prevTotal + day, weekday: i % 7 });
            else if (day > total)
                out.push({ day: 0, label: day - total, weekday: i % 7 });
            else
                out.push({ day: day, label: day, weekday: i % 7 });
        }
        return out;
    }

    // "Today" / "Tomorrow" / "In 3 days" / "5 days ago" for the selection.
    readonly property string selectedRelative: {
        var t = new Date(today.getFullYear(), today.getMonth(), today.getDate());
        var s = new Date(selectedYear, selectedMonth, selectedDay);
        var d = Math.round((s - t) / 86400000);
        if (d === 0)
            return "Today";
        if (d === 1)
            return "Tomorrow";
        if (d === -1)
            return "Yesterday";
        return d > 0 ? "In " + d + " days" : -d + " days ago";
    }

    ColumnLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14
        spacing: 12

        // ── header: month, navigation ────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            spacing: 6

            ColumnLayout {
                spacing: 0

                Text {
                    text: root.monthNames[root.viewMonth]
                    color: Palette.Theme.textTitle
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeHeadline
                    font.weight: Font.DemiBold
                }

                Text {
                    text: root.viewYear
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeSmall
                }
            }

            Item {
                Layout.fillWidth: true
            }

            ActionChip {
                label: "Today"
                visible: !(root.viewMonth === root.today.getMonth() && root.viewYear === root.today.getFullYear())
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.goToday()
            }

            IconButton {
                icon: "chevron_left"
                implicitWidth: 34
                implicitHeight: 34
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.prevMonth()
            }

            IconButton {
                icon: "chevron_right"
                implicitWidth: 34
                implicitHeight: 34
                Layout.alignment: Qt.AlignVCenter
                onClicked: root.nextMonth()
            }
        }

        // ── weekdays + days ──────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: grid.implicitHeight + 16
            radius: Palette.Theme.radiusMedium
            color: Palette.Theme.surfaceContainer

            // Wheel steps through months.
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    if (event.angleDelta.y > 0)
                        root.prevMonth();
                    else if (event.angleDelta.y < 0)
                        root.nextMonth();
                }
            }

            GridLayout {
                id: grid
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                columns: 7
                rowSpacing: 2
                columnSpacing: 0

                Repeater {
                    model: root.weekdayShort
                    delegate: Text {
                        required property string modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 26
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: modelData
                        color: index === 0 || index === 6 ? Palette.Theme.textMuted : Palette.Theme.textSecondary
                        font.family: Palette.Theme.fontSans
                        font.pixelSize: Palette.Theme.fontSizeXs
                        font.weight: Font.DemiBold
                    }
                }

                Repeater {
                    model: root.dayModel

                    delegate: Item {
                        id: cell

                        required property var modelData

                        readonly property int day: modelData.day
                        readonly property bool outside: day === 0
                        readonly property bool weekend: modelData.weekday === 0 || modelData.weekday === 6
                        readonly property bool today: !outside && root.isToday(day)
                        readonly property bool selected: !outside && root.isSelected(day)

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 36

                        Rectangle {
                            anchors.centerIn: parent
                            width: 32
                            height: 32
                            // Keep selected and today markers on the same
                            // roundness scale as the rest of the interface.
                            radius: Math.min(width / 2, Palette.Theme.radiusSmall)
                            color: cell.today ? Palette.Theme.accent : (cell.selected ? Palette.Theme.accentTonal : "transparent")

                            Behavior on radius {
                                SpatialMotion {}
                            }
                            Behavior on color {
                                ColorMotion {}
                            }

                            StateLayer {
                                radius: parent.radius
                                hovered: cellMouse.containsMouse && !cell.outside
                                pressed: cellMouse.pressed
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: cell.modelData.label
                            color: cell.today ? Palette.Theme.accentText : (cell.selected ? Palette.Theme.accent : (cell.outside ? Palette.Theme.textDisabled : (cell.weekend ? Palette.Theme.textSecondary : Palette.Theme.textPrimary)))
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: Palette.Theme.fontSizeBody
                            font.weight: cell.today || cell.selected ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            id: cellMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: !cell.outside
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectDay(cell.day)
                        }
                    }
                }
            }
        }

        // ── selected date ───────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 6
            Layout.rightMargin: 6
            spacing: 8

            Text {
                text: "event"
                color: Palette.Theme.accent
                font.family: Palette.Theme.fontIcons
                font.weight: Palette.Theme.iconWeight
                font.pixelSize: Palette.Theme.iconSizeSmall
            }

            Text {
                Layout.fillWidth: true
                text: root.weekdayNames[new Date(root.selectedYear, root.selectedMonth, root.selectedDay).getDay()] + ", " + root.selectedDay + " " + root.monthNames[root.selectedMonth] + " " + root.selectedYear
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeSmall
                elide: Text.ElideRight
            }

            Text {
                text: root.selectedRelative
                color: Palette.Theme.textMuted
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeXs
            }
        }
    }

    Timer {
        id: closeTimer
        interval: 180
        onTriggered: root.visible = false
    }
    Keys.onPressed: function (event) {
        root.handleKey(event);
    }
}
