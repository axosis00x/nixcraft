.pragma library

// Max content widths for panels hosted in the shared notch stage
// (components/overlay/CenterOverlay.qml) — the stage itself owns shape,
// position, and radius.
const themeOverlayWidth = 560
const clipboardOverlayWidth = 468
const wayclickOverlayWidth = 560

// Width of the vertical bar/dock (when active — see services/BarLayoutService.qml,
// which owns the live-toggleable, persisted top/left choice). The clock is
// stacked ("18" over "59") rather than inline in this orientation, so it no
// longer needs to be as wide as it did with "18:59" on one line.
const barThickness = 34

