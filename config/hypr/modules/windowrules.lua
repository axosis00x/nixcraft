-- ┬ ┬┬┌┐┌┌┬┐┌─┐┬ ┬  ┬─┐┬ ┬┬  ┌─┐┌─┐
-- │││││││ │││ ││││  ├┬┘│ ││  ├┤ └─┐
-- └┴┘┴┘└┘─┴┘└─┘└┴┘  ┴└─└─┘┴─┘└─┘└─┘

local theme = dofile(os.getenv("HOME") .. "/.config/hypr/theme.lua")

hl.window_rule({
    name = "audio-tui-float",
    match = {
        class = "^(audio-tui)$",
    },
    float = true,
    size = "800 500",
    center = true,
})

-- Zenity dialogs (file pickers, prompts) always float, centered, instead of
-- tiling. Newer zenity versions report the org.gnome.Zenity class.
hl.window_rule({
    name = "zenity-float",
    match = {
        class = "^(zenity|org\\.gnome\\.Zenity)$",
    },
    float = true,
    center = true,
})

-- File choosers (zenity's included) are drawn by the GTK desktop portal, not
-- the app asking for them: float those too, at a usable size.
hl.window_rule({
    name = "portal-dialog-float",
    match = {
        class = "^(xdg-desktop-portal-gtk)$",
    },
    float = true,
    size = "900 600",
    center = true,
})

for _, class in ipairs({ "brave-browser", "zen-twilight", "vesktop", "helium", "brave" }) do
    hl.window_rule({
        name = class .. "-full-opacity",
        match = { class = "^(" .. class .. ")$" },
        opacity = "1.0 override",
    })
end

hl.window_rule({
    name = "suppress-maximize",
    match = {
        class = ".*",
    },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

hl.window_rule({
    name = "border-frgnc",
    match = {
        title = ".*frgnc-subash.*",
    },
    border_color = theme.tertiary,
})

hl.window_rule({
    name = "errands-float",
    match = {
        title = "^(Errands)$",
    },
    float = true,
    size = "500 550",
    center = true,
})

-- Audio mixer and enterprise Wi-Fi setup opened from the control center /
-- settings (kitty --class wiremix / nmtui).
hl.window_rule({
    name = "wiremix-float",
    match = { class = "^(wiremix|nmtui)$" },
    float = true,
    size = "900 560",
    center = true,
    animation = "popin 50%",
})

hl.window_rule({
    name = "move-kitty",
    match = { class = "kitty" },
    move = { 100, 100 },
    animation = "popin 50%",
})

-- Quickshell's settings window (quickshell/modules/settings/SettingsWindow.qml):
-- a rounded card drawn on a transparent window in the theme's background, so
-- Hyprland's own translucency and border stay out of the way. Blur is kept for
-- translucent themes, clipped by a rounding that matches the card's corners
-- (Theme.radiusLarge) so it doesn't spill past them.
hl.window_rule({
    name = "nixcraft-settings",
    match = {
        title = "^(nixcraft-settings)$",
    },
    animation = "popin 50%",
    float = true,
    -- size = "940 600",
    center = true,
    opacity = "1.0 override",
    no_shadow = true,
    border_size = 0,
    rounding = 20,
    rounding_power = 2,
})
