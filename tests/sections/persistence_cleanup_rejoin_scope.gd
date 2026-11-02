extends RefCounted
const SECTION := "persistence_cleanup_rejoin_scope"
const TIMEOUT_S := 180.0

func run(t) -> void:
	for conflicting in [false, true]: await _rejoin(t, conflicting)

func _aliases(value: Variant, path: String, out: Dictionary) -> void:
	if value is Array or value is Dictionary:
		out[path] = value
		if value is Array:
			for i in value.size(): _aliases(value[i], path+"/"+str(i), out)
		else:
			for key in value: _aliases(value[key], path+"/"+str(key), out)
	elif value is Object: out[path] = value

func _graph(row: PlayerState) -> Dictionary:
	var out := {}
	for key in ["inventory", "equipment", "arsenal", "arsenal_orphans", "quests", "flags", "owed", "wardrobe", "hotbar", "_vital_writes"]:
		_aliases(row.get(key), key, out)
	return out

func _values(row: PlayerState) -> Dictionary:
	# to_dict covers the persistent row; retain runtime-only scalar fields too.
	return {"persistent":row.to_dict(), "max_half_hearts":row.max_half_hearts, "max_stamina":row.max_stamina, "max_oil":row.max_oil, "arsenal_orphans":row.arsenal_orphans.duplicate(true)}

func _same_graph(row: PlayerState, before: Dictionary) -> bool:
	var after := _graph(row)
	if after.keys() != before.keys(): return false
	for key in before:
		if not is_same(before[key], after[key]): return false
	return true

func _load_owed(economy: Node, pid: StringName, material: StringName) -> void:
	PlayerRegistry.for_player(pid, func():
		var entries := []
		for i in economy.INVENTORY_SLOTS:
			entries.append({"id":"wood", "amount":1, "meta":{"fixture_slot":i}})
		entries.append({"id":str(material), "amount":3, "meta":{}})
		economy.from_dict({"gold":321, "inventory":entries}))

func _rejoin(t, conflicting: bool) -> void:
	await t.start_world()
	var label := "conflicting" if conflicting else "ordinary"
	var w: Node = t.world()
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SaveManager")
	var economy: Node = t.autoload("EconomyManager")
	var bus: Node = t.autoload("EventBus")
	sm.autosave_enabled = false
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	var secondary: Node2D = w._make_player()
	w._register_player(secondary, 1, 2)
	PlayerRegistry.for_player(&"p1", func(): w.add_child(secondary))
	secondary.enter_area(w.area, w.area.get_spawn("default") + Vector2(100, 0))
	secondary.set_physics_process(false)
	_load_owed(economy, &"p1", &"stone")
	_load_owed(economy, &"p0", &"stone")
	await t.frames(5) # Let setup tickets settle while both packs remain full.
	var p1: PlayerState = PlayerRegistry._states[&"p1"]
	var p0: PlayerState = PlayerRegistry._states[&"p0"]
	p1.inventory.clear() # Actual loader overflow remains owed; now there is room.
	p0.inventory.clear()
	w.player.half_hearts = 4
	w.player.stamina = 31.0
	w.player.oil = 52.0
	w.player.hotbar.assign(6, &"stone")
	w.player.hotbar.select(6)
	var hotbar: Dictionary = w.player.hotbar.to_dict()
	var pose: Vector2 = w.player.global_position
	w._unregister_player(w.player)
	await t.frames(3)
	t.check("LC1_"+label+"_real_secondary_group_local_and_deliverable_debt", PlayerRegistry.local_id() == &"p1" and PlayerRegistry.by_id(&"p1") == secondary and p1.owed.size() == 1 and p1.owed[0].id == &"stone" and p1.owed[0].amount == 3 and p1.inventory.is_empty() and p0.owed.size() == 1)
	var values: Dictionary = _values(p1)
	var graph := _graph(p1)
	var states: Dictionary = PlayerRegistry._states
	var fallback: PlayerState = PlayerRegistry._fallback_state
	var labels := {"health":[], "stats":[], "hotbar":[], "oil":[]}
	var on_health := func(pid, _hp, _max): labels.health.append(pid)
	var on_stats := func(pid, _data): labels.stats.append(pid)
	var on_hotbar := func(pid, _slots, _selected): labels.hotbar.append(pid)
	var on_oil := func(pid, _oil, _max): labels.oil.append(pid)
	bus.player_health_changed.connect(on_health)
	bus.player_stats_changed.connect(on_stats)
	bus.hotbar_changed.connect(on_hotbar)
	bus.player_oil_changed.connect(on_oil)
	var caller_before: StringName = PlayerRegistry._acting_id
	var joined: Node2D
	if conflicting:
		joined = PlayerRegistry.for_player(&"p1", func():
			var p: Node2D = w.rejoin_host()
			t.check("LC1_conflicting_inner_scope_restored", PlayerRegistry._acting_id == &"p1")
			return p)
	else: joined = w.rejoin_host()
	bus.player_health_changed.disconnect(on_health)
	bus.player_stats_changed.disconnect(on_stats)
	bus.hotbar_changed.disconnect(on_hotbar)
	bus.player_oil_changed.disconnect(on_oil)
	t.check("LC1_"+label+"_complete_secondary_values_and_aliases_unchanged", PlayerRegistry._states[&"p1"] == p1 and is_same(PlayerRegistry._states, states) and PlayerRegistry._fallback_state == fallback and _values(p1) == values and _same_graph(p1, graph))
	t.check("LC1_"+label+"_readiness_categories_exact_actual_p0_labels", labels.values().all(func(ids): return not ids.is_empty() and ids.all(func(pid): return pid == &"p0")), str(labels))
	t.check("LC1_"+label+"_owned_p0_debt_delivered_not_p1", p0.owed.is_empty() and p0.inventory.size() == 1 and p0.inventory[0].id == &"stone" and p0.inventory[0].amount == 3 and p1.owed.size() == 1 and p1.inventory.is_empty())
	t.check("LC1_"+label+"_hydration_and_caller_restored", joined != null and w._host_live() and joined.half_hearts == 4 and joined.stamina == 31.0 and joined.oil == 52.0 and joined.hotbar.to_dict() == hotbar and joined.global_position == pose and PlayerRegistry._acting_id == caller_before)
	await t.frames(5)
	t.check("LC1_"+label+"_secondary_graph_after_deferred_work", _values(p1) == values and _same_graph(p1, graph))
	await w.travel(&"home", &"default")
	var at: Vector2 = joined.global_position
	t.hold(&"move_right")
	await t.seconds(0.2)
	t.release(&"move_right")
	t.check("LC1_"+label+"_future_real_travel_enabled_movement_save", joined.is_physics_processing() and joined.global_position.distance_to(at) > 1.0 and w.area.map.id == &"home" and sm.save_game(4))
	gm.clear_config_overrides()
