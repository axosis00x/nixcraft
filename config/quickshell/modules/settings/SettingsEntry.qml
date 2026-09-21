import QtQuick

// Wires one row spec ({ kind, key, icon, title, ... }) to the panel's live
// state, so pages can be plain static data.
SettingsItem {
    id: entry

    required property var panel
    required property var spec
    property bool isFirst: true
    property bool isLast: true

    kind: spec.kind
    icon: spec.icon || ""
    title: spec.title
    subtitle: spec.sub ? panel.subtitleFor(spec.sub) : (spec.subtitle || "")
    tint: panel.tintFor(spec.tint)
    first: isFirst
    last: isLast
    checked: spec.kind === "switch" ? panel.flag(spec.key) : false
    value: spec.kind === "slider" ? panel.level(spec.key) : 0
    options: spec.options || []
    current: spec.kind === "segment" ? panel.choice(spec.key) : ""
    infoText: spec.kind === "info" ? panel.infoFor(spec.key) : ""

    onActivated: panel.activate(spec)
    onToggled: value => panel.setFlag(spec.key, value)
    onMoved: value => panel.setLevel(spec.key, value)
    onPicked: id => panel.setChoice(spec.key, id)
}
