class_name TTSlider
extends HSlider
## The slider of every screen (UI_NAVIGATION.md 4.6 item 2). Godot's Slider NEVER draws a theme `focus` StyleBox (probed in 4.7.2 and looked at: a magenta 6 px
## `focus` style defined for HSlider and for Button left 0 magenta pixels on a focused slider and 2976 on a focused button), so the guide's rule "everything
## interactive gets a gold ring at focus" needs a script: this slider paints get_theme_stylebox("focus") (the theme's `HSlider/focus` entry = the selection
## ring, 3 px gold + 2 px ink outside the rect) in `_draw` while it has focus, redraws on every focus change and says so with the meta `tt_focus_style`, which
## is what the audit (focusable_report / ring_pixels) looks for. A plain HSlider in a screen is a defect (`ui_conformance.sliders_are_ttslider`).
##
## The ring surrounds everything that is drawn: with the theme constant `center_grabber` = 1 the grabber sticks out of the control rect by half its width at
## value 0 and at the maximum, so the ring rect is grown by half the grabber at both ends in that case (the built theme sets `center_grabber` = 0: the
## grabber stays inside the rect and the ring hugs the control, which is also what ring_pixels samples).


func _ready() -> void:
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	_declare_style()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_declare_style()
		queue_redraw()


## meta tt_focus_style: the StyleBox this control paints itself (the audit reads it instead of expecting a Button-like focus stylebox).
func _declare_style() -> void:
	var sb := get_theme_stylebox(&"focus")
	if sb != null and not (sb is StyleBoxEmpty):
		set_meta(&"tt_focus_style", sb)


func _draw() -> void:
	if not has_focus():
		return
	var sb := get_theme_stylebox(&"focus")
	if sb == null or sb is StyleBoxEmpty:
		return
	draw_style_box(sb, focus_rect())


## The rect the ring surrounds (control coordinates).
func focus_rect() -> Rect2:
	var r := Rect2(Vector2.ZERO, size)
	if get_theme_constant(&"center_grabber") != 0:
		var tex := get_theme_icon(&"grabber")
		if tex != null:
			var half := tex.get_width() * 0.5
			r = r.grow_individual(half, 0.0, half, 0.0)
	return r
