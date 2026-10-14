extends RefCounted
## Planted defects whose SOURCE the audit's own script scans would flag (R2: a script that names the gold constant, the Window scan: a script that creates a drop-down). They live in
## this file, which no screen node runs, so the conforming layouts of screen.gd stay clean while the planted ones still show the defect on screen.

const C = preload("res://scripts/ui/theme/tt_colors.gd")


## defect "gold_decoration": a gold stripe and a gold tag, both decoration (gold is for focus and selected only).
static func gold_decoration(vbox: VBoxContainer) -> void:
	var stripe := ColorRect.new()
	stripe.name = "GoldStripe"
	stripe.color = C.GOLD
	stripe.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(stripe)
	vbox.move_child(stripe, 1)
	var tag := Panel.new()
	tag.name = "GoldTag"
	tag.custom_minimum_size = Vector2(120, 24)
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = C.GOLD
	gsb.set_border_width_all(2)
	gsb.border_color = C.INK
	tag.add_theme_stylebox_override("panel", gsb)
	vbox.add_child(tag)


## defect "window_option": a drop-down whose popup is a Window (banned in game screens).
static func window_option(box: Node) -> OptionButton:
	var options := OptionButton.new()
	options.name = "WindowSize"
	options.custom_minimum_size = Vector2(0, 48)
	for txt in ["1280 x 720", "1600 x 900", "1920 x 1080"]:
		options.add_item(txt)
	box.add_child(options)
	return options


## defect "radio_page_defects": a gold stripe on a page the first tab hides.
static func gold_stripe(parent: Node) -> void:
	var stripe := ColorRect.new()
	stripe.name = "GoldStripe"
	stripe.color = C.GOLD
	stripe.custom_minimum_size = Vector2(0, 8)
	parent.add_child(stripe)
