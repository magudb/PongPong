extends RefCounted
const SECTION := "ui_mechanics"
const TIMEOUT_S := 60.0
class NamedSelection extends ColorRect:
	var selected := "chair_pine"
func run(t) -> void:
	var surface := NamedSelection.new()
	surface.color = preload("res://scripts/ui/theme/tt_colors.gd").GOLD
	surface.size = Vector2(50,50)
	t.root.add_child(surface)
	var rules := UiAudit.rule_report(surface)
	t.check("string_selection_does_not_exempt_gold",rules.defects.any(func(row):return row.code=="r2_gold_decoration"))
	surface.queue_free()
	var calendar: Control = await UiAudit.open_screen(t,"calendar")
	await t.frames(3)
	var columns := calendar.get_child(1) as Control
	var card := columns.get_child(0) as Control
	t.check("calendar_card_stays_in_content",calendar.get_global_rect().encloses(card.get_global_rect()),str(calendar.get_global_rect())+" contains "+str(card.get_global_rect()))
	await UiAudit.close_screen(t,"calendar")
func run_windowed(t) -> void:
	await run(t)
	var calendar: Control = await UiAudit.open_screen(t,"calendar")
	await t.frames(3)
	var picture: Image = await t.capture("calendar_bounded_card")
	var card: Control = calendar.get_child(1).get_child(0)
	t.check("reopened_calendar_card_stays_in_content",calendar.get_global_rect().encloses(card.get_global_rect()),str(card.get_global_rect()))
	var below := picture.get_pixel(200,690)
	t.check("calendar_card_paint_stays_in_book",maxf(below.r,maxf(below.g,below.b))<0.85,str(below))
	await UiAudit.close_screen(t,"calendar")
