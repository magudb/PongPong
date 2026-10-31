extends RefCounted
const SECTION := "tutorial_hint_origins"
const TIMEOUT_S := 180.0
const Runner := preload("res://scripts/farm/steading/tutorial/tutorial_runner.gd")
const FIELDS := ["player_id", "peer_id", "name", "character_type", "character_skin", "area", "player_pos", "hotbar", "half_hearts", "max_half_hearts", "stamina", "max_stamina", "oil", "max_oil", "gold", "inventory", "equipment", "arsenal", "arsenal_orphans", "quests", "flags", "owed", "wardrobe"]

func run(t) -> void:
	for mode in ["empty", "primed", "ordinary"]: await _delivery(t, mode)
	for mode in ["same", "failed", "fresh"]: await _reentry(t, mode)

func _freeze(t) -> void:
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))

func _guest(world: Node) -> RefCounted:
	var body: Node2D = world._make_player()
	world._register_player(body, 1, 2)
	world.add_child(body)
	body.enter_area(world.area, world.player.global_position)
	return PlayerRegistry.peek_state(&"p1")

# Capture ALL live profile fields, not just the serialized subset. Retain each
# original nested container so equal-valued replacement cannot hide alias loss.
func _capture(profile: RefCounted) -> Dictionary:
	var values: Dictionary = {}
	var refs: Array = []
	for key in FIELDS:
		var value: Variant = profile.get(key)
		values[key] = value.duplicate(true) if value is Array or value is Dictionary else value
		_refs(value, [key], refs)
	return {"profile": profile, "values": values, "refs": refs}

func _refs(value: Variant, path: Array, out: Array) -> void:
	if not (value is Array or value is Dictionary): return
	out.append([path, value])
	for key in (value.keys() if value is Dictionary else range(value.size())):
		_refs(value[key], path + [key], out)

func _values_same(saved: Dictionary) -> bool:
	if PlayerRegistry.peek_state(&"p1") != saved.profile: return false
	for key in FIELDS:
		if saved.profile.get(key) != saved.values[key]: return false
	return true

func _changed(saved: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in FIELDS:
		if saved.profile.get(key) != saved.values[key]: out[key] = [saved.values[key], saved.profile.get(key)]
	return out

func _aliases_same(saved: Dictionary) -> bool:
	if PlayerRegistry.peek_state(&"p1") != saved.profile: return false
	for row in saved.refs:
		var value: Variant = saved.profile
		for key in row[0]:
			if value is Object: value = value.get(key)
			elif value is Dictionary and value.has(key): value = value[key]
			elif value is Array and key is int and key < value.size(): value = value[key]
			else: return false
		if not is_same(value, row[1]): return false
	return true

func _launch(session: RefCounted, done: Array) -> void:
	await session.play()
	done.append(true)

func _delivery(t, mode: String) -> void:
	if not await t.start_world(): return
	_freeze(t)
	var world: Node = t.world()
	var profile := _guest(world)
	if mode == "primed":
		PlayerRegistry.for_player(&"p1", func():
			EconomyManager.from_dict(EconomyManager.to_dict())
			QuestManager.from_dict(QuestManager.to_dict()))
	var before := _capture(profile)
	var hints: Node = world.get_node("FarmTutorialHints")
	t.check(mode + "_actual_attached_polling_and_guest_precondition", hints is TutorialHints and hints.world == world and hints.is_processing() and (not profile.quests.is_empty() if mode == "primed" else profile.quests.is_empty()))
	var requests: Array = []
	var shown: Array = []
	var whispers: Array = []
	var terminals: Array = []
	var order: Array = []
	var recipients: Array = []
	var phases: Array = []
	var weather_watch := func(_v): phases.append(["weather", profile.quests.is_empty()])
	var clock_watch := func(_h, _m): phases.append(["clock", profile.quests.is_empty()])
	var flag_watch := func(key, _v): phases.append([str(key), profile.quests.is_empty()])
	var accepted_watch := func(_pid, key): phases.append([str(key), profile.quests.is_empty()])
	EventBus.weather_changed.connect(weather_watch)
	EventBus.time_of_day_changed.connect(clock_watch)
	EventBus.flag_changed.connect(flag_watch)
	EventBus.quest_accepted.connect(accepted_watch)
	var notice := func(id, payload):
		if id == &"tutorial_step": order.append(str(payload.kind))
		if id == &"tutorial_hint_request":
			requests.append(payload.duplicate(true))
			order.append("request")
			recipients.append(PlayerRegistry.acting_id())
		if id == &"tutorial_hint_shown": shown.append(payload.duplicate(true))
		if id == &"tutorial_finished":
			terminals.append(payload.duplicate(true))
			order.append("finished")
	var whisper := func(text): whispers.append(text)
	EventBus.game_event.connect(notice)
	EventBus.whisper_requested.connect(whisper)
	var session := Runner.new()
	session.world = world
	session.origin = EventBus.interaction_origin(&"p0")
	session.skipped = mode != "ordinary"
	var done: Array = []
	var restored: Array = []
	PlayerRegistry.for_player(&"p1", func():
		_launch(session, done)
		restored.append(PlayerRegistry.acting_id()))
	if mode == "ordinary":
		var ui: Node = t.first(&"dialogue_ui")
		await t.until_game(func():
			if ui.is_open():
				ui._typing = false
				ui.get_node("%NextButton").pressed.emit()
			return done == [true], 30)
	t.check(mode + "_authored_host_quests_terminal_and_caller", done == [true] and restored == [&"p1"] and PlayerRegistry.acting_id() == &"p0" and QuestManager.is_active(&"intro_lottery") and QuestManager.is_active(&"forste_dage") and bool(GameManager.get_flag(&"first_morning_done", false)))
	t.check(mode + "_authored_hoe_queued_or_already_delivered", hints.queued.has("hoe") or shown == [{"id":"hoe"}])
	t.check(mode + "_whole_guest_values_at_unwind", _values_same(before), str({"changed":_changed(before),"phases":phases}))
	t.check(mode + "_original_guest_alias_graph_at_unwind", _aliases_same(before))
	# Polling stays enabled throughout; deterministic public tick only advances
	# the real consumer's monotonic cadence, without forging a hint flag.
	hints.tick(maxf(hints.last_shown + TutorialHints.GAP, float(Time.get_ticks_msec()) / 1000.0))
	await t.frames(3)
	hints.tick(hints.last_shown + TutorialHints.GAP)
	t.check(mode + "_public_request_shown_whisper_exactly_once", requests == [{"id":"hoe"}] and shown == [{"id":"hoe"}] and whispers.size() == 1 and terminals == [{"skipped":mode != "ordinary"}] and bool(GameManager.get_flag(&"tut_hint_hoe", false)))
	t.check(mode + "_public_authored_order_and_recipient", recipients == [&"p0"] and order == (["npc_enter", "dialogue", "dialogue", "quest_accept", "quest_accept", "dialogue", "npc_leave", "hint", "request", "finished"] if mode == "ordinary" else ["request", "finished"]))
	t.check(mode + "_guest_values_and_aliases_after_natural_poll", _values_same(before) and _aliases_same(before))
	EventBus.whisper_requested.disconnect(whisper)
	EventBus.game_event.disconnect(notice)
	EventBus.weather_changed.disconnect(weather_watch)
	EventBus.time_of_day_changed.disconnect(clock_watch)
	EventBus.flag_changed.disconnect(flag_watch)
	EventBus.quest_accepted.disconnect(accepted_watch)
	await t.go_menu()

func _reentry(t, mode: String) -> void:
	if not await t.start_world(): return
	_freeze(t)
	var world: Node = t.world()
	_guest(world)
	# Save loaders legitimately normalize empty equipment/logs. Establish their
	# real preimage BEFORE the lifecycle control, separate from empty-row RED.
	PlayerRegistry.for_player(&"p1", func():
		EconomyManager.from_dict(EconomyManager.to_dict())
		QuestManager.from_dict(QuestManager.to_dict()))
	var saves: Node = t.autoload("SaveManager")
	var old_dir: String = saves.save_dir
	saves.save_dir = "user://hint-reentry-" + mode
	var late := preload("res://tests/sections/multiplayer_rollback.gd").LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("hint_late", late, 1000)
	t.check(mode + "_actual_disk_no_backup", saves.save_game(0) and not FileAccess.file_exists(saves.backup_path(0)))
	var session := Runner.new()
	session.world = world
	session.origin = EventBus.interaction_origin(&"p0")
	session.skipped = true
	var origin: Dictionary = session.origin
	var profile := PlayerRegistry.peek_state(&"p0")
	var stamp: Array = saves._save_owner_stamp()
	var before := _capture(PlayerRegistry.peek_state(&"p1"))
	var hints: Node = world.get_node("FarmTutorialHints")
	var entered: Array = []
	var barriers: Array = []
	var final_barriers: Array = []
	var notices: Array = []
	var terminals: Array = []
	var fresh: Array = []
	var after_apply: Array = []
	late.callback = func(): barriers.append(not EventBus.interaction_current(origin))
	var failure := func(title, _message, kind):
		if kind == "save" and title == TranslationServer.translate("NOTIF_LOAD_FAILED_TITLE"):
			final_barriers.append(not saves.continuation_available(profile) and not EventBus.interaction_current(origin))
	var listener := func(id, payload):
		if id == &"tutorial_finished": terminals.append(payload.duplicate(true))
		if id != &"tutorial_hint_request": return
		notices.append(payload.duplicate(true))
		if not entered.is_empty(): return
		entered.append(true)
		entered.append(not hints.queued.has("hoe"))
		late.rejects = 1 if mode == "failed" else 0
		entered.append(saves.load_game(0) if mode == "failed" else saves._apply_payload(saves.gather_payload()).ok)
		after_apply.append(_capture(PlayerRegistry.peek_state(&"p1")))
		if mode == "fresh":
			var current := Runner.new()
			current.world = world
			current.origin = EventBus.interaction_origin(&"p0")
			current.skipped = true
			_launch(current, fresh)
	EventBus.game_event.connect(listener)
	EventBus.notification_posted.connect(failure)
	var done: Array = []
	var restored: Array = []
	PlayerRegistry.for_player(&"p1", func():
		_launch(session, done)
		restored.append(PlayerRegistry.acting_id()))
	EventBus.notification_posted.disconnect(failure)
	t.check(mode + "_public_first_real_lifecycle_and_restore", entered == [true, true, mode != "failed"] and done == [true] and restored == [&"p1"] and PlayerRegistry.acting_id() == &"p0")
	t.check(mode + "_retained_original_authority", (EventBus.interaction_current(origin) and PlayerRegistry.peek_state(&"p0") == profile and saves._save_owner_stamp() == stamp and barriers == [true, true] and final_barriers == [true] and _values_same(before) and _aliases_same(before)) if mode == "failed" else not EventBus.interaction_current(origin))
	t.check(mode + "_only_eligible_hint_and_terminal", hints.queued.has("hoe") == (mode != "same") and bool(GameManager.get_flag(&"first_morning_done", false)) == (mode != "same") and terminals == ([] if mode == "same" else [{"skipped":true}]) and fresh == ([true] if mode == "fresh" else []) and notices.size() == (2 if mode == "fresh" else 1))
	t.check(mode + "_post_callback_guest_graph_not_adopted", after_apply.size() == 1 and _values_same(after_apply[0]) and _aliases_same(after_apply[0]))
	# A live 3Hz poll is not guaranteed within four render frames. Observe the
	# actual consumer with its original cadence still enabled, not a flag write.
	await t.until_game(func(): return bool(GameManager.get_flag(&"tut_hint_hoe", false)) == (mode != "same"), 2.0)
	await t.seconds(0.5)
	await t.frames(4)
	t.check(mode + "_later_poll_and_retained_origin", bool(GameManager.get_flag(&"tut_hint_hoe", false)) == (mode != "same") and EventBus.interaction_current(origin) == (mode == "failed"))
	EventBus.game_event.disconnect(listener)
	saves.unregister_section("hint_late")
	late.free()
	saves.save_dir = old_dir
	await t.go_menu()
