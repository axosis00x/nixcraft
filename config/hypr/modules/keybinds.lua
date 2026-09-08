-- ┬┌─┌─┐┬ ┬┌┐ ┬┌┐┌┌┬┐┌─┐
-- ├┴┐├┤ └┬┘├┴┐││││ ││└─┐
-- ┴ ┴└─┘ ┴ └─┘┴┘└┘─┴┘└─┘

local terminal = "kitty"
local fileManager = "nautilus"
local browser = "zen-twilight"
local secondBrowser = "brave"
local mainMod = "SUPER"
local guiEditor = "zeditor"

local function app(cmd)
    return hl.dsp.exec_cmd("uwsm app -- " .. cmd)
end

hl.bind(mainMod .. " + RETURN", app(terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + E", app(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("quickshell ipc call launcher toggle"))

hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + C", app(guiEditor))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("quickshell ipc call powermenu toggle"))
hl.bind(mainMod .. " + D", app("vesktop"))
hl.bind(mainMod .. " + O", app("obsidian"))
hl.bind(mainMod .. " + N", app("kitty -e nvim"))
hl.bind(mainMod .. " + Y", app("kitty -e yazi"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("quickshell ipc call mediapanel toggle"))
hl.bind(mainMod .. " + M", app("spotify"))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())

hl.bind(mainMod .. " + Z", app(browser))
hl.bind(mainMod .. " + B", app(secondBrowser))
hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("quickshell ipc call barlayout toggle"))
hl.bind("ALT + B", app("kitty -e btop"))

hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("quickshell ipc call clipboard toggle"))
hl.bind(mainMod .. " + SHIFT + E", hl.dsp.exec_cmd("quickshell ipc call toolmenu toggle"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("quickshell ipc call controlcenter toggle"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("quickshell ipc call theme toggle"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("~/.config/quickshell/scripts/reload.sh"))
hl.bind("ALT + V", hl.dsp.exec_cmd("sg input -c $HOME/.config/wayclick/scripts/wayclick.sh"))

hl.bind("ALT + E", hl.dsp.exec_cmd("eww open activate-linux"))
hl.bind("ALT + X", hl.dsp.exec_cmd("eww close activate-linux"))
hl.bind("ALT + N", app("errands"))

hl.bind(mainMod .. " + period", hl.dsp.layout("move +col"))
hl.bind(mainMod .. " + comma", hl.dsp.layout("move -col"))

hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd("quickshell ipc call wallpicker toggle"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("quickshell ipc call wallpicker cycle"))

hl.bind("F7", hl.dsp.exec_cmd("quickshell ipc call osd volumeDown"), { locked = true })
hl.bind("F8", hl.dsp.exec_cmd("quickshell ipc call osd volumeUp"), { locked = true })
hl.bind("F9", hl.dsp.exec_cmd("quickshell ipc call osd brightnessDown"), { locked = true })
hl.bind("F10", hl.dsp.exec_cmd("quickshell ipc call osd brightnessUp"), { locked = true })

local function lockNotify(kind)
    return hl.dsp.exec_cmd(string.format(
        [[sh -lc '
state_dir="${XDG_RUNTIME_DIR:-/tmp}/quickshell-locks"
mkdir -p "$state_dir"
lock_file="$state_dir/%s.lock"
state_file="$state_dir/%s.state"
exec 9>"$lock_file"
command -v flock >/dev/null 2>&1 || exit 0
flock -n 9 || exit 0
state=$(cat "$state_file" 2>/dev/null || echo 0)
if [ "$state" = "1" ]; then
  state=0
else
  state=1
fi
printf "%%s" "$state" > "$state_file"
quickshell ipc call osd lockState %s "$state"
sleep 0.35
']],
        kind,
        kind,
        kind
    ))
end

hl.bind("Caps_Lock", lockNotify("capsLock"), { locked = true })
hl.bind("Num_Lock", lockNotify("numLock"), { locked = true })

hl.bind("Print", hl.dsp.exec_cmd("~/.config/quickshell/scripts/screenshot.sh rc"), { locked = true })
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("~/.config/quickshell/scripts/screenshot.sh rf"), { locked = true })
hl.bind("CTRL + Print", hl.dsp.exec_cmd("~/.config/quickshell/scripts/screenshot.sh ri"), { locked = true })
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("~/.config/quickshell/scripts/screenshot.sh sc"), { locked = true })
hl.bind(
    mainMod .. " + SHIFT + Print",
    hl.dsp.exec_cmd("~/.config/quickshell/scripts/screenshot.sh sf"),
    { locked = true }
)
hl.bind("CTRL + SHIFT + Print", hl.dsp.exec_cmd("~/.config/quickshell/scripts/screenshot.sh si"), { locked = true })
hl.bind("ALT + Print", hl.dsp.exec_cmd("~/.config/quickshell/scripts/screenshot.sh p"), { locked = true })

hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end


hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + TAB", hl.dsp.focus({ workspace = "previous" }))
hl.bind("ALT + TAB", hl.dsp.exec_cmd("quickshell ipc call workspaces next"))
hl.bind("ALT + SHIFT + TAB", hl.dsp.exec_cmd("quickshell ipc call workspaces prev"))
hl.bind("ALT + Alt_L", hl.dsp.exec_cmd("quickshell ipc call workspaces activate"), { release = true })

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(
    "XF86AudioRaiseVolume",
    hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
    { locked = true, repeating = true }
)
hl.bind(
    "XF86AudioLowerVolume",
    hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
    { locked = true, repeating = true }
)
hl.bind(
    "XF86AudioMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
    { locked = true, repeating = true }
)
hl.bind(
    "XF86AudioMicMute",
    hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
    { locked = true, repeating = true }
)
hl.bind(
    "XF86MonBrightnessUp",
    hl.dsp.exec_cmd("quickshell ipc call osd brightnessUp"),
    { locked = true, repeating = true }
)
hl.bind(
    "XF86MonBrightnessDown",
    hl.dsp.exec_cmd("quickshell ipc call osd brightnessDown"),
    { locked = true, repeating = true }
)

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.bind(mainMod .. " + minus", hl.dsp.window.move({ workspace = "special" }))
hl.bind(mainMod .. " + equal", hl.dsp.workspace.toggle_special())

hl.bind("XF86KbdLightOnOff", hl.dsp.exec_cmd("brightnessctl -s rgb:kbd_backlight set 0"))
hl.bind("XF86KbdLightOnOff", hl.dsp.exec_cmd("brightnessctl -s rgb:kbd_backlight set 1"))

local MIN_ZOOM = 1
local MAX_ZOOM = 6
local ZOOM_STEP = 0.25

local function set_zoom(factor)
    factor = math.max(MIN_ZOOM, math.min(MAX_ZOOM, factor))
    hl.config({ cursor = { zoom_factor = factor } })
end

local function zoom_in()
    set_zoom(hl.get_config("cursor.zoom_factor") + ZOOM_STEP)
end

local function zoom_out()
    set_zoom(hl.get_config("cursor.zoom_factor") - ZOOM_STEP)
end

local function zoom_reset()
    set_zoom(MIN_ZOOM)
end

-- SUPER + Z to reset back to 1x
hl.bind("SUPER + X", zoom_reset)

-- optional: keyboard zoom
hl.bind("SUPER + equal", zoom_in)
hl.bind("SUPER + minus", zoom_out)
