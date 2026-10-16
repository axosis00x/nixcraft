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

    // Short-lived system OSDs use the same near-black shell surface across
    // every theme, with high-contrast text and a neutral meter track.
    readonly property color osdBackground: "#050608"
    readonly property color osdTrack: "#292b30"
    readonly property color osdText: "#f5f5f2"
    readonly property color osdMuted: "#a8abb2"

    // Decorative hues, from each theme's own palette (quickshell.js): for
    // deliberate color beyond the accent, e.g. one hue per gauge, icon or
    // category. Not for state: errorColor and warning still mean errors and
    // warnings, and "on"/selected is still the accent.
    property var blue: "#83a598"
    property var green: "#b8bb26"
    property var yellow: "#fabd2f"
    property var purple: "#d3869b"
    property var aqua: "#8ec07c"
    property var orange: "#fe8019"

    readonly property real surfaceTintOpacity: 0.015
    readonly property string fontMono: "SF Mono "
    readonly property string fontSans: "Inter"
    readonly property string fontIcons: "Material Symbols Rounded "
    // One weight for every icon glyph (Material Symbols is variable).
    readonly property int iconWeight: Font.Medium

    // ── User customization ──────────────────────────────────────────
    // Set by services/ShellSettings.qml (Settings → Customize), which clamps
    // every value to a safe range and saves it. The defaults here are the
    // stock look, so a missing or broken settings file changes nothing.
    property real roundness: 1.0          // scales every radius* token
    property int controlCenterWidth: 480  // px, kept even
    property real dockIconScale: 1.0      // scales the dock's icon sizes
    property bool dockAutoHide: true      // hide the dock over busy workspaces
    property bool showGlyph: true         // the control center's glyph matrix
    property bool clockSeconds: false     // desktop clock format
    property bool clock24h: false
    property real clockScale: 1.0         // desktop widget sizes
    property real weatherScale: 1.0
    property real cavaScale: 1.0

    // ── Design tokens ──────────────────────────────────────────────────
    // The shared shape, type and motion values. Prefer a token over a literal.

    // Shape. Interactive things morph between these (e.g. a tile rounds
    // into a pill when switched on); radiusFull is "as round as the item
    // is tall", resolved by the user as height / 2.
    readonly property int radiusXs: Math.round(6 * roundness)
    readonly property int radiusSmall: Math.round(13 * roundness)
    readonly property int radiusMedium: Math.round(13 * roundness)
    readonly property int radiusLarge: Math.round(20 * roundness)
    readonly property int radiusExtraLarge: Math.round(28 * roundness)

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

    // Shell layout: vertical bar thickness, horizontal bar height, list
    // panel width, and the notch-mode screen frame's edge and corner radius.
    readonly property int barThickness: 40
    readonly property int barHeight: 34
    readonly property int listPanelWidth: 440
    readonly property int screenFrameBorder: 4
    readonly property int screenFrameRadius: 10

    // Motion: spatial (size, position) springs and settles; effects (color,
    // opacity) ease without overshoot. Use the atoms in components/material.
    readonly property int motionFast: 180
    readonly property int motionDefault: 320
    readonly property int motionSlow: 480
    readonly property int effectFast: 110
    readonly property int effectDefault: 200
    readonly property real springOvershoot: 0.6
    readonly property real springBouncy: 1.0

    // State layers: a tint of the content color laid over a surface.
    readonly property real stateHover: 0.08
    readonly property real statePressed: 0.12
    readonly property real stateSelected: 0.16

    // Derived roles. Bindings, so they follow palette changes live.
    readonly property color accentTonal: Qt.alpha(accent, stateSelected)
    // Scales the outline's own alpha rather than replacing it (Qt.alpha
    // sets alpha), so themes with already-translucent outlines stay subtle.
    readonly property color outlineColor: outlineVariant
    readonly property color outlineSoft: Qt.rgba(outlineColor.r, outlineColor.g, outlineColor.b, outlineColor.a * 0.35)
    readonly property color surfaceSolid: Qt.alpha(bg, 1)
    // Desktop widgets sit on arbitrary wallpapers, so they're built from the
    // theme background (which the text colours are designed against), made
    // opaque and lightly lifted, then given a fixed glass alpha. Themes whose
    // container colours are white washes (transparent) stay readable too.
    readonly property color widgetSurface: Qt.alpha(Qt.tint(surfaceSolid, Qt.alpha(textPrimary, 0.05)), 0.85)
    // Chips and wells inside a widget: a wash of the text colour, so they
    // read as one step up in every theme.
    readonly property color widgetChip: Qt.alpha(textPrimary, 0.08)

    // A stable decorative hue for a name (an app, a category), so the same
    // thing always gets the same color.
    function hueFor(name) {
        var hues = [blue, green, yellow, purple, aqua, orange];
        var h = 0;
        var s = String(name || "");
        for (var i = 0; i < s.length; i++)
            h = (h * 31 + s.charCodeAt(i)) | 0;
        return hues[Math.abs(h) % hues.length];
    }

    function apply(values) {
        var paletteKeys = ["bg", "surface", "surfaceContainerLow", "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest", "surfaceTint", "outlineVariant", "border", "accent", "accentText", "info", "warning", "success", "errorColor", "accentLight", "primaryContainer", "primaryText", "secondaryContainer", "secondaryContainerHover", "secondaryText", "wsInactive", "textPrimary", "textTitle", "textSecondary", "textMuted", "textDisabled", "blue", "green", "yellow", "purple", "aqua", "orange"];
        for (var key in values) {
            if (paletteKeys.indexOf(key) !== -1)
                root[key] = values[key];
        }
    }
}
