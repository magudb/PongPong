extends RefCounted
## Regressions from the 2026-10-19 review of player interaction, combat input and world hosts; each group of checks names
## its finding id (DUN-01, GAP3-02/03/06/08/10/12/13, GAP4-02/04, SIM-03).
const SECTION := "interaction_review"
const TIMEOUT_S := 180.0

## 14 x 14 open iso platform with nothing on it: every host of the E checks is placed by the section.
const OPEN_MAP := """
@id _t_interaction
@projection iso
@ambient farm
@theme farm
@zone farm
@ground
##############
#............#
#............#
#............#
#............#
#............#
#............#
#............#
#............#
#............#
#............#
#............#
#............#
##############
@objects
..............
..............
..............
..............
..............
..............
.......@......
..............
..............
..............
..............
..............
..............
..............
"""

## A host with the E-query contract of an opened chest or a dug spot.
class SpentProbe extends Interactable2D:
	var spent := true
	func is_spent() -> bool:
		return spent

## A rock: takes tool hits.
class RockProbe extends Interactable2D:
	var hits: Array = []
	func tool_hit(tool: String, power: int, _player: Node) -> bool:
		hits.append([tool, power])
		return true


func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0)
	var world: WorldRoot2D = t.world()
	await world.travel(&"_fixture_ortho", &"from_iso")
	for node in t.tree.get_nodes_in_group("enemy"):
		node.queue_free()
	await t.frames(2)
	DungeonRun.apply_preset("none")
	await _telegraph_only(t)
	await _dodge_direction(t)
	await _buffer_across_pause(t)
	WorldRoot2D.register_map(&"_t_interaction", AreaMap.parse_text(OPEN_MAP))
	await world.travel(&"_t_interaction", &"default")
	await _reach_touching(t)
	await _spent_hosts(t)
	await _tool_targets(t)
	await _hotbar_auto_assign(t)
	await world.travel(&"farm", &"default")
	WorldRoot2D.unregister_map(&"_t_interaction")
	await _axe_on_crops(t)
	await _placement_reasons(t)
	gm.clear_config_overrides()


## DUN-01: a lunge hits only inside its drawn band. Walking into the region from the south during the lunge used to hit through an
## upper-body hurtbox capsule while the feet were still ~100 ground px outside the band.
func _telegraph_only(t) -> void:
	var world: WorldRoot2D = t.world()
	var area := world.area
	var player: Player2D = world.player
	var origin := player.global_position + Vector2(300, 0)
	var enemy: Enemy2D = Enemy2D.create_marker({"kind": "ugleoje"}, origin, area.global_to_cell(origin), area)
	area.objects.add_child(enemy)
	enemy.set_awake(true)
	enemy.set_physics_process(false)
	enemy.begin_windup({"shape": "line", "width": 80, "length": 300, "direction": Vector2.LEFT}, .5, "dash")
	enemy.remaining = 0
	enemy._windup(Vector2.LEFT)
	player.combat._iframes = 0
	player.state = PlayerBody2D.S.FREE
	var hearts: int = player.half_hearts
	var lost := [0]
	var damage := func(amount: int) -> void: lost[0] += amount
	player.damaged.connect(damage)
	# feet walk north from 200 to 60 screen px south of the band's centre line (band half width 40 ground = 23.75 screen px)
	for y in [200.0, 160.0, 120.0, 90.0, 60.0]:
		player.global_position = origin + Vector2(-150, y)
		await t.physics(2)
		enemy._during_attack(1.0 / 60.0)
	t.check("lunge_spares_feet_outside_band", enemy.state == Enemy2D.S.LUNGE and lost[0] == 0 and player.half_hearts == hearts,
		"state %d, lost %d half hearts with the feet 60 screen px south of the band" % [enemy.state, lost[0]])
	player.global_position = origin + Vector2(-150, 0)
	await t.physics(1)
	enemy._during_attack(1.0 / 60.0)
	t.check("lunge_hits_feet_inside_band", lost[0] == enemy.hit_damage() and player.half_hearts == hearts - enemy.hit_damage(), "lost %d" % lost[0])
	player.damaged.disconnect(damage)
	enemy.queue_free()
	for ring in area.ground_fx.get_node("TelegraphPool").get_children():
		ring.finish()
	player.revive(origin + Vector2(-300, 0))
	player.combat._iframes = 0
	await t.physics(2)


## GAP3-06: a dodge runs parallel to the walk. The stick is already a ground vector; converting it again made a diagonal dodge 14 degrees steeper.
func _dodge_direction(t) -> void:
	var player: Player2D = t.world().player
	player.combat.cooldowns.dodge = 0
	t.hold(&"move_right")
	t.hold(&"move_back")
	await t.physics(6)
	var walk := Input.get_vector("move_left", "move_right", "move_forward", "move_back").normalized()
	var began: bool = player.combat.dodge()
	var dodge: Vector2 = player.combat._dodge_direction
	t.release(&"move_right")
	t.release(&"move_back")
	t.check("diagonal_dodge_parallel_to_walk", began and absf(rad_to_deg(dodge.angle_to(walk))) < 0.5,
		"walk %s, dodge %s (%.1f degrees apart)" % [walk, dodge, rad_to_deg(dodge.angle_to(walk))])
	await t.physics(int(ceil(float(GameData.combat("dodge_time", 0.3)) * 60.0)) + 6)    # the dodge runs on physics ticks
	# without input the dodge follows the last precise walking direction
	player.combat.cooldowns.dodge = 0
	player.combat_aim = Vector2(1, 1).normalized()
	t.check("idle_dodge_follows_last_walk", player.combat.dodge() and player.combat._dodge_direction.is_equal_approx(Vector2(1, 1).normalized()), str(player.combat._dodge_direction))
	await t.physics(int(ceil(float(GameData.combat("dodge_time", 0.3)) * 60.0)) + 6)    # the dodge runs on physics ticks
	player.combat.cooldowns.dodge = 0


## GAP3-12: a dodge buffered just before a pause or modal is dropped instead of firing on resume.
func _buffer_across_pause(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var player: Player2D = t.world().player
	for pauses in [true, false]:
		player.state = PlayerBody2D.S.FREE
		player.combat.cooldowns.dodge = 0.05
		player.combat.request(&"dodge")
		var buffered: bool = player.combat._buffer == &"dodge" and player.state == PlayerBody2D.S.FREE
		gm.push_modal(&"interaction_review", pauses)
		await t.physics(3)
		gm.pop_modal(&"interaction_review")
		player.combat.cooldowns.dodge = 0
		await t.physics(3)
		t.check("buffered_dodge_dropped_by_%s_modal" % ("pausing" if pauses else "open"), buffered and player.state != PlayerBody2D.S.DODGE and player.combat._buffer == &"",
			"state %d buffer %s" % [player.state, player.combat._buffer])
	player.state = PlayerBody2D.S.FREE


func _probe(t, host: Interactable2D, at: Vector2) -> Interactable2D:
	host.radius = Vector2(60, 60 * Iso.squash())          # the reach ellipse of an Npc2D (reach 60)
	t.world().area.objects.add_child(host)
	host.global_position = at
	return host


## GAP3-02: a host the body touches is found from every spot inside the player's cell. The query circle sat on the facing cell
## centre, 64-192 ground px ahead, so a touching NPC was missed from about a third of the positions facing S, W, N or E.
func _reach_touching(t) -> void:
	var area: IsoArea = t.world().area
	var player: Player2D = t.world().player
	var home: Vector2i = area.global_to_cell(player.global_position)
	var probe := _probe(t, Interactable2D.new(), player.global_position)
	var found := 0
	var total := 0
	var missed: Array = []
	for facing in [0, 2, 4, 6]:
		var ahead: Vector2 = Iso.to_ground(area.cell_to_global(home + area.facing_step(facing)) - area.cell_to_global(home)).normalized()
		for s in [-0.4, -0.15, 0.15, 0.4]:
			for u in [-0.4, -0.15, 0.15, 0.4]:
				player.global_position = area.cell_to_global(home) + s * Vector2(64, 38) + u * Vector2(-64, 38)
				player.facing8 = facing
				probe.global_position = player.global_position + Iso.to_screen(ahead * 40.0)   # body radii 25 + 14 ground px: touching
				await t.physics(1)
				total += 1
				if player.nearest_interactable() == probe:
					found += 1
				elif missed.size() < 4:
					missed.append([facing, s, u])
	t.check("touching_host_found_from_anywhere_in_cell", found == total, "%d of %d found, first misses (facing, s, u) %s" % [found, total, missed])
	probe.queue_free()
	player.global_position = area.cell_to_global(home)
	player.facing8 = 0
	await t.physics(2)


## GAP3-03: an emptied chest or dug spot never takes E (or blanks the prompt) from a live host in reach, but still answers when it is alone.
func _spent_hosts(t) -> void:
	var area: IsoArea = t.world().area
	var player: Player2D = t.world().player
	var home: Vector2i = area.global_to_cell(player.global_position)
	player.global_position = area.cell_to_global(home)
	player.facing8 = 0
	var ahead: Vector2 = area.cell_to_global(home + area.facing_step(0))
	var spent: SpentProbe = _probe(t, SpentProbe.new(), player.global_position + Vector2(0, 30))
	var live := _probe(t, Interactable2D.new(), ahead)
	await t.physics(2)
	t.check("spent_host_yields_to_live_host", player.nearest_interactable() == live)
	live.set_enabled(false)
	await t.physics(2)
	t.check("spent_host_alone_still_answers", player.nearest_interactable() == spent)
	spent.spent = false
	t.check("refilled_host_is_live_again", player.nearest_interactable() == spent)
	spent.queue_free()
	live.queue_free()
	var dig := DigSpot2D.new()
	dig.spent = true
	var chest := LootChest2D.new()
	chest.is_open = true
	var closed := LootChest2D.new()
	var spot := UniqueSpot2D.new()
	spot.claimed = true
	t.check("spent_states_follow_the_contract", dig.is_spent() and chest.is_spent() and not closed.is_spent() and spot.is_spent())
	for node in [dig, chest, closed, spot]:
		node.free()
	await t.physics(2)


## GAP3-03 (merged GAP3-04): a tool looks past nearer hosts it cannot act on. The axe asked only the single nearest host for tool_hit.
func _tool_targets(t) -> void:
	var area: IsoArea = t.world().area
	var player: Player2D = t.world().player
	var home: Vector2i = area.global_to_cell(player.global_position)
	player.global_position = area.cell_to_global(home)
	player.facing8 = 0
	player.state = PlayerBody2D.S.FREE
	player.stamina = player.max_stamina
	var sign_host := _probe(t, Interactable2D.new(), player.global_position + Vector2(0, 30))
	var rock: RockProbe = _probe(t, RockProbe.new(), area.cell_to_global(home + area.facing_step(0)))
	await t.physics(2)
	player.hotbar.assign(0, &"axe_wooden")
	player.hotbar.select(0)
	var nearest_is_sign: bool = player.nearest_interactable() == sign_host
	t.check("axe_reaches_rock_past_nearer_host", nearest_is_sign and player.use_selected() and rock.hits.size() == 1 and rock.hits[0][0] == "axe", str(rock.hits))
	player.state = PlayerBody2D.S.FREE
	player._tool_time = 0.0
	sign_host.queue_free()
	rock.queue_free()
	await t.physics(2)


## A farm cell to aim at from the cell before it (facing S): `pick` (cell -> bool) decides; Vector2i.MAX when none fits.
func _aim_cell(t, cells: Array, pick: Callable) -> Vector2i:
	var area: IsoArea = t.world().area
	var player: Player2D = t.world().player
	for cell in cells:
		var stand: Vector2i = cell - area.facing_step(0)
		if not area.is_walkable(stand) or not pick.call(cell):
			continue
		player.global_position = area.cell_to_global(stand)
		player.facing8 = 0
		player.state = PlayerBody2D.S.FREE
		player._tool_time = 0.0
		player.stamina = player.max_stamina
		return cell
	return Vector2i.MAX


func _whispers(keys: Array) -> Callable:
	var listen := func(key: String) -> void: keys.append(key)
	EventBus.whisper_requested.connect(listen)
	return listen


## GAP4-02: the axe / pickaxe acts on the object it reaches first, harvests a ripe crop before clearing it, and says so when it
## clears a living one. It cleared any crop on the target cell first, losing a READY crop's yield, even when aimed past it.
func _axe_on_crops(t) -> void:
	var world: WorldRoot2D = t.world()
	var area: IsoArea = world.area
	var player: Player2D = world.player
	var farm: FarmGrid = world.farm
	var eco: Node = t.autoload("EconomyManager")
	eco.add_item(&"turnip_seeds", 3, true)
	player.hotbar.assign(0, &"axe_wooden")
	player.hotbar.select(0)
	var tool_free := func(cell: Vector2i) -> bool:
		player.global_position = area.cell_to_global(cell - area.facing_step(0))
		player.facing8 = 0
		return farm.state_of(cell) in [FarmGrid.State.EMPTY, FarmGrid.State.TILLED] and farm.can_till(cell) \
			and player.nearest_interactable(func(h: Node) -> bool: return h.has_method("tool_hit")) == null
	var cell := _aim_cell(t, farm.farmable_cells(), tool_free)
	if cell == Vector2i.MAX:
		t.fail("no free field cell to aim the axe at")
		return
	var keys: Array = []
	var listen := _whispers(keys)
	if farm.state_of(cell) == FarmGrid.State.EMPTY:
		farm.till(cell)
	farm.plant(cell, &"turnip_seeds")
	farm.get_plot(cell).state = FarmGrid.State.READY
	var turnips: int = eco.count_item(&"turnip")
	var ripe_ok: bool = player.use_selected()
	t.check("axe_harvests_ripe_crop_first", ripe_ok and eco.count_item(&"turnip") > turnips and farm.state_of(cell) == FarmGrid.State.TILLED, "ok %s turnips %d -> %d" % [ripe_ok, turnips, eco.count_item(&"turnip")])
	_aim_cell(t, [cell], func(_c: Vector2i) -> bool: return true)
	farm.plant(cell, &"turnip_seeds")
	keys.clear()
	t.check("axe_clears_living_crop_with_a_word", player.use_selected() and farm.state_of(cell) == FarmGrid.State.TILLED and keys == ["FARM_CROP_CLEARED"], str(keys))
	_aim_cell(t, [cell], func(_c: Vector2i) -> bool: return true)
	farm.plant(cell, &"turnip_seeds")
	var rock: RockProbe = _probe(t, RockProbe.new(), area.cell_to_global(cell + area.facing_step(7)))
	await t.physics(2)
	t.check("axe_hits_object_in_reach_before_crop", player.use_selected() and rock.hits.size() == 1 and farm.state_of(cell) == FarmGrid.State.PLANTED, "hits %s state %d" % [rock.hits, farm.state_of(cell)])
	rock.queue_free()
	farm.clear_crop(cell, false)
	EventBus.whisper_requested.disconnect(listen)
	player.state = PlayerBody2D.S.FREE
	player._tool_time = 0.0
	await t.physics(2)


## GAP4-04: the farm marker shows whether the HELD placeable can stand on the cell, and a refusal names its reason. The marker showed
## tillability (gold on the fields, where a decoration is refused) and every refusal said "Det kan vi prøve en anden dag".
func _placement_reasons(t) -> void:
	var world: WorldRoot2D = t.world()
	var area: IsoArea = world.area
	var player: Player2D = world.player
	var farm: FarmGrid = world.farm
	t.autoload("EconomyManager").add_item(&"scarecrow", 1, true)
	player.hotbar.assign(0, &"scarecrow")
	player.hotbar.select(0)
	var field := _aim_cell(t, farm.farmable_cells(), func(c: Vector2i) -> bool: return farm.state_of(c) in [FarmGrid.State.EMPTY, FarmGrid.State.TILLED])
	await t.physics(2)
	var keys: Array = []
	var listen := _whispers(keys)
	var field_marker: bool = player._marker.valid
	t.check("decoration_marker_dark_on_field", field != Vector2i.MAX and not field_marker and PlacementService.can_place(&"scarecrow", field) == "FARM_PLACE_FIELD")
	t.check("decoration_refusal_names_the_field", not player.use_selected() and keys == ["FARM_PLACE_FIELD"], str(keys))
	var grass_cells: Array = []
	for y in area.map.height:
		for x in area.map.width:
			grass_cells.append(Vector2i(x, y))
	var grass := _aim_cell(t, grass_cells, func(c: Vector2i) -> bool: return PlacementService.can_place(&"scarecrow", c) == "")
	await t.physics(2)
	t.check("decoration_marker_gold_where_it_fits", grass != Vector2i.MAX and player._marker.valid)
	EventBus.whisper_requested.disconnect(listen)


## GAP3-10: "use" of a placeable from the backpack never overwrites the selected tool on a full hotbar, and never duplicates a slot.
func _hotbar_auto_assign(t) -> void:
	var player: Player2D = t.world().player
	var bar: Hotbar = player.hotbar
	var before := bar.to_dict()
	var whispers: Array = []
	var listen := func(key: String) -> void: whispers.append(key)
	EventBus.whisper_requested.connect(listen)
	var kit: Array[StringName] = [&"hoe_wooden", &"watering_can_copper", &"axe_wooden", &"pickaxe_wooden", &"scythe", &"turnip_seeds", &"sword_rusty", &"health_tonic"]
	for i in Hotbar.SIZE:
		bar.assign(i, kit[i])
	bar.select(2)
	var full := bar.slots.duplicate()
	EventBus.hotbar_assign_requested.emit(-1, &"scarecrow")
	t.check("full_hotbar_refuses_auto_assign", bar.slots == full and bar.selected == 2 and whispers == ["HUD_HOTBAR_FULL"], "%s selected %d whispers %s" % [bar.slots, bar.selected, whispers])
	EventBus.hotbar_assign_requested.emit(-1, &"turnip_seeds")
	t.check("held_item_is_selected_not_duplicated", bar.slots == full and bar.selected == 5 and bar.slots.count(&"turnip_seeds") == 1)
	bar.assign(3, &"")
	EventBus.hotbar_assign_requested.emit(-1, &"scarecrow")
	t.check("free_slot_takes_item_in_hand", bar.slots[3] == &"scarecrow" and bar.selected == 3 and bar.slots[2] == &"axe_wooden")
	EventBus.whisper_requested.disconnect(listen)
	bar.from_dict(before)
