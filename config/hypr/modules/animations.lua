-- ┌─┐┌┐┌┬┌┬┐┌─┐┌┬┐┬┌─┐┌┐┌┌─┐
-- ├─┤│││││││├─┤ │ ││ ││││└─┐
-- ┴ ┴┘└┘┴┴ ┴┴ ┴ ┴ ┴└─┘┘└┘└─┘

-- The bar itself is a layer-shell surface that gets reanchored/resized in
-- place when switched between the top and left edge — that's a config
-- change, not something that should visibly slide, so layer transitions are
-- instant regardless of which workspace-slide direction is active below.
hl.animation({ leaf = "layers", enabled = false })

-- Which edge the bar lives on decides which way workspace switches slide.
-- barorientation.lua is rewritten by
-- quickshell/scripts/bar-style.sh whenever the bar's layout
-- picker (Super+Shift+B) changes it.
local orientation = dofile(os.getenv("HOME") .. "/.config/hypr/barorientation.lua")
if orientation == "horizontal" then
    require("modules.animations.horizontal")
else
    require("modules.animations.vertical")
end
