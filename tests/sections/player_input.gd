extends RefCounted
## Player input regressions of the 2026-10-19 review (group "input"): what a REAL key, mouse or pad event does in
## Player2D._unhandled_input, the order of the shared bindings and the device-dependent aim.
const SECTION := "player_input"
const TIMEOUT_S := 200.0

class HostProbe extends Node2D:
	var used := 0
	func interact(_player: Node) -> void:
		used += 1
	func get_interaction_prompt() -> String:
		return "E: Probe"

func _mouse(button: MouseButton, pressed := true) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	return ev

func _pad(button: JoyButton, pressed := true) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = pressed
	return ev

func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	return ev

func _key(code: Key, pressed := true) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev

func _motion(relative: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.relative = relative
	return ev

func _free(p: Player2D) -> void:
	p.state = PlayerBody2D.S.FREE
	p.combat.reset()
	p.combat.tick(2.0)
	p.combat.attack_held = false
	p._cancel_flight()

func run_windowed(t) -> void:
	await run(t)

func run(t) -> void:
	_pad_families(t)
	await t.start_world()
	var world: WorldRoot2D = t.world()
	var p: Player2D = world.player as Player2D
	t.check("production_player", p != null)
	if p == null:
		return
	var eco: Node = t.autoload("EconomyManager")
	p.set_physics_process(false)
	p.restore_after_sleep()
	await _attack_before_tool(t, world, p, eco)
	_hop_on_pad_a(t, world, p)
	_keyboard_tool_key(t, world, p)
	_aim_follows_device(t, world, p)
	_mac_keys(t, world, p)
	await _pad_run_fly_zoom(t, world, p)
	_take_off_while_landing(t, world, p)
	await _prompt_follows_gate(t, world, p)
	_forced_landing_search(t, world, p)
	_oil_rules_direct(t, world, p, eco)
	world.call("_enter", &"farm", &"default")
	p.restore_after_sleep()
	_free(p)
	p.set_physics_process(true)
	await _pause_row_hotkeys(t, world)
	await _controls_page(t)

## DUN-07: in an action area LMB / pad X are the attack (buffer, held flag, Cozy auto-swing), never a hotbar consumable;
## only a selected tool with a node it can hit in front takes the press.
func _attack_before_tool(t, world: WorldRoot2D, p: Player2D, eco: Node) -> void:
	world.call("_enter", &"_fixture_ortho", &"default")
	p.set_physics_process(false)
	_free(p)
	eco.add_item(&"wpn_spear_iron", 1, true)
	eco.equip(&"weapon", &"wpn_spear_iron")
	eco.add_item(&"health_tonic", 2, true)
	p.hotbar.assign(0, &"health_tonic")
	p.hotbar.select(0)
	var tonics: int = eco.count_item(&"health_tonic")
	p._unhandled_input(_mouse(MOUSE_BUTTON_LEFT))
	var swung: bool = p.state == PlayerBody2D.S.SWING and p.combat.attack_held
	t.check("action_area_click_attacks_not_hotbar_item", swung and eco.count_item(&"health_tonic") == tonics, "state %d held %s tonics %d -> %d" % [p.state, p.combat.attack_held, tonics, eco.count_item(&"health_tonic")])
	p._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, false))
	t.check("attack_release_clears_held", not p.combat.attack_held)
	_free(p)
	var before_auto: Variant = DungeonRun.assist("assist_auto_swing")
	DungeonRun.set_assist("assist_auto_swing", 1)
	p._unhandled_input(_pad(JOY_BUTTON_X))
	var first: bool = p.state == PlayerBody2D.S.SWING
	for i in 90:
		p.combat.tick(1.0 / 60.0)
	var again: bool = p.state == PlayerBody2D.S.SWING or p.combat.cooldowns.slash > 0.0
	p._unhandled_input(_pad(JOY_BUTTON_X, false))
	DungeonRun.set_assist("assist_auto_swing", before_auto)
	t.check("pad_x_holds_cozy_auto_swing", first and again and not p.combat.attack_held and eco.count_item(&"health_tonic") == tonics)
	_free(p)
	# A swing pressed during the cooldown is buffered and fires as soon as it can.
	p._unhandled_input(_mouse(MOUSE_BUTTON_LEFT))
	p._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, false))
	p.combat.tick(p.combat.cooldowns.slash - 0.1)
	p.state = PlayerBody2D.S.FREE
	p._unhandled_input(_mouse(MOUSE_BUTTON_LEFT))
	p._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, false))
	var waiting: bool = p.state == PlayerBody2D.S.FREE and p.combat._buffer == &"slash"
	p.combat.tick(0.12)
	t.check("early_click_is_buffered", waiting and p.state == PlayerBody2D.S.SWING, "buffered %s, then state %d" % [waiting, p.state])
	_free(p)
	# Hotbar tools still work there: a pickaxe with ore in front mines, and with nothing in front the same click attacks.
	eco.add_item(&"pickaxe_wooden", 1, true)
	p.hotbar.assign(0, &"pickaxe_wooden")
	p.hotbar.select(0)
	var ore_cell: Vector2i = p.target_cell()
	var ore: Node = ResourceNode2D.create_marker({"kind": "copper_ore"}, p.target_global(), ore_cell, world.area)
	if ore == null:
		t.skip("no copper ore node in the fixture")
	else:
		world.area.objects.add_child(ore)
		await t.physics(2)
		var hp: int = ore.hp
		var used := []
		var record := func(item, _cell, ok): used.append([item, ok])
		p.tool_used.connect(record)
		p._unhandled_input(_mouse(MOUSE_BUTTON_LEFT))
		p._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, false))
		var mined: bool = p.state == PlayerBody2D.S.USING and ore.hp == hp - 1 and used == [[&"pickaxe_wooden", true]] and not p.combat.attack_held
		t.check("action_area_pickaxe_mines_ore_in_front", mined, "state %d, ore hp %d -> %d, tool_used %s" % [p.state, hp, ore.hp, used])
		ore.queue_free()
		_free(p)
		await t.physics(2)
		p._unhandled_input(_mouse(MOUSE_BUTTON_LEFT))
		var attacked: bool = p.state == PlayerBody2D.S.SWING and p.combat.attack_held and used.size() == 1
		p._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, false))
		p.tool_used.disconnect(record)
		t.check("action_area_pickaxe_attacks_with_no_target", attacked, "state %d, tool_used %s" % [p.state, used])
		_free(p)
	# A hotbar weapon in an iso area goes through the same request path.
	world.call("_enter", &"farm", &"default")
	p.set_physics_process(false)
	_free(p)
	p.hotbar.assign(0, &"wpn_spear_iron")
	p.hotbar.select(0)
	p._unhandled_input(_mouse(MOUSE_BUTTON_LEFT))
	t.check("iso_hotbar_weapon_uses_request", p.state == PlayerBody2D.S.SWING and p.combat.attack_held and p.combat.active_weapon_id() == &"wpn_spear_iron")
	p._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, false))
	_free(p)
	p.hotbar.assign(0, &"hoe_wooden")

## UX-03: mouse-free play: the X key tills on the farm and attacks in the forest.
func _keyboard_tool_key(t, world: WorldRoot2D, p: Player2D) -> void:
	world.call("_enter", &"farm", &"default")
	p.set_physics_process(false)
	_free(p)
	var spot: Vector2 = p.global_position
	var cell := Vector2i(-1, -1)
	for c in world.farm.farmable_cells():
		if world.farm.can_till(c):
			cell = c
			break
	if cell == Vector2i(-1, -1):
		t.skip("no tillable farm cell")
		return
	p.facing8 = 0
	p.facing_vec = Iso.dir8_vector(0)
	p.global_position = world.area.cell_to_global(cell - world.area.facing_step(0))
	p.hotbar.assign(0, &"hoe_wooden")
	p.hotbar.select(0)
	p._unhandled_input(_key(KEY_X))
	p._unhandled_input(_key(KEY_X, false))
	t.check("x_key_tills", world.farm.state_of(cell) == FarmGrid.State.TILLED)
	_free(p)
	p.global_position = spot
	world.call("_enter", &"_fixture_ortho", &"default")
	p.set_physics_process(false)
	_free(p)
	p._unhandled_input(_key(KEY_X))
	var swung: bool = p.state == PlayerBody2D.S.SWING and p.combat.attack_held
	p._unhandled_input(_key(KEY_X, false))
	t.check("x_key_attacks_in_action_area", swung and not p.combat.attack_held)
	_free(p)

## GAP3-11: pad A is interact and jump; with nothing in front it hops, with a host in front it interacts, and a target
## that refuses (a ripe crop that cannot be harvested) does not make it hop.
func _hop_on_pad_a(t, world: WorldRoot2D, p: Player2D) -> void:
	world.call("_enter", &"farm", &"default")
	p.set_physics_process(false)
	_free(p)
	var spot: Vector2 = p.global_position
	var found := false
	for cell in world.farm.farmable_cells():
		p.global_position = world.area.cell_to_global(cell)
		if p.nearest_interactable() == null and not (world.farm.state_of(p.target_cell()) == FarmGrid.State.READY):
			found = true
			break
	if not found:
		t.skip("no free farm cell without an interactable in front")
		p.global_position = spot
		return
	p._unhandled_input(_pad(JOY_BUTTON_A))
	t.check("pad_a_hops_with_nothing_in_front", p.is_jumping)
	_free(p)
	p.is_jumping = false
	p._vertical_speed = 0.0
	# A ripe crop that cannot be harvested (here the farm is mid-harvest, as with a full bag) refuses A: no hop.
	var cell := Vector2i(-1, -1)
	for c in world.farm.farmable_cells():
		p.global_position = world.area.cell_to_global(c - world.area.facing_step(p.facing8))
		if world.farm.can_till(c) and p.target_cell() == c and p.nearest_interactable() == null:
			cell = c
			break
	var tilled_here: bool = cell != Vector2i(-1, -1) and world.farm.till(cell)
	var plot: FarmGrid.PlotData = world.farm.get_plot(cell) if tilled_here else null
	if plot == null or world.farm.crop_defs.is_empty():
		t.skip("no tillable farm cell with nothing else in front")
	else:
		var before := [plot.crop_id, plot.state]
		plot.crop_id = StringName(str(world.farm.crop_defs.keys()[0]))
		plot.state = FarmGrid.State.READY
		world.farm._busy = true
		p._unhandled_input(_pad(JOY_BUTTON_A))
		world.farm._busy = false
		t.check("pad_a_refused_crop_does_not_hop", not p.is_jumping and world.farm.state_of(cell) == FarmGrid.State.READY, "jumping %s, state %d" % [p.is_jumping, world.farm.state_of(cell)])
		plot.crop_id = before[0]
		plot.state = before[1]
		if tilled_here:
			world.farm.plots.erase(cell)
			world.farm.plot_changed.emit(cell)
	_free(p)
	p.global_position = spot

## GAP3-05: the swing follows the cursor only while the mouse is in use.
func _aim_follows_device(t, world: WorldRoot2D, p: Player2D) -> void:
	world.call("_enter", &"_fixture_ortho", &"default")
	p.set_physics_process(false)
	_free(p)
	p.mouse_aim = false
	p._unhandled_input(_motion(Vector2(12, 0)))
	var by_mouse: bool = p.mouse_aim
	p._unhandled_input(_axis(JOY_AXIS_LEFT_X, 0.9))
	var by_stick: bool = not p.mouse_aim
	p._unhandled_input(_mouse(MOUSE_BUTTON_LEFT, false))
	p._unhandled_input(_motion(Vector2(1, 0)))
	var jitter_ignored: bool = not p.mouse_aim
	p._unhandled_input(_axis(JOY_AXIS_LEFT_X, 0.1))
	p._unhandled_input(_mouse(MOUSE_BUTTON_RIGHT))
	var by_click: bool = p.mouse_aim
	_free(p)
	p._unhandled_input(_pad(JOY_BUTTON_START, false))
	var release_kept: bool = p.mouse_aim
	p._unhandled_input(_pad(JOY_BUTTON_Y))
	var by_button: bool = not p.mouse_aim
	_free(p)
	p.combat_aim = Vector2.RIGHT
	p.event_face(Iso.to_screen(Vector2.RIGHT))
	p.combat.swing()
	var follows: bool = p.combat._swing_direction.dot(Vector2.RIGHT) > 0.99
	t.check("aim_device_mouse_then_pad", by_mouse and by_stick and jitter_ignored and by_click and release_kept and by_button and follows,
		"mouse move %s, stick %s, jitter ignored %s, click %s, a release keeps it %s, pad button %s, the swing follows the stick %s" % [by_mouse, by_stick, jitter_ignored, by_click, release_kept, by_button, follows])
	_free(p)

## UX-18: the pad hints follow the pad family (Godot names the face buttons by position).
func _pad_families(t) -> void:
	var names := {"DualSense Wireless Controller": UiHints.PLAYSTATION, "PS4 Controller": UiHints.PLAYSTATION, "Nintendo Switch Pro Controller": UiHints.NINTENDO,
		"Xbox Series X Controller": UiHints.XBOX, "": UiHints.XBOX}
	var families_ok := true
	for n in names:
		families_ok = families_ok and UiHints.pad_family_of(n) == names[n]
	var labels := {}
	for f in [UiHints.XBOX, UiHints.PLAYSTATION, UiHints.NINTENDO]:
		labels[f] = [UiHints.glyph(&"interact", &"gamepad", f), UiHints.glyph(&"light", &"gamepad", f), UiHints.glyph(&"pause", &"gamepad", f), UiHints.glyph(&"ui_page_up", &"gamepad", f)]
	var labels_ok: bool = labels[UiHints.XBOX] == ["A", "Y", str(TranslationServer.translate("NAV_PAD_START")), "LB"] \
		and labels[UiHints.PLAYSTATION] == [str(TranslationServer.translate("NAV_PAD_PS_CROSS")), str(TranslationServer.translate("NAV_PAD_PS_TRIANGLE")), str(TranslationServer.translate("NAV_PAD_PS_OPTIONS")), "L1"] \
		and labels[UiHints.NINTENDO] == ["B", "X", "+", "L"]
	t.check("pad_glyphs_follow_family", families_ok and labels_ok and UiHints.glyph(&"interact", &"gamepad") == "A", "families %s, labels %s" % [families_ok, labels])

## UX-16: no Ctrl (Spaces on macOS) and no PgUp / PgDn needed: Shift descends in flight, Q / E page, letters stay typing in a field.
func _mac_keys(t, world: WorldRoot2D, p: Player2D) -> void:
	world.call("_enter", &"farm", &"default")
	p.set_physics_process(false)
	_free(p)
	p.is_flying = true
	p._unhandled_input(_key(KEY_SHIFT))
	var down: bool = p._climb_down
	p._unhandled_input(_key(KEY_SHIFT, false))
	var up: bool = not p._climb_down
	_free(p)
	var field := LineEdit.new()
	t.root.add_child(field)
	var page_free: bool = UiNav.page_pressed(_key(KEY_E), &"ui_page_down") and UiNav.page_pressed(_key(KEY_Q), &"ui_page_up") and not UiNav.page_pressed(_key(KEY_Q), &"ui_page_down")
	field.grab_focus()
	var typing: bool = not UiNav.page_pressed(_key(KEY_E), &"ui_page_down") and not UiNav.page_pressed(_key(KEY_Q), &"ui_page_up") \
		and UiNav.page_pressed(_key(KEY_PAGEDOWN), &"ui_page_down") and UiNav.page_pressed(_pad(JOY_BUTTON_LEFT_SHOULDER), &"ui_page_up")
	field.queue_free()
	t.check("mac_friendly_keys", down and up and page_free and typing, "Shift descends %s / stops %s; Q E page %s; in a text field only PgDn and LB page %s" % [down, up, page_free, typing])

## UX-04: a pad runs (LT), takes off (Y), descends (LT in flight) and zooms (right stick); the trackpad pans and pinches the zoom.
func _pad_run_fly_zoom(t, world: WorldRoot2D, p: Player2D) -> void:
	var hints := [UiHints.glyph(&"run", &"gamepad", UiHints.XBOX), UiHints.glyph(&"fly_toggle", &"gamepad", UiHints.XBOX), UiHints.glyph(&"fly_descend", &"gamepad", UiHints.XBOX),
		UiHints.glyph_pair(&"zoom_in", &"zoom_out", &"gamepad"), UiHints.glyph(&"run", &"gamepad", UiHints.PLAYSTATION)]
	var hints_ok: bool = hints == ["LT", "Y", "LT", "RS↑ RS↓", "L2"]
	Input.parse_input_event(_axis(JOY_AXIS_TRIGGER_LEFT, 1.0))
	Input.flush_buffered_events()
	var runs: bool = Input.is_action_pressed(&"run")
	Input.parse_input_event(_axis(JOY_AXIS_TRIGGER_LEFT, 0.0))
	Input.flush_buffered_events()
	var stops: bool = not Input.is_action_pressed(&"run")
	world.call("_enter", &"farm", &"default")
	p.set_physics_process(false)
	_free(p)
	p.is_flying = true
	p._unhandled_input(_axis(JOY_AXIS_TRIGGER_LEFT, 1.0))
	var descends: bool = p._climb_down
	p._unhandled_input(_axis(JOY_AXIS_TRIGGER_LEFT, 0.0))
	descends = descends and not p._climb_down
	_free(p)
	p.combat.cooldowns.light = 0.0
	p._unhandled_input(_pad(JOY_BUTTON_Y))
	var takes_off: bool = p.is_flying == p.can_fly_here() and p.combat.cooldowns.light == 0.0
	_free(p)
	t.check("pad_runs_and_flies", hints_ok and runs and stops and descends and takes_off, "hints %s; LT runs %s / stops %s; LT descends in flight %s; Y takes off where the hero can fly (%s), never lights on the farm: %s" % [hints, runs, stops, descends, p.can_fly_here(), takes_off])
	world.call("_enter", &"_fixture_ortho", &"default")
	p.set_physics_process(false)
	_free(p)
	p._unhandled_input(_pad(JOY_BUTTON_Y))
	t.check("pad_y_lights_in_action_area", p.combat.cooldowns.light > 0.0 and not p.is_flying)
	_free(p)
	world.call("_enter", &"farm", &"default")
	p.set_physics_process(false)
	var range: Vector2 = world.area.zoom_range
	p.set_zoom((range.x + range.y) * 0.5)
	var z0: float = p.camera.zoom.x
	p._unhandled_input(_axis(JOY_AXIS_RIGHT_Y, -1.0))
	var motion_skipped: bool = is_equal_approx(p.camera.zoom.x, z0)
	Input.action_press(&"zoom_in", 1.0)
	p._zoom_stick(0.1)
	Input.action_release(&"zoom_in")
	var stick_in: bool = is_equal_approx(p.camera.zoom.x, minf(range.y, z0 + 0.1 * float(GameData.player_cfg("zoom_stick_per_second", 0.5))))
	p.set_zoom(z0)
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(0, -1.0)
	p._unhandled_input(pan)
	var pan_in: bool = is_equal_approx(p.camera.zoom.x, minf(range.y, z0 + PlayerBody2D.ZOOM_STEP))
	p.set_zoom(z0)
	var pinch := InputEventMagnifyGesture.new()
	pinch.factor = 0.9
	p._unhandled_input(pinch)
	var pinch_out: bool = is_equal_approx(p.camera.zoom.x, maxf(range.x, z0 * 0.9))
	p.set_zoom(world.area.zoom_default)
	t.check("pad_stick_and_trackpad_zoom", motion_skipped and stick_in and pan_in and pinch_out, "a stick event steps nothing %s; held stick zooms in %s; pan up zooms in %s; pinch zooms out %s" % [motion_skipped, stick_in, pan_in, pinch_out])

## GAP3-01: F during the landing descent is ignored; the fairy lands, then takes off again normally.
func _take_off_while_landing(t, world: WorldRoot2D, p: Player2D) -> void:
	world.call("_enter", &"farm", &"default")
	p.set_physics_process(false)
	_free(p)
	if not p.can_fly_here():
		t.skip("this hero cannot fly on the farm (run with --character=fairy)")
		return
	p.toggle_flight()
	var landing: bool = p._try_land(false) and p._landing
	p.toggle_flight()
	var refused: bool = not p.is_flying and p._landing
	for i in 120:
		p._update_vertical(1.0 / 60.0)
	var landed: bool = not p._landing and not p.is_flying
	p.toggle_flight()
	t.check("take_off_ignored_while_landing", landing and refused and landed and p.is_flying, "landing %s, F refused %s, landed %s, flies again %s" % [landing, refused, landed, p.is_flying])
	_free(p)

## GAP3-07: the E prompt and E use one gate: a flying fairy sees no prompt, and the cached prompt follows the change at once.
func _prompt_follows_gate(t, world: WorldRoot2D, p: Player2D) -> void:
	world.call("_enter", &"farm", &"default")
	p.set_physics_process(false)
	_free(p)
	var host := HostProbe.new()
	var zone := Area2D.new()
	zone.collision_layer = Iso.LAYER_INTERACTABLE
	zone.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 20.0
	collision.shape = shape
	zone.add_child(collision)
	host.add_child(zone)
	world.area.objects.add_child(host)
	host.global_position = p.target_global()
	await t.physics(2)
	p._update_prompt(PlayerBody2D.PROMPT_REFRESH_S)
	var shown: bool = p._prompt == "E: Probe"
	p.is_flying = true
	p._update_prompt(0.0)
	var hidden_in_flight: bool = p._prompt == "" and not p.try_interact() and host.used == 0
	p.is_flying = false
	p._update_prompt(0.0)
	var back: bool = p._prompt == "E: Probe" and p.try_interact() and host.used == 1
	t.check("prompt_and_e_share_one_gate", shown and hidden_in_flight and back, "prompt on the ground %s, none and no E in flight %s, back at once on landing %s" % [shown, hidden_in_flight, back])
	# A swing or a tool use only lasts a moment: the prompt stays instead of blinking; a talk hides it.
	var steady := true
	for brief in PlayerBody2D.BRIEF_STATES:
		p.state = brief
		p._update_prompt(PlayerBody2D.PROMPT_REFRESH_S)
		steady = steady and p._prompt == "E: Probe"
	p.state = PlayerBody2D.S.TALKING
	p._update_prompt(PlayerBody2D.PROMPT_REFRESH_S)
	var hidden_in_talk: bool = p._prompt == ""
	p.state = PlayerBody2D.S.FREE
	p._update_prompt(0.0)
	t.check("prompt_steady_through_brief_actions", steady and hidden_in_talk and p._prompt == "E: Probe", "kept through swing/use/dodge/hurt %s, hidden in a talk %s" % [steady, hidden_in_talk])
	host.queue_free()
	_free(p)

## GAP3-09: the forced landing finds the same nearest safe cell as the old full-map sort, without sorting the map.
func _forced_landing_search(t, world: WorldRoot2D, p: Player2D) -> void:
	world.call("_enter", &"farm", &"default")
	p.set_physics_process(false)
	_free(p)
	var area: IsoArea = world.area
	var spots: Array[Vector2] = [p.global_position]
	for y in area.map.height:
		for x in area.map.width:
			if not area.is_walkable(Vector2i(x, y)) and spots.size() < 4:
				spots.append(area.cell_to_global(Vector2i(x, y)))
	var same := true
	var worst_us := 0.0
	var detail: Array[String] = []
	for at in spots:
		p.global_position = at
		var started := Time.get_ticks_usec()
		var found: Variant = p._nearest_landing()
		worst_us = maxf(worst_us, float(Time.get_ticks_usec() - started))
		var want: Variant = null
		var want_d := INF
		for y in area.map.height:
			for x in area.map.width:
				var c := area.cell_to_global(Vector2i(x, y))
				if area.is_walkable(Vector2i(x, y)) and Iso.ground_dist(at, c) < want_d and p._landing_safe(c):
					want = c
					want_d = Iso.ground_dist(at, c)
		var ok: bool = (found == null) == (want == null) and (found == null or is_equal_approx(Iso.ground_dist(at, found), want_d))
		same = same and ok
		detail.append("%s -> %s / %s" % [at, found, want])
	t.check("forced_landing_matches_full_search", same and spots.size() > 1, ", ".join(detail))
	t.check("forced_landing_search_is_cheap", t.perf_ok("forced_landing_search_is_cheap", worst_us, 3000.0), "worst %.0f us over %d spots (the full sort took ~19 ms)" % [worst_us, spots.size()])
	p.global_position = spots[0]
	_free(p)

## QUAL-11: the lantern follows DungeonOilRules itself: the auto-refuel assist decides, and the tuning comes from game_balance.lua.
func _oil_rules_direct(t, world: WorldRoot2D, p: Player2D, eco: Node) -> void:
	world.call("_enter", &"_fixture_ortho", &"default")
	p.set_physics_process(false)
	_free(p)
	var draining := p.oil_draining
	var before_assist: Variant = DungeonRun.assist("assist_auto_refuel")
	eco.remove_item(&"lysdraabe", eco.count_item(&"lysdraabe"))
	eco.add_item(&"lantern_oil", 2, true)
	var flasks: int = eco.count_item(&"lantern_oil")
	p.oil_draining = true
	DungeonRun.set_assist("assist_auto_refuel", 0)
	p.oil = 5.0
	p._update_oil(0.01)
	var off_kept: bool = eco.count_item(&"lantern_oil") == flasks
	DungeonRun.set_assist("assist_auto_refuel", 1)
	p._update_oil(0.01)
	var on_used: bool = eco.count_item(&"lantern_oil") == flasks - 1
	DungeonRun.set_assist("assist_auto_refuel", before_assist)
	p.oil_draining = draining
	p.restore_oil()
	var tuned: bool = is_equal_approx(float(GameData.player_cfg("flight_min_stamina", -1)), 15.0) and is_equal_approx(float(GameData.player_cfg("stamina_regen_delay", -1)), 1.0) \
		and is_equal_approx(float(GameData.player_cfg("tool_seconds", -1)), 0.34)
	t.check("oil_rules_called_directly", off_kept and on_used and tuned, "auto-refuel off keeps the flask %s, on uses one %s; the three literals are Lua config %s" % [off_kept, on_used, tuned])
	_free(p)

## UX-17: the pause rows name their world hotkey (keyboard only: a pad has none of these buttons).
func _pause_row_hotkeys(t, world: WorldRoot2D) -> void:
	var pause: TTScreen = world.game_ui.get_screen(&"pause_menu")
	await UiAudit.device_swap(t, "keyboard")
	pause.open()
	await t.frames(2)
	var keys := {}
	for name in ["InventoryButton", "MapButton", "JournalButton", "PeopleButton", "WardrobeButton", "BuildButton"]:
		var row: Node = pause.get_node_or_null("%" + name)
		keys[name] = str(row.get_node("Hotkey").text) if row != null and row.has_node("Hotkey") else "-"
	var resume_plain: bool = not pause.get_node("%ResumeButton").has_node("Hotkey")
	await UiAudit.device_swap(t, "pad")
	var pad_hidden: bool = str(pause.get_node("%InventoryButton/Hotkey").text) == ""
	await UiAudit.device_swap(t, "keyboard")
	pause.close()
	await t.frames(2)
	var want := {"InventoryButton": "I", "MapButton": "M", "JournalButton": "J", "PeopleButton": "P", "WardrobeButton": "G", "BuildButton": "B"}
	var ok := resume_plain and pad_hidden
	for name in keys:
		ok = ok and (keys[name] == want[name] or keys[name] == "-")
	# In the world the Settings footer also carries the forest help: all four buttons still fit the panel.
	var settings: TTScreen = world.game_ui.get_screen(&"settings_ui")
	settings.open()
	await t.frames(2)
	var footer_fits := true
	for button in [settings.forest_help_button, settings.updates_button, settings.controls_button, settings.get_node("%CloseButton")]:
		footer_fits = footer_fits and button.visible and settings.get_node("Panel").get_global_rect().encloses((button as Control).get_global_rect())
	settings.close()
	await t.frames(2)
	t.check("world_settings_footer_fits", footer_fits, str(settings.get_node("Panel").get_global_rect()))
	t.check("pause_rows_show_hotkeys", ok and keys["InventoryButton"] == "I", "keys %s, resume has none %s, a pad shows none %s" % [keys, resume_plain, pad_hidden])

## UX-17: Settings opens a read-only Styring page that lists the live keys and pad buttons.
func _controls_page(t) -> void:
	await t.go_menu()
	var settings: TTScreen = t.tree.current_scene.get_node("SettingsUI")
	settings.open()
	await t.frames(2)
	var footer_fits: bool = settings.get_node("Panel").get_global_rect().encloses(settings.controls_button.get_global_rect()) and settings.get_node("Panel").get_global_rect().encloses(settings.get_node("%CloseButton").get_global_rect())
	t.check("settings_footer_fits_controls_button", footer_fits and settings.controls_button.visible, "panel %s, button %s" % [settings.get_node("Panel").get_global_rect(), settings.controls_button.get_global_rect()])
	settings.controls_button.pressed.emit()
	await t.frames(2)
	var panel: TTScreen = settings.get_node("Controls")
	var book: Control = panel.get_child(panel.get_child_count() - 1) as Control
	var cells_fit := true
	for cell in panel._cells:
		for label in [cell[1], cell[2]]:
			cells_fit = cells_fit and book.get_global_rect().encloses((label as Control).get_global_rect())
	t.check("settings_opens_controls_page", panel.is_open() and t.autoload("GameManager").modal_stack() == [&"settings", &"controls"])
	var texts := {}
	for cell in panel._cells:
		texts[str(cell[0][0])] = [str(cell[1].text), str(cell[2].text)]
	var listed: bool = texts["NAV_CONTROLS_TOOL"][0].contains("X") and texts["NAV_CONTROLS_TOOL"][0].contains(str(TranslationServer.translate("KEY_MOUSE_LEFT"))) \
		and texts["NAV_CONTROLS_RUN"][1] == "LT" and texts["NAV_CONTROLS_FLY"] == ["F", "Y"] and texts["INDRET_TITLE"][0] == "H" \
		and texts["INV_TITLE"] == ["I / Tab", str(TranslationServer.translate("NAV_CONTROLS_PAUSE_ROW"))] and texts["NAV_CONTROLS_HOTBAR"][0] == "1–8"
	var complete := true
	for key in texts:
		complete = complete and texts[key][0] != "" and texts[key][1] != ""
	t.check("controls_page_lists_live_bindings", listed and complete, str(texts))
	t.check("controls_page_fits_its_panel", cells_fit)
	if t.has_window():
		await t.capture("controls_page")
	t.tap_key(KEY_ESCAPE)
	await t.frames(2)
	t.check("controls_escape_returns_to_settings", not panel.is_open() and settings.is_open() and settings.get_viewport().gui_get_focus_owner() == settings.controls_button)
	settings.close()
	await UiAudit.audit_screen(t, "controls")
