extends RefCounted
const SECTION := "evidence_origins"
const TIMEOUT_S := 120.0
const Callback := preload("res://tests/sections/multiplayer_callback_ownership.gd")

func run(t) -> void:
	for kind in ["normal", "direct", "failed", "body", "actor_free", "cleanup"]:
		await _mother(t, kind)

func _mother(t, kind: String) -> void:
	if not await t.start_world(): return
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	GameManager.set_flag(&"forest_mother_version", 1)
	var marker := MotherEvidenceMarker.new()
	marker.evidence_id = "marked_lamp"
	marker.area = t.world().area
	t.world().area.objects.add_child(marker)
	var ui: Node = t.first(&"dialogue_ui")
	var saves: Node = t.autoload("SaveManager")
	var late := Callback.Rollback.LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("evidence_late", late, 1000)
	var payload: Dictionary = saves.gather_payload()
	var original := PlayerRegistry.peek_state(&"p0")
	var observed: Array = []
	var body: Node = t.player()
	var next: Array = []
	var on_choice := func(action, _data):
		if action != "mother_record" or kind == "normal" or not observed.is_empty(): return
		observed.append(true)
		if kind == "body":
			body.get_parent().remove_child(body)
			return
		if kind in ["actor_free", "cleanup"]:
			if kind == "cleanup":
				var replacement := MotherEvidenceMarker.new()
				replacement.evidence_id = "memory_table"
				replacement.area = t.world().area
				t.world().area.objects.add_child(replacement)
				replacement.interact(body)
				next.append(replacement)
			marker.free()
			return
		if kind == "failed": late.rejects = 1
		observed.append(saves._apply_payload(payload).ok)
		observed.append(PlayerRegistry.peek_state(&"p0") == original)
	ui.choice_selected.connect(on_choice)
	marker.interact(t.player())
	await t.page_to_choices(ui)
	var record := {}
	for button in ui._buttons:
		var choice: Dictionary = button.get_meta("choice")
		if choice.get("action") == "mother_record": record = choice
	t.check(kind + "_mother_real_read_record_choice", ui.is_open() and ui._shown == ui._lines.size() and not record.is_empty() and not MotherStory.has("marked_lamp") and saves.validate_payload(payload).ok)
	if not record.is_empty(): ui._pick(record)
	ui.choice_selected.disconnect(on_choice)
	if kind == "direct":
		t.check("mother_successful_same_value_replacement_reached", observed == [true, true, false])
		t.check("mother_old_page_cannot_record_winner", not MotherStory.has("marked_lamp"))
	else:
		t.check(kind + "_mother_earned_record", (observed.is_empty() if kind == "normal" else observed == [true, false, true] and late.calls == 2 if kind == "failed" else observed == [true]) and MotherStory.has("marked_lamp"))
	if kind == "cleanup":
		t.check("mother_old_exit_keeps_replacement_request_and_hold", ui.is_open() and not next.is_empty() and next[0]._busy and body.state == PlayerBody2D.S.TALKING)
		ui.close()
	else:
		t.check(kind + "_mother_cleanup", not ui.is_open() and (not is_instance_valid(marker) or not marker._busy) and body.state == PlayerBody2D.S.FREE)
	if kind == "body": t.world().add_child(body)
	saves.unregister_section("evidence_late")
	late.free()
	await t.go_menu()
