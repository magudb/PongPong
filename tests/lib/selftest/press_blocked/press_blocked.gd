extends RefCounted
## Harness self-test (NEGATIVE): t.press() is a real click, so it refuses a button a player could not click: a hidden one, one
## outside the window and one under a full-window overlay that takes the mouse. Each refusal is a failed check, none presses.
const SECTION := "press_blocked"

func run(t) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1000
	t.root.add_child(layer)
	var hits := [0]
	var hidden := _button(layer, "StHiddenButton", Vector2(100, 100), hits)
	hidden.visible = false
	_button(layer, "StOutsideButton", Vector2(2000, 100), hits)
	_button(layer, "StCoveredButton", Vector2(300, 300), hits)
	await t.frames(2)
	t.press("%StHiddenButton")
	t.press("%StOutsideButton")
	var cover := ColorRect.new()
	cover.name = "StOverlay"
	cover.color = Color(0, 0, 0, 0)
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	var over := CanvasLayer.new()
	over.layer = 1001
	t.root.add_child(over)
	over.add_child(cover)
	await t.frames(2)
	t.press("%StCoveredButton")
	t.check("refused_buttons_did_not_fire", hits[0] == 0, "%d presses" % hits[0])
	layer.queue_free()
	over.queue_free()


func _button(parent: Node, n: String, pos: Vector2, hits: Array) -> Button:
	var b := Button.new()
	b.name = n
	b.text = n
	b.position = pos
	b.size = Vector2(120, 40)
	b.pressed.connect(func() -> void: hits[0] += 1)
	parent.add_child(b)
	return b
