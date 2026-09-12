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

for _, class in ipairs({ "brave-browser", "zen-twilight", "vesktop" }) do
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

hl.window_rule({
    name = "move-kitty",
    match = { class = "kitty" },
    move = { 100, 100 },
    animation = "popin 50%",
})
