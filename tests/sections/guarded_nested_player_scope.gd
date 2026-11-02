extends RefCounted
## Real authored friendship gift, committed before an unrelated outer scope drains.
const SECTION := "guarded_nested_player_scope"
const TIMEOUT_S := 180.0
const QUEST := &"zz_guarded_nested_scope"

func run(t) -> void:
	for mode in ["ordinary", "nested"]:
		await t.start_world()
		var gm: Node = t.autoload("GameManager")
		var social: Node = t.autoload("SocialManager")
		var eco: Node = t.autoload("EconomyManager")
		var loot: Node = t.autoload("LootService")
		var qm: Node = t.autoload("QuestManager")
		var bus: Node = t.autoload("EventBus")
		t.autoload("SaveManager").autosave_enabled = false
		gm.set_config_override("time.minutes_per_real_second", 0.0)
		var body: Node2D = t.world()._make_player()
		t.world()._register_player(body, 1, 2)
		t.world().add_child(body)
		qm.register_quest_from_lua({"id":str(QUEST), "objectives":[{"id":"receive", "on":"item_gained", "item":"table_stump", "target":1}, {"id":"stay_active", "target":1}], "rewards":{}})
		PlayerRegistry.for_player(&"p1", func():
			qm.accept_quest(QUEST)
			social.add_points("guard_oak", 399, &"debug", {"toast":false}))
		var before: int = PlayerRegistry.for_player(&"p1", func(): return eco.count_item(&"table_stump"))
		t.check(mode+"_real_shipped_gift_eligible", social.points("guard_oak", &"p1") == 399 and not loot.claimed.has("guard_oak:4") and before == 0 and PlayerRegistry.registered_id(body) == &"p1" and PlayerRegistry.for_player(&"p1", func(): return eco.free_slots()) > 0)
		var p0: Dictionary = PlayerRegistry._states[&"p0"].to_dict().duplicate(true)
		var s0: Dictionary = social._rows.get(&"p0", {}).duplicate(true)
		var inventory: Array = []
		var items: Array = []
		var on_inv := func(pid, _pack): inventory.append([str(pid),str(PlayerRegistry.acting_id())])
		var on_item := func(pid, id, n): items.append([str(pid),str(id),n,str(PlayerRegistry.acting_id())])
		bus.player_inventory_changed.connect(on_inv)
		bus.item_gained.connect(on_item)
		var cross := func():
			PlayerRegistry.for_player(&"p1", func(): social.add_points("guard_oak", 1, &"debug", {"toast":false}))
			if mode == "nested": t.check(mode+"_inner_unwound_before_outer_flush", PlayerRegistry.acting_id() == &"p0" and items.is_empty() and inventory.is_empty())
		PlayerRegistry.for_player(&"p0", func():
			if mode == "nested": eco.defer_notifications(cross)
			else: cross.call()
			t.check(mode+"_outer_scope_restored", PlayerRegistry._acting_id == &"p0"))
		t.check(mode+"_real_transfer_and_claim_committed", PlayerRegistry.for_player(&"p1", func(): return eco.count_item(&"table_stump")) == before+1 and loot.claimed.get("guard_oak:4") == gm.total_day())
		t.check(mode+"_inventory_exactly_once_p1_scope", inventory == [["p1","p1"]], str(inventory))
		t.check(mode+"_item_exactly_once_p1_scope", items == [["p1","table_stump",1,"p1"]], str(items))
		t.check(mode+"_actual_quest_consumer_progress", PlayerRegistry.for_player(&"p1", func(): return qm.active_quests[QUEST].objectives["receive"].current) == 1)
		t.check(mode+"_whole_p0_and_social_unchanged_no_phantoms", PlayerRegistry._states[&"p0"].to_dict() == p0 and social._rows.get(&"p0", {}) == s0 and PlayerRegistry._states.size() == 2)
		t.check(mode+"_scope_and_deferral_unwound", PlayerRegistry._acting_id == &"" and eco._notification_depth == 0 and eco._deferred_notifications.is_empty())
		bus.player_inventory_changed.disconnect(on_inv)
		bus.item_gained.disconnect(on_item)
		t.world()._unregister_player(body)
		gm.clear_config_overrides()
	qm_cleanup(t)

func qm_cleanup(t) -> void:
	t.autoload("QuestManager").quest_defs.erase(QUEST)
