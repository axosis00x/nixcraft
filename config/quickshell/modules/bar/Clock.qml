import Quickshell
import QtQuick
import "../../theme" as Palette

Text {
    id: root

    // Stacked mode splits hours/minutes onto two centered lines ("12"
    // over "00") instead of one "12:00" row — used by the vertical bar,
    // where a wide inline time doesn't fit as comfortably.
    property bool stacked: false

    text: Qt.formatDateTime(clock.date, root.stacked ? "hh\nmm" : "hh:mm")
    horizontalAlignment: Text.AlignHCenter

    color: Palette.Theme.textPrimary
    font.family: Palette.Theme.fontMono
    font.pixelSize: Palette.Theme.fontSizeSmall
    font.weight: Font.DemiBold

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
}
