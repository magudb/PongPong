extends RefCounted
const SECTION := "evidence_origins"
const TIMEOUT_S := 120.0
const Callback := preload("res://tests/sections/multiplayer_callback_ownership.gd")

func run(t) -> void:
	for kind in ["normal", "direct", "failed", "body", "actor_free", "cleanup"]:
		await _mother(t, kind)
	for kind in ["normal", "direct", "failed", "body", "letter_body", "letter_free", "cancel"]:
		await _garden(t, kind)
	for kind in ["normal", "direct", "failed"]:
		await _work(t, kind)
	for kind in ["normal", "direct", "failed"]:
		await _director(t, kind)

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

func _garden(t, kind: String) -> void:
	if not await t.start_world(): return
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	QuestManager.accept_quest(SecretGardenStory.QUEST)
	var letter := kind.begins_with("letter")
	if letter:
		for index in 7:
			if index == 6: GameManager.set_flag(SecretGardenStory.WATER_DAY, GameManager.total_day()-1)
			SecretGardenStory.advance(index)
	await t.world().travel(&"secret_garden", &"default")
	var marker: Node
	for node in t.world().area.objects.get_children():
		if node is SecretGardenMarker and node.kind == ("letter" if letter else "path"): marker = node
	var body: Node = t.player()
	var ui: Node = t.first(&"dialogue_ui")
	var saves: Node = t.autoload("SaveManager")
	var late := Callback.Rollback.LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("garden_late", late, 1000)
	var payload: Dictionary = saves.gather_payload()
	var original := PlayerRegistry.peek_state(&"p0")
	var observed: Array = []
	var on_choice := func(action, _data):
		if action != "garden_work" or kind in ["normal", "cancel"] or not observed.is_empty(): return
		observed.append(true)
		if kind in ["body", "letter_body"]:
			body.get_parent().remove_child(body)
			return
		if kind == "letter_free":
			marker.free()
			return
		if kind == "failed": late.rejects = 1
		observed.append(saves._apply_payload(payload).ok)
		observed.append(PlayerRegistry.peek_state(&"p0") == original)
	ui.choice_selected.connect(on_choice)
	if marker != null: marker.interact(body)
	await t.page_to_choices(ui)
	var work := {}
	for button in ui._buttons:
		var choice: Dictionary = button.get_meta("choice")
		if choice.get("action") == "garden_work": work = choice
	t.check(kind + "_garden_real_authored_choice", marker != null and ui.is_open() and ui._shown == ui._lines.size() and not work.is_empty() and SecretGardenStory.step() == (7 if letter else 0))
	if kind == "cancel": ui.close()
	elif not work.is_empty(): ui._pick(work)
	ui.choice_selected.disconnect(on_choice)
	if kind in ["direct", "failed"]: t.check(kind + "_garden_replacement", observed == ([true, true, false] if kind == "direct" else [true, false, true]) and (late.calls == 2 if kind == "failed" else true))
	var expected := 8 if letter else (0 if kind in ["direct", "body", "cancel"] else 1)
	t.check(kind + "_garden_progress_authority", SecretGardenStory.step() == expected)
	t.check(kind + "_garden_cleanup", not ui.is_open() and (not is_instance_valid(marker) or not marker._busy) and body.state == PlayerBody2D.S.FREE)
	if kind in ["body", "letter_body"]: t.world().add_child(body)
	saves.unregister_section("garden_late")
	late.free()
	await t.go_menu()

func _work(t, kind: String) -> void:
	if not await t.start_world(): return
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	GameManager.set_flag(&"forest_mother_version", 1)
	var marker := MotherEvidenceMarker.new()
	marker.evidence_id = "memory_lamp"
	marker.area = t.world().area
	t.world().area.objects.add_child(marker)
	var saves: Node = t.autoload("SaveManager")
	var late := Callback.Rollback.LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("work_late", late, 1000)
	var payload: Dictionary = saves.gather_payload()
	var original := PlayerRegistry.peek_state(&"p0")
	var observed: Array = []
	var events: Array = []
	var on_flag := func(key, _value):
		if key != &"forest_mother_v1_work_memory_lamp" or kind == "normal" or not observed.is_empty(): return
		observed.append(true)
		if kind == "failed": late.rejects = 1
		observed.append(saves._apply_payload(payload).ok)
		observed.append(PlayerRegistry.peek_state(&"p0") == original)
	var on_event := func(id, _data):
		if id == &"forest_mother_work": events.append(id)
	var ui: Node = t.first(&"dialogue_ui")
	marker.interact(t.player())
	await t.page_to_choices(ui)
	var stitch := {}
	for button in ui._buttons:
		var choice: Dictionary = button.get_meta("choice")
		if choice.get("action") == "stitch_0": stitch = choice
	t.check(kind + "_work_actual_first_stitch", ui.is_open() and not stitch.is_empty() and MotherMemoryWork.state("memory_lamp") == 0)
	EventBus.flag_changed.connect(on_flag)
	EventBus.game_event.connect(on_event)
	if not stitch.is_empty(): ui._pick(stitch)
	EventBus.flag_changed.disconnect(on_flag)
	EventBus.game_event.disconnect(on_event)
	if kind == "direct":
		t.check("work_successful_replacement", observed == [true, true, false])
		t.check("work_no_old_save_event_or_projection", events.is_empty() and MotherMemoryWork.state("memory_lamp") == 0 and not QuestManager.is_active(MotherStory.quest_id("s03")))
	else:
		t.check(kind + "_work_committed_once", (observed.is_empty() if kind == "normal" else observed == [true, false, true] and late.calls == 2) and MotherMemoryWork.state("memory_lamp") == 1 and events.size() == 1 and ui.is_open())
	ui.close()
	t.check(kind + "_work_cleanup", not marker._busy and t.player().state == PlayerBody2D.S.FREE)
	saves.unregister_section("work_late")
	late.free()
	await t.go_menu()

func _director(t, kind: String) -> void:
	if not await t.start_world(): return
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	GameManager.set_flag(&"forest_mother_version", 1)
	var marker := MotherEvidenceMarker.new()
	marker.evidence_id = "memory_lamp"
	marker.area = t.world().area
	t.world().area.objects.add_child(marker)
	var director: Node = t.world().get_node("MotherStory")
	var saves: Node = t.autoload("SaveManager")
	var late := Callback.Rollback.LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("director_late", late, 1000)
	# A valid enabled but not-yet-projected winner distinguishes stale
	# continuation from an independently requested current-state recomputation.
	var payload: Dictionary = saves.gather_payload()
	var original := PlayerRegistry.peek_state(&"p0")
	var observed: Array = []
	var notices: Array = []
	var on_event := func(id, _data):
		if id != &"forest_mother_work": return
		notices.append(id)
		if kind == "normal" or not observed.is_empty(): return
		observed.append(true)
		if kind == "failed": late.rejects = 1
		observed.append(saves._apply_payload(payload).ok)
		observed.append(PlayerRegistry.peek_state(&"p0") == original)
		observed.append(QuestManager.is_active(MotherStory.quest_id("s03")))
	EventBus.game_event.disconnect(director._event)
	EventBus.game_event.connect(on_event)
	EventBus.game_event.connect(director._event)
	var ui: Node = t.first(&"dialogue_ui")
	marker.interact(t.player())
	await t.page_to_choices(ui)
	var stitch := {}
	for button in ui._buttons:
		var choice: Dictionary = button.get_meta("choice")
		if choice.get("action") == "stitch_0": stitch = choice
	t.check(kind + "_director_actual_producer_eligible", not stitch.is_empty() and not QuestManager.is_active(MotherStory.quest_id("s03")) and saves.validate_payload(payload).ok)
	if not stitch.is_empty(): ui._pick(stitch)
	EventBus.game_event.disconnect(on_event)
	t.check(kind + "_director_public_notification_once", notices == [&"forest_mother_work"])
	if kind == "direct":
		t.check("director_replacement_before_real_listener", observed == [true, true, false, false])
		t.check("director_old_event_cannot_project_winner", not QuestManager.is_active(MotherStory.quest_id("s03")))
		MotherStory.sync()
		t.check("director_independent_current_root_still_projects", QuestManager.is_active(MotherStory.quest_id("s03")))
	else:
		t.check(kind + "_director_normal_projection", (observed.is_empty() if kind == "normal" else observed == [true, false, true, false] and late.calls == 2) and QuestManager.is_active(MotherStory.quest_id("s03")))
	ui.close()
	saves.unregister_section("director_late")
	late.free()
	await t.go_menu()
