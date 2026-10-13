extends RefCounted
## Harness self-test: the LEGACY 3D flow of the old tests/playtest.gd (movement, pause, panels), lifted as a section.
## The harness boot stage has already walked main_menu -> character_select -> world. The legacy tree has ONE known
## failure here (pause_resumes: the second Esc does not resume) and the harness must report it, not crash.
## Skips itself once the 2D world replaced the 3D one.
const SECTION := "legacy_flow"

func run(t) -> void:
	var p: Node = t.player()
	if p == null or not (p is Node3D):
		t.skip("legacy 3D world not present (the 2D world replaced it)")
		return
	var gm: Node = t.autoload("GameManager")
	t.check("player_settled", p.is_on_floor(), "after boot")
	var start: Vector3 = p.global_position
	t.hold(&"move_forward")
	await t.seconds(1.0)
	t.release(&"move_forward")
	var moved := start.distance_to(p.global_position)
	t.check("player_moves", moved > 1.0, "moved %.2f m" % moved)
	t.tap(&"pause")
	await t.frames(5)
	t.check("pause_pauses", gm.current_phase == gm.GamePhase.PAUSED)
	t.tap(&"pause")
	await t.frames(5)
	t.check("pause_resumes", gm.current_phase == gm.GamePhase.PLAYING, "known legacy failure until the 2D menus land")
	t.tap(&"inventory")
	await t.frames(5)
	t.tap(&"journal")
	await t.frames(5)
	t.check("panels_do_not_crash", true)
