extends Node2D
## Browse-only developer art studio. The unfinished towns branch is not loaded.
const View = preload("res://tools/art/drawn/shop_special_view.gd")
var _ids: Array = []
var _index := 0
var _night := false
var _dressed := true
var _view: View
var _title: Label

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("eee7d8"))
	_ids = View.room_ids()
	var overlay := CanvasLayer.new()
	add_child(overlay)
	_title = Label.new()
	_title.position = Vector2(24, 12)
	_title.add_theme_color_override("font_color", Color("2b2340"))
	_title.add_theme_font_size_override("font_size", 22)
	overlay.add_child(_title)
	var hint := Label.new()
	hint.position = Vector2(24, 685)
	hint.text = "Art review · ← → room · N evening · D toggle specialist dressing · no gameplay or saves"
	hint.add_theme_color_override("font_color", Color("2b2340"))
	hint.add_theme_font_size_override("font_size", 16)
	overlay.add_child(hint)
	_show()

func _show() -> void:
	if is_instance_valid(_view):
		_view.free()
	_view = View.new()
	add_child(_view)
	_view.setup_special(str(_ids[_index]), _dressed, _night)
	_view.fit_viewport(Vector2(1280, 625), Vector2(0, 45))
	_title.text = "%s · %s · %s" % [_ids[_index], "specialist dressing" if _dressed else "core room", "evening" if _night else "daylight"]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	match event.keycode:
		KEY_LEFT: _index = wrapi(_index - 1, 0, _ids.size())
		KEY_RIGHT: _index = wrapi(_index + 1, 0, _ids.size())
		KEY_N: _night = not _night
		KEY_D: _dressed = not _dressed
		_: return
	_show()
