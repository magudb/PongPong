extends Button
## A single node per citizen keeps the full thirty-person list below its node cap.
var row: Dictionary = {}
var portrait: Texture2D

func setup(data: Dictionary, texture: Texture2D) -> void:
	row = data
	portrait = texture
	accessibility_name = SocialLayout.npc_name(row.id) + ", " + SocialLayout.stage_name(row.stage)
	tooltip_text = accessibility_name
	queue_redraw()

func _draw() -> void:
	if row.is_empty():
		return
	if portrait != null:
		draw_texture_rect(portrait, Rect2(10, 7, 44, 44), false)
	var ink := preload("res://scripts/ui/theme/tt_colors.gd").INK
	var font := get_theme_font("font", "Heavy18")
	draw_string(font, Vector2(64, 24), SocialLayout.npc_name(row.id), HORIZONTAL_ALIGNMENT_LEFT, size.x - 76, 18, ink)
	SocialHearts.paint(self, Vector2(64, 28), 10, int(row.half_hearts), Vector2(15, 14), 2)
	var stage := SocialLayout.stage_name(row.stage)
	var small := get_theme_font("font", "Muted14")
	draw_string(small, Vector2(246, 48), stage, HORIZONTAL_ALIGNMENT_RIGHT, maxf(0, size.x - 258), 14, ink)
