extends RefCounted
const SECTION := "rollback_alias_graph"
const TIMEOUT_S := 180.0
class RejectLate extends Node:
	var mode := "failed"
	var data := {"reject":false}
	var observe: Callable
	func to_dict() -> Dictionary: return data.duplicate(true)
	func reset() -> void: data = {"reject":false}
	func from_dict(d: Dictionary) -> bool:
		if observe.is_valid(): observe.call()
		if d.get("reject",false):
			data = {"reject":true}
			return false
		if mode == "partial": return false
		if mode == "liar": return true # reports success without restoring its mutated value
		data = d.duplicate(true)
		return true
func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var saves: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	saves.save_dir = "user://rollback_alias_graph"
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	saves.autosave_enabled = false
	for seam in ["cost", "owed"]:
		for mode in ["failed", "partial", "early_partial", "liar", "same", "backup", "direct"]:
			gm.start_new_game("Alias", gm.character_type, "Alias")
			gm.set_config_override("time.minutes_per_real_second", 0.0)
			gm.clear_flag(&"intro_pending")
			var late := RejectLate.new()
			late.mode = "partial" if mode == "early_partial" else mode
			t.root.add_child(late)
			saves.register_section("alias_late", late, -100 if mode == "early_partial" else 999)
			saves.save_dir = "user://rollback_alias_graph/"+seam+"_"+mode
			DirAccess.make_dir_recursive_absolute(saves.save_dir)
			qm.register_quest_from_lua({"id":"zz_alias", "objectives":[{"id":"first","on":"manual","target":1},{"id":"last","on":"manual","target":1}], "rewards":{"items":{"wood":2,"stone":3}}, "meta":{}})
			PlayerRegistry.state(&"p1")
			PlayerRegistry.for_player(&"p1", func():
				eco.from_dict(eco.to_dict())
				qm.accept_quest(&"zz_alias")
				eco.add_item(&"wood", 7, true))
			saves.gather_payload() # normalize actual world travel/display fields before retention
			var profile: PlayerState = PlayerRegistry._states[&"p1"]
			profile.max_half_hearts = 38; profile.max_stamina = 137.0; profile.max_oil = 211.0
			var inventory: Array = profile.inventory
			var quests: Dictionary = profile.quests
			var runtime: Variant = quests.active[&"zz_alias"]
			var objectives: Dictionary = runtime.objectives
			var first: Dictionary = objectives[&"first"]
			var pending: Dictionary = quests.pending_rewards
			var host_before: Dictionary = PlayerRegistry._states[&"p0"].to_dict()
			var original_rows: Dictionary = PlayerRegistry._states
			var original_fallback: PlayerState = PlayerRegistry._fallback_state
			var guard: Callable = PlayerRegistry.for_player(&"p1", func(): return preload("res://scripts/traetoppen/life/presenter_origin.gd").model_guard())
			var observations: Array = []
			var barriers: Array = []
			var nested: Array = []
			var owed_alias: Array = []
			var callback_host: Array = []
			late.observe = func():
				barriers.append(not guard.call() and gm.lifecycle_busy())
				nested.append(saves.try_load_game(0).code == "busy")
			var transition := func():
				if not observations.is_empty(): return
				observations.append("reached")
				if seam == "owed": owed_alias.append(pending.get(&"zz_alias", {}))
				var payload: Dictionary = saves.gather_payload()
				if mode in ["failed", "partial", "early_partial", "liar"]: payload.alias_late["reject"] = true
				if mode == "direct":
					PlayerRegistry.reset_states()
					observations.append(t.world().roster.from_dict(payload.players))
				else:
					var f := FileAccess.open(saves.slot_path(0), FileAccess.WRITE)
					f.store_string("not json" if mode == "backup" else JSON.stringify(payload)); f.close()
					if mode == "backup":
						var backup := FileAccess.open(saves.backup_path(0), FileAccess.WRITE)
						backup.store_string(JSON.stringify(payload)); backup.close()
					observations.append(saves.load_game(0))
				observations.append(guard.call())
				callback_host.append(PlayerRegistry._states[&"p0"].to_dict())
			var on_objective := func(pid, qid, oid, _current, _target):
				if seam == "cost" and pid == &"p1" and qid == &"zz_alias" and oid == &"first": transition.call()
			var on_item := func(pid, id, _amount):
				if seam == "owed" and pid == &"p1" and id == &"wood": transition.call()
			bus.quest_objective_updated.connect(on_objective)
			bus.item_gained.connect(on_item)
			var cost_before: int = PlayerRegistry.for_player(&"p1", func(): return eco.count_item(&"wood"))
			PlayerRegistry.for_player(&"p1", func():
				qm.complete_manual_owned(&"zz_alias", &"first", guard, {"wood":2}, true)
				if seam == "owed": qm.complete_manual_owned(&"zz_alias", &"last", guard))
			bus.quest_objective_updated.disconnect(on_objective)
			bus.item_gained.disconnect(on_item)
			var label: String = seam+"_"+mode
			var allowed: bool = mode == "failed"
			t.check(label+"_real_observer_transition", observations == ["reached", mode in ["same", "backup", "direct"], allowed], str(observations))
			if mode != "direct": t.check(label+"_actual_apply_rollback_barriers_and_nested_busy", not barriers.is_empty() and barriers.all(func(v): return v) and nested.all(func(v): return v), str({"barriers":barriers,"nested":nested}))
			t.check(label+"_exact_profile_identity_policy", PlayerRegistry._states.get(&"p1") == profile if mode == "early_partial" else (PlayerRegistry._states.get(&"p1") == profile) == allowed)
			if allowed:
				t.check(label+"_registry_and_fallback_aliases", is_same(PlayerRegistry._states, original_rows) and PlayerRegistry._fallback_state == original_fallback)
				t.check(label+"_nested_quest_inventory_runtime_graph", is_same(profile.inventory, inventory) and is_same(profile.quests, quests) and is_same(profile.quests.pending_rewards, pending) and is_same(runtime.objectives, objectives) and is_same(objectives[&"first"], first))
				t.check(label+"_runtime_only_vitals_preserved", profile.max_half_hearts == 38 and profile.max_stamina == 137.0 and profile.max_oil == 211.0)
				if seam == "cost":
					t.check(label+"_actual_cost_and_runtime_progress", int(first.current) == 1 and first.done and profile.quests.active[&"zz_alias"] == runtime and PlayerRegistry.for_player(&"p1", func(): return eco.count_item(&"wood")) == cost_before-2)
					PlayerRegistry.for_player(&"p1", func(): qm.complete_manual_owned(&"zz_alias", &"last", guard))
				else:
					t.check(label+"_actual_retained_owed_container_drained", owed_alias.size() == 1 and owed_alias[0].is_empty() and pending.is_empty())
				var counts: Array = PlayerRegistry.for_player(&"p1", func(): return [eco.count_item(&"wood"), eco.count_item(&"stone")])
				t.check(label+"_followup_actual_rewards_exactly_once", counts == [cost_before, 3] and PlayerRegistry.for_player(&"p1", func(): return qm.is_completed(&"zz_alias")), str(counts))
				PlayerRegistry.for_player(&"p1", func(): qm.claim_rewards())
				t.check(label+"_no_duplicate_second_claim", counts == PlayerRegistry.for_player(&"p1", func(): return [eco.count_item(&"wood"),eco.count_item(&"stone")]))
			var expected_host: Dictionary = callback_host[0] if mode in ["same", "backup", "direct"] else host_before
			t.check(label+"_unrelated_host_and_no_phantom_rows", PlayerRegistry._states[&"p0"].to_dict() == expected_host and PlayerRegistry._states.size() == 2, str({"before":expected_host,"after":PlayerRegistry._states[&"p0"].to_dict()}))
			t.check(label+"_no_actor_scope_or_lifecycle_leak", PlayerRegistry._acting_id == &"" and not gm.lifecycle_busy() and not t.autoload("SocialManager")._accounting_suspended)
			saves.unregister_section("alias_late")
			late.free()
			await t.frames(1)
	# Validate once, then reach a genuine child Quest decoder refusal through
	# Economy's real inventory notification between validation and that decoder.
	gm.start_new_game("Child refusal", gm.character_type)
	var wire: Dictionary = t.world().roster.to_dict()
	var reached_child: Array = []
	var child_observer := func(_pid, _inventory):
		if not reached_child.is_empty(): return
		reached_child.append(true)
		wire.rows.p0.quests["active"] = []
	t.check("child_input_valid_before_actual_notification", t.world().roster.validate_dict(wire))
	bus.player_inventory_changed.connect(child_observer)
	var child_result: bool = t.world().roster.from_dict(wire)
	bus.player_inventory_changed.disconnect(child_observer)
	t.check("actual_nested_quest_decoder_false_propagates", reached_child == [true] and not child_result)
	t.check("child_refusal_preserves_caller_scope", PlayerRegistry._acting_id == &"")
	gm.clear_config_overrides()
