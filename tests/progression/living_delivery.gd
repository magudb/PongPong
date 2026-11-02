extends RefCounted
## Fixture grants prerequisite stock; real Npc2D initial meeting performs delivery.
## Headless actor/API integration, not keyboard/travel acceptance.
const Q := &"dark_forest_mining"
const NPC := "smith_thorin"
const NEEDS := {"iron_ore": 6, "amethyst": 2}

static func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var sm: Node = t.autoload("SocialManager")
	var bus: Node = t.autoload("EventBus")
	var saves: Node = t.autoload("SaveManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	var bodies: Array = []
	for slot in [1, 2]:
		var body := PlayerStub2D.new()
		t.world()._register_player(body, slot, slot + 1)
		t.world().add_child(body)
		bodies.append(body)
	for pid in [&"p0", &"p1", &"p2"]:
		PlayerRegistry.for_player(pid, func():
			t.expect(qm.accept_quest(Q), "living fixture accepts " + str(pid))
			eco.add_item(&"iron_ore", 8)
			eco.add_item(&"amethyst", 4)
			qm.refresh_objectives()
			bus.zone_entered.emit(&"dark_forest")
			load("res://tests/progression/mining_deliveries.gd")._ready_delivery(t, qm, eco, Q, NEEDS, "living_" + str(pid)))
	await t.frames(3)
	var before := {}
	for pid in [&"p0", &"p1", &"p2"]:
		before[pid] = load("res://tests/progression/mining_deliveries.gd")._owner_state(t, pid)
	var smith := Npc2D.create({"id": NPC, "wander": "0"})
	smith.area = t.world().area
	t.world().area.objects.add_child(smith)
	# Each refusal begins with a fully eligible target and owned stock.
	var empty_living: Dictionary = sm.living_snapshot() if sm.has_method("living_snapshot") else {}
	var forged := PlayerStub2D.new()
	forged.player_id = &"p1"
	t.world().add_child(forged)
	smith.is_talking = true
	smith._talk_player = forged
	bus.npc_meeting_started.emit(smith)
	t.check("forged_registered_id_not_help", _memories(sm, &"p1").is_empty() and load("res://tests/progression/mining_deliveries.gd")._owner_state(t, &"p1") == before[&"p1"])
	forged.queue_free()
	var departed: Node = bodies[0]
	t.world()._unregister_player(departed)
	smith._talk_player = departed
	bus.npc_meeting_started.emit(smith)
	t.check("departed_body_not_help", _memories(sm, &"p1").is_empty() and load("res://tests/progression/mining_deliveries.gd")._owner_state(t, &"p1") == before[&"p1"])
	var replacement := PlayerStub2D.new()
	t.world()._register_player(replacement, 1, 2)
	t.world().add_child(replacement)
	bodies[0] = replacement
	smith.is_talking = false
	smith._talk_player = null
	PlayerRegistry.for_player(&"p1", func(): eco.remove_item(&"amethyst", 3))
	var short_inventory: Dictionary = PlayerRegistry.for_player(&"p1", func(): return eco.to_dict().duplicate(true))
	PlayerRegistry.for_player(&"p2", func(): smith.interact(bodies[0]))
	t.check("missing_last_item_no_memory_or_partial_cost", _memories(sm, &"p1").is_empty() and PlayerRegistry.for_player(&"p1", func(): return eco.to_dict() == short_inventory and qm.is_active(Q) and not qm.get_objective_progress(Q, &"return_to_smith").get("done", false)))
	await load("res://tests/progression/mining_deliveries.gd")._close(t)
	PlayerRegistry.for_player(&"p1", func(): eco.add_item(&"amethyst", 3))
	if sm.has_method("living_snapshot"):
		t.check("refusals_no_living_rows", sm.living_snapshot() == empty_living)
	var directory_before: String = saves.save_dir
	saves.save_dir = "user://living-delivery-before"
	t.check("save_immediately_before_receipt", saves.save_game(0) and saves.load_game(0) and _memories(sm, &"p1").is_empty())
	if not await resume_loaded_world(t, "pre_receipt"): return
	# The pending-only load replaced profiles, not physical attachments (D09).
	# Admit genuinely new bodies/NPC in the fresh World; never rebind the old ones.
	bodies.clear()
	for slot in [1, 2]:
		var body := PlayerStub2D.new()
		t.world()._register_player(body, slot, slot + 1)
		t.world().add_child(body)
		bodies.append(body)
	smith = Npc2D.create({"id": NPC, "wander": "0"})
	smith.area = t.world().area
	t.world().area.objects.add_child(smith)
	saves.save_dir = directory_before
	# Load normalizes empty legacy equipment slots. Take the isolation baseline
	# after that pre-receipt roundtrip, not before the independent load fixture.
	for pid in [&"p0", &"p1", &"p2"]:
		before[pid] = load("res://tests/progression/mining_deliveries.gd")._owner_state(t, pid)
	var observer_directory: String = saves.save_dir
	saves.save_dir = "user://living-observer-saves"
	var observations: Array = []
	var observe := func(kind: String):
		var payload: Dictionary = saves.gather_payload()
		var slot := 0 if kind == "objective" else (1 if kind == "gold" else 2)
		var wrote: bool = saves.save_game(slot)
		var disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(saves.slot_path(slot))) if wrote else {}
		var memory: Array = _memories(sm, &"p1")
		observations.append({"kind": kind, "saved": wrote, "disk_living": disk.get("social", {}).get("living", {}), "disk_owner": disk.get("players", {}).get("rows", {}).get("p1", {}), "memory": memory.duplicate(true), "social": payload.get("social", {}), "stock": PlayerRegistry.for_player(&"p1", func(): return {"iron_ore": eco.count_item(&"iron_ore"), "amethyst": eco.count_item(&"amethyst")})})
		# Source capability must already be closed before public observers.
		if sm.has_method("living_record_delivery"):
			t.check("observer_" + kind + "_source_closed", not sm.living_record_delivery(qm).get("ok", false))
		bus.npc_meeting_started.emit(smith)
	var objective := func(pid, q, obj, _n, _target):
		if q == Q and obj == &"return_to_smith":
			t.check("memory_objective_actor", pid == &"p1")
			observe.call("objective")
	var gold := func(pid, _balance, _delta):
		if pid == &"p1": observe.call("gold")
	var inventory := func(pid, _items):
		if pid == &"p1": observe.call("inventory")
	bus.quest_objective_updated.connect(objective)
	bus.gold_changed.connect(gold)
	bus.player_inventory_changed.connect(inventory)
	PlayerRegistry.for_player(&"p2", func(): smith.interact(bodies[0]))
	t.check("committed_physical_help_memory_exists", _memories(sm, &"p1").size() == 1)
	for kind in ["objective", "gold", "inventory"]:
		var category: Array = observations.filter(func(o): return o.kind == kind)
		t.check("observer_category_" + kind + "_present", not category.is_empty())
		t.check("observer_" + kind + "_persisted_progress_and_both_costs", not category.is_empty() and category.all(func(o): return _persisted_delivery_consistent(o.kind, o.disk_owner)), str(category.map(func(o): return o.disk_owner)))
	t.check("memory_before_all_public_observer_saves", observations.size() >= 3 and observations.all(func(o): return o.saved and o.memory.size() == 1 and o.stock == {"iron_ore": 2, "amethyst": 2} and o.social.get("living", {}).get("players", {}).has("p1") and o.disk_living.get("players", {}).get("p1", {}).get("npcs", {}).get(NPC, {}).get("memories", []).size() == 1), str(observations.map(func(o): return {"kind": o.kind, "saved": o.saved, "stock": o.stock, "memories": o.memory.size()})))
	PlayerRegistry.for_player(&"p1", func():
		t.check("memory_preserves_exact_cost_and_reward", qm.is_completed(Q) and eco.gold == int(before[&"p1"].economy.gold) + 600 and eco.count_item(&"iron_ore") == 2 and eco.count_item(&"amethyst") == 2)
		var rewards := LuaData.int_map(LuaData.dict(qm.get_quest_def(Q).get("rewards", {})).get("items", {}))
		for item in rewards:
			t.check("memory_exact_reward_" + str(item), eco.count_item(StringName(item)) == int(rewards[item])))
	bus.quest_objective_updated.disconnect(objective)
	bus.gold_changed.disconnect(gold)
	bus.player_inventory_changed.disconnect(inventory)
	saves.save_dir = observer_directory
	await load("res://tests/progression/mining_deliveries.gd")._close(t)
	for pid in [&"p0", &"p2"]:
		t.check("memory_unrelated_" + str(pid), _memories(sm, pid).is_empty() and load("res://tests/progression/mining_deliveries.gd")._owner_state(t, pid) == before[pid], _differences(before[pid], load("res://tests/progression/mining_deliveries.gd")._owner_state(t, pid)))
	t.check("memory_scope_restored", PlayerRegistry._acting_id == &"")
	if sm.has_method("living_snapshot"):
		var committed: Dictionary = sm.living_snapshot()
		t.check("direct_source_call_refused", not sm.living_record_delivery(qm).get("ok", false))
		bus.game_event.emit(&"lc_interaction_committed", {"npc": NPC, "player_id": "p2", "fulfilled": true})
		bus.dialogue_started.emit(&"smith_thorin", &"smith_thorin")
		bus.npc_meeting_started.emit(smith)
		PlayerRegistry.for_player(&"p2", func(): qm.complete_quest(Q))
		t.check("raw_bus_and_direct_completion_not_help", sm.living_snapshot() == committed)
		smith._begin_followup(bodies[0], {"lines": [{"text_key": "DLG_NEUTRAL"}], "choices": [{"text_key": "REL_TALK_GOODBYE", "action": "close"}]})
		t.check("followup_not_second_help", sm.living_snapshot() == committed)
		await load("res://tests/progression/mining_deliveries.gd")._close(t)
		var directory: String = saves.save_dir
		saves.save_dir = "user://living-delivery"
		t.check("physical_memory_disk_roundtrip", saves.save_game(0) and saves.load_game(0) and sm.living_snapshot() == committed)
		if not await resume_loaded_world(t, "committed_receipt"): return
		saves.save_dir = directory
	if is_instance_valid(smith): smith.queue_free()
	for body in bodies:
		if is_instance_valid(body): t.world()._unregister_player(body)
	gm.clear_config_overrides()

## Preserve the model-only load/apply assertions, then perform the caller's real
## pending World handoff. SceneTree entry does not reset models or reload disk.
## Old body/profile authority remains revoked; all physical consumers reacquire.
static func resume_loaded_world(t, phase: String) -> bool:
	var saves: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SocialManager")
	var old: Node = t.world()
	var old_id: int = old.get_instance_id()
	var rows: Dictionary = PlayerRegistry._states.duplicate()
	var private_rows := {}
	for pid in [&"p1", &"p2"]:
		if rows.has(pid): private_rows[pid] = JSON.stringify(rows[pid].to_dict())
	var living: Dictionary = sm.living_snapshot()
	t.check("handoff_" + phase + "_old_projection_revoked", not gm.lifecycle_busy() and not old.persistence_ready() and old._host_profile != rows.get(&"p0") and not saves.pending_world.is_empty())
	if not await t.change_scene(t.WORLD_SCENE): return false
	var ready: bool = await t.until(func(): return t.world() != null and t.world().get_instance_id() != old_id and t.world().ready_for_play and not gm.lifecycle_busy(), 15.0)
	t.check("handoff_" + phase + "_fresh_scene_consumed_pending", ready and t.world().persistence_ready() and saves.pending_world.is_empty())
	t.check("handoff_" + phase + "_loaded_profiles_and_memory_retained", PlayerRegistry._states.size() == rows.size() and rows.keys().all(func(pid): return PlayerRegistry._states.get(pid) == rows[pid]) and private_rows.keys().all(func(pid): return JSON.stringify(rows[pid].to_dict()) == private_rows[pid]) and sm.living_snapshot() == living)
	return ready

static func _persisted_delivery_consistent(kind: String, owner: Dictionary) -> bool:
	var stock := {"iron_ore": 0, "amethyst": 0}
	for slot in owner.get("inventory", []):
		var id := str(slot.get("id", ""))
		if stock.has(id): stock[id] += int(slot.get("amount", 0))
	if owner.get("id") != "p1" or stock != {"iron_ore": 2, "amethyst": 2}:
		return false
	var quests: Dictionary = owner.get("quests", {})
	if kind == "objective":
		var progress: Dictionary = quests.get("active", {}).get(str(Q), {}).get("objectives", {}).get("return_to_smith", {})
		return progress.get("done", false) and progress.get("current") == 1 and progress.get("target") == 1 and not quests.get("completed", []).has(str(Q))
	return quests.get("completed", []).has(str(Q)) and not quests.get("active", {}).has(str(Q))

static func _differences(a: Variant, b: Variant, path: String = "") -> String:
	var differences: Array[String] = []
	if a is Dictionary and b is Dictionary:
		var keys: Array = a.keys()
		for key in b:
			if not keys.has(key): keys.append(key)
		for key in keys:
			if a.get(key) != b.get(key): differences.append(_differences(a.get(key), b.get(key), path + "/" + str(key)))
		return "; ".join(differences)
	return "%s: %s -> %s" % [path, a, b]

static func _memories(sm: Node, pid: StringName) -> Array:
	return sm.living_context(NPC, pid).get("memories", []) if sm.has_method("living_context") else []
