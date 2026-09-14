pragma Singleton

import QtQuick

QtObject {
    id: root

    // Palette values are properties, not JavaScript constants. Any assignment
    // here notifies every bound component and updates the UI immediately.
    property var bg: "#030305"
    property var surface: "#030305"
    property var surfaceContainerLow: "#101018"
    property var surfaceContainer: "#0a0a10"
    property var surfaceContainerHigh: "#181822"
    property var surfaceContainerHighest: "#22222e"
    property var surfaceTint: "#eef5f7"
    property var outlineVariant: "#233240"
    property var border: "#233240"
    property var accent: "#29c4d9"
    property var accentText: "#00161b"
    property var info: "#29c4d9"
    property var warning: "#d99a2b"
    property var success: "#2ecc76"
    property var errorColor: "#dd3f66"
    property var accentLight: "#07161a"
    property var primaryContainer: "#0a2d36"
    property var primaryText: "#a8dbe6"
    property var secondaryContainer: "#22102e"
    property var secondaryContainerHover: "#2c1640"
    // Names beginning with `on` and an uppercase letter are reserved for QML
    // signal handlers, so keep the semantic color under a safe property name.
    property var secondaryText: "#c9a8dc"
    property var wsInactive: "#4a5a68"
    property var textPrimary: "#eef5f7"
    property var textTitle: "#eef5f7"
    property var textSecondary: "#9fb4c4"
    property var textMuted: "#6c8494"
    property var textDisabled: "#2c3a46"

    readonly property real surfaceTintOpacity: 0.015
    readonly property string fontMono: "SF Mono "
    readonly property string fontIcons: "Material Symbols Rounded "
    readonly property int radiusSmall: 10
    readonly property int radiusMedium: 16
    readonly property int radiusLarge: 22
    readonly property int radiusExtraLarge: 28
    readonly property int iconButtonSize: 28

    function apply(values) {
        var paletteKeys = ["bg", "surface", "surfaceContainerLow", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceTint", "outlineVariant", "border", "accent", "accentText", "info", "warning", "success", "errorColor", "accentLight", "primaryContainer", "primaryText", "secondaryContainer", "secondaryContainerHover", "secondaryText", "wsInactive", "textPrimary", "textTitle", "textSecondary", "textMuted", "textDisabled"];
        for (var key in values) {
            if (paletteKeys.indexOf(key) !== -1)
                root[key] = values[key];
        }
    }
}
