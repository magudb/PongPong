extends HSlider
## The slider a screen must use (the spec's TTSlider): Godot's HSlider draws NO focus indicator at all - not even when the theme has a `focus` StyleBox for it (probed in 4.7.2 and
## looked at: a magenta 6 px HSlider focus style left zero magenta pixels on a focused slider, a Button's 2976). So this slider paints the guide's gold focus ring (the Button focus
## style of the project theme) itself while it has focus, and declares the style with the meta `tt_focus_style` so the audit (focusable_report / ring_pixels) knows it is there.


func _ready() -> void:
	var ring := get_theme_stylebox("focus") if has_theme_stylebox("focus") and not (get_theme_stylebox("focus") is StyleBoxEmpty) else get_theme_stylebox("focus", "Button")
	set_meta(&"tt_focus_style", ring)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	if has_focus():
		draw_style_box(get_meta(&"tt_focus_style") as StyleBox, Rect2(Vector2.ZERO, size))
