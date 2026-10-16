extends RefCounted
## Add the documented calendar variations locally; the reviewed shared theme stays pinned.
static func make() -> Theme:
	var base: Theme = load("res://assets/ui/theme.tres")
	var out := base.duplicate() as Theme
	var c := preload("res://scripts/ui/theme/tt_colors.gd")
	for variation in ["CalCell", "CalCellFest", "CalCellToday"]:
		out.set_type_variation(variation, &"Button")
		out.set_font("font", variation, base.get_font("font", "Display20"))
		out.set_font_size("font_size", variation, 20)
		out.set_color("font_color", variation, c.INK)
		out.set_stylebox("focus", variation, base.get_stylebox("focus", "RowButton"))
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var style := TTBoxStyle.new()
			style.radius = 10
			style.fill = Color(c.PARCHMENT_DARK, 0.9)
			style.border_color = c.DIVIDER
			if variation == "CalCellFest":
				style.fill = c.LAVENDER_PALE
				style.border_color = c.INK
			elif variation == "CalCellToday":
				style.fill = c.PARCHMENT_DARK
				style.border_width = 3
				style.border_color = c.INK
			if state in ["hover", "pressed", "hover_pressed"]:
				style.fill = style.fill.lerp(c.CHALK, 0.35)
			out.set_stylebox(state, variation, style)
	return out
