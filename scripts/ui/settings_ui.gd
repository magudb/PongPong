class_name SettingsUI
extends TTScreen
## Settings share the locale config file. Every write reloads it, preserving other owners' sections.
const PATH := "user://settings.cfg"
const SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]
const BUSES := ["Master", "Music", "Sfx", "Voice"]
var _applying := false

func _init() -> void:
	super._init()
	screen_id = &"settings_ui"
	modal_name = &"settings"
	nested_under = &"pause"

func _ready() -> void:
	super._ready()
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
	_refresh_texts()

static func _config() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(PATH)
	return config

static func _volume(config: ConfigFile, bus: String) -> float:
	var value: Variant = config.get_value("audio", bus.to_lower(), 0.8)
	return clampf(float(value), 0.0, 1.0) if value is int or value is float else 0.8

static func _apply_volume(bus: String, value: float) -> void:
	var index := AudioServer.get_bus_index("SFX" if bus == "Sfx" else bus)
	if index >= 0:
		AudioServer.set_bus_mute(index, value <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))

static func apply_saved() -> void:
	var config := _config()
	for bus in BUSES:
		_apply_volume(bus, _volume(config, bus))
	if DisplayServer.get_name() == "headless":
		return
	var fullscreen: bool = config.get_value("video", "fullscreen", false) == true
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not fullscreen:
		var size_index: Variant = config.get_value("video", "size", 0)
		var index := clampi(int(size_index), 0, SIZES.size() - 1) if size_index is int else 0
		DisplayServer.window_set_size(SIZES[index])

func open(opener: Control = null) -> void:
	pauses_tree = get_tree().get_first_node_in_group("world_2d") != null
	super.open(opener)

func _initial_focus() -> Control:
	return %LangDa if LocalizationManager.is_da() else %LangEn

func _refresh_texts() -> void:
	if not is_node_ready():
		return
	_applying = true
	%LangDa.button_pressed = LocalizationManager.is_da()
	%LangEn.button_pressed = not LocalizationManager.is_da()
	var config := _config()
	for bus in BUSES:
		(get_node("%" + bus + "Slider") as Slider).value = _volume(config, bus)
	%FullscreenCheck.button_pressed = config.get_value("video", "fullscreen", false) == true
	var saved_size: Variant = config.get_value("video", "size", 0)
	var size_index := clampi(int(saved_size), 0, SIZES.size() - 1) if saved_size is int else 0
	for index in SIZES.size():
		(get_node("%%Size%d" % index) as Button).button_pressed = index == size_index
	_applying = false
	_update_sizes()

func _store(section: String, key: String, value: Variant) -> void:
	var config := _config()
	config.set_value(section, key, value)
	config.save(PATH)

func _volume_changed(bus: String, value: float) -> void:
	if _applying:
		return
	_apply_volume(bus, value)
	_store("audio", bus.to_lower(), value)

func _fullscreen_changed(value: bool) -> void:
	if _applying:
		return
	_store("video", "fullscreen", value)
	apply_saved()
	_update_sizes()

func _fullscreen_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		%FullscreenCheck.button_pressed = event.is_action_pressed("ui_right")
		%FullscreenCheck.accept_event()

func _size_changed(index: int) -> void:
	if %FullscreenCheck.button_pressed:
		return
	_store("video", "size", index)
	apply_saved()

func _update_sizes() -> void:
	var sizes: Array = []
	for index in SIZES.size():
		var chip: Button = get_node("%%Size%d" % index)
		UiNav.set_enabled(chip, not %FullscreenCheck.button_pressed)
		chip.modulate.a = 0.5 if %FullscreenCheck.button_pressed else 1.0
		sizes.append(chip)
	var rows: Array = [[%LangDa, %LangEn]]
	for bus in BUSES:
		rows.append([get_node("%" + bus + "Slider")])
	rows.append([%FullscreenCheck])
	rows.append(sizes)
	rows.append([%CloseButton])
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
