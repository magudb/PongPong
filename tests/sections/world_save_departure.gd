extends RefCounted
## A read Mother page may earn profile progress after its host body departs.
## The incomplete live world must refuse persistence, never save pending/default pose.
const SECTION := "world_save_departure"
const TIMEOUT_S := 120.0
const LateSection := preload("res://tests/sections/multiplayer_rollback.gd").LateSection
var _oracles: Array = []

func _audit(kind: String, point: String, saves: Node) -> void:
	var entries := {}
	for name in DirAccess.get_files_at(saves.save_dir):
		var path: String = saves.save_dir.path_join(name)
		entries[name] = {"sha256": FileAccess.get_sha256(path), "bytes": FileAccess.get_file_as_bytes(path).size()}
	_oracles.append({"kind": kind, "point": point, "files": entries})

class CallbackCodec extends Node:
	var callback: Callable
	var source: Node
	func reset() -> void: pass
	func to_dict() -> Dictionary:
		var work := callback
		callback = Callable()
		if work.is_valid(): work.call()
		return source.to_dict() if source != null else {"value": 1}
	func from_dict(d: Dictionary) -> void:
		if source != null: source.from_dict(d)
		var work := callback
		callback = Callable()
		if work.is_valid(): work.call()

func run(t) -> void:
	var saves: Node = t.autoload("SaveManager")
	var prior: String = saves.save_dir
	t.on_cleanup(func():
		saves.save_dir = prior
		TimeManager.resume_time()
		GameManager.set_process(true))
	for kind in ["unregister", "free", "detach", "host_unregister", "host_free"]:
		await _mother(t, saves, kind)
	for kind in ["reattach", "toast_reattach", "direct", "disk", "backup", "failed", "toast_load"]:
		await _failure_callback(t, saves, kind)
	for kind in ["section", "farm", "apply"]:
		await _codec_callback(t, saves, kind)
	await _title(t, saves)
	var audit := FileAccess.open("user://world-save-departure-oracles.json", FileAccess.WRITE)
	audit.store_string(JSON.stringify(_oracles, "	", true, true))

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
	if kind.begins_with("host_"): t.check(kind + "_real_host_authority", world.session.host(24564, 4, "127.0.0.1") == OK and world.session.is_host() and NetAuthority.can_write())
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
	_audit(kind, "before", saves)
	var saved_world: Dictionary = world.to_dict()
	# The body moves after the last capture; retained profile/pending poses are
	# legitimate but stale and must not substitute for the departed final body.
	pose += Vector2(4, 2)
	body.global_position = pose
	saves.pending_world = saved_world.duplicate(true)
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
		elif kind in ["unregister", "host_unregister"]: observed.append(world._unregister_player(body))
		else: body.free()
	var on_failed := func(slot, code):
		_audit(kind, "save_failed", saves)
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
	_audit(kind, "unwind", saves)
	t.check(kind + "_whole_unwind_no_corruption", _files(saves) == files and not ui.is_open() and not marker._busy)
	await t.frames(2)
	t.check(kind + "_physical_departure_real", (weak_body.get_ref() == null if kind != "detach" else is_instance_valid(body) and not body.is_inside_tree()) and PlayerRegistry.by_id(&"p0") == null and PlayerRegistry.by_id(&"p1") == other)
	t.check(kind + "_p1_unchanged", p1 == PlayerRegistry.peek_state(&"p1") and p1.to_dict() == p1_before)
	# Direct consumers get explicit refusal, with no error or fabricated world.
	t.check(kind + "_direct_serializer_refuses", world.to_dict() == null)
	t.check(kind + "_manual_refusal_no_corruption", not saves.save_game(0) and saves.last_error.get("code") == "gather" and _files(saves) == files)
	_audit(kind, "manual_refusal", saves)
	PlayerRegistry._states.erase(&"p0")
	t.check(kind + "_absent_profile_not_created", saves.gather_payload().is_empty() and PlayerRegistry.peek_state(&"p0") == null and _files(saves) == files)
	PlayerRegistry._states[&"p0"] = p0
	var applied: Array = []
	var on_applied := func(): applied.append(true)
	world.state_applied.connect(on_applied)
	world.from_dict(saved_world)
	world.state_applied.disconnect(on_applied)
	t.check(kind + "_bodyless_world_apply_shared_only", applied == [true] and PlayerRegistry.peek_state(&"p0") == p0 and p1.to_dict() == p1_before and world.to_dict() == null)
	var recovered: Node2D
	if kind == "detach":
		world.add_child(body)
		recovered = body
	else: recovered = _attach(world, pose)
	t.check(kind + "_next_healthy_save", saves.save_game(1) and saves.autosave() and not saves.save_failing and PlayerRegistry.registered_id(recovered) == &"p0")
	var disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(saves.slot_path(saves.AUTO_SLOT)))
	t.check(kind + "_earned_progress_persisted", disk is Dictionary and saves.validate_payload(disk).ok and disk.game.world_flags.get("forest_mother_v1_marked_lamp", -1) == GameManager.total_day() and disk.world.player_pos == [pose.x, pose.y] and saves.validate_payload(disk).payload.players.rows.p1 == expected_p1, "flag=%s pose=%s expected=%s p1=%s expectedp1=%s" % [disk.game.world_flags.get("forest_mother_v1_marked_lamp"), disk.world.player_pos, pose, disk.players.rows.p1, p1_before])
	await t.go_menu()

func _failure_callback(t, saves: Node, kind: String) -> void:
	if not await t.start_world(): return
	TimeManager.pause_time()
	GameManager.set_process(false)
	saves.save_dir = "user://world-save-callback-" + kind
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	GameManager.set_flag(&"forest_mother_version", 1)
	var world: Node = t.world()
	var body: Node2D = t.player()
	var pose: Vector2 = body.global_position
	var profile := PlayerRegistry.peek_state(&"p0")
	var origin: Dictionary = EventBus.interaction_origin()
	var late := LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("departure_late", late, 1000)
	var payload: Dictionary = saves.gather_payload()
	t.check(kind + "_callback_valid_saved_winner", saves.validate_payload(payload).ok and saves.save_game(0) and saves.save_game(0) and saves.autosave())
	if kind == "backup":
		# Valid primary, real late rejection, then the real valid backup wins.
		late.rejects = 1
	var files := _files(saves)
	var entered: Array = []
	var notices: Array = []
	var recovered: Array = []
	var winner: Array = []
	var denials: Array = []
	if kind == "failed": late.callback = func(): denials.append(EventBus.interaction_current(origin))
	var work := func():
		if not entered.is_empty(): return
		entered.append(_files(saves) == files)
		entered.append(MotherStory.has("marked_lamp"))
		if kind in ["reattach", "toast_reattach"]:
			recovered.append(_attach(world, pose))
			if kind == "reattach": entered.append(saves.autosave())
		else:
			if kind == "failed": late.rejects = 1
			entered.append(saves._apply_payload(payload).ok if kind in ["direct", "failed"] else saves.load_game(0))
			entered.append(PlayerRegistry.peek_state(&"p0") == profile)
			entered.append(EventBus.interaction_current(origin))
			winner.append(GameManager.to_dict())
			winner.append(PlayerRegistry.peek_state(&"p0").to_dict())
			winner.append(_files(saves))
	var on_failed := func(_slot, _code):
		if kind not in ["toast_reattach", "toast_load"]: work.call()
	var on_toast := func(_title, _message, category):
		if category == "save" and kind in ["toast_reattach", "toast_load"]: work.call()
	var on_choice := func(action, _data):
		if action == "mother_record": world._unregister_player(body)
	var on_event := func(id, _data):
		if id == &"forest_mother_evidence": notices.append(id)
	var ui: Node = t.first(&"dialogue_ui")
	var marker := MotherEvidenceMarker.new()
	marker.evidence_id = "marked_lamp"
	marker.area = world.area
	world.area.objects.add_child(marker)
	ui.choice_selected.connect(on_choice)
	EventBus.save_failed.connect(on_failed)
	EventBus.notification_posted.connect(on_toast)
	EventBus.game_event.connect(on_event)
	marker.interact(body)
	await t.page_to_choices(ui)
	var choice := {}
	for button in ui._buttons:
		if button.get_meta("choice").get("action") == "mother_record": choice = button.get_meta("choice")
	t.check(kind + "_callback_actual_read_page", not choice.is_empty() and ui._shown == ui._lines.size() and not MotherStory.has("marked_lamp"))
	if not choice.is_empty(): ui._pick(choice)
	ui.choice_selected.disconnect(on_choice)
	EventBus.save_failed.disconnect(on_failed)
	EventBus.notification_posted.disconnect(on_toast)
	EventBus.game_event.disconnect(on_event)
	var retained := kind in ["reattach", "toast_reattach", "failed"]
	t.check(kind + "_callback_reached_before_any_write", entered.size() >= 2 and entered[0] and entered[1])
	if kind == "failed":
		t.check("callback_complete_failed_rollback_continues", entered == [true, true, false, true, true] and late.calls == 2 and PlayerRegistry.peek_state(&"p0") == profile and not saves.network_admission_blocked() and denials == [false, false])
	elif not retained:
		t.check(kind + "_callback_new_winner_revokes", entered == [true, true, true, false, false] and (late.calls == 3 if kind == "backup" else true))
		t.check(kind + "_callback_winner_whole_unwind", winner.size() == 3 and GameManager.to_dict() == winner[0] and PlayerRegistry.peek_state(&"p0").to_dict() == winner[1] and _files(saves) == winner[2])
	else:
		t.check(kind + "_callback_reattach_live", recovered.size() == 1 and PlayerRegistry.registered_id(recovered[0]) == &"p0" and (entered == [true, true, true] if kind == "reattach" else entered == [true, true]))
	t.check(kind + "_callback_earned_vs_replaced", MotherStory.has("marked_lamp") == retained and notices.size() == (1 if retained else 0) and not ui.is_open() and not marker._busy)
	if recovered.is_empty(): recovered.append(_attach(world, pose))
	# A separate current root remains usable after every old facade has unwound.
	t.check(kind + "_callback_next_current_progress", MotherStory.record("map_account") and MotherStory.has("map_account") and saves.autosave() and not saves.save_failing)
	var disk: Dictionary = saves.validate_payload(JSON.parse_string(FileAccess.get_file_as_string(saves.slot_path(saves.AUTO_SLOT)))).payload
	t.check(kind + "_callback_disk_current_only", disk.game.world_flags.has("forest_mother_v1_map_account") and disk.game.world_flags.has("forest_mother_v1_marked_lamp") == retained)
	saves.unregister_section("departure_late")
	late.free()
	await t.go_menu()

func _codec_callback(t, saves: Node, kind: String) -> void:
	if not await t.start_world(): return
	TimeManager.pause_time()
	GameManager.set_process(false)
	saves.save_dir = "user://world-save-codec-" + kind
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	var world: Node = t.world()
	var body: Node2D = t.player()
	var pose: Vector2 = body.global_position
	var saved_world: Dictionary = world.to_dict()
	saves.pending_world = saved_world.duplicate(true)
	t.check(kind + "_codec_healthy_seed", saves.save_game(0) and saves.save_game(0) and saves.autosave())
	var files := _files(saves)
	var codec := CallbackCodec.new()
	t.tree.root.add_child(codec)
	var farm: Node = world.farm
	var recovered: Array = []
	codec.callback = func():
		world._unregister_player(body)
		if kind == "apply": recovered.append(_attach(world, pose + Vector2(8, 4)))
	if kind == "section": saves.register_section("departure_gather", codec, 1000)
	else:
		codec.source = farm
		world.farm = codec
	if kind == "apply":
		world.from_dict(saved_world)
		t.check("apply_codec_cannot_project_new_body", recovered.size() == 1 and recovered[0].global_position == pose + Vector2(8, 4))
	else:
		t.check(kind + "_codec_gather_refused_not_pending", not saves.autosave() and saves.last_error.get("code") == "gather" and _files(saves) == files)
	if kind == "section": saves.unregister_section("departure_gather")
	else: world.farm = farm
	codec.free()
	if recovered.is_empty(): recovered.append(_attach(world, pose))
	t.check(kind + "_codec_recovery", saves.autosave() and saves.last_error.is_empty())
	await t.go_menu()

func _title(t, saves: Node) -> void:
	await t.go_menu()
	saves.save_dir = "user://world-save-title"
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	saves.pending_world = {"v": 1, "area": "farm", "player_pos": [123, 456], "hotbar": {"slots": [], "selected": 0}, "placed": [], "area_flags": {"farm": {"retained": true}}}
	var pending: Dictionary = saves.pending_world.duplicate(true)
	t.check("title_pending_world_save_compatible", PlayerRegistry.world() == null and saves.save_game(0) and saves.gather_payload().world == pending and saves.pending_world == pending)
	saves.pending_world = {}
	t.check("title_empty_world_save_compatible", saves.save_game(1) and saves.gather_payload().world == {})
