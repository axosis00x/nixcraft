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
    readonly property string fontSans: "Inter"
    readonly property string fontIcons: "Material Symbols Rounded "

    // ── Design tokens ────────────────────────────────────────────────
    // Every surface in the shell is built from these, so the bar, panels,
    // pickers, settings and widgets share one shape, type and motion
    // language. Prefer a token over a literal; add a token before adding
    // a new literal.

    // Shape. Interactive things morph between these (e.g. a tile rounds
    // into a pill when switched on); radiusFull is "as round as the item
    // is tall", resolved by the user as height / 2.
    readonly property int radiusXs: 6
    readonly property int radiusSmall: 10
    readonly property int radiusMedium: 14
    readonly property int radiusLarge: 20
    readonly property int radiusExtraLarge: 28

    // Spacing.
    readonly property int spacingXs: 4
    readonly property int spacingSmall: 8
    readonly property int spacingMedium: 12
    readonly property int spacingLarge: 16
    readonly property int spacingExtraLarge: 24

    // Type scale (pixel sizes).
    readonly property int fontSizeXs: 11
    readonly property int fontSizeSmall: 12
    readonly property int fontSizeBody: 13
    readonly property int fontSizeTitle: 16
    readonly property int fontSizeHeadline: 20
    readonly property int fontSizeDisplay: 28
    readonly property int iconSizeSmall: 16
    readonly property int iconSize: 18
    readonly property int iconSizeLarge: 22

    readonly property int iconButtonSize: 30

    // Motion (Material 3 Expressive). "Spatial" motion — position, size,
    // shape, scale — springs past its target and settles; "effects" motion
    // — color, opacity — eases without overshoot. Use the atoms in
    // components/material (SpatialMotion, EffectMotion, ColorMotion)
    // rather than these numbers directly.
    readonly property int motionFast: 180
    readonly property int motionDefault: 320
    readonly property int motionSlow: 480
    readonly property int effectFast: 110
    readonly property int effectDefault: 200
    readonly property real springOvershoot: 1.3
    readonly property real springBouncy: 2.2

    // State layers: a tint of the content color laid over a surface.
    readonly property real stateHover: 0.08
    readonly property real statePressed: 0.12
    readonly property real stateSelected: 0.16

    // Derived roles. Bindings, so they follow palette changes live.
    readonly property color accentTonal: Qt.alpha(accent, stateSelected)
    // Scales the outline's own alpha rather than replacing it (Qt.alpha
    // sets alpha), so themes with already-translucent outlines stay subtle.
    readonly property color outlineColor: outlineVariant
    readonly property color outlineSoft: Qt.rgba(outlineColor.r, outlineColor.g, outlineColor.b, outlineColor.a * 0.6)
    readonly property color surfaceSolid: Qt.alpha(bg, 1)

    function apply(values) {
        var paletteKeys = ["bg", "surface", "surfaceContainerLow", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceTint", "outlineVariant", "border", "accent", "accentText", "info", "warning", "success", "errorColor", "accentLight", "primaryContainer", "primaryText", "secondaryContainer", "secondaryContainerHover", "secondaryText", "wsInactive", "textPrimary", "textTitle", "textSecondary", "textMuted", "textDisabled"];
        for (var key in values) {
            if (paletteKeys.indexOf(key) !== -1)
                root[key] = values[key];
        }
    }
}
