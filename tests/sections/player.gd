extends RefCounted
const SECTION := "player"
const TIMEOUT_S := 170.0

class EnemyProbe extends Node2D:
	var hits: int = 0
	var frozen: int = 0
	func take_hit(_damage: int, _from: Vector2, _attacker: Node) -> void:
		hits += 1
	func hit_stop(frames: int) -> void:
		frozen = frames

func run(t) -> void:
	await t.start_world()
	var world: WorldRoot2D = t.world()
	var p: Player2D = world.player as Player2D
	t.check("production_scene", p != null)
	if p == null:
		return
	var gm: Node = t.autoload("GameManager")
	var eco: Node = t.autoload("EconomyManager")
	var bus: Node = t.autoload("EventBus")
	gm.hour = 12
	p.set_physics_process(false)
	t.check("geometry", p.scale == Vector2.ONE and p.visual.scale == Vector2.ONE and p.get_node("Body").shape.points.size() == 12)
	t.check("perks_speed_energy_applied", is_equal_approx(p._walk, 285.0 * (1.0 + Perks.total("speed"))) and is_equal_approx(p._run, 450.0 * (1.0 + Perks.total("speed"))) and is_equal_approx(p.max_stamina, 100.0 + Perks.total("energy")) and p._accel == 2500 and p._decel == 3300)
	var seen: Array = []
	var stats := func(values: Dictionary) -> void: seen.append(values.duplicate())
	bus.player_stats_changed.connect(stats)
	var idle_us: float = t.median_usec(func() -> void: p._physics_process(1.0 / 60.0), 10, 10)
	t.check("idle_controller_budget", t.perf_ok("idle_controller_budget", idle_us, 300.0), "%.2f microseconds per tick, median of 10 batches of 10 (native reference 300, runner limit %.0f)" % [idle_us, t.perf_limit(300.0)])
	t.check("idle_stats_are_quiet", seen.is_empty(), str(seen.size()))
	p.stamina = 20
	p.restore_stamina(10)
	t.check("four_key_stats_signal", seen.size() == 1 and seen[0].size() == 4 and seen[0].stamina == 30)
	p.heal_half(999)
	p.half_hearts = 2
	seen.clear()
	p.heal_half(2)
	p.heal_half(0)
	t.check("heal_half_clamps_and_emits_once", seen.size() == 1 and p.half_hearts == 4)
	bus.player_stats_changed.disconnect(stats)
	p.restore_after_sleep()
	t.hold(&"run")
	t.hold(&"move_right")
	p.stamina = 1.0
	p._physics_process(0.2)
	t.check("run_exhausts_at_zero", p.stamina == 0 and p._exhausted)
	t.release(&"run")
	t.release(&"move_right")
	p.stamina = p.max_stamina * 0.19
	p._physics_process(0.0)
	t.check("run_hysteresis_waits_below_20_percent", p._exhausted)
	p.stamina = p.max_stamina * 0.2
	p._physics_process(0.0)
	t.check("run_recovers_at_20_percent", not p._exhausted)
	p._regen_delay = 0.0
	p.stamina = 10.0
	p._physics_process(1.0)
	t.check("configured_stamina_regen", is_equal_approx(p.stamina, 10.0 + float(GameData.player_cfg("stamina_regen_per_second", 12))))
	p.restore_after_sleep()
	var hb: Array = []
	var hotbar_signal := func(entries: Array, selected: int) -> void: hb.append({"entries": entries, "selected": selected})
	bus.hotbar_changed.connect(hotbar_signal)
	p._emit_hotbar()
	t.check("hotbar_signal_shape", hb.size() == 1 and hb[0].entries.size() == 8 and hb[0].entries[0].has_all(["id", "amount", "name", "rare"]))
	p.hotbar.assign(0, &"")
	bus.hotbar_assign_requested.emit(-1, &"carrot_seeds")
	t.check("hotbar_assign_first_free", p.hotbar.slots[0] == &"carrot_seeds")
	var first := p.hotbar.selected
	var dpad := InputEventJoypadButton.new()
	dpad.pressed = true
	dpad.button_index = JOY_BUTTON_DPAD_RIGHT
	p._unhandled_input(dpad)
	t.check("hotbar_dpad_cycle", p.hotbar.selected == posmod(first + 1, 8))
	gm.push_modal(&"player_test")
	var selected := p.hotbar.selected
	var zoom := p.camera.zoom
	for action in ["slot_1", "zoom_in", "interact", "use_tool", "jump", "fly_toggle", "attack", "dodge"]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = true
		p._unhandled_input(event)
	p._unhandled_input(dpad)
	t.check("world_input_guarded_by_modals", p.hotbar.selected == selected and p.camera.zoom == zoom and p.state == PlayerBody2D.S.FREE and not p.is_jumping and not p.is_flying)
	gm.pop_modal(&"player_test")
	bus.hotbar_changed.disconnect(hotbar_signal)
	# Farm tool use spends energy only after a successful model action.
	var cell: Vector2i = world.farm.farmable_cells()[0]
	p.facing8 = 0
	p.facing_vec = Iso.dir8_vector(0)
	p.global_position = world.area.cell_to_global(cell - world.area.facing_step(0))
	p.hotbar.assign(0, &"hoe_wooden")
	p.hotbar.select(0)
	var energy := p.stamina
	t.check("hoe_on_farm", p.use_selected() and world.farm.state_of(cell) == FarmGrid.State.TILLED and p.stamina < energy)
	p.state = PlayerBody2D.S.FREE
	energy = p.stamina
	t.check("failed_tool_is_free", not p.use_selected() and p.stamina == energy)
	p.hop()
	t.check("space_is_hop_on_farm", p.is_jumping)
	p._cancel_flight()
	var can_fly := p.can_fly_here()
	p.toggle_flight()
	t.check("flight_race_and_area_gate", p.is_flying == can_fly)
	if can_fly:
		p._update_vertical(8.1)
		t.check("flight_forces_safe_landing", not p.is_flying and p._landing and p._landing_safe(p._landing_at))
	p._cancel_flight()
	# Health, oil and energy survive re-entry; sleep restores all three.
	p.half_hearts = 4
	p.stamina = 30
	p.oil = 40
	world.call("_enter", &"_fixture_ortho", &"default")
	t.check("enter_preserves_stats", p.half_hearts == 4 and p.stamina == 30 and p.oil == 40 and not p.can_fly_here())
	p.set_physics_process(false)
	p.state = PlayerBody2D.S.FREE
	p.combat.reset()
	t.check("attack_starts", p.swing() and p.state == PlayerBody2D.S.SWING and p.cd_ratio("slash") > 0)
	t.check("dodge_cannot_cancel_early_swing", not p.dodge())
	p.combat.tick(0.13)
	t.check("dodge_cancels_after_40_percent", p.dodge() and p.state == PlayerBody2D.S.DODGE and p.invulnerable)
	p.combat.tick(0.5)
	p.state = PlayerBody2D.S.FREE
	# Real physics query: one enemy is hit once, even across several active swing frames.
	var enemy := EnemyProbe.new()
	var hurt := Area2D.new()
	hurt.collision_layer = Iso.LAYER_ENEMY
	hurt.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	collision.shape = shape
	hurt.add_child(collision)
	enemy.add_child(hurt)
	world.area.objects.add_child(enemy)
	enemy.global_position = p.global_position + Vector2(80.0, -6.0 * Iso.S)
	await t.physics(2)
	p.event_face(Vector2.RIGHT)
	p.combat.cooldowns.slash = 0.0
	p.swing()
	p.combat.tick(0.1)
	t.check("swing_hits_real_collider", enemy.hits == 1 and enemy.frozen == 3)
	var stopped := 0
	for frame in 3:
		p.combat.tick(1.0 / 60.0)
		if p.combat.stopped_this_tick:
			stopped += 1
	p.combat.tick(0.01)
	t.check("three_frame_hit_stop_and_no_duplicate_hit", stopped == 3 and enemy.hits == 1)
	enemy.free()
	p.state = PlayerBody2D.S.FREE
	p.combat.reset()
	p.combat.tick(2.0)
	p.half_hearts = 2
	var defeats: Array = []
	var defeated := func() -> void: defeats.append(true)
	# Avoid a real scene transition here; D0 tests the complete wake sequence separately.
	bus.player_defeated.disconnect(world._on_player_defeated)
	bus.player_defeated.connect(defeated)
	p.take_damage(99)
	p.take_damage(99)
	t.check("faint_emits_once", defeats == [true] and p.state == PlayerBody2D.S.FAINTED)
	bus.player_defeated.disconnect(defeated)
	bus.player_defeated.connect(world._on_player_defeated)
	p.revive(p.global_position)
	t.check("dungeon_restore_api", p.half_hearts == p.max_half_hearts and p.stamina == p.max_stamina and p.oil == p.max_oil)
	p.oil = 0
	p.add_oil(999)
	t.check("oil_clamps", p.oil == p.max_oil)
	p.half_hearts = 2
	p.oil = 0
	eco.remove_item(&"lantern_oil", eco.count_item(&"lantern_oil"))
	eco.remove_item(&"lysdraabe", eco.count_item(&"lysdraabe"))
	p._update_oil(13)
	t.check("dark_bite_floor", p.half_hearts == 2 and p.lantern.texture_scale > 0)
	# Stat observers see the consumed tonic already removed and cannot re-enter consumption.
	eco.add_item(&"health_tonic", 2, true)
	var tonics: int = eco.count_item(&"health_tonic")
	var observations: Array = []
	var consumed := func(_values: Dictionary) -> void:
		observations.append([eco.count_item(&"health_tonic"), eco.use_item(&"health_tonic")])
	bus.player_stats_changed.connect(consumed)
	t.check("consume_tonic", eco.use_item(&"health_tonic"))
	bus.player_stats_changed.disconnect(consumed)
	t.check("consumable_commits_before_stats_and_blocks_reentry", observations == [[tonics - 1, false]])
	world.call("_enter", &"farm", &"default")
	p.event_begin()
	t.check("event_input_frozen", not p.world_input_allowed() and p.state == PlayerBody2D.S.TALKING)
	p.event_face(Vector2.LEFT)
	t.check("event_face", p.facing8 == 2)
	var walked := await p.event_walk_to(p.global_position + Vector2(30.0, 0.0), 185.0)
	t.check("event_walk_moves_through_physics", walked)
	await p.camera_focus(p.global_position + Vector2(50, 0), 999.0, 0.01)
	t.check("camera_focus_clamped", p.camera.zoom.x == world.area.zoom_range.y)
	await p.camera_release(0.01)
	t.check("camera_focus_release_roundtrip", p.camera.offset == Vector2.ZERO and is_equal_approx(p.camera.zoom.x, world.area.zoom_default))
	p.event_end()
	t.check("event_releases_input", p.world_input_allowed())
	p.restore_after_sleep()
	p.set_physics_process(true)

func run_windowed(t) -> void:
	await t.start_world()
	var world: WorldRoot2D = t.world()
	var p: Player2D = world.player
	var gm: Node = t.autoload("GameManager")
	gm.hour = 12
	world.day_night.override_hour = 12.0
	world.day_night.snap()
	p.set_physics_process(false)
	var cells: Array = world.farm.farmable_cells()
	cells.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y or a.y == b.y and a.x < b.x)
	var middle: Vector2i = cells[cells.size() / 2]
	p.global_position = world.area.cell_to_global(middle + Vector2i(2, 2))
	p.camera.zoom = Vector2.ONE * 0.9
	p._apply_camera_limits()
	p.camera.reset_smoothing()
	p._update_target()
	var sheet: Sprite2D = _textured_sprite(p.visual)
	t.check("sprite_visible", sheet != null and sheet.texture != null and sheet.is_visible_in_tree())
	await t.frames(30)
	var with_player: Image = await t.capture("hero")
	p.visual.visible = false
	await t.frames(2)
	var without_player: Image = await t.capture()
	p.visual.visible = true
	var changed := 0
	var rect: Rect2 = sheet.get_global_transform_with_canvas() * sheet.get_rect()
	var region := Rect2i(rect).intersection(Rect2i(0, 0, with_player.get_width(), with_player.get_height()))
	for y in range(region.position.y, region.end.y, 2):
		for x in range(region.position.x, region.end.x, 2):
			var a := with_player.get_pixel(x, y)
			var b := without_player.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.08:
				changed += 1
	t.check("sprite_visible_pixels", changed > 100, "%d changed pixel samples" % changed)
	var crop_ids: Array = world.farm.crop_defs.keys()
	for stage in 4:
		var rows := {}
		for index in crop_ids.size():
			var cell := middle + Vector2i(index % 4 - 1, index / 4 - 1)
			if not world.farm.can_till(cell):
				cell = cells[cells.size() / 2 + index]
			var crop: String = crop_ids[index]
			var def: Dictionary = world.farm.crop_defs[crop]
			var growth := float(def.stages) * float(def.days_per_stage) * (float(stage) / 3.0 + (0.01 if stage in [1, 2] else 0.0))
			rows["%d,%d" % [cell.x, cell.y]] = {"state": 4 if stage == 3 else 3, "crop_id": crop, "growth_days": growth, "watered": true}
		world.farm.from_dict({"plots": rows})
		await t.frames(3)
		await t.capture("farm_0%d" % (stage + 1))
		var view: FarmView = world.area.get_node_or_null("FarmView")
		var painted := view != null and view._crops.size() == 8
		for cell in world.farm.plots:
			painted = painted and world.farm.visual_stage(cell) == stage and world.area.cell_kind(cell) == &"soil_watered"
			var crop: String = world.farm.get_plot(cell).crop_id
			painted = painted and view._crops[cell].texture == ArtCatalog.prop(StringName("crop_%s_%d" % [crop, stage])).texture
		t.check("painted_stage_%d" % stage, painted, "Eight approved painted crops, wet soil and matching stage textures")
	await _light_budget(t, world, p)
	p.set_physics_process(true)

func _textured_sprite(root: Node) -> Sprite2D:
	if root is Sprite2D and root.texture != null:
		return root
	for child in root.get_children():
		var found := _textured_sprite(child)
		if found != null:
			return found
	return null

func _light_budget(t, world: WorldRoot2D, p: Player2D) -> void:
	world.call("_enter", &"_fixture_ortho", &"default")
	world.day_night.override_hour = 23.0
	world.day_night.snap()
	p.set_physics_process(false)
	# The fixture already has a mushroom lamp. Isolate exactly fourteen other lights.
	for light in world.area.find_children("*", "PointLight2D", true, false):
		if not p.is_ancestor_of(light):
			light.enabled = false
	p.ghost_light.enabled = false
	p.combat._burst.enabled = false
	var probe := Polygon2D.new()
	probe.polygon = PackedVector2Array([Vector2(-48, -48), Vector2(48, -48), Vector2(48, 48), Vector2(-48, 48)])
	probe.color = Color.WHITE
	world.area.objects.add_child(probe)
	probe.global_position = p.global_position + Vector2(150, 0)
	p.lantern.enabled = true
	p.lantern.color = Color(1, 0, 0)
	p.lantern.energy = 1.0
	p.lantern.texture_scale = 4.0
	var lights: Array[PointLight2D] = []
	for index in 14:
		var light := PointLight2D.new()
		light.texture = Glow.light_texture()
		light.texture_scale = 4.0
		light.energy = 0.001
		world.area.objects.add_child(light)
		light.global_position = probe.global_position
		lights.append(light)
	for order in ["first", "last"]:
		if order == "last":
			var replacement := p.lantern.duplicate() as PointLight2D
			p.lantern.free()
			p.add_child(replacement)
			p.lantern = replacement
		await t.frames(5)
		var shot: Image = await t.capture("lantern_14_lights_" + order)
		var at: Vector2 = probe.get_global_transform_with_canvas() * Vector2.ZERO
		var color := shot.get_pixelv(Vector2i(at))
		t.check("lantern_survives_light_budget_" + order, color.r - color.g > 0.08, "R-G %.3f with 14 other lights" % (color.r - color.g))
	for light in lights:
		light.free()
	probe.free()
	p.combat._burst.enabled = true
	world.call("_enter", &"farm", &"default")
