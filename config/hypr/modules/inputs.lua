-- ┬┌┐┌┌─┐┬ ┬┌┬┐┌─┐
-- ││││├─┘│ │ │ └─┐
-- ┴┘└┘┴  └─┘ ┴ └─┘

hl.config({
	input = {
		kb_layout = "us",
		kb_variant = "",
		kb_model = "",
		kb_options = "",
		kb_rules = "",

		repeat_rate = 35,
		repeat_delay = 200,

		follow_mouse = 1,
		sensitivity = 0.7,
		accel_profile = "flat",
		numlock_by_default = false,

		touchpad = {
			natural_scroll = true,
			scroll_factor = 0.7,
		},
	},

	cursor = {
		inactive_timeout = 30,
		no_hardware_cursors = true,
		zoom_factor = 1,
		zoom_rigid = false,
	},

	dwindle = {
		preserve_split = true,
	},

	scrolling = {
		fullscreen_on_one_column = true,
	},

	master = {
		new_status = "master",
	},
})

hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

hl.device({
	name = "synps/2-synaptics-touchpad",
	enabled = true,
	natural_scroll = true,
})

hl.config({
	misc = {
		force_default_wallpaper = 0,
		disable_hyprland_logo = true,
	},
})
