import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../theme" as Palette
import "../../components/material"

GridLayout {
    id: root

    // Pass the enclosing PanelWindow so right-click menus can position correctly.
    required property var parentWindow
    property bool vertical: false

    columns: vertical ? 1 : 999
    rowSpacing: 5
    columnSpacing: 5

    Repeater {
        model: SystemTray.items

        delegate: Item {
            id: trayIcon
            required property SystemTrayItem modelData

            implicitWidth: 16
            implicitHeight: 16
            Layout.alignment: Qt.AlignVCenter

            // ── icon ─────────────────────────────────────────────
            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                source: trayIcon.modelData.icon
                smooth: true
                mipmap: true
            }

            // ── hover state layer ────────────────────────────────
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: 4
                color: Palette.Theme.surfaceTint
                opacity: ma.containsMouse ? Palette.Theme.stateHover : 0
                Behavior on opacity {
                    EffectMotion {}
                }
            }

            // ── mouse handling ───────────────────────────────────
            MouseArea {
                id: ma
                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton)
                        trayIcon.modelData.activate();
                    else if (mouse.button === Qt.MiddleButton)
                        trayIcon.modelData.secondaryActivate();
                    else if (mouse.button === Qt.RightButton && trayIcon.modelData.hasMenu)
                        trayIcon.modelData.display(root.parentWindow, trayIcon.x + mouse.x, trayIcon.y + mouse.y);
                }
            }

            // ── tooltip ──────────────────────────────────────────
            ToolTip {
                visible: ma.containsMouse && trayIcon.modelData.tooltipTitle !== ""
                text: {
                    var t = trayIcon.modelData.tooltipTitle;
                    var d = trayIcon.modelData.tooltipDescription;
                    return d !== "" ? t + "\n" + d : t;
                }
                delay: 600
                font.family: Palette.Theme.fontMono
                font.pixelSize: Palette.Theme.fontSizeXs
            }
        }
    }
}
