.pragma library

// Max content widths for panels hosted in the shared notch stage
// (components/overlay/CenterOverlay.qml) — the stage itself owns shape,
// position, and radius.
const themeOverlayWidth = 560
// Shared by the launcher, theme picker, clipboard and calendar so they all
// open at one width.
const listPanelWidth = 440

// Width of the vertical bar's solid strip (when active — see
// services/BarLayoutService.qml, which owns the live-toggleable, persisted
// top/left choice).
const barThickness = 40
// Height of the horizontal (top) bar.
const barHeight = 34


// The screen frame shown with the left bar in notch mode
// (components/overlay/ScreenFrame.qml): its width along each edge and the
// radius of its inner corners. The left bar's curved joins use the same
// numbers so the two meet without a seam.
const screenFrameBorder = 4
const screenFrameRadius = 10
