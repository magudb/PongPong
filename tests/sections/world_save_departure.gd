extends RefCounted
## A read Mother page may earn profile progress after its host body departs.
## The incomplete live world must refuse persistence, never save pending/default pose.
const SECTION := "world_save_departure"
const TIMEOUT_S := 120.0

func run(t) -> void:
	var saves: Node = t.autoload("SaveManager")
	var prior: String = saves.save_dir
	t.on_cleanup(func():
		saves.save_dir = prior
		TimeManager.resume_time()
		GameManager.set_process(true))
	for kind in ["unregister", "free", "detach"]:
		await _mother(t, saves, kind)

func _files(saves: Node) -> Dictionary:
	var out := {}
	for name in DirAccess.get_files_at(saves.save_dir):
		out[name] = FileAccess.get_file_as_bytes(saves.save_dir.path_join(name))
	return out

func _attach(world: Node, pose: Vector2) -> Node2D:
	var body: Node2D = world._make_player()
	world._register_player(body, 0, 1)
	world.add_child(body)
	body.enter_area(world.area, pose)
	return body

func _mother(t, saves: Node, kind: String) -> void:
	if not await t.start_world(): return
	TimeManager.pause_time()
	GameManager.set_process(false)
	saves.save_dir = "user://world-save-departure-" + kind
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	GameManager.set_flag(&"forest_mother_version", 1)
	var world: Node = t.world()
	var body: Node2D = t.player()
	var pose := body.global_position + Vector2(7, 3)
	body.global_position = pose
	var p0 := PlayerRegistry.peek_state(&"p0")
	var other: Node2D = world._make_player()
	world._register_player(other, 1, 2)
	world.add_child(other)
	other.enter_area(world.area, pose + Vector2(20, 0))
	var p1 := PlayerRegistry.state(&"p1")
	t.check(kind + "_healthy_seed", saves.save_game(0) and saves.save_game(0) and saves.autosave())
	# Seed the existing previous-auto file (auto slots have no .bak).
	t.check(kind + "_backup_seed", DirAccess.copy_absolute(saves.slot_path(saves.AUTO_SLOT), saves.slot_path(saves.PREV_AUTO_SLOT)) == OK)
	var files := _files(saves)
	var p1_before := p1.to_dict()
	var expected_p1: Dictionary = saves.validate_payload(JSON.parse_string(FileAccess.get_file_as_string(saves.slot_path(0)))).payload.players.rows.p1
	var marker := MotherEvidenceMarker.new()
	marker.evidence_id = "marked_lamp"
	marker.area = world.area
	world.area.objects.add_child(marker)
	var ui: Node = t.first(&"dialogue_ui")
	var observed: Array = []
	var failures: Array = []
	var notices: Array = []
	var weak_body: WeakRef = weakref(body)
	var on_choice := func(action, _data):
		if action != "mother_record" or not observed.is_empty(): return
		observed.append(true)
		if kind == "detach": body.get_parent().remove_child(body)
		elif kind == "unregister": observed.append(world._unregister_player(body))
		else: body.free()
	var on_failed := func(slot, code):
		failures.append([slot, code, _files(saves) == files, MotherStory.has("marked_lamp")])
	var on_event := func(id, _data):
		if id == &"forest_mother_evidence": notices.append(id)
	ui.choice_selected.connect(on_choice)
	EventBus.save_failed.connect(on_failed)
	EventBus.game_event.connect(on_event)
	marker.interact(body)
	await t.page_to_choices(ui)
	var record := {}
	for button in ui._buttons:
		var choice: Dictionary = button.get_meta("choice")
		if choice.get("action") == "mother_record": record = choice
	t.check(kind + "_actual_read_page_eligible", ui.is_open() and ui._shown == ui._lines.size() and not record.is_empty() and not MotherStory.has("marked_lamp") and PlayerRegistry.registered_id(body) == &"p0")
	if not record.is_empty(): ui._pick(record)
	ui.choice_selected.disconnect(on_choice)
	EventBus.save_failed.disconnect(on_failed)
	EventBus.game_event.disconnect(on_event)
	t.check(kind + "_earned_record_and_notice", MotherStory.has("marked_lamp") and notices == [&"forest_mother_evidence"] and PlayerRegistry.peek_state(&"p0") == p0)
	t.check(kind + "_gather_refusal_at_callback", failures == [[saves.AUTO_SLOT, "gather", true, true]] and saves.last_error.get("code") == "gather")
	t.check(kind + "_whole_unwind_no_corruption", _files(saves) == files and not ui.is_open() and not marker._busy)
	await t.frames(2)
	t.check(kind + "_physical_departure_real", (weak_body.get_ref() == null if kind != "detach" else is_instance_valid(body) and not body.is_inside_tree()) and PlayerRegistry.by_id(&"p0") == null and PlayerRegistry.by_id(&"p1") == other)
	t.check(kind + "_p1_unchanged", p1 == PlayerRegistry.peek_state(&"p1") and p1.to_dict() == p1_before)
	# Direct consumers get explicit refusal, with no error or fabricated world.
	t.check(kind + "_direct_serializer_refuses", world.to_dict() == null)
	t.check(kind + "_manual_refusal_no_corruption", not saves.save_game(0) and saves.last_error.get("code") == "gather" and _files(saves) == files)
	var recovered: Node2D
	if kind == "detach":
		world.add_child(body)
		recovered = body
	else: recovered = _attach(world, pose)
	t.check(kind + "_next_healthy_save", saves.save_game(1) and saves.autosave() and not saves.save_failing and PlayerRegistry.registered_id(recovered) == &"p0")
	var disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(saves.slot_path(saves.AUTO_SLOT)))
	t.check(kind + "_earned_progress_persisted", disk is Dictionary and saves.validate_payload(disk).ok and disk.game.world_flags.get("forest_mother_v1_marked_lamp", -1) == GameManager.total_day() and disk.world.player_pos == [pose.x, pose.y] and saves.validate_payload(disk).payload.players.rows.p1 == expected_p1, "flag=%s pose=%s expected=%s p1=%s expectedp1=%s" % [disk.game.world_flags.get("forest_mother_v1_marked_lamp"), disk.world.player_pos, pose, disk.players.rows.p1, p1_before])
	await t.go_menu()
