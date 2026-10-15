extends Node2D
## Browse-only art review; no festival clock, gameplay manager or save is changed.
const View = preload("res://tools/art/drawn/festival_view.gd")
const FESTIVALS := ["blomsterfesten", "midsommerlanterner", "hoestfesten", "vinterlysene"]
var _index := 0
var _town := "hyggebyen"
var _evening := false
var _dressed := true
var _view: View
var _title: Label

func _ready() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 100
	add_child(ui)
	_title = Label.new()
	_title.position = Vector2(20, 12)
	_title.add_theme_color_override("font_color", Color("2b2340"))
	_title.add_theme_color_override("font_shadow_color", Color("f4e6c4"))
	_title.add_theme_constant_override("shadow_offset_x", 1)
	_title.add_theme_constant_override("shadow_offset_y", 1)
	_title.add_theme_font_size_override("font_size", 22)
	ui.add_child(_title)
	var hint := Label.new()
	hint.position = Vector2(20, 685)
	hint.text = "Art fixture · ← → season · T town · N evening · D decor · live festival integration pending"
	hint.add_theme_color_override("font_color", Color("f4e6c4"))
	hint.add_theme_color_override("font_shadow_color", Color("2b2340"))
	hint.add_theme_font_size_override("font_size", 16)
	ui.add_child(hint)
	_show()

func _show() -> void:
	if is_instance_valid(_view):
		_view.free()
	_view = View.new()
	add_child(_view)
	_view.setup(_town, FESTIVALS[_index], _evening, _dressed)
	_title.text = "%s · %s · %s · proposed art placement" % [_town, FESTIVALS[_index], "evening" if _evening else "daylight"]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	match event.keycode:
		KEY_LEFT: _index = wrapi(_index - 1, 0, 4)
		KEY_RIGHT: _index = wrapi(_index + 1, 0, 4)
		KEY_T: _town = "traetoppen" if _town == "hyggebyen" else "hyggebyen"
		KEY_N: _evening = not _evening
		KEY_D: _dressed = not _dressed
		_: return
	_show()
