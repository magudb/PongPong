extends RefCounted
## Player input regressions of the 2026-10-19 review (group "input"): what a REAL key, mouse or pad event does in
## Player2D._unhandled_input, the order of the shared bindings and the device-dependent aim.
const SECTION := "player_input"
const TIMEOUT_S := 200.0

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

func run(t) -> void:
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
	_aim_follows_device(t, world, p)
	world.call("_enter", &"farm", &"default")
	p.restore_after_sleep()
	_free(p)
	p.set_physics_process(true)

## DUN-07: in an action area LMB / pad X are the attack (buffer, held flag, Cozy auto-swing), never the hidden hotbar item.
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

## GAP3-11: pad A is interact and jump; with nothing in front it hops, with a host in front it interacts.
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
