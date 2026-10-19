class_name SettingsUI
extends TTScreen
## Settings share the locale config file through SettingsStore, which keeps the other owners' sections. A slider saves once it rests
## (SAVE_DELAY), not on every step; the volume itself follows every step.
const PATH := SettingsStore.PATH
## Root window meta: the window was sized by whoever started the game (tests/playtest.gd --windowed) and the title must not resize it.
const KEEP_WINDOW := &"tt_keep_window"
## Window presets in points: on a Retina Mac a point is two pixels (DisplayServer.screen_get_max_scale), on Windows one.
const SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
## The smallest window (points) the player can drag to: below it the 1280x720 layout's text is too small to read.
const MIN_SIZE := Vector2i(960, 540)
## Slider names; "Sfx" is the bus "SFX" (AudioManager.VOLUME_BUSES), its settings key is "sfx" either way.
const BUSES := ["Master", "Music", "Sfx", "Voice"]
const SAVE_DELAY := 0.4
## The saved window is put on screen once per run (the first title), never again by a later visit to the title.
static var _window_restored := false
var _applying := false
var _unsaved: Dictionary = {}           # section -> {key: value} waiting for the save timer
var _save_timer: Timer
var forest_help_button: Button
var updates_button: Button

func _init() -> void:
	super._init()
	screen_id = &"settings_ui"
	modal_name = &"settings"
	nested_under = &"pause"

func _ready() -> void:
	super._ready()
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	_save_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer.timeout.connect(_flush)
	add_child(_save_timer)
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("settings", Callable(get_script(), &"fixture_setup"))
	get_node("Panel").item_rect_changed.connect(_snap_panel)
	_snap_panel.call_deferred()
	%LangDa.pressed.connect(func(): LocalizationManager.set_locale("da"))
	%LangEn.pressed.connect(func(): LocalizationManager.set_locale("en"))
	%CloseButton.pressed.connect(close)
	%FullscreenCheck.toggled.connect(_fullscreen_changed)
	%FullscreenCheck.gui_input.connect(_fullscreen_input)
	for bus in BUSES:
		var slider: TTSlider = get_node("%" + bus + "Slider")
		slider.value_changed.connect(func(value: float): _volume_changed(bus, value))
	for index in SIZES.size():
		var chip: Button = get_node("%%Size%d" % index)
		chip.pressed.connect(func(): _size_changed(index))
	%HintBar.set_hints([{"action": &"ui_left", "key": "HINT_CHANGE"}, {"action": &"ui_cancel", "key": "HINT_BACK"}])
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	%CloseButton.get_parent().add_child(footer)
	%CloseButton.reparent(footer)
	forest_help_button = preload("res://scripts/ui/social/social_layout.gd").button(footer,"ASSIST_TITLE","ButtonSecondaryS")
	forest_help_button.pressed.connect(_open_forest_help)
	updates_button = preload("res://scripts/ui/social/social_layout.gd").button(footer,"UPDATE_TITLE","ButtonSecondaryS")
	updates_button.pressed.connect(_open_updates)
	footer.move_child(%CloseButton, footer.get_child_count() - 1)
	_refresh_texts()

func _open_updates() -> void:
	var screen := get_node_or_null("Updates")
	if screen == null:
		screen = load("res://scenes/ui/update_panel.tscn").instantiate()
		add_child(screen)
	screen.open(updates_button)

func _open_forest_help() -> void:
	var screen := get_node_or_null("ForestHelp")
	if screen == null:
		screen = load("res://scenes/ui/forest_help.tscn").instantiate()
		screen.name = "ForestHelp"
		add_child(screen)
	screen.open(forest_help_button)

static func _audio_bus(bus: String) -> String:
	return "SFX" if bus == "Sfx" else bus

static func _size_index(config: ConfigFile) -> int:
	var saved: Variant = config.get_value("video", "size", 0)
	return clampi(int(saved), 0, SIZES.size() - 1) if saved is int else 0

## The title calls this on every visit: the saved volumes always, the saved window only the first time in a run, so a resize, a
## maximise or the native full screen the player made since is kept.
static func apply_saved() -> void:
	var audio := Svc.node("AudioManager")
	if audio != null:
		audio.call("apply_saved_volumes")
	if not _window_restored:
		_window_restored = true
		apply_window(false)

## Puts the saved mode and size on screen: the preset scaled to window pixels, clamped to the usable area of the window's screen and
## centred on it. `chosen` (the player picked it just now) also leaves a maximised window; otherwise a maximised or minimised window
## is the player's own choice and stays. A window marked KEEP_WINDOW (the windowed test harness owns its 1280x720 window) keeps its
## size at boot. Godot keeps engine options such as `--resolution` out of OS.get_cmdline_args(), so the mark is the only signal.
static func apply_window(chosen: bool) -> void:
	var window := (Engine.get_main_loop() as SceneTree).root
	if DisplayServer.get_name() == "headless" or (not chosen and keeps_window(window)):
		return
	var config := SettingsStore.read()
	window.min_size = preset_pixels(MIN_SIZE, DisplayServer.screen_get_max_scale(), _room(window))
	var full := window.mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	if config.get_value("video", "fullscreen", false) == true:
		if not full:
			window.mode = Window.MODE_FULLSCREEN
		return
	if full or (chosen and window.mode == Window.MODE_MAXIMIZED):
		window.mode = Window.MODE_WINDOWED
	elif window.mode != Window.MODE_WINDOWED:
		return
	var preset: Vector2i = SIZES[_size_index(config)]
	var place := func() -> void:
		window.size = preset_pixels(preset, DisplayServer.screen_get_max_scale(), _room(window))
		window.move_to_center()
	place.call()
	if full:
		# Leaving the (animated) macOS full screen restores the old frame when the animation ends; place the window again after it.
		window.get_tree().create_timer(0.6, true).timeout.connect(place)

static func keeps_window(window: Window) -> bool:
	return window.get_meta(KEEP_WINDOW, false) == true

## A size in points as window pixels at `scale`, no larger than `room` (Vector2i.ZERO = unknown, no limit).
static func preset_pixels(preset: Vector2i, scale: float, room: Vector2i) -> Vector2i:
	var pixels := Vector2i((Vector2(preset) * maxf(scale, 1.0)).round())
	return pixels if room == Vector2i.ZERO else pixels.min(room)

## Does the preset fit the screen whole? A size that does not is offered disabled.
static func preset_fits(preset: Vector2i, scale: float, room: Vector2i) -> bool:
	var pixels := preset_pixels(preset, scale, Vector2i.ZERO)
	return room == Vector2i.ZERO or (pixels.x <= room.x and pixels.y <= room.y)

## The window pixels the screen has for the window's content: its usable area (no Dock, menu bar or task bar) minus the title bar.
static func _room(window: Window) -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return Vector2i.ZERO
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen).size
	var frame := (window.get_size_with_decorations() - window.size).max(Vector2i.ZERO)
	return (usable - frame).max(Vector2i.ONE)

func open(opener: Control = null) -> void:
	pauses_tree = get_tree().get_first_node_in_group("world_2d") != null
	super.open(opener)

func _initial_focus() -> Control:
	return %LangDa if LocalizationManager.is_da() else %LangEn

func _refresh_texts() -> void:
	if not is_node_ready():
		return
	if forest_help_button != null:
		forest_help_button.visible = get_tree().get_first_node_in_group("world_2d") != null
	_applying = true
	%LangDa.button_pressed = LocalizationManager.is_da()
	%LangEn.button_pressed = not LocalizationManager.is_da()
	var config := SettingsStore.read()
	for section in _unsaved:
		for key in _unsaved[section]:
			config.set_value(section, key, _unsaved[section][key])
	for bus in BUSES:
		(get_node("%" + bus + "Slider") as Slider).value = AudioManager.saved_volume(config, bus)
	%FullscreenCheck.button_pressed = config.get_value("video", "fullscreen", false) == true
	var size_index := _size_index(config)
	for index in SIZES.size():
		(get_node("%%Size%d" % index) as Button).button_pressed = index == size_index
	_applying = false
	_update_sizes()

func close() -> void:
	_flush()
	super.close()

func _exit_tree() -> void:
	_flush()
	super._exit_tree()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_flush()

## A chip or a toggle saves at once (together with a slider value still waiting).
func _store(section: String, key: String, value: Variant) -> void:
	_queue(section, key, value)
	_flush()

func _queue(section: String, key: String, value: Variant) -> void:
	if not _unsaved.has(section):
		_unsaved[section] = {}
	_unsaved[section][key] = value

func _flush() -> void:
	if _save_timer != null:
		_save_timer.stop()
	if _unsaved.is_empty():
		return
	SettingsStore.store_all(_unsaved, "setting")
	_unsaved.clear()

func _volume_changed(bus: String, value: float) -> void:
	if _applying:
		return
	AudioManager.set_bus_volume(_audio_bus(bus), value, false)
	_queue("audio", bus.to_lower(), value)
	_save_timer.start()

func _fullscreen_changed(value: bool) -> void:
	if _applying:
		return
	_store("video", "fullscreen", value)
	apply_window(true)
	_update_sizes()

func _fullscreen_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		%FullscreenCheck.button_pressed = event.is_action_pressed("ui_right")
		%FullscreenCheck.accept_event()

func _size_changed(index: int) -> void:
	if %FullscreenCheck.button_pressed:
		return
	_store("video", "size", index)
	apply_window(true)

func _update_sizes() -> void:
	var sizes: Array = []
	var room := _room(get_window())
	for index in SIZES.size():
		var chip: Button = get_node("%%Size%d" % index)
		var usable: bool = not %FullscreenCheck.button_pressed and preset_fits(SIZES[index], DisplayServer.screen_get_max_scale(), room)
		UiNav.set_enabled(chip, usable)
		chip.modulate.a = 1.0 if usable else 0.5
		sizes.append(chip)
	var rows: Array = [[%LangDa, %LangEn]]
	for bus in BUSES:
		rows.append([get_node("%" + bus + "Slider")])
	rows.append([%FullscreenCheck])
	rows.append(sizes)
	var footer: Array = []
	if forest_help_button != null and forest_help_button.visible: footer.append(forest_help_button)
	if updates_button != null: footer.append(updates_button)
	footer.append(%CloseButton)
	rows.append(footer)
	for row in rows:
		UiNav.wire_row(row)
	# Enter a radio row at its selected chip; keyboard history must not change the route.
	var active: Array = rows.filter(func(row): return UiNav.first_enabled(row) != null)
	var preferred: Array = []
	var stops: Array = []
	for row in active:
		var entry := UiNav.first_enabled(row)
		for control in row:
			if UiNav.is_stop(control):
				stops.append(control)
				if control is BaseButton and control.button_pressed:
					entry = control
		preferred.append(entry)
	for index in active.size():
		for control in active[index]:
			UiNav.link(control, &"up", preferred[posmod(index - 1, active.size())])
			UiNav.link(control, &"down", preferred[(index + 1) % active.size()])
	for index in stops.size():
		stops[index].focus_next = stops[index].get_path_to(stops[(index + 1) % stops.size()])
		stops[index].focus_previous = stops[index].get_path_to(stops[posmod(index - 1, stops.size())])

static func fixture_setup(node: Node, _host: Node) -> void:
	(node as TTScreen).open()

func _snap_panel() -> void:
	# An odd content height otherwise centres at a half pixel and softens the ink border.
	var panel := get_node("Panel") as Control
	var aligned := panel.position.round()
	if panel.position != aligned:
		panel.position = aligned
