-- ┌─┐┌┐┌┬┌┬┐┌─┐┌┬┐┬┌─┐┌┐┌┌─┐
-- ├─┤│││││││├─┤ │ ││ ││││└─┐
-- ┴ ┴┘└┘┴┴ ┴┴ ┴ ┴ ┴└─┘┘└┘└─┘

-- The bar itself is a layer-shell surface that gets reanchored/resized in
-- place when switched between the top and left edge — that's a config
-- change, not something that should visibly slide or fade (Quickshell animates
-- its own panels), so layer transitions are
-- instant regardless of which workspace-slide direction is active below.
hl.animation({ leaf = "layers", enabled = false })
hl.animation({ leaf = "fadeLayers", enabled = false })

-- Which edge the bar lives on decides which way workspace switches slide.
-- barorientation.lua is rewritten by
-- quickshell/scripts/bar-style.sh whenever the bar's layout
-- picker (Super+Shift+B) changes it. It's per-machine state, not tracked by
-- git, so a fresh checkout starts with the top bar.
local ok, orientation = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/barorientation.lua")
if not ok then
    orientation = "horizontal"
end
if orientation == "horizontal" then
    require("modules.animations.horizontal")
else
    require("modules.animations.vertical")
end
