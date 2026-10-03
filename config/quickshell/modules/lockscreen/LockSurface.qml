import Quickshell.Wayland
import QtQuick

// One session-lock surface per monitor; the visuals live in LockContent.
WlSessionLockSurface {
    id: root

    required property var lockScreen

    // Opaque fallback so nothing behind the compositor's lock surface can
    // ever show through before the wallpaper image finishes loading.
    color: "#000000"

    LockContent {
        anchors.fill: parent
        lockScreen: root.lockScreen
    }
}
