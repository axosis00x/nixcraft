-- ┬ ┬┌─┐┬─┐┬┌─┌─┐┌─┐┌─┐┌─┐┌─┐┌─┐
-- ││││ │├┬┘├┴┐└─┐├─┘├─┤│  ├┤ └─┐
-- └┴┘└─┘┴└─┴ ┴└─┘┴  ┴ ┴└─┘└─┘└─┘

-- Keep workspaces 1-10 on one output (the laptop panel, say) when
-- displays.lua names one; otherwise Hyprland places them itself.
local ok, displays = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/displays.lua")
local monitor = ok and type(displays) == "table" and displays.workspaceMonitor or nil

if monitor then
    for i = 1, 10 do
        hl.workspace_rule({ workspace = tostring(i), monitor = monitor })
    end
end
