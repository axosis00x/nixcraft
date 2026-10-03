import QtQuick
import "../../theme" as Palette

Rectangle {
    property bool vertical: false

    width: vertical ? 1 : parent ? parent.width : 1
    height: vertical ? 14 : 1
    color: Palette.Theme.outlineSoft
}
