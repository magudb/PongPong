extends RefCounted
## Mouse targeting (owner request 2026-10-20: "use the mouse to click on the ground around the character so that it can be used
## for tools and weapons"). Every hover and click is a REAL event fed through Input at the window position of a ground point,
## so the GUI sees it first and the window stretch applies, as in play. Group "input".
const SECTION := "mouse_targeting"
const TIMEOUT_S := 240.0

const HOE := &"hoe_wooden"
const CAN := &"watering_can_copper"
const SEEDS := &"turnip_seeds"

var _last_screen := Vector2.ZERO

## The window position of a ground point: the canvas transform (camera zoom, smoothing) and the window's own stretch.
func _window_pos(p: Player2D, at: Vector2) -> Vector2:
	return p.get_viewport_transform() * at

## The same position computed from the camera alone (not from the transform the player converts with): what the screen shows.
func _camera_pos(p: Player2D, at: Vector2) -> Vector2:
	var view: Vector2 = p.get_viewport().get_visible_rect().size
	var screen: Vector2 = view * 0.5 + (at - p.camera.get_screen_center_position()) * p.camera.zoom
	return p.get_tree().root.get_final_transform() * screen

func _motion_to(window_pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = window_pos
	ev.global_position = window_pos
	# A real move (the aim device switches only on a move of UiNavWatcher.MOUSE_MOVE_MIN or more).
	ev.relative = Vector2(30, 0) if window_pos.distance_to(_last_screen) < 30.0 else window_pos - _last_screen
	_last_screen = window_pos
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _button_at(window_pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	ev.pressed = pressed
	ev.position = window_pos
	ev.global_position = window_pos
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _hover(p: Player2D, at: Vector2) -> void:
	_motion_to(_window_pos(p, at))

func _press(p: Player2D, at: Vector2) -> void:
	_hover(p, at)
	_button_at(_window_pos(p, at), true)

func _release(p: Player2D, at: Vector2) -> void:
	_button_at(_window_pos(p, at), false)

func _click(p: Player2D, at: Vector2) -> void:
	_press(p, at)
	_release(p, at)

func _key(code: Key, pressed := true) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _stick() -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = JOY_AXIS_LEFT_X
	ev.axis_value = 0.9
	Input.parse_input_event(ev)
	ev = InputEventJoypadMotion.new()
	ev.axis = JOY_AXIS_LEFT_X
	ev.axis_value = 0.0
	Input.parse_input_event(ev)
	Input.flush_buffered_events()

func _free(p: Player2D) -> void:
	p.state = PlayerBody2D.S.FREE
	p._tool_time = 0.0
	p._using_item = &""
	p.stamina = p.max_stamina
	p.combat.reset()
	p.combat.tick(2.0)
	p.combat.attack_held = false
	p._cancel_flight()
	p._farm_use_held = false

func _select(p: Player2D, item: StringName) -> void:
	GameData.eco().add_item(item, 1, true)
	p.hotbar.assign(0, item)
	p.hotbar.select(0)

## A point inside a cell but off its centre: clicks never land on the exact centre.
func _in_cell(area: IsoArea, cell: Vector2i) -> Vector2:
	return area.cell_to_global(cell) + Vector2(9.0, -5.0)

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0)
	var world: WorldRoot2D = t.world()
	var p: Player2D = world.player as Player2D
	t.check("production_player", p != null)
	if p == null:
		return
	# A headless window never sees the pointer enter it, and the GUI tracks hover only for a pointer inside the window.
	t.tree.root.notification(Node.NOTIFICATION_VP_MOUSE_ENTER)
	world.call("_enter", &"farm", &"default")
	p.set_physics_process(false)
	_free(p)
	var centre := _open_field(world, p)
	if centre == Vector2i(-1, -1):
		t.skip("no 5 x 5 patch of free, tillable farm cells")
		return
	p.global_position = world.area.cell_to_global(centre)
	p.camera.reset_smoothing()
	await t.physics(2)
	_world_cells_free_of_gui(t, world, p, centre, "farm")
	_reach(t, world, p, centre)
	await _farm_clicks(t, world, p, centre)
	await _hold_repeats(t, world, p, centre)
	_marker_follows(t, world, p, centre)
	await _gui_never_reaches_world(t, world, p, centre)
	_keyboard_and_pad_unchanged(t, world, p, centre)
	_flight_refuses(t, world, p, centre)
	await _any_zoom_and_scale(t, world, p, centre)
	_clear_plots(world, centre)
	world.call("_enter", &"_fixture_ortho", &"default")
	p.set_physics_process(false)
	for node in t.tree.get_nodes_in_group("enemy"):
		node.queue_free()
	await t.physics(2)
	_free(p)
	_world_cells_free_of_gui(t, world, p, world.area.global_to_cell(p.global_position), "action area")
	await _weapon_aim(t, world, p)
	await _tools_on_clicked_hosts(t, world, p)
	# The town HUD (festival ribbon, birthday chips) must not cover the ground either.
	if world.call("_enter", &"hyggebyen", &"default"):
		p.set_physics_process(false)
		p.camera.reset_smoothing()
		await t.physics(2)
		_world_cells_free_of_gui(t, world, p, world.area.global_to_cell(p.global_position), "town")
	world.call("_enter", &"farm", &"default")
	_free(p)
	p.mouse_aim = false
	p.set_physics_process(true)

## A farm cell whose 5 x 5 neighbourhood is free, tillable soil with no host on it (the far clicks land two cells out).
func _open_field(world: WorldRoot2D, p: Player2D) -> Vector2i:
	for c in world.farm.farmable_cells():
		var ok := true
		for dx in range(-3, 4):
			for dy in range(-3, 4):
				var cell: Vector2i = c + Vector2i(dx, dy)
				ok = ok and world.farm.can_till(cell) and world.farm.state_of(cell) == FarmGrid.State.EMPTY and world.area.is_walkable(cell)
		if not ok:
			continue
		p.global_position = world.area.cell_to_global(c)
		if p.nearest_interactable() == null and p._host_at(c, func(_h: Node) -> bool: return true) == null:
			return c
	return Vector2i(-1, -1)

func _clear_plots(world: WorldRoot2D, centre: Vector2i) -> void:
	for dx in range(-3, 4):
		for dy in range(-3, 4):
			var cell := centre + Vector2i(dx, dy)
			if world.farm.plots.has(cell):
				world.farm.plots.erase(cell)
				world.farm.plot_changed.emit(cell)

## No GUI control may cover the ground around the hero: there a click is a world click and the marker shows.
func _world_cells_free_of_gui(t, world: WorldRoot2D, p: Player2D, centre: Vector2i, where: String) -> void:
	var covered: Array[String] = []
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			_hover(p, _in_cell(world.area, centre + Vector2i(dx, dy)))
			var over: Control = p.get_viewport().gui_get_hovered_control()
			if over != null:
				covered.append("%s: %s" % [centre + Vector2i(dx, dy), over.get_path()])
	t.check("ground_around_hero_free_of_gui_%s" % where.replace(" ", "_"), covered.is_empty(), ", ".join(covered))

## The cell under the cursor within the nine cells around the feet; beyond them the neighbour toward the cursor; seeds never underfoot.
func _reach(t, world: WorldRoot2D, p: Player2D, centre: Vector2i) -> void:
	var area: IsoArea = world.area
	p.facing8 = 0
	var wrong: Array[String] = []
	for index in 8:
		var step: Vector2i = area.facing_step(index)
		_hover(p, _in_cell(area, centre + step))
		if p.cursor_cell(HOE) != centre + step:
			wrong.append("near %d -> %s" % [index, p.cursor_cell(HOE)])
		_hover(p, area.cell_to_global(centre + step * 3))
		if p.cursor_cell(HOE) != centre + step:
			wrong.append("far %d -> %s" % [index, p.cursor_cell(HOE)])
	t.check("cursor_cell_within_reach_and_clamped", wrong.is_empty() and p.mouse_aim, ", ".join(wrong))
	_hover(p, _in_cell(area, centre))
	var feet_ok: bool = p.cursor_cell(HOE) == centre and p.cursor_cell(CAN) == centre
	var seeds_ahead: bool = p.cursor_cell(SEEDS) == p.target_cell() and p.target_cell() != centre
	t.check("feet_cell_for_tools_never_for_seeds", feet_ok and seeds_ahead, "hoe %s, can %s, seeds %s (facing %s)" % [p.cursor_cell(HOE), p.cursor_cell(CAN), p.cursor_cell(SEEDS), p.target_cell()])

## Till, water, plant and harvest the clicked cell; the hero turns toward it; a click beyond reach works the neighbour toward it.
func _farm_clicks(t, world: WorldRoot2D, p: Player2D, centre: Vector2i) -> void:
	var area: IsoArea = world.area
	var farm: Node = world.farm
	var eco: Node = GameData.eco()
	var used: Array = []
	var record := func(item, cell, ok): used.append([item, cell, ok])
	p.tool_used.connect(record)
	p.facing8 = 0
	p.facing_vec = Iso.dir8_vector(0)
	var east: Vector2i = centre + area.facing_step(6)
	_select(p, HOE)
	_click(p, _in_cell(area, east))
	var tilled: bool = farm.state_of(east) == FarmGrid.State.TILLED and farm.state_of(centre + area.facing_step(0)) == FarmGrid.State.EMPTY
	t.check("click_tills_clicked_cell", tilled and used.size() == 1 and used[0][1] == east, "east %s state %d, facing cell state %d, tool_used %s" % [east, farm.state_of(east), farm.state_of(centre + area.facing_step(0)), used])
	t.check("click_turns_hero_toward_cell", p.facing8 == 6 and p.target_cell() == east, "facing8 %d" % p.facing8)
	_free(p)
	_select(p, CAN)
	_click(p, _in_cell(area, east))
	t.check("click_waters_clicked_cell", farm.get_plot(east) != null and farm.get_plot(east).watered)
	_free(p)
	if not farm.in_season(&"turnip"):
		t.skip("turnips are out of season: plant / harvest by click")
	else:
		_select(p, SEEDS)
		var seeds: int = eco.count_item(SEEDS)
		_click(p, _in_cell(area, east))
		var planted: bool = farm.get_plot(east).crop_id == &"turnip" and eco.count_item(SEEDS) == seeds - 1
		t.check("click_plants_clicked_cell", planted, "crop %s, seeds %d -> %d" % [farm.get_plot(east).crop_id, seeds, eco.count_item(SEEDS)])
		_free(p)
		farm.get_plot(east).state = FarmGrid.State.READY
		_select(p, HOE)
		p.facing8 = 0
		var turnips: int = eco.count_item(&"turnip")
		_click(p, _in_cell(area, east))
		t.check("click_harvests_ripe_crop_like_e", farm.state_of(east) != FarmGrid.State.READY and eco.count_item(&"turnip") > turnips and p.facing8 == 6,
			"state %d, turnips %d -> %d" % [farm.state_of(east), turnips, eco.count_item(&"turnip")])
		_free(p)
	# Beyond reach: the neighbour toward the click (west), never the clicked far cell.
	var west: Vector2i = centre + area.facing_step(2)
	_select(p, HOE)
	_click(p, area.cell_to_global(centre + area.facing_step(2) * 3))
	t.check("far_click_works_neighbour_toward_it", farm.state_of(west) == FarmGrid.State.TILLED and farm.state_of(centre + area.facing_step(2) * 3) == FarmGrid.State.EMPTY and p.facing8 == 2)
	_free(p)
	p.tool_used.disconnect(record)

## Holding the button and moving the cursor repeats the tool on each newly targeted cell, once per cell.
func _hold_repeats(t, world: WorldRoot2D, p: Player2D, centre: Vector2i) -> void:
	var area: IsoArea = world.area
	var farm: Node = world.farm
	_select(p, HOE)
	var path: Array[Vector2i] = [centre + area.facing_step(4), centre + area.facing_step(5), centre + area.facing_step(3)]
	var used: Array = []
	var record := func(_item, cell, ok):
		if ok: used.append(cell)
	p.tool_used.connect(record)
	p.set_physics_process(true)
	_press(p, _in_cell(area, path[0]))
	for cell in path.slice(1):
		await t.physics(30)
		_hover(p, _in_cell(area, cell))
	await t.physics(30)
	_release(p, _in_cell(area, path[-1]))
	await t.physics(2)
	p.set_physics_process(false)
	p.tool_used.disconnect(record)
	var all_tilled := true
	for cell in path:
		all_tilled = all_tilled and farm.state_of(cell) == FarmGrid.State.TILLED
	t.check("held_click_repeats_on_new_cells", all_tilled and used == path and not p._farm_use_held, "tilled %s, uses %s" % [all_tilled, used])
	_free(p)

## The marker follows the cursor's cell (valid / invalid) while the mouse is in use and returns to the facing cell with a pad.
func _marker_follows(t, world: WorldRoot2D, p: Player2D, centre: Vector2i) -> void:
	var area: IsoArea = world.area
	_select(p, HOE)
	p.facing8 = 0
	var cell: Vector2i = centre + area.facing_step(7)
	_hover(p, _in_cell(area, cell))
	p._update_target()
	var on_cursor: bool = p._marker.visible and p._marker.global_position.is_equal_approx(area.cell_to_global(cell)) and p._marker.valid == world.farm.can_till(cell)
	_hover(p, area.cell_to_global(centre + area.facing_step(1) * 4))
	p._update_target()
	var clamped: bool = p._marker.global_position.is_equal_approx(area.cell_to_global(centre + area.facing_step(1)))
	_stick()
	p._update_target()
	var back: bool = not p.mouse_aim and p._marker.global_position.is_equal_approx(p.target_global())
	t.check("marker_follows_cursor_then_facing_cell", on_cursor and clamped and back, "on cursor %s, clamped %s, back on the facing cell with a pad %s" % [on_cursor, clamped, back])

## A press on the hotbar or a HUD panel, and a click while a modal is open, never act on the ground; no marker over the HUD.
func _gui_never_reaches_world(t, world: WorldRoot2D, p: Player2D, centre: Vector2i) -> void:
	var area: IsoArea = world.area
	var hud: Node = world.game_ui.get_screen(&"hud")
	_select(p, HOE)
	var used: Array = []
	var record := func(item, cell, ok): used.append([item, cell, ok])
	p.tool_used.connect(record)
	var blocked: Array[String] = []
	var targets: Array[Control] = []
	if hud != null and hud.get("hotbar") is Control:
		targets.append(hud.hotbar.get_child(hud.hotbar.get_child_count() - 1) as Control)
	if hud != null and hud.get_node_or_null("DatePanel") is Control:
		targets.append(hud.get_node("DatePanel") as Control)
	for control in targets:
		if not control.is_visible_in_tree():
			continue
		var at: Vector2 = control.get_viewport().get_final_transform() * (control.get_global_transform_with_canvas() * (control.size * 0.5))
		_free(p)
		p.hotbar.select(0)
		_motion_to(at)
		p._update_target()
		var marker_hidden: bool = not p._marker.visible
		var stamina: float = p.stamina
		_button_at(at, true)
		_button_at(at, false)
		if not used.is_empty() or p.state != PlayerBody2D.S.FREE or p.stamina != stamina or not marker_hidden:
			blocked.append("%s: used %s, state %d, marker hidden %s, hovered %s" % [control.name, used, p.state, marker_hidden, p.get_viewport().gui_get_hovered_control()])
		used.clear()
	t.check("gui_clicks_never_reach_world", targets.size() == 2 and blocked.is_empty(), "%d targets; %s" % [targets.size(), ", ".join(blocked)])
	_free(p)
	p.hotbar.assign(0, HOE)
	p.hotbar.select(0)
	var cell: Vector2i = centre + area.facing_step(1)
	var gm: Node = t.autoload("GameManager")
	gm.push_modal(&"mouse_targeting_probe", true)
	await t.frames(2)
	_click(p, _in_cell(area, cell))
	# Straight to the handler as well: the modal gate itself refuses, whatever covers the screen.
	var direct := InputEventMouseButton.new()
	direct.button_index = MOUSE_BUTTON_LEFT
	direct.pressed = true
	direct.position = p.get_canvas_transform() * _in_cell(area, cell)
	p._unhandled_input(direct)
	gm.pop_modal(&"mouse_targeting_probe")
	await t.frames(2)
	t.check("modal_click_does_nothing_in_world", used.is_empty() and world.farm.state_of(cell) == FarmGrid.State.EMPTY and p.state == PlayerBody2D.S.FREE, str(used))
	p.tool_used.disconnect(record)
	_free(p)

## The X key (and the pad) keep today's facing cell even while the cursor rests on another cell.
func _keyboard_and_pad_unchanged(t, world: WorldRoot2D, p: Player2D, centre: Vector2i) -> void:
	var area: IsoArea = world.area
	_select(p, HOE)
	p.facing8 = 1
	p.facing_vec = Iso.dir8_vector(1)
	var cursor_cell: Vector2i = centre + area.facing_step(7)
	_hover(p, _in_cell(area, cursor_cell))
	var facing: Vector2i = p.target_cell()
	_key(KEY_X)
	_key(KEY_X, false)
	t.check("x_key_tills_facing_cell_not_cursor", not p.mouse_aim and world.farm.state_of(facing) == FarmGrid.State.TILLED and world.farm.state_of(cursor_cell) == FarmGrid.State.EMPTY and p.facing8 == 1,
		"facing %s state %d, cursor %s state %d" % [facing, world.farm.state_of(facing), cursor_cell, world.farm.state_of(cursor_cell)])
	_free(p)

## Tools are refused in flight: a click does what the X key does there (nothing), and the hero does not turn.
func _flight_refuses(t, world: WorldRoot2D, p: Player2D, centre: Vector2i) -> void:
	var area: IsoArea = world.area
	_free(p)
	if not p.can_fly_here():
		t.skip("this hero cannot fly on the farm (run with --character=fairy)")
		return
	_select(p, HOE)
	p.facing8 = 0
	p.toggle_flight()
	var cell: Vector2i = centre + area.facing_step(7)
	var stamina: float = p.stamina
	_click(p, _in_cell(area, cell))
	var click_refused: bool = world.farm.state_of(cell) == FarmGrid.State.EMPTY and p.facing8 == 0 and p.stamina == stamina
	_key(KEY_X)
	_key(KEY_X, false)
	var key_refused: bool = world.farm.state_of(p.target_cell()) == FarmGrid.State.EMPTY
	t.check("flight_refuses_click_like_key", p.is_flying and click_refused and key_refused, "flying %s, click refused %s, key refused %s" % [p.is_flying, click_refused, key_refused])
	_free(p)

## The cursor cell matches what the camera shows at both zoom limits, while the camera is still smoothing toward the hero,
## and with a 2x window stretch (a Retina screen): the event positions arrive in viewport coordinates.
func _any_zoom_and_scale(t, world: WorldRoot2D, p: Player2D, centre: Vector2i) -> void:
	var area: IsoArea = world.area
	var range: Vector2 = area.zoom_range
	var wrong: Array[String] = []
	for z in [range.x, range.y]:
		p.set_zoom(z)
		await t.physics(2)
		for index in [0, 3, 6]:
			var cell: Vector2i = centre + area.facing_step(index)
			_motion_to(_camera_pos(p, _in_cell(area, cell)))
			if p.cursor_cell(HOE) != cell:
				wrong.append("zoom %.2f dir %d -> %s" % [z, index, p.cursor_cell(HOE)])
	p.set_zoom(area.zoom_default)
	# Smoothing: the hero steps one cell, the camera lags behind it for a few ticks.
	p.global_position = area.cell_to_global(centre + area.facing_step(6))
	await t.physics(3)
	var lagging: bool = not p.camera.get_screen_center_position().is_equal_approx(p.global_position)
	var here: Vector2i = centre + area.facing_step(6)
	_motion_to(_camera_pos(p, _in_cell(area, here + area.facing_step(2))))
	if p.cursor_cell(HOE) != here + area.facing_step(2):
		wrong.append("smoothing -> %s" % p.cursor_cell(HOE))
	p.global_position = area.cell_to_global(centre)
	p.camera.reset_smoothing()
	await t.physics(2)
	var root: Window = t.tree.root
	var factor: float = root.content_scale_factor
	root.content_scale_factor = factor * 2.0
	await t.physics(2)
	var stretched: bool = not root.get_final_transform().is_equal_approx(Transform2D.IDENTITY)
	for index in [1, 5]:
		var cell: Vector2i = centre + area.facing_step(index)
		_motion_to(_camera_pos(p, _in_cell(area, cell)))
		if p.cursor_cell(HOE) != cell:
			wrong.append("stretch dir %d -> %s" % [index, p.cursor_cell(HOE)])
	root.content_scale_factor = factor
	await t.physics(2)
	t.check("cursor_cell_at_any_zoom_smoothing_and_stretch", wrong.is_empty() and lagging and stretched, "lagging camera %s, stretched window %s; %s" % [lagging, stretched, ", ".join(wrong)])

## The swing goes toward the clicked ground point, measured from the slash's origin; a buffered click keeps its press position.
func _weapon_aim(t, world: WorldRoot2D, p: Player2D) -> void:
	var eco: Node = GameData.eco()
	eco.add_item(&"wpn_spear_iron", 1, true)
	eco.equip(&"weapon", &"wpn_spear_iron")
	_select(p, HOE)
	var lift := Vector2(0, PlayerCombat2D.SLASH_LIFT)
	var bad: Array[String] = []
	for ground in [Vector2(260, -140), Vector2(-90, 210), Vector2(-300, -20)]:
		_free(p)
		var at: Vector2 = p.global_position + Iso.to_screen(ground)
		_click(p, at)
		var want: Vector2 = Iso.to_ground(at - p.global_position - lift).normalized()
		var swung: bool = p.state == PlayerBody2D.S.SWING and p.combat._swing_direction.dot(want) > 0.999 and p.facing8 == Iso.dir8_of(Iso.to_screen(want))
		if not swung:
			bad.append("%s: state %d dir %s want %s facing %d" % [ground, p.state, p.combat._swing_direction, want, p.facing8])
	t.check("click_swings_toward_clicked_ground", bad.is_empty(), ", ".join(bad))
	_free(p)
	# During the cooldown the click is buffered; the cursor then moves away before it fires.
	var first: Vector2 = p.global_position + Iso.to_screen(Vector2(250, 0))
	_click(p, first)
	p.combat.tick(p.combat.cooldowns.slash - 0.1)
	p.state = PlayerBody2D.S.FREE
	var pressed_at: Vector2 = p.global_position + Iso.to_screen(Vector2(0, 260))
	_click(p, pressed_at)
	var waiting: bool = p.state == PlayerBody2D.S.FREE and p.combat._buffer == &"slash"
	_hover(p, p.global_position + Iso.to_screen(Vector2(0, -260)))
	p.combat.tick(0.12)
	var want_buffered: Vector2 = Iso.to_ground(pressed_at - p.global_position - lift).normalized()
	t.check("buffered_click_aims_at_press_position", waiting and p.state == PlayerBody2D.S.SWING and p.combat._swing_direction.dot(want_buffered) > 0.999,
		"buffered %s, state %d, dir %s want %s" % [waiting, p.state, p.combat._swing_direction, want_buffered])
	_free(p)

## In an action area a click on a rock with the pickaxe mines that rock (and turns toward it); a click on empty ground, on a rock
## with the axe, or on a rock beyond reach is a swing toward the click.
func _tools_on_clicked_hosts(t, world: WorldRoot2D, p: Player2D) -> void:
	var area: IsoArea = world.area
	var feet: Vector2i = area.global_to_cell(p.global_position)
	p.facing8 = 0
	p.facing_vec = Iso.dir8_vector(0)
	var ore_cell: Vector2i = feet + area.facing_step(6)
	var ore: Node = ResourceNode2D.create_marker({"kind": "copper_ore"}, area.cell_to_global(ore_cell), ore_cell, area)
	if ore == null:
		t.skip("no copper ore node in the fixture")
		return
	area.objects.add_child(ore)
	await t.physics(2)
	_select(p, &"pickaxe_wooden")
	var hp: int = ore.hp
	_click(p, _in_cell(area, ore_cell))
	t.check("click_pickaxe_mines_clicked_rock", p.state == PlayerBody2D.S.USING and ore.hp == hp - 1 and p.facing8 == 6, "state %d, hp %d -> %d, facing %d" % [p.state, hp, ore.hp, p.facing8])
	_free(p)
	hp = ore.hp
	var empty: Vector2i = feet + area.facing_step(2)
	_click(p, _in_cell(area, empty))
	var swung_west: bool = p.state == PlayerBody2D.S.SWING and ore.hp == hp and p.combat._swing_direction.x < -0.9
	_free(p)
	_select(p, &"axe_wooden")
	_click(p, _in_cell(area, ore_cell))
	var axe_swings: bool = p.state == PlayerBody2D.S.SWING and ore.hp == hp
	_free(p)
	t.check("click_empty_or_wrong_tool_swings", swung_west and axe_swings, "empty cell swings west %s, axe on rock swings %s" % [swung_west, axe_swings])
	# The rock three cells out is beyond reach: the click works the empty neighbour toward it, a swing.
	ore.global_position = area.cell_to_global(feet + area.facing_step(6) * 3)
	await t.physics(2)
	_select(p, &"pickaxe_wooden")
	hp = ore.hp
	_click(p, _in_cell(area, feet + area.facing_step(6) * 3))
	t.check("click_rock_beyond_reach_swings", p.state == PlayerBody2D.S.SWING and ore.hp == hp, "state %d, hp %d -> %d" % [p.state, hp, ore.hp])
	_free(p)
	ore.queue_free()
	await t.physics(2)
