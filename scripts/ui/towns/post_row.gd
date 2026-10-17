extends Button
var row: Dictionary = {}
var portrait: Texture2D
func setup(data: Dictionary) -> void:
	row = data
	portrait = SocialLayout.Portraits.portrait(StringName(str(row.id)))
	accessibility_name = SocialLayout.npc_name(row.id)+", "+str(row.place)+", "+str(row.act)
	tooltip_text = accessibility_name
	queue_redraw()
func _draw() -> void:
	if row.is_empty(): return
	if portrait != null: draw_texture_rect(portrait,Rect2(12,8,44,44),false)
	var ink := preload("res://scripts/ui/theme/tt_colors.gd").INK
	draw_string(get_theme_font("font","Heavy18"),Vector2(72,25),SocialLayout.npc_name(row.id),HORIZONTAL_ALIGNMENT_LEFT,size.x-90,18,ink)
	var location := str(row.place)+( " · "+str(row.act) if str(row.act) != "" else "")
	draw_string(get_theme_font("font","Muted14"),Vector2(72,46),location,HORIZONTAL_ALIGNMENT_LEFT,size.x-90,14,ink)
