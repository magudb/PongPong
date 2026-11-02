extends RefCounted
const SECTION := "persistence_nested_scope_controls"
const TIMEOUT_S := 300.0
const QUEST := &"zz_nested_scope_controls"
const Origin := preload("res://scripts/traetoppen/life/presenter_origin.gd")
class Late extends Node:
	var partial := false
	var data := {"reject":false}
	func to_dict() -> Dictionary: return data.duplicate(true)
	func reset() -> void: data = {"reject":false}
	func from_dict(d: Dictionary) -> bool:
		if d.get("reject",false):
			data = {"reject":true}
			return false
		if partial: return false
		data = d.duplicate(true)
		return true

func run(t) -> void:
	for mode in ["same_player", "raw_profile", "same_apply", "row_replace", "body_replace", "complete_rollback", "partial_rollback", "earned_body_independent"]:
		await _gift_case(t, mode)
	await _raw_before_delivery(t)
	await _guard_stack(t)
	await _independent_roots(t)
	await _unscoped_and_full(t)
	t.autoload("QuestManager").quest_defs.erase(QUEST)

func _gift_case(t, mode: String) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var social: Node = t.autoload("SocialManager")
	var eco: Node = t.autoload("EconomyManager")
	var loot: Node = t.autoload("LootService")
	var qm: Node = t.autoload("QuestManager")
	var saves: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	saves.autosave_enabled = false
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	var late := Late.new()
	t.root.add_child(late)
	saves.register_section("nested_scope_late", late, 999)
	var body: Node2D = t.world()._make_player()
	t.world()._register_player(body, 1, 2)
	t.world().add_child(body)
	qm.register_quest_from_lua({"id":str(QUEST), "objectives":[{"id":"receive", "on":"item_gained", "item":"table_stump", "target":1}, {"id":"gate", "on":"manual", "target":1}], "rewards":{}})
	PlayerRegistry.for_player(&"p1", func():
		qm.accept_quest(QUEST)
		eco.from_dict(eco.to_dict())
		social.add_points("guard_oak",399,&"debug",{"toast":false}))
	loot.from_dict(loot.to_dict())
	saves.gather_payload()
	await t.frames(3)
	var profile: PlayerState = PlayerRegistry._states[&"p1"]
	var original_rows: Dictionary = PlayerRegistry._states
	var social_row: Dictionary = social._row_for(&"p1", "guard_oak", false)
	var original_run: RefCounted = social._accounting_world
	var p0: Dictionary = PlayerRegistry._states[&"p0"].to_dict().duplicate(true)
	var s0: Dictionary = social._rows.get(&"p0",{}).duplicate(true)
	var items: Array = []
	var rolls: Array = []
	var scopes: Array = []
	var on_item := func(pid,id,n):
		if id == &"table_stump": items.append([str(pid),str(id),n,str(PlayerRegistry.acting_id())])
	var on_roll := func(source, _results):
		if source == &"gift:guard_oak:4": rolls.append(str(PlayerRegistry.acting_id()))
	bus.item_gained.connect(on_item)
	bus.loot_rolled.connect(on_roll)
	var changes: Array = []
	var allowed := mode in ["same_player","complete_rollback","earned_body_independent"]
	var opts := {"toast":false}
	if mode == "earned_body_independent":
		opts["effects_current"] = PlayerRegistry.for_player(&"p1",func(): return Origin.model_guard())
	t.check(mode+"_otherwise_valid_original_gift", social.points("guard_oak",&"p1") == 399 and not loot.claimed.has("guard_oak:4") and PlayerRegistry.registered_id(body) == &"p1")
	PlayerRegistry.for_player(&"p0",func():
		eco.defer_notifications(func():
			if mode == "same_player":
				PlayerRegistry.for_player(&"p1",func(): eco.defer_notifications(func(): social.add_points("guard_oak",1,&"debug",opts)))
			else: PlayerRegistry.for_player(&"p1",func(): social.add_points("guard_oak",1,&"debug",opts))
			changes.append(loot.claimed.get("guard_oak:4") == gm.total_day() and PlayerRegistry.for_player(&"p1",func(): return eco.count_item(&"table_stump")) == 1)
			if mode == "raw_profile":
				var replacement := PlayerState.new()
				changes.append(replacement.from_dict(profile.to_dict()))
				PlayerRegistry._states[&"p1"] = replacement
				PlayerRegistry.for_player(&"p1",func(): qm.from_dict(replacement.quests))
			elif mode in ["same_apply","complete_rollback","partial_rollback"]:
				# The first real keepsake creates a sparse dungeon registry. Prime
				# its shipped codec before retaining the rollback preimage; the
				# unchanged graph/claim/earned-event predicates remain below.
				loot.from_dict(loot.to_dict())
				var payload: Dictionary = saves.gather_payload()
				payload.nested_scope_late.reject = mode != "same_apply"
				late.partial = mode == "partial_rollback"
				var snapshots: Dictionary = {}
				for entry in saves._ordered_entries():
					var target: Variant = saves._node_of(entry)
					if target != null and target.has_method("to_dict"): snapshots[entry.name] = saves._section_projection(target).duplicate(true)
				changes.append(saves._apply_payload(payload).ok)
				if mode == "complete_rollback":
					for entry in saves._ordered_entries():
						var target: Variant = saves._node_of(entry)
						if target != null and snapshots.has(entry.name):
							var after: Dictionary = saves._section_projection(target)
							if after != snapshots[entry.name]: print("NESTED_ROLLBACK_DIFF ",entry.name," before=",JSON.stringify(snapshots[entry.name])," after=",JSON.stringify(after))
			elif mode == "row_replace": social._rows[&"p1"]["guard_oak"] = social_row.duplicate(true)
			elif mode in ["body_replace","earned_body_independent"]:
				changes.append(t.world()._unregister_player(body))
				if mode == "body_replace":
					var successor: Node2D = t.world()._make_player()
					t.world()._register_player(successor,1,2)
					t.world().add_child(successor)
			# No natural frame or scope is kept across the deferral.
			scopes.append(PlayerRegistry.acting_id() == &"p0")
		)
		scopes.append(PlayerRegistry.acting_id() == &"p0"))
	t.check(mode+"_committed_before_transition", not changes.is_empty() and changes[0],str(changes))
	if mode in ["same_apply","complete_rollback","partial_rollback"]:
		t.check(mode+"_real_apply_outcome", changes == [true,mode == "same_apply"],str(changes))
	if mode == "complete_rollback":
		t.check(mode+"_exact_original_graph_authenticated", is_same(PlayerRegistry._states,original_rows) and PlayerRegistry._states[&"p1"] == profile and is_same(social._row_for(&"p1","guard_oak",false),social_row) and social._accounting_world == original_run)
	if mode == "partial_rollback": t.check(mode+"_incomplete_restoration_revokes_original", social._accounting_world != original_run and PlayerRegistry._states[&"p1"] != profile)
	if mode == "same_apply": t.check(mode+"_equal_values_success_still_replaces", PlayerRegistry._states[&"p1"] != profile and social._accounting_world != original_run and PlayerRegistry._states[&"p1"].gold == profile.gold)
	t.check(mode+"_only_original_valid_item_notifications", items == ([["p1","table_stump",1,"p1"]] if allowed else []),str(items))
	t.check(mode+"_only_original_valid_loot_notifications", rolls == (["p1"] if allowed else []),str(rolls))
	t.check(mode+"_original_consequential_quest_policy", int(profile.quests.active[QUEST].objectives["receive"].current) == (1 if allowed else 0))
	if mode not in ["same_apply","partial_rollback"]:
		t.check(mode+"_whole_unrelated_p0_and_social_unchanged", PlayerRegistry._states[&"p0"].to_dict() == p0 and social._rows.get(&"p0",{}) == s0 and PlayerRegistry._states.size() == 2)
	t.check(mode+"_caller_and_queue_unwound", scopes == [true,true] and PlayerRegistry._acting_id == &"" and eco._notification_depth == 0 and eco._deferred_notifications.is_empty() and not gm.lifecycle_busy())
	# Observers remain connected through actual retirement and natural frames.
	await t.frames(3)
	t.check(mode+"_no_late_old_item_or_loot", items.size() == (1 if allowed else 0) and rolls.size() == (1 if allowed else 0))
	var next_items: Array = []
	var on_next := func(pid,id,n):
		if id == &"stone": next_items.append([str(pid),n,str(PlayerRegistry.acting_id())])
	bus.item_gained.connect(on_next)
	PlayerRegistry.for_player(&"p1",func(): eco.add_item(&"stone",1))
	t.check(mode+"_next_legitimate_transaction_delivers_once", next_items == [["p1",1,"p1"]] and PlayerRegistry._acting_id == &"",str(next_items))
	bus.item_gained.disconnect(on_next)
	bus.item_gained.disconnect(on_item)
	bus.loot_rolled.disconnect(on_roll)
	saves.unregister_section("nested_scope_late")
	late.free()
	gm.clear_config_overrides()

func _raw_before_delivery(t) -> void:
	await t.start_world()
	var social: Node = t.autoload("SocialManager")
	var eco: Node = t.autoload("EconomyManager")
	var loot: Node = t.autoload("LootService")
	var qm: Node = t.autoload("QuestManager")
	var bus: Node = t.autoload("EventBus")
	t.autoload("SaveManager").autosave_enabled = false
	var body: Node2D = t.world()._make_player()
	t.world()._register_player(body,1,2)
	t.world().add_child(body)
	PlayerRegistry.for_player(&"p1",func(): social.add_points("guard_oak",399,&"debug",{"toast":false}); eco.from_dict(eco.to_dict()))
	var original: PlayerState = PlayerRegistry._states[&"p1"]
	var observed: Array = []
	var items: Array = []
	var on_item := func(pid,id,n):
		if id == &"table_stump": items.append([str(pid),n,str(PlayerRegistry.acting_id())])
	var on_friend := func(pid,npc,_hearts):
		if pid != &"p1" or npc != &"guard_oak" or not observed.is_empty(): return
		observed.append(true)
		var successor := PlayerState.new()
		observed.append(successor.from_dict(original.to_dict()))
		PlayerRegistry._states[&"p1"] = successor
		qm.from_dict(successor.quests)
	bus.item_gained.connect(on_item)
	bus.friend_changed.connect(on_friend)
	PlayerRegistry.for_player(&"p0",func(): eco.defer_notifications(func(): PlayerRegistry.for_player(&"p1",func(): social.add_points("guard_oak",1,&"debug",{"toast":false}))))
	bus.friend_changed.disconnect(on_friend)
	t.check("raw_replacement_before_delivery_real_threshold_and_body_unchanged", observed == [true,true] and PlayerRegistry._states[&"p1"] != original and PlayerRegistry.registered_id(body) == &"p1" and social.points("guard_oak",&"p1") == 400)
	t.check("raw_replacement_does_not_recapture_winner_for_old_gift", items.is_empty() and not loot.claimed.has("guard_oak:4") and PlayerRegistry.for_player(&"p1",func(): return eco.count_item(&"table_stump")) == 0,str(items))
	PlayerRegistry.for_player(&"p1",func(): social.add_points("guard_oak",100,&"debug",{"toast":false}))
	t.check("raw_replacement_independent_current_gift_progresses_once", loot.claimed.has("guard_oak:4") and items == [["p1",1,"p1"]] and PlayerRegistry._acting_id == &"",str(items))
	bus.item_gained.disconnect(on_item)

func _guard_stack(t) -> void:
	await t.start_world()
	var eco: Node = t.autoload("EconomyManager")
	var bus: Node = t.autoload("EventBus")
	PlayerRegistry.state(&"p1")
	var guards: Array = []
	for pid in [&"p0",&"p1"]: guards.append(PlayerRegistry.for_player(pid,func(): return Origin.model_guard()))
	var observations: Array = []
	var on_gold := func(pid,_gold,delta): observations.append([str(pid),delta,str(PlayerRegistry.acting_id())])
	bus.gold_changed.connect(on_gold)
	PlayerRegistry.for_player(&"p0",func():
		eco.defer_notifications(func():
			eco.add_gold(2)
			PlayerRegistry.for_player(&"p1",func(): eco.defer_notifications(func(): eco.add_gold(3),guards[1]))
			eco.add_gold(5)
		,guards[0]))
	t.check("nested_guard_stack_each_record_keeps_its_producer", observations == [["p0",2,"p0"],["p1",3,"p1"],["p0",5,"p0"]],str(observations))
	var phantom: Array = []
	PlayerRegistry.for_player(&"p3",func(): eco.defer_notifications(func(): eco.after_transaction(func(): phantom.append(true)),func(): return true))
	t.check("noncreating_scope_rejects_absent_profile_without_phantom", phantom.is_empty() and PlayerRegistry._states.size() == 2 and not PlayerRegistry._states.has(&"p3") and PlayerRegistry._acting_id == &"")
	bus.gold_changed.disconnect(on_gold)

func _independent_roots(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var social: Node = t.autoload("SocialManager")
	var eco: Node = t.autoload("EconomyManager")
	var saves: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	saves.autosave_enabled = false
	gm.set_config_override("time.minutes_per_real_second",0.0)
	var body: Node2D = t.world()._make_player()
	t.world()._register_player(body,1,2)
	t.world().add_child(body)
	PlayerRegistry.for_player(&"p1",func(): social.add_points("guard_oak",399,&"debug",{"toast":false}); eco.from_dict(eco.to_dict()))
	var payload: Dictionary = saves.gather_payload()
	var old: Callable = PlayerRegistry.for_player(&"p0",func(): return Origin.model_guard())
	var golds: Array = []
	var items: Array = []
	var on_gold := func(pid,_gold,delta):
		if delta != 0: golds.append([str(pid),delta,str(PlayerRegistry.acting_id())])
	var on_item := func(pid,id,n):
		if id == &"table_stump": items.append([str(pid),n,str(PlayerRegistry.acting_id())])
	bus.gold_changed.connect(on_gold)
	bus.item_gained.connect(on_item)
	var outcomes: Array = []
	PlayerRegistry.for_player(&"p0",func():
		eco.defer_notifications(func():
			eco.add_gold(3) # old queued publication must be cancelled
			outcomes.append(saves._apply_payload(payload).ok)
			eco.add_gold(7) # independent unguarded new-model root stays legacy p0
			PlayerRegistry.for_player(&"p1",func(): social.add_points("guard_oak",1,&"debug",{"toast":false}))
		,old))
	t.check("independent_current_lifecycle_root_not_poisoned_by_outer_guard", outcomes == [true] and golds == [["p0",7,"p0"]],str(golds))
	t.check("independent_current_nested_p1_root_not_poisoned", items == [["p1",1,"p1"]],str(items))
	t.check("independent_roots_scope_restored", PlayerRegistry._acting_id == &"" and eco._notification_depth == 0)
	bus.gold_changed.disconnect(on_gold)
	bus.item_gained.disconnect(on_item)
	gm.clear_config_overrides()

func _unscoped_and_full(t) -> void:
	await t.start_world()
	var eco: Node = t.autoload("EconomyManager")
	var bus: Node = t.autoload("EventBus")
	var observations: Array = []
	var on_item := func(pid,id,n):
		if id == &"stone": observations.append([str(pid),n,str(PlayerRegistry.acting_id())])
	bus.item_gained.connect(on_item)
	PlayerRegistry.state(&"p1")
	PlayerRegistry.for_player(&"p0",func(): eco.defer_notifications(func(): PlayerRegistry.for_player(&"p1",func(): eco.add_item(&"stone",1))))
	t.check("original_unguarded_nested_delivery_not_globally_rescoped", observations == [["p1",1,"p0"]],str(observations))
	PlayerRegistry.for_player(&"p1",func():
		eco.inventory.clear()
		for i in eco.INVENTORY_SLOTS: eco.inventory.append({"id":&"wood","amount":99,"meta":{}}))
	var full: Dictionary = PlayerRegistry._states[&"p1"].to_dict().duplicate(true)
	var result: Array = []
	var guard: Callable = PlayerRegistry.for_player(&"p1",func(): return Origin.model_guard())
	PlayerRegistry.for_player(&"p0",func(): eco.defer_notifications(func(): PlayerRegistry.for_player(&"p1",func(): eco.defer_notifications(func(): result.append(eco.add_item(&"stone",1)),guard))))
	t.check("full_backpack_refuses_no_transfer_or_item_event", result == [false] and observations.size() == 1 and PlayerRegistry._states[&"p1"].to_dict() == full)
	PlayerRegistry.for_player(&"p1",func(): eco.inventory.pop_back(); eco.defer_notifications(func(): eco.add_item(&"stone",1),guard))
	t.check("room_reopened_next_guarded_transaction_exactly_once", observations == [["p1",1,"p0"],["p1",1,"p1"]] and PlayerRegistry._acting_id == &"",str(observations))
	bus.item_gained.disconnect(on_item)
