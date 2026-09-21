import QtQuick

// Same job as SettingsEntry, for tile-layout sections.
SettingsTile {
    id: entry

    required property var panel
    required property var spec

    icon: spec.icon || ""
    title: spec.title
    tint: panel.tintFor(spec.tint)
    checked: panel.flag(spec.key)
    stateText: checked ? "On" : "Off"
    onToggled: value => panel.setFlag(spec.key, value)
}
