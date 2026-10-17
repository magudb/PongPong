extends VBoxContainer
const L := preload("res://scripts/ui/social/social_layout.gd")
var _title: Label
var _subtitle: Label
var _tween: Tween
var arrivals := 0
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_title = L.label(self,"","Display30")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_color",Color("fffdf6"))
	_title.add_theme_color_override("font_outline_color",Color("2b2340"))
	_title.add_theme_constant_override("outline_size",6)
	_subtitle = L.label(self,"","Body")
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_color_override("font_color",Color("fffdf6"))
	visible = false
func show_floor(area: IsoArea, boss_visible: bool) -> void:
	if boss_visible or area == null or DungeonFloors.floor_of(area) <= 0: return
	arrivals += 1
	_title.text = TranslationServer.translate("DUNGEON_FLOOR_FMT") % area.map.depth
	_subtitle.text = TranslationServer.translate(area.map.title)
	if _tween != null and _tween.is_valid(): _tween.kill()
	visible = true
	modulate.a = 0
	_tween = create_tween()
	_tween.tween_property(self,"modulate:a",1.0,.3)
	_tween.tween_interval(1.6)
	_tween.tween_property(self,"modulate:a",0.0,.3)
	_tween.tween_callback(hide)
func dismiss() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	hide()
