extends Control
## Native concept review. Selection is local and never equips or grants game items.
const MANIFEST := "res://assets/art_studies/equipment/manifest.json"
var data: Dictionary
var hero_index := 0
var mode_index := 0
var selected_item := "iron_sword"
var _figure: TextureRect
var _world_figure: TextureRect
var _item_figure: TextureRect
var _name: Label
var _fit: Label
var _item_title: Label
var _item_note: Label
var _hero_buttons: Array[Button] = []
var _mode_buttons: Array[Button] = []
var _item_buttons: Dictionary = {}

func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST)) as Dictionary
	theme = Theme.new()
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("d5dfbd") if state in ["pressed", "hover_pressed"] else Color("f9f1df")
		style.border_color = Color("b39368") if state == "focus" else Color("c9b795")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(7)
		style.content_margin_left = 7
		style.content_margin_right = 7
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		if state == "focus":
			style.draw_center = false
		theme.set_stylebox(state, "Button", style)
	for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(color, "Button", Color("4b3c49"))
	for color in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_hover_pressed_color"]:
		theme.set_color(color, "Button", Color.WHITE)
	var background := ColorRect.new()
	background.color = Color("eee7d8")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)
	_label(layout, "Equipment design studio", 28)
	_label(layout, "Outfit concepts and object studies · Front view · Clothing, tools and five weapon families", 16)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	layout.add_child(columns)
	var cast := VBoxContainer.new()
	cast.custom_minimum_size.x = 196
	cast.add_theme_constant_override("separation", 6)
	columns.add_child(cast)
	_label(cast, "Playable heroes", 19)
	for i in (data["heroes"] as Array).size():
		var button := Button.new()
		button.text = data["heroes"][i]["name"]
		button.toggle_mode = true
		button.custom_minimum_size.y = 38
		button.pressed.connect(_select_hero.bind(i))
		cast.add_child(button)
		_hero_buttons.append(button)
	_fit = _label(cast, "", 15)
	_fit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_fit.custom_minimum_size.x = 196
	_label(cast, "← → Hero\n1 / 2 / 3 Outfit\n4 In hand", 14)
	var hero := VBoxContainer.new()
	hero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(hero)
	_name = _label(hero, "", 22)
	var choices := HBoxContainer.new()
	hero.add_child(choices)
	for i in (data["review_modes"] as Array).size():
		var button := Button.new()
		button.text = data["review_modes"][i]["name"]
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_mode.bind(i))
		choices.add_child(button)
		_mode_buttons.append(button)
	_figure = _texture(hero, Vector2(260, 310))
	_figure.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label(hero, "Small-scale silhouette check", 14)
	_world_figure = _texture(hero, Vector2(72, 80))
	var items := VBoxContainer.new()
	items.custom_minimum_size.x = 400
	items.add_theme_constant_override("separation", 7)
	columns.add_child(items)
	_label(items, "Clothing, hands and action items", 19)
	var grid := GridContainer.new()
	grid.columns = 5
	items.add_child(grid)
	for id in data["items"]:
		var rec: Dictionary = data["items"][id]
		var button := Button.new()
		button.custom_minimum_size = Vector2(76, 46)
		button.icon = load("res://" + str(rec["file"])) as Texture2D
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 36)
		button.tooltip_text = rec["name"]
		button.toggle_mode = true
		button.pressed.connect(select_item.bind(str(id)))
		grid.add_child(button)
		_item_buttons[id] = button
	_item_title = _label(items, "", 21)
	_item_figure = _texture(items, Vector2(120, 120))
	_item_note = _label(items, "", 14)
	_item_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_note.custom_minimum_size.x = 400
	_label(layout, "Design review only · Outfit drawings are flattened; animated fitted layers and hand grips are the next production step.", 14)
	refresh()
	select_item(selected_item)

func _label(host: Node, value: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("4b3c49"))
	host.add_child(label)
	return label

func _texture(host: Node, minimum: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = minimum
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	host.add_child(rect)
	return rect

func _select_hero(index: int) -> void:
	hero_index = index
	refresh()

func _select_mode(index: int) -> void:
	mode_index = index
	refresh()

func refresh() -> void:
	var hero: Dictionary = data["heroes"][hero_index]
	var mode: Dictionary = data["review_modes"][mode_index]
	var held: bool = mode["id"] == "held"
	var rec: Dictionary = data["held_examples"][hero["id"]] if held else data["looks"][str(hero["id"]) + "_" + str(mode["id"])]
	var texture := load("res://" + str(rec["file"])) as Texture2D
	_figure.texture = texture
	_world_figure.texture = texture
	_name.text = "%s · %s" % [hero["name"], mode["name"]]
	if held:
		select_item(rec["equipment"])
	_fit.text = "Fit notes\n" + str(hero["fit"])
	for i in _hero_buttons.size():
		_hero_buttons[i].set_pressed_no_signal(i == hero_index)
	for i in _mode_buttons.size():
		_mode_buttons[i].set_pressed_no_signal(i == mode_index)

func select_item(id: String) -> void:
	selected_item = id
	var rec: Dictionary = data["items"][id]
	_item_figure.texture = load("res://" + str(rec["file"])) as Texture2D
	_item_title.text = rec["name"]
	var source := "System presentation; no new inventory slot" if rec["reference_status"] == "presentation_only" else (
		"Existing item" if rec["reference_status"] == "existing" else "Planned dungeon item")
	_item_note.text = "%s · %s\nFront-view object study; fitted directional views and grips are still required." % [source, rec["presentation_slot"]]
	for key in _item_buttons:
		(_item_buttons[key] as Button).set_pressed_no_signal(key == id)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if event.keycode in [KEY_RIGHT, KEY_LEFT]:
		_select_hero(wrapi(hero_index + (1 if event.keycode == KEY_RIGHT else -1), 0, (data["heroes"] as Array).size()))
	elif event.keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
		_select_mode(int(event.keycode) - KEY_1)
