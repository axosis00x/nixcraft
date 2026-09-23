import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../components/material"
import "../../config/Ui.js" as Ui
import "../../theme" as Palette

// Small interactive month calendar, hosted in the shared bottom stage
// (components/overlay/CenterOverlay.qml) alongside Clipboard/ThemePicker/etc.
Item {
    id: root
    anchors.fill: parent
    visible: false
    focus: visible

    property real maxWidth: 4000
    property real maxHeight: 4000

    // Same footprint as Clipboard, so the shared stage doesn't resize
    // between the two.
    implicitWidth: Math.min(maxWidth - 20, Ui.clipboardOverlayWidth)
    implicitHeight: Math.min(maxHeight - 12, 390)

    signal aboutToOpen
    signal aboutToClose

    IpcHandler {
        target: "calendar"
        function toggle(): void {
            root.visible ? root.close() : root.open();
        }
        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
    }

    function open() {
        aboutToOpen();
        visible = true;
        goToday();
    }

    function close(immediate) {
        if (!visible)
            return;
        aboutToClose();
        if (immediate) {
            closeTimer.stop();
            visible = false;
            return;
        }
        closeTimer.restart();
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
    readonly property var weekdayShort: ["S", "M", "T", "W", "T", "F", "S"]

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

    // 42 slots = 6 full weeks, enough to cover any month/first-weekday
    // combination; slots before day 1 or after the month's last day are
    // blank.
    readonly property var dayModel: {
        var lead = firstWeekday(viewYear, viewMonth);
        var total = daysInMonth(viewYear, viewMonth);
        var out = [];
        for (var i = 0; i < 42; i++) {
            var day = i - lead + 1;
            out.push(day >= 1 && day <= total ? day : 0);
        }
        return out;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 14
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        anchors.bottomMargin: 22
        spacing: 10

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Calendar"
                color: Palette.Theme.textTitle
                font.family: Palette.Theme.fontSans
                font.pixelSize: 16
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

            ActionChip {
                label: "Today"
                visible: !(root.viewMonth === root.today.getMonth() && root.viewYear === root.today.getFullYear())
                onClicked: root.goToday()
            }
        }

        // ── month navigation ────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30

                Text {
                    anchors.centerIn: parent
                    text: "‹"
                    color: Palette.Theme.textSecondary
                    font.pixelSize: 22
                    font.weight: Font.Bold
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.prevMonth()
                }
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: root.monthNames[root.viewMonth] + " " + root.viewYear
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontMono
                font.pixelSize: 18
                font.weight: Font.Bold
            }

            Item {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30

                Text {
                    anchors.centerIn: parent
                    text: "›"
                    color: Palette.Theme.textSecondary
                    font.pixelSize: 22
                    font.weight: Font.Bold
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.nextMonth()
                }
            }
        }

        // ── weekday initials ────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: root.weekdayShort
                delegate: Text {
                    required property string modelData
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontMono
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
        }

        // ── day grid ─────────────────────────────────────────────────
        GridLayout {
            Layout.fillWidth: true
            columns: 7
            rowSpacing: 3
            columnSpacing: 0

            Repeater {
                model: root.dayModel

                delegate: Item {
                    required property int modelData
                    required property int index

                    readonly property int day: modelData
                    readonly property bool empty: day === 0
                    readonly property bool today: !empty && root.isToday(day)
                    readonly property bool selected: !empty && root.isSelected(day)

                    Layout.fillWidth: true
                    Layout.preferredHeight: 32

                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 14
                        visible: parent.today || parent.selected
                        color: parent.today ? Palette.Theme.accent : "transparent"
                        border.width: parent.selected && !parent.today ? 1.5 : 0
                        border.color: Palette.Theme.accent
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !parent.empty
                        text: parent.day
                        color: parent.today ? Palette.Theme.accentText : Palette.Theme.textPrimary
                        font.family: Palette.Theme.fontMono
                        font.pixelSize: 14
                        font.weight: parent.today || parent.selected ? Font.Bold : Font.Normal
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !parent.empty
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.selectDay(parent.day)
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
            Layout.minimumHeight: 0
        }

        // ── selected date readout ───────────────────────────────────
        Text {
            Layout.fillWidth: true
            text: root.monthNames[root.selectedMonth] + " " + root.selectedDay + ", " + root.selectedYear
            color: Palette.Theme.textMuted
            font.family: Palette.Theme.fontMono
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
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
