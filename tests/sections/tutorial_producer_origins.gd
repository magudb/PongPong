extends RefCounted
const SECTION := "tutorial_producer_origins"
const TIMEOUT_S := 180.0
const Runner := preload("res://scripts/farm/steading/tutorial/tutorial_runner.gd")

func run(t) -> void:
	await _successor(t, "talk")
	await _successor(t, "hold")
	await _successor(t, "attachment")
	await _leave_successor(t)
	await _admission_hold(t)
	await _intro_body_completion(t)
	await _intro_area_completion(t)
	for mode in ["body", "area"]: await _root_attachment(t, mode)
	for mode in ["direct", "disk", "backup", "failed", "incomplete"]:
		await _post_reentry(t, mode)

class PostQuery extends RefCounted:
	var area_id := "farm"
	var callback: Callable
	var point := Vector2.ZERO
	func post_ground(_post: StringName) -> Vector2:
		if callback.is_valid(): callback.call()
		return point

func _post_reentry(t, mode: String) -> void:
	if not await t.start_world(): return
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	var saves: Node = t.autoload("SaveManager")
	var prior: String = saves.save_dir
	saves.save_dir = "user://tutorial-post-" + mode
	var late := preload("res://tests/sections/multiplayer_rollback.gd").LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("tutorial_post_late", late, 1000)
	t.check(mode + "_post_real_disk_precondition", saves.save_game(0) and not FileAccess.file_exists(saves.backup_path(0)))
	if mode == "backup":
		t.check("backup_post_real_backup_precondition", saves.save_game(0) and FileAccess.file_exists(saves.backup_path(0)))
		var file := FileAccess.open(saves.slot_path(0), FileAccess.WRITE)
		file.store_string("invalid primary")
		file.close()
	var session := Runner.new()
	session.world = t.world()
	session.origin = EventBus.interaction_origin(&"p0")
	var profile := PlayerRegistry.peek_state(&"p0")
	var stamp: Array = saves._save_owner_stamp()
	var query := PostQuery.new()
	var entered: Array = []
	var spawns: Array = []
	var barriers: Array = []
	var final_barriers: Array = []
	late.callback = func(): barriers.append(not EventBus.interaction_current(session.origin))
	var failed := func(title, _message, kind):
		if kind == "save" and title == TranslationServer.translate("NOTIF_LOAD_FAILED_TITLE"):
			final_barriers.append(not saves.continuation_available(profile) and not EventBus.interaction_current(session.origin))
	query.callback = func():
		if not entered.is_empty(): return
		entered.append(true)
		late.rejects = 1 if mode == "failed" else (2 if mode == "incomplete" else 0)
		entered.append(saves._apply_payload(saves.gather_payload()).ok if mode == "direct" else saves.load_game(0))
	var added := func(node):
		if node is Npc2D and node.npc_id == &"postman_pip" and node.guest: spawns.append(weakref(node))
	var step := func(id, payload):
		if id == &"tutorial_step" and payload.kind == "dialogue": session.skip()
	# Exercise the existing facade's real virtual post callback first in its
	# registered list; restore every real director, not a replacement world.
	var directors: Array = NpcDirector._active.duplicate()
	for director in directors: NpcDirector.unregister(director)
	NpcDirector.register(query)
	t.tree.node_added.connect(added)
	EventBus.game_event.connect(step)
	EventBus.notification_posted.connect(failed)
	await session.play()
	EventBus.notification_posted.disconnect(failed)
	EventBus.game_event.disconnect(step)
	t.tree.node_added.disconnect(added)
	NpcDirector.unregister(query)
	for director in directors:
		if is_instance_valid(director): NpcDirector.register(director)
	t.check(mode + "_post_actual_query_reentry", entered == [true, mode in ["direct", "disk", "backup"]])
	t.check(mode + "_post_no_stale_actor_admission", spawns.size() == (1 if mode == "failed" else 0))
	t.check(mode + "_post_earned_or_revoked_terminal", bool(GameManager.get_flag(&"first_morning_done", false)) == (mode == "failed") and QuestManager.is_active(&"forste_dage") == (mode == "failed"))
	t.check(mode + "_post_exact_model_authority", (EventBus.interaction_current(session.origin) and PlayerRegistry.peek_state(&"p0") == profile and saves._save_owner_stamp() == stamp and barriers == [true, true] and final_barriers == [true]) if mode == "failed" else not EventBus.interaction_current(session.origin))
	saves.unregister_section("tutorial_post_late")
	late.free()
	saves.save_dir = prior
	await t.frames(3)
	await t.go_menu()

func _leave_successor(t) -> void:
	if not await t.start_world(): return
	var session := Runner.new()
	session.world = t.world()
	session.origin = EventBus.interaction_origin(&"p0")
	var done: Array = []
	var entered: Array = []
	var successor: Array = []
	var references: Array = []
	var watch := func():
		if not session.trace.has("npc_leave") or not references.is_empty(): return
		var walking: Variant = session.actors.get("postman_pip")
		if not is_instance_valid(walking) or walking._walk_ticket == null: return
		references.append(weakref(walking))
		walking._walk_ticket.finished.connect(func(completed):
			entered.append(completed)
			walking.event_walk_to(walking.global_position, 100).connect(func(arrived): successor.append(arrived)), CONNECT_ONE_SHOT)
	t.tree.physics_frame.connect(watch)
	_launch(session, done)
	var ui: Node = t.first(&"dialogue_ui")
	var deadline := Time.get_ticks_msec() + 20000
	while entered.is_empty() and done.is_empty() and Time.get_ticks_msec() < deadline:
		if ui.is_open():
			ui._typing = false
			ui.get_node("%NextButton").pressed.emit()
		await t.frames(2)
	t.tree.physics_frame.disconnect(watch)
	t.check("leave_real_authored_walk_enabled", references.size() == 1 and references[0].get_ref() != null and references[0].get_ref().is_physics_processing())
	await t.until(func(): return not successor.is_empty() and done == [true], 6)
	await t.physics(3)
	var actor: Variant = references[0].get_ref() if references.size() == 1 else null
	t.check("leave_new_walk_completes_naturally", entered == [true] and successor == [true])
	t.check("leave_new_activity_not_retired_by_old_route", is_instance_valid(actor) and actor.is_inside_tree() and not actor.is_queued_for_deletion())
	t.check("leave_old_producer_earned_terminal", done == [true] and bool(GameManager.get_flag(&"first_morning_done", false)) and QuestManager.is_active(&"intro_lottery") and QuestManager.is_active(&"forste_dage"), str({"done":done,"trace":session.trace,"skipped":session.skipped,"active":session.active,"good":session._good(),"actor":is_instance_valid(actor),"walking":actor._event_walking if is_instance_valid(actor) else null,"held":actor._held if is_instance_valid(actor) else null,"entered":entered,"successor":successor,"flags":GameManager.world_flags}))
	if is_instance_valid(actor): actor.queue_free()
	await t.go_menu()

func _root_attachment(t, mode: String) -> void:
	if not await t.start_world(): return
	var world: Node = t.world()
	var old_body: Node2D = t.player()
	var area: Node = world.area
	var session := Runner.new()
	session.world = world
	session.origin = EventBus.interaction_origin(&"p0")
	var entered: Array = []
	var step := func(id, payload):
		if id != &"tutorial_step" or payload.kind != "npc_enter" or not entered.is_empty(): return
		entered.append(true)
		if mode == "body":
			var at: Vector2 = old_body.global_position
			world._unregister_player(old_body)
			var next: Node2D = world._make_player()
			world._register_player(next, 0, 1)
			world.add_child(next)
			next.enter_area(area, at)
		else:
			var parent: Node = area.get_parent()
			parent.remove_child(area)
			parent.add_child(area)
	EventBus.game_event.connect(step)
	var done: Array = []
	_launch(session, done)
	EventBus.game_event.disconnect(step)
	var ui: Node = t.first(&"dialogue_ui")
	t.check(mode + "_root_attachment_actual_callback", entered == [true] and area == world.area and area.is_inside_tree())
	t.check(mode + "_old_root_cannot_present_on_successor", not ui.is_open())
	session.skip()
	await t.frames(4)
	t.check(mode + "_old_model_vs_physical_terminal", done == [true] and bool(GameManager.get_flag(&"first_morning_done", false)) == (mode == "body"))
	if mode == "area":
		var current := Runner.new()
		current.world = world
		current.origin = EventBus.interaction_origin(&"p0")
		current.skipped = true
		await current.play()
		t.check("area_new_root_after_reattachment_progress", bool(GameManager.get_flag(&"first_morning_done", false)) and QuestManager.is_active(&"intro_lottery") and QuestManager.is_active(&"forste_dage"))
	await t.go_menu()

func _admission_hold(t) -> void:
	if not await t.start_world(): return
	var session := Runner.new()
	session.world = t.world()
	session.origin = EventBus.interaction_origin(&"p0")
	var entered: Array = []
	var actors: Array = []
	var listener := func(id, _module):
		if id != &"postman_pip" or not entered.is_empty(): return
		entered.append(true)
		var actor: Variant = session.actors.get("postman_pip")
		actors.append(weakref(actor))
		actor.event_begin()
		actor.event_clip("walk")
	EventBus.dialogue_started.connect(listener)
	var done: Array = []
	_launch(session, done)
	EventBus.dialogue_started.disconnect(listener)
	var ui: Node = t.first(&"dialogue_ui")
	t.check("admission_public_started_reached", entered == [true])
	t.check("admission_new_hold_prevents_obsolete_page", not ui.is_open())
	# Cancel only this tutorial's exact request, not the new actor activity.
	session.skip()
	await t.frames(4)
	var actor: Variant = actors[0].get_ref() if actors.size() == 1 else null
	t.check("admission_new_hold_survives_old_talk_cleanup", is_instance_valid(actor) and actor._held and actor._event and not actor.is_talking and actor._act == &"walk")
	t.check("admission_original_waiter_terminal", done == [true] and bool(GameManager.get_flag(&"first_morning_done", false)) and t.player().state == PlayerBody2D.S.FREE)
	if is_instance_valid(actor):
		actor.event_end()
		actor.queue_free()
	await t.go_menu()

func _intro_body_completion(t) -> void:
	if not await t.start_world("ghost"): return
	var body: Node = t.player()
	var ui: Node = t.first(&"dialogue_ui")
	var done: Array = []
	_intro(t.world(), done)
	var request: RefCounted = ui._request
	t.check("intro_body_earned_actual_letter", request != null and ui.is_open() and ui._lines.any(func(row): return row.get("text_key") == "DLG_KING_LETTER"))
	var left: Array = []
	var closed := func():
		if not left.is_empty(): return
		left.append(true)
		body.get_parent().remove_child(body)
		body.free()
	ui.closed.connect(closed)
	for i in 12:
		if ui._request != request or not ui.is_open(): break
		ui._typing = false
		ui.get_node("%NextButton").pressed.emit()
		await t.frames(2)
	ui.closed.disconnect(closed)
	t.check("intro_body_loss_preserves_earned_seen", left == [true] and done == [true] and request.result.get("completed", false) and bool(GameManager.get_flag(&"intro_letter_seen", false)))
	t.check("intro_body_loss_no_optional_reaction", not ui.is_open() and ui._request == null)
	await t.go_menu()

func _intro_area_completion(t) -> void:
	if not await t.start_world("ghost"): return
	var ui: Node = t.first(&"dialogue_ui")
	var area: Node = t.world().area
	var done: Array = []
	_intro(t.world(), done)
	var request: RefCounted = ui._request
	var moved: Array = []
	var closed := func():
		if not moved.is_empty(): return
		moved.append(request.result.get("completed", false))
		var parent: Node = area.get_parent()
		parent.remove_child(area)
		parent.add_child(area)
	ui.closed.connect(closed)
	for i in 12:
		if ui._request != request or not ui.is_open(): break
		ui._typing = false
		ui.get_node("%NextButton").pressed.emit()
		await t.frames(2)
	ui.closed.disconnect(closed)
	t.check("intro_actual_completed_before_area_departure", moved == [true] and area.is_inside_tree() and t.world().area == area)
	t.check("intro_retired_area_no_optional_reaction", not ui.is_open() and done == [true])
	ui.close()
	await t.frames(2)
	t.check("intro_retired_area_preserves_preterminal_earned_seen", request.result.get("completed", false) and done == [true] and bool(GameManager.get_flag(&"intro_letter_seen", false)))
	await t.go_menu()

func _intro(world: Node, done: Array) -> void:
	await preload("res://scripts/world2d/intro_sequence.gd").letter(world)
	done.append(true)

func _successor(t, mode: String) -> void:
	if not await t.start_world(): return
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	var world: Node = t.world()
	var body: Node = t.player()
	body.set_physics_process(true)
	var ui: Node = t.first(&"dialogue_ui")
	var session := Runner.new()
	session.world = world
	session.origin = EventBus.interaction_origin(&"p0")
	var entered: Array = []
	var actor_ref: Array = []
	var requests: Array = []
	var next_parent := Node2D.new()
	world.area.objects.add_child(next_parent)
	var listener := func(id, _payload):
		if id != &"tutorial_finished" or not entered.is_empty(): return
		entered.append(true)
		var actor: Variant = session.actors.get("postman_pip")
		if not is_instance_valid(actor): return
		actor_ref.append(weakref(actor))
		if mode == "talk":
			actor.interact(body)
			requests.append(ui._request)
		elif mode == "hold":
			actor.event_begin()
		else:
			actor.reparent(next_parent)
			actor.event_begin()
	EventBus.game_event.connect(listener)
	var done: Array = []
	_launch(session, done)
	t.check(mode + "_authored_initial_page", ui.is_open() and ui._speaker.get("id") == "postman_pip")
	t.tap_key(KEY_ESCAPE)
	await t.frames(8)
	EventBus.game_event.disconnect(listener)
	t.check(mode + "_authored_skip_completes_earned_model", entered == [true] and done == [true] and bool(GameManager.get_flag(&"first_morning_done", false)) and bool(GameManager.get_flag(&"intro_letter_seen", false)) and QuestManager.is_active(&"intro_lottery") and QuestManager.is_active(&"forste_dage"))
	var actor: Variant = actor_ref[0].get_ref() if actor_ref.size() == 1 else null
	t.check(mode + "_new_same_actor_survives_old_cleanup", is_instance_valid(actor) and actor.is_inside_tree() and not actor.is_queued_for_deletion())
	var talking: bool = is_instance_valid(actor) and actor.is_talking and actor._held
	var held: bool = is_instance_valid(actor) and actor._event and actor._held
	t.check(mode + "_successor_exact_authority_preserved", (talking and requests.size() == 1 and requests[0] != null and ui._request == requests[0] and requests[0].result.is_empty()) if mode == "talk" else (held and (mode != "attachment" or actor.get_parent() == next_parent)))
	# Every predicate is emitted on baseline as well as candidate. No repair of
	# actor state/timers: finish the actual successor through its real UI API.
	if mode == "talk" and requests.size() == 1 and requests[0] != null:
		ui.close_request(requests[0])
	elif is_instance_valid(actor):
		actor.event_end()
	await t.physics(3)
	t.check(mode + "_successor_terminal_releases_body", body.state == PlayerBody2D.S.FREE and not GameManager.is_modal_open())
	var before: Vector2 = body.global_position
	t.hold(&"move_left")
	await t.physics(8)
	t.release(&"move_left")
	await t.physics(2)
	t.check(mode + "_enabled_natural_body_progress", body.is_physics_processing() and body.global_position.distance_to(before) > 1)
	if is_instance_valid(actor): actor.queue_free()
	await t.go_menu()

func _launch(session: RefCounted, done: Array) -> void:
	await session.play()
	done.append(true)
