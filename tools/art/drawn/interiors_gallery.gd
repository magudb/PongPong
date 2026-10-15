extends Node2D
## Developer art gallery. Never enters a gameplay world or writes a save.
const ViewScript = preload("res://tools/art/drawn/interiors_view.gd")
var room_ids: Array[String] = []
var current: ViewScript
var _index := 0
var _night := false
var _title: Label
var _hint: Label

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("eee7d8"))
	room_ids = PaintedInteriorArt.room_ids()
	var ui := CanvasLayer.new()
	add_child(ui)
	_title = Label.new()
	_title.position = Vector2(28, 16)
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color("4b3c49"))
	ui.add_child(_title)
	_hint = Label.new()
	_hint.position = Vector2(28, 682)
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color("67534a"))
	ui.add_child(_hint)
	get_viewport().size_changed.connect(_fit)
	show_room(room_ids[0])

func show_room(id: String, night: bool = false) -> void:
	if current != null:
		remove_child(current)
		current.free()
	_index = room_ids.find(id)
	_night = night
	current = ViewScript.new()
	add_child(current)
	current.setup(id, night)
	_title.text = "%s  ·  %s" % [str(current.room["title"]), "Evening" if night else "Daylight"]
	_hint.text = "Art study %d / %d  ·  ← → Browse   N Day / evening  ·  Fixed furnishing layouts, no gameplay changes" % [_index + 1, room_ids.size()]
	_fit()

func _fit() -> void:
	if current != null:
		var size := get_viewport_rect().size
		current.fit_viewport(Vector2(size.x, size.y - 95), Vector2(0, 55))
		_hint.position.y = size.y - 32

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey:
		if event.keycode in [KEY_RIGHT, KEY_LEFT]:
			_index = wrapi(_index + (1 if event.keycode == KEY_RIGHT else -1), 0, room_ids.size())
			show_room(room_ids[_index], _night)
		elif event.keycode == KEY_N:
			show_room(room_ids[_index], not _night)
