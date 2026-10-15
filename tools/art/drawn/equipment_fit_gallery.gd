extends Node2D
## Inspectable two-body fit proof. Controls never mutate game equipment.
const Figure = preload("res://tools/art/drawn/equipment_fit_figure.gd")
var body_id := "rasmus"
var clip := "idle"
var direction := 0
var figures: Array[Figure] = []
var selected_parts: Dictionary = {}
var _content: Node2D
var _title: Label
var _status: Label
var _buttons: Dictionary = {}

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("eee7d8")
	background.size = Vector2(1280, 720)
	add_child(background)
	var ui := CanvasLayer.new()
	add_child(ui)
	_title = _label(ui, Vector2(24, 12), "", 25)
	_label(ui, Vector2(24, 48), "Two-body fit proof · 8 directions · shared body clock · independent clothing and hand occluders", 15)
	var bar := HBoxContainer.new()
	bar.position = Vector2(24, 78)
	ui.add_child(bar)
	for id in ["rasmus", "pedro"]:
		_button(bar, id.capitalize(), _select_body.bind(id))
	for name_ in ["idle", "walk", "run", "interact"]:
		_button(bar, "Reach" if name_ == "interact" else name_.capitalize(), select_clip.bind(name_))
	_button(bar, "Left", _turn.bind(-1))
	_button(bar, "Right", _turn.bind(1))
	_button(bar, "Flash", flash_all)
	_button(bar, "Spin", spin_all)
	var layers := HBoxContainer.new()
	layers.position = Vector2(24, 126)
	ui.add_child(layers)
	for part in ["hat", "shirt", "pants", "shoes", "sword"]:
		var button := CheckButton.new()
		button.text = part.capitalize()
		button.button_pressed = true
		button.toggled.connect(set_part_enabled.bind(part))
		layers.add_child(button)
		_buttons[part] = button
	_status = _label(ui, Vector2(24, 680), "", 15)
	_show()

func _label(host: Node, at: Vector2, value: String, font_size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.text = value
	label.add_theme_color_override("font_color", Color("4b3c49"))
	label.add_theme_font_size_override("font_size", font_size)
	host.add_child(label)
	return label

func _button(host: Node, value: String, action: Callable) -> void:
	var button := Button.new()
	button.text = value
	button.add_theme_font_size_override("font_size", 20)
	button.custom_minimum_size.y = 32
	button.pressed.connect(action)
	host.add_child(button)

func _select_body(id: String) -> void:
	body_id = id
	_show()

func _show() -> void:
	figures.clear()
	if is_instance_valid(_content):
		_content.free()
	_content = Node2D.new()
	add_child(_content)
	for side in 2:
		var texture := load("res://assets/iso_tiles/drawn_floor_plank.webp" if side == 0 else "res://assets/iso_tiles/drawn_forest_floor.webp") as Texture2D
		for y in 4:
			for x in 4:
				var tile := Sprite2D.new()
				tile.texture = texture
				tile.region_enabled = true
				tile.region_rect = Rect2(x * 144, y * 84, 144, 84)
				tile.position = Vector2(320 + side * 640 + (x - y) * 64 * .9, 410 + (x + y) * 38 * .9)
				tile.scale = Vector2.ONE * .9
				if side == 1:
					tile.modulate = Color(.55, .64, .72)
				_content.add_child(tile)
		_label(_content, Vector2(32 + side * 640, 354), "Warm floor" if side == 0 else "Forest floor", 18)
	for d in 8:
		var f := _figure(Vector2(126 + d * 146, 326), .78, d)
		figures.append(f)
		_label(_content, Vector2(116 + d * 146, 334), Figure.manifest()["directions"][d], 15)
	for side in 2:
		figures.append(_figure(Vector2(320 + side * 640, 650), 1.65, direction))
	_title.text = "%s · fitted starter clothes + iron sword" % body_id.capitalize()
	_status.text = "← → direction · 1–4 motion · H hero · F flash · S spin · preview only; full clip sets and live wardrobe integration remain"
	select_clip(clip)

func _figure(at: Vector2, size_: float, d: int) -> Figure:
	var f := Figure.new()
	f.body_id = body_id
	f.position = at
	f.scale = Vector2.ONE * size_
	_content.add_child(f)
	f.clock.set_direction_index(d)
	for part in selected_parts:
		f.set_part_enabled(part, selected_parts[part])
	f.sync_pose()
	return f

func select_clip(value: String) -> void:
	clip = value
	for figure in figures:
		figure.select_clip(value)

func set_part_enabled(value: bool, part: String) -> void:
	selected_parts[part] = value
	for figure in figures:
		figure.set_part_enabled(part, value)

func _turn(delta: int) -> void:
	direction = wrapi(direction + delta, 0, 8)
	for index in [8, 9]:
		figures[index].clock.set_direction_index(direction)
		figures[index].sync_pose()

func flash_all() -> void:
	for figure in figures:
		figure.clock.flash(Color("f3a59e"))

func spin_all() -> void:
	var tween := create_tween()
	tween.tween_method(_spin, 0.01, TAU, .65)
	tween.tween_callback(_spin.bind(0.0))

func _spin(angle: float) -> void:
	for figure in figures:
		figure.clock.set_spin(angle)
		figure.sync_pose()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	match event.keycode:
		KEY_LEFT: _turn(-1)
		KEY_RIGHT: _turn(1)
		KEY_H: _select_body("pedro" if body_id == "rasmus" else "rasmus")
		KEY_1: select_clip("idle")
		KEY_2: select_clip("walk")
		KEY_3: select_clip("run")
		KEY_4: select_clip("interact")
		KEY_F: flash_all()
		KEY_S: spin_all()
