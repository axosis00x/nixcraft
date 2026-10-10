-- ┌┬┐┌─┐┌┐┌┬┌┬┐┌─┐┬─┐┌─┐
-- ││││ │││││ │ │ │├┬┘└─┐
-- ┴ ┴└─┘┘└┘┴ ┴ └─┘┴└─└─┘

-- Resolution, scale and mirroring chosen in the Quickshell settings panel
-- (Display page, services/DisplayService.qml) are written to displays.lua.
-- Without it, the built-in panel runs at its native mode and mirrors HDMI.
local ok, displays = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/displays.lua")
if not ok or type(displays) ~= "table" then
    displays = {}
end
local outputs = displays.outputs or {}

-- Output the built-in panel mirrors, or false to extend instead.
local mirror = displays.mirror
if mirror == nil then
    mirror = "HDMI-A-1"
end

local function setting(output, key, default)
    local o = outputs[output]
    if o and o[key] ~= nil then
        return o[key]
    end
    return default
end

hl.monitor({
    output = "eDP-1",
    mode = setting("eDP-1", "mode", "1366x768@60.02"),
    position = "3393x1056",
    scale = setting("eDP-1", "scale", 1.0),
    mirror = mirror or nil,
})

for name, o in pairs(outputs) do
    if name ~= "eDP-1" then
        hl.monitor({
            output = name,
            mode = o.mode or "highres",
            position = "auto",
            scale = o.scale or 1.0,
        })
    end
end
--
-- local scale = 2
--
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
