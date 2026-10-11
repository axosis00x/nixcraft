-- ┌┬┐┌─┐┌┐┌┬┌┬┐┌─┐┬─┐┌─┐
-- ││││ │││││ │ │ │├┬┘└─┐
-- ┴ ┴└─┘┘└┘┴ ┴ └─┘┴└─└─┘

-- Resolution, position, scale and mirroring come from displays.lua, written
-- by the Quickshell settings panel (Display page, services/DisplayService.qml).
-- It's per-machine and not tracked by git; without it every output runs at
-- its best mode and is placed automatically, which works anywhere.
local ok, displays = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/displays.lua")
if not ok or type(displays) ~= "table" then
    displays = {}
end

-- Output that shows another one's picture (`mirror` names the source).
local builtIn = displays.builtIn or "eDP-1"

for name, o in pairs(displays.outputs or {}) do
    hl.monitor({
        output = name,
        mode = o.mode or "highres",
        position = o.position or "auto",
        scale = o.scale or 1.0,
        mirror = (name == builtIn and displays.mirror) or nil,
    })
end

hl.monitor({
    output = "",
    mode = "highres",
    position = "auto",
    scale = 1.0,
})

hl.config({
    xwayland = { force_zero_scaling = true },
})

hl.env("GDK_SCALE", tostring(1.0))
