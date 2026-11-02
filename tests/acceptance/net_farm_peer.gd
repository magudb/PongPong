extends "res://tests/acceptance/net_peer.gd"
## Connected consequences, stationary fixtures (movement is a separate lane).
var farmer: StringName
var cell: Vector2i
var costs := {}
var rounds := {}
var guest_events := {"item": 0, "crop": 0}
var files_before := {}
var replay_during_callback := {"seen": false, "denied": false, "scope": false}

func _movement(world: Node, host: bool) -> void:
	world.sync.set_physics_process(false)
	for body in world.all_players(): body.set_physics_process(false)
	if host: root.get_node("TimeManager").pause_time()
	if not host:
		files_before = save_hashes(root.get_node("SaveManager").save_dir)
		root.get_node("EventBus").item_gained.connect(func(_id, _item, _amount): guest_events.item += 1)
		root.get_node("EventBus").crop_harvested.connect(func(_plot, _crop, _amount): guest_events.crop += 1)
	check("farm_intent_available", world.get("intents") != null)
	_write_json(path("identity-" + str(options.role)), {"id": str(world.local_player().player_id)})
	marker("farm-ready-" + str(options.role))
	for i in range(1, int(options.count)): await _wait_file(path("farm-ready-guest%d" % i), 10.0)
	if host:
		farmer = StringName(_read_json(path("identity-guest1")).id)
		cell = world.farm.farmable_cells()[0]
		for body in world.all_players():
			if body.player_id != &"p0": body.global_position = world.area.cell_to_global(cell + Vector2i(1, 0))
		for item in [&"hoe_wooden", &"turnip_seeds", &"watering_can_copper"]:
			costs[str(item)] = load("res://scripts/world2d/player_registry.gd").for_player(farmer, func() -> float:
				return float(load("res://scripts/world2d/game_data.gd").item_def(item).get("stamina_cost", 4.0)) * float(load("res://scripts/data/species_perks.gd").value(load("res://scripts/world2d/player_registry.gd").peek_state(farmer).character_skin, "tool_cost_mult", 1.0)))
		_write_json(path("farm-fixture"), {"cell": [cell.x, cell.y], "farmer": str(farmer), "costs": costs})
		marker("farm-fixture-ready")
	else:
		await _wait_file(path("farm-fixture-ready"), 10.0)
		var fixture := _read_json(path("farm-fixture"))
		cell = Vector2i(int(fixture.cell[0]), int(fixture.cell[1]))
		farmer = StringName(fixture.farmer)
		costs = fixture.costs
	details["farmer"] = str(farmer)
	if host:
		root.get_node("EventBus").crop_planted.connect(func(_plot, _crop):
			if replay_during_callback.seen: return
			replay_during_callback.seen = true
			var peer: int = world.player_by_id(farmer).peer_id
			replay_during_callback.scope = load("res://scripts/world2d/player_registry.gd").acting_id() == farmer
			world.intents._request(JSON.stringify({"epoch": world.session.generation, "seq": world.intents._watermarks[peer], "op": "plant", "cell": [cell.x, cell.y], "item": "turnip_seeds"}).to_utf8_buffer())
			replay_during_callback.denied = world.intents.last_result.get("reason") == "replay")
	await round_request(world, host, "till", &"till", cell, &"hoe_wooden")
	var till: Dictionary = rounds.till
	check("farm_till_applied", int(till.after.farm.plots.get(key(cell), {}).get("state", -1)) == 1 and till.result.get("ok") == true and till.result.get("actor") == str(farmer))
	check("farm_till_cost_owner", cost_owner(till, float(costs.hoe_wooden), "", 0))
	check("farm_till_replicated", till.matched)
	await round_request(world, host, "plant", &"plant", cell, &"turnip_seeds")
	var plant: Dictionary = rounds.plant
	check("farm_plant_applied", int(plant.after.farm.plots.get(key(cell), {}).get("state", -1)) == 2 and plant.result.get("ok") == true)
	check("farm_plant_cost_owner", cost_owner(plant, float(costs.turnip_seeds), "turnip_seeds", -1))
	check("farm_plant_replicated", plant.matched)
	if host: check("farm_callback_replay_denied", replay_during_callback.seen and replay_during_callback.denied and replay_during_callback.scope)
	await round_request(world, host, "water", &"water", cell, &"watering_can_copper")
	var water: Dictionary = rounds.water
	check("farm_water_applied", int(water.after.farm.plots.get(key(cell), {}).get("state", -1)) == 3 and water.result.get("ok") == true)
	check("farm_water_cost_owner", cost_owner(water, float(costs.watering_can_copper), "", 0))
	check("farm_water_replicated", water.matched)
	# Calendar fixture advances the production crop day handler; readiness is
	# earned by actual daily water/growth, never by setting a READY plot.
	for day_index in range(4):
		if day_index > 0: await round_request(world, host, "grow-water-%d" % day_index, &"water", cell, &"watering_can_copper")
		if host:
			root.get_node("GameManager").day += 1
			world.farm._on_day_started(root.get_node("GameManager").day, &"foraar")
			marker("grown-%d" % day_index)
		else: await _wait_file(path("grown-%d" % day_index), 10.0)
	if host:
		# Choose a genuine RNG seed whose first draw exercises the host animal
		# bonus if the guest fairy wrongly borrows it.
		var probe := RandomNumberGenerator.new()
		for seed_value in range(1, 100):
			probe.seed = seed_value
			if probe.randf() < 0.2:
				world.farm.rng.seed = seed_value
				break
	await round_request(world, host, "harvest", &"harvest", cell, &"")
	var harvest: Dictionary = rounds.harvest
	check("farm_growth_ready", int(harvest.before.farm.plots.get(key(cell), {}).get("state", -1)) == 4)
	check("farm_harvest_applied", int(harvest.after.farm.plots.get(key(cell), {}).get("state", -1)) == 1 and harvest.result.get("ok") == true and harvest.result.get("actor") == str(farmer))
	check("farm_harvest_reward_owner", cost_owner(harvest, 0.0, "turnip", 1))
	check("farm_harvest_replicated", harvest.matched)
	check("farm_result_immutable", world.intents.last_result.is_read_only())
	await round_request(world, host, "replay", &"harvest", cell, &"", {"replay": true})
	check("farm_replay_refused_once", refused(rounds.replay, "replay"))
	if host: world.player_by_id(farmer).global_position = world.area.cell_to_global(cell + Vector2i(8, 0))
	await round_request(world, host, "range", &"plant", cell, &"turnip_seeds")
	check("farm_authoritative_range", refused(rounds.range, "range"))
	if host:
		world.player_by_id(farmer).global_position = world.area.cell_to_global(cell + Vector2i(1, 0))
		world.player_by_id(farmer).stamina = 0.0
	await round_request(world, host, "stamina", &"plant", cell, &"turnip_seeds")
	check("farm_insufficient_stamina", refused(rounds.stamina, "stamina"))
	if host:
		world.player_by_id(farmer).stamina = 50.0
		load("res://scripts/world2d/player_registry.gd").peek_state(farmer).area = &"home"
	await round_request(world, host, "area", &"plant", cell, &"turnip_seeds")
	check("farm_area_refused", refused(rounds.area, "area"))
	if host:
		load("res://scripts/world2d/player_registry.gd").peek_state(farmer).area = &"farm"
		world.player_by_id(farmer).is_flying = true
	await round_request(world, host, "eligibility", &"plant", cell, &"turnip_seeds")
	check("farm_flying_refused", refused(rounds.eligibility, "eligibility"))
	if host: world.player_by_id(farmer).is_flying = false
	await round_request(world, host, "forged", &"plant", cell, &"turnip_seeds", {"actor": "p0"})
	check("farm_forged_actor_refused", refused(rounds.forged, "schema"))
	await round_request(world, host, "old-epoch", &"plant", cell, &"turnip_seeds", {"epoch": 2})
	check("farm_stale_epoch_refused", refused(rounds["old-epoch"], "epoch"))
	await round_request(world, host, "bool-cell", &"plant", cell, &"turnip_seeds", {"cell": [true, cell.y]})
	await round_request(world, host, "oversize", &"plant", cell, &"turnip_seeds", {"item": "x".repeat(600)})
	check("farm_closed_bounded_schema", refused(rounds["bool-cell"], "schema") and refused(rounds.oversize, "schema"))
	await round_request(world, host, "burst", &"plant", cell, &"turnip_seeds", {"burst": true})
	check("farm_cooldown_bounds_mutation", rounds.burst.result.get("reason") == "cooldown" and int(rounds.burst.after.farm.plots.get(key(cell), {}).get("state", -1)) == 2 and cost_owner(rounds.burst, float(costs.turnip_seeds), "turnip_seeds", -1) and rounds.burst.matched)
	if host:
		# Restore only the test target to an otherwise-eligible TILLED plot.
		world.farm.clear_crop(cell, false)
		load("res://scripts/world2d/player_registry.gd").for_player(farmer, func() -> void:
			root.get_node("EconomyManager").remove_item(&"turnip_seeds", 3))
	await round_request(world, host, "seeds", &"plant", cell, &"turnip_seeds")
	check("farm_insufficient_seeds", refused(rounds.seeds, "ownership"))
	# Fresh rate window: 24 genuine replay RPCs earn at most 16 responses and
	# zero mutations. Both limits are observed, not inferred from a timeout.
	for tick in 70: await physics_frame
	if host:
		_write_json(path("quota-before"), state(world, true))
		marker("quota-go")
	elif str(options.role) == "guest1":
		await _wait_file(path("quota-go"), 10.0)
		var before_count: Variant = world.intents.get("responses_received")
		var payload := JSON.stringify({"epoch": world.session._host_generation, "seq": world.intents._sequence, "op": "plant", "cell": [cell.x, cell.y], "item": "turnip_seeds"}).to_utf8_buffer()
		for n in 24: world.intents._request.rpc_id(1, payload)
		for tick in 20: await physics_frame
		var after_count: Variant = world.intents.get("responses_received")
		_write_json(path("quota-count"), {"responses": int(after_count) - int(before_count) if before_count is int and after_count is int else -1})
		marker("quota-sent")
	await _wait_file(path("quota-sent"), 10.0)
	if host:
		var peer: int = world.player_by_id(farmer).peer_id
		_write_json(path("quota-host"), {"requests": world.intents._rates[peer].count, "unchanged": state(world, true) == _read_json(path("quota-before"))})
		marker("quota-checked")
	else: await _wait_file(path("quota-checked"), 10.0)
	var quota := _read_json(path("quota-host"))
	check("farm_rate_quota_bounded", quota.get("requests") == 24 and quota.get("unchanged") == true and _read_json(path("quota-count")).get("responses") == 16)
	if not host:
		check("farm_guest_no_economic_replay", guest_events.item == 0 and guest_events.crop == 0)
		check("farm_guest_projection_only", world.farm_replication.projection != null and not world.farm_replication.projection.till(cell) and world.area == null and world.farm == null and not world.ready_for_play)
		check("farm_guest_no_save", not root.get_node("SaveManager").save_game(0) and save_hashes(root.get_node("SaveManager").save_dir) == files_before)
	details["rounds"] = rounds

func path(id: String) -> String: return str(options.directory).path_join(id)
func key(at: Vector2i) -> String: return "%d,%d" % [at.x, at.y]

func state(world: Node, host: bool) -> Dictionary:
	var registry: Script = load("res://scripts/world2d/player_registry.gd")
	var rows := {}
	for body in world.all_players():
		var row: RefCounted = registry.peek_state(body.player_id)
		rows[str(body.player_id)] = {"peer": body.peer_id, "gold": row.gold, "inventory": row.to_dict().inventory, "stamina": body.stamina, "max_stamina": body.max_stamina}
	var grid: Node = world.farm if host else world.farm_replication.projection
	return JSON.parse_string(JSON.stringify({"rows": rows, "farm": grid.to_dict() if grid != null else {}}))

func round_request(world: Node, host: bool, label: String, op: StringName, at: Vector2i, item: StringName, raw: Dictionary = {}) -> void:
	# Fixed production cooldown is respected, never shortened by the fixture.
	for tick in 24: await physics_frame
	if host:
		_write_json(path(label + "-before"), state(world, true))
		marker(label + "-go")
	else:
		await _wait_file(path(label + "-go"), 10.0)
		if str(options.role) == "guest1":
			world.intents.last_result = {}
			if raw.has("burst"):
				world.intents.submit(op, at, item)
				world.intents.submit(&"water", at, &"watering_can_copper")
			elif raw.is_empty(): world.intents.submit(op, at, item)
			else:
				if not raw.has("replay"): world.intents._sequence += 1
				var payload := {"epoch": world.session._host_generation, "seq": world.intents._sequence, "op": str(op), "cell": [at.x, at.y], "item": str(item)}
				for field in raw:
					if field != "replay": payload[field] = raw[field]
				world.intents._request.rpc_id(1, JSON.stringify(payload).to_utf8_buffer())
			var end := Time.get_ticks_msec() + 1000
			while (world.intents.last_result.is_empty() or (raw.has("burst") and int(world.intents.last_result.get("seq", -1)) != world.intents._sequence)) and Time.get_ticks_msec() < end: await process_frame
			for tick in 3: await physics_frame
			_write_json(path(label + "-result"), world.intents.last_result)
			marker(label + "-sent")
	if host:
		await _wait_file(path(label + "-sent"), 10.0)
		var after := state(world, true)
		world.farm_replication.publish()
		_write_json(path(label + "-after"), after)
		marker(label + "-checked")
	else:
		await _wait_file(path(label + "-checked"), 10.0)
	var expected := _read_json(path(label + "-after"))
	var deadline := Time.get_ticks_msec() + 1000
	var result := _read_json(path(label + "-result"))
	while not host and (state(world, false) != expected or world.intents.last_result != result) and Time.get_ticks_msec() < deadline: await process_frame
	rounds[label] = {"before": _read_json(path(label + "-before")), "after": expected, "result": result, "matched": state(world, host) == expected and (host or world.intents.last_result == result)}
	marker(label + "-observed-" + str(options.role))
	for i in range(1, int(options.count)): await _wait_file(path(label + "-observed-guest%d" % i), 10.0)

func count_item(row: Dictionary, item: String) -> int:
	var n := 0
	for slot in row.inventory:
		if slot.id == item: n += int(slot.amount)
	return n

func cost_owner(record: Dictionary, stamina_cost: float, item: String, delta: int) -> bool:
	var before: Dictionary = record.before.rows
	var after: Dictionary = record.after.rows
	for id in before:
		if id != str(farmer):
			if before[id] != after[id]: return false
		else:
			if not is_equal_approx(float(before[id].stamina) - float(after[id].stamina), stamina_cost) or before[id].gold != after[id].gold: return false
			if before[id].max_stamina != after[id].max_stamina: return false
			if item != "" and count_item(after[id], item) - count_item(before[id], item) != delta: return false
			if item != "" and before[id].inventory.filter(func(slot): return slot.id != item) != after[id].inventory.filter(func(slot): return slot.id != item): return false
			if item == "" and before[id].inventory != after[id].inventory: return false
	return true

func refused(record: Dictionary, reason: String) -> bool:
	return record.result.get("ok") == false and record.result.get("reason") == reason and record.before == record.after and record.matched
