extends RefCounted

const ScopedInputObserver := preload("res://tests/lib/scoped_input_observer.gd")
## MP2 actual-body routing tracers. Injected events are not hardware/LAN acceptance.
const SECTION := "multiplayer_input"
const TIMEOUT_S := 90.0

func run_windowed(t) -> void:
	await run(t)

func run(t) -> void:
	await _forest_boot_inventory(t)
	await t.start_world()
	var w: WorldRoot2D = t.world()
	var local: Player2D = w.player
	local.set_physics_process(false)
	await _hud_mouse_authority(t, w, local)
	var remote := Player2D.new()
	w._register_player(remote, 1, 2)
	w.add_child(remote)
	remote.set_physics_process(false)
	remote.enter_area(w.area, local.global_position + Vector2(150, 0))
	t.check("remote_enter_area_camera_isolated", local.camera.is_current() and not remote.camera.is_current())
	t.check("remote_enter_area_marker_isolated", not remote._marker.visible)
	t.check("descend_hint_names_down", UiHints.glyph(&"fly_descend", &"gamepad") == str(TranslationServer.translate("NAV_PAD_DPAD")) + "↓")
	# Deliberately make the remote the first member of the historical group.
	w.area.objects.move_child(remote, 0)
	t.check("remote_first_fixture", t.tree.get_nodes_in_group("player")[0] == remote)
	t.check("registry_remote_first_keeps_local", PlayerRegistry.local_player() == local)
	local.camera.make_current()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_2
	key.keycode = KEY_2
	key.pressed = true
	local.hotbar.select(0)
	remote.hotbar.select(0)
	remote._unhandled_input(key)
	local._unhandled_input(key)
	t.check("remote_ignores_keyboard_hotbar", remote.hotbar.selected == 0)
	t.check("local_keyboard_hotbar_positive", local.hotbar.selected == 1)
	var mouse := InputEventMouseMotion.new()
	mouse.position = Vector2(333, 222)
	mouse.relative = Vector2(20, 0)
	remote.mouse_aim = false
	remote._input(mouse)
	local._input(mouse)
	t.check("remote_ignores_raw_mouse", not remote.mouse_aim and remote._cursor_screen != mouse.position)
	t.check("local_raw_mouse_positive", local.mouse_aim and local._cursor_screen == mouse.position)
	# A real non-local body must never poll this machine's held movement.
	var before := remote.global_position
	Input.action_press("move_right")
	remote._physics_process(0.1)
	Input.action_release("move_right")
	t.check("remote_continuous_input_isolated", remote.global_position.is_equal_approx(before))
	remote.is_local = true
	# Runtime seam: baseline has no abstraction, but still reaches real input behavior.
	if "controls" in remote:
		remote.get("controls").bind_pad(2)
	remote.hotbar.select(0)
	remote._unhandled_input(key)
	t.check("bound_pad_refuses_keyboard", remote.hotbar.selected == 0)
	var pad := InputEventJoypadButton.new()
	pad.device = 3
	pad.button_index = JOY_BUTTON_DPAD_RIGHT
	pad.pressed = true
	remote._unhandled_input(pad)
	t.check("bound_pad_refuses_foreign_discrete", remote.hotbar.selected == 0)
	pad.device = 2
	remote._unhandled_input(pad)
	t.check("bound_pad_discrete_positive", remote.hotbar.selected == 1)
	var axis := InputEventJoypadMotion.new()
	axis.device = 3
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 1.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	before = remote.global_position
	remote._physics_process(0.1)
	t.check("bound_pad_refuses_foreign_continuous", remote.global_position.is_equal_approx(before))
	axis.axis_value = 0.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	axis.device = 2
	axis.axis_value = 1.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	remote._input(axis)
	remote._physics_process(0.1)
	t.check("bound_pad_continuous_positive", remote.global_position.x > before.x)
	axis.axis_value = 0.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	pad.device = 2
	t.check("registry_routes_bound_pad", PlayerRegistry.for_event(pad) == remote and w.player_for_event(pad) == remote)
	pad.device = 77
	t.check("registry_refuses_unknown_device", PlayerRegistry.for_event(pad) == null and w.player_for_event(pad) == null)
	t.check("registry_null_fixture_contract", PlayerRegistry.for_event(null) == local)
	remote.is_local = false
	local.is_local = false
	t.check("registry_no_local_does_not_borrow_remote", PlayerRegistry.local_player() == null and w.local_player() == null)
	local.is_local = true
	var clone := Player2D.new()
	clone.player_id = &"p0"
	var clone_events := []
	var on_hotbar := func(id, _entries, _selected): clone_events.append(["hotbar", id])
	var on_stats := func(id, _stats): clone_events.append(["stats", id])
	var on_oil := func(id, _oil, _max): clone_events.append(["oil", id])
	EventBus.hotbar_changed.connect(on_hotbar)
	EventBus.player_stats_changed.connect(on_stats)
	EventBus.player_oil_changed.connect(on_oil)
	w.add_child(clone)
	clone.set_physics_process(false)
	clone.enter_area(w.area, local.global_position + Vector2(300, 0))
	clone.hotbar.select(0)
	clone._unhandled_input(key)
	t.check("unregistered_clone_cannot_read_input", clone.hotbar.selected == 0)
	clone.hotbar.select(2)
	t.check("unregistered_clone_cannot_publish_owner_ui", clone_events.is_empty(), str(clone_events))
	EventBus.hotbar_changed.disconnect(on_hotbar)
	EventBus.player_stats_changed.disconnect(on_stats)
	EventBus.player_oil_changed.disconnect(on_oil)
	clone.queue_free()
	t.check("queued_clone_has_no_authority", PlayerRegistry.registered_id(clone) == &"")
	_forest_inventory_owner(t, w, local, remote)
	await _actor_actions(t, w, local, remote)
	_pad_chords(t, local, remote)
	_device_dodge(t, w, local, remote)
	await _disconnect_contract(t, w, remote)
	_zoom_deadzone(t, remote)
	_zoom_deadzone(t, local, 0)
	_unique_sources(t, local, remote)
	await _unique_lifetimes(t, w, local)
	await _passive_stub(t, w, local)
	await _modal_origin_samples(t, remote)
	await _remote_frame(t, remote)
	await _lifetime_and_default(t, w, local, remote)
	if t.has_window():
		await t.capture("multiplayer_input_isolation")
	w._unregister_player(remote)
	local.hotbar.select(0)

func _hud_mouse_authority(t, w: WorldRoot2D, body: Player2D) -> void:
	t.tree.root.notification(Node.NOTIFICATION_VP_MOUSE_ENTER)
	var hud: Node = w.game_ui.get_screen(&"hud")
	await t.frames(2)
	body.hotbar.select(0)
	await _parsed_slot_click(t, hud, 1)
	t.check("hud_fresh_mouse_positive", body.hotbar.selected == 1 and hud._selected == 1)
	var foreign := InputEventJoypadButton.new()
	foreign.device = 17
	foreign.button_index = JOY_BUTTON_A
	Input.parse_input_event(ScopedInputObserver.tag_if_active(foreign))
	Input.flush_buffered_events()
	await _parsed_slot_click(t, hud, 2)
	t.check("hud_mouse_after_foreign_pad", body.hotbar.selected == 2 and hud._selected == 2)
	body.is_local = false
	body.is_local = true
	body.controls.bind_default()
	await _parsed_slot_click(t, hud, 3)
	t.check("hud_mouse_after_locality_restored", body.hotbar.selected == 3 and hud._selected == 3)
	for guard in ["modal", "travel", "talk", "locality", "source", "incarnation"]:
		body.hotbar.select(0)
		if guard == "modal":
			GameData.gm().push_modal(&"hud_origin_probe", true)
		elif guard == "travel":
			w.traveling = true
		elif guard == "talk":
			body.state = PlayerBody2D.S.TALKING
		hud._slot_clicked(4)
		if guard == "modal":
			GameData.gm().pop_modal(&"hud_origin_probe")
		elif guard == "travel":
			w.traveling = false
		elif guard == "talk":
			body.state = PlayerBody2D.S.FREE
		elif guard == "locality":
			body.is_local = false
			body.is_local = true
		elif guard == "source":
			body.controls = PlayerInput.new()
			body.controls.attach(body)
		elif guard == "incarnation":
			EventBus.load_completed.emit(0)
		await t.frames(2)
		t.check("hud_deferred_origin_" + guard, body.hotbar.selected == 0 and hud._selected == 0)
	# A same-id replacement is not the click's original registered body.
	hud._slot_clicked(4)
	var replacement := Player2D.new()
	w._register_player(replacement, 0, 1)
	w.add_child(replacement)
	replacement.set_physics_process(false)
	replacement.hotbar.select(0)
	await t.frames(2)
	t.check("hud_deferred_slot_replacement_refused", replacement.hotbar.selected == 0 and body.hotbar.selected == 0)
	w._register_player(body, 0, 1)
	replacement.queue_free()
	body.camera.make_current()
	body.controls.bind_default()
	await _parsed_slot_click(t, hud, 1)
	t.check("hud_live_positive_after_origin_refusals", body.hotbar.selected == 1 and hud._selected == 1)
	body.hotbar.select(0)

func _parsed_slot_click(t, hud: Node, index: int) -> void:
	var pos: Vector2 = t.button_center(hud.hotbar.get_child(index))
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	motion.relative = Vector2(30, 0)
	Input.parse_input_event(ScopedInputObserver.tag_if_active(motion))
	Input.flush_buffered_events()
	for pressed in [true, false]:
		var button := InputEventMouseButton.new()
		button.position = pos
		button.global_position = pos
		button.button_index = MOUSE_BUTTON_LEFT
		button.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		button.pressed = pressed
		Input.parse_input_event(ScopedInputObserver.tag_if_active(button))
		Input.flush_buffered_events()
	await t.frames(2)

func _forest_boot_inventory(t) -> void:
	await t.clear_scene()
	var eco := GameData.eco()
	var before0: Dictionary = PlayerRegistry.for_player(&"p0", func(): return eco.to_dict()).duplicate(true)
	var before1: Dictionary = PlayerRegistry.for_player(&"p1", func(): return eco.to_dict()).duplicate(true)
	var given := []
	PlayerRegistry.for_player(&"p0", func():
		eco.inventory.clear()
		given.append(eco.add_item(&"health_tonic", 2, true))
		given.append(eco.add_item(&"lantern_oil", 3, true)))
	PlayerRegistry.for_player(&"p1", func():
		eco.inventory.clear()
		given.append(eco.add_item(&"health_tonic", 8, true)))
	var hud := preload("res://scripts/ui/forest_hud.gd").new()
	var scopes := []
	PlayerRegistry.for_player(&"p1", func():
		t.tree.root.add_child(hud)
		scopes.append(PlayerRegistry.acting_id()))
	t.check("forest_no_world_boot_fallback", not given.has(false) and PlayerRegistry.world() == null and hud._player == null and hud.drink_count.text == "×2" and hud.oil_count.text == "×3" and not hud.backpack_chip.visible and hud.backpack_chip.text.ends_with("2/24") and scopes == [&"p1"] and PlayerRegistry.acting_id() == &"p0")
	PlayerRegistry.for_player(&"p1", func(): hud.notification(Node.NOTIFICATION_TRANSLATION_CHANGED))
	t.check("forest_no_world_refresh_fallback", hud.drink_count.text == "×2" and hud.oil_count.text == "×3" and hud.backpack_chip.text.ends_with("2/24") and PlayerRegistry.acting_id() == &"p0")
	hud.free()
	PlayerRegistry.for_player(&"p0", func(): eco.from_dict(before0))
	PlayerRegistry.for_player(&"p1", func(): eco.from_dict(before1))

func _forest_inventory_owner(t, w: WorldRoot2D, local: Player2D, other: Player2D) -> void:
	var eco := GameData.eco()
	var hud: Control = w.game_ui.get_screen(&"forest_hud")
	var before0: Dictionary = PlayerRegistry.for_player(&"p0", func(): return eco.to_dict()).duplicate(true)
	var before1: Dictionary = PlayerRegistry.for_player(&"p1", func(): return eco.to_dict()).duplicate(true)
	var hotbar_before := local.hotbar.to_dict().duplicate(true)
	var health_before := local.half_hearts
	var state_before := local.state
	var stamina_before := local.stamina
	var other_body := [other.half_hearts, other.oil, other.stamina, other.state]
	var given := []
	PlayerRegistry.for_player(&"p0", func():
		eco.inventory.clear()
		for entry in [[&"health_tonic", 2], [&"lantern_oil", 2], [&"lysdraabe", 3], [&"svampe_eliksir", 1], [&"turnip_seeds", 20 * eco.max_stack_of(&"turnip_seeds")]]:
			given.append(not GameData.item_def(entry[0]).is_empty() and eco.add_item(entry[0], entry[1], true)))
	PlayerRegistry.for_player(&"p1", func():
		eco.inventory.clear()
		given.append(eco.add_item(&"health_tonic", 7, true))
		given.append(eco.add_item(&"lantern_oil", 9, true)))
	local._cancel_flight()
	local._click_cell = null
	local.state = PlayerBody2D.S.FREE
	local.stamina = local.max_stamina
	local.half_hearts = 2
	local.hotbar.assign(0, &"health_tonic")
	local.hotbar.select(0)
	var p1_inventory: Dictionary = PlayerRegistry.for_player(&"p1", func(): return eco.to_dict()).duplicate(true)
	t.check("forest_batched_fixture_eligible", not given.has(false) and given.size() == 7 and PlayerRegistry.registered_id(local) == &"p0" and local.world_input_allowed() and not local.is_flying and local._click_cell == null and local.state == PlayerBody2D.S.FREE and local.hotbar.current() == &"health_tonic" and local.stamina > 0 and local.max_half_hearts > 2 and eco.count_item(&"health_tonic") == 2 and eco.used_slots() == 24)
	var observed := []
	var on_inventory := func(id: StringName, items: Dictionary):
		observed.append([id, PlayerRegistry.acting_id(), items.duplicate(true)])
	EventBus.player_inventory_changed.connect(on_inventory)
	var action := []
	PlayerRegistry.for_player(&"p1", func():
		eco.defer_notifications(func(): action.append(local.use_selected()))
		action.append(PlayerRegistry.acting_id()))
	EventBus.player_inventory_changed.disconnect(on_inventory)
	t.check("forest_batched_body_consumes_and_heals", action == [true, &"p1"] and eco.count_item(&"health_tonic") == 1 and local.half_hearts == mini(local.max_half_hearts, 6))
	t.check("forest_batched_genuine_owner_notification", observed.size() == 1 and observed[0][0] == &"p0" and observed[0][1] == &"p1" and observed[0][2].get(&"health_tonic") == 1)
	t.check("forest_batched_other_inventory_body_unchanged", PlayerRegistry.for_player(&"p1", func(): return eco.to_dict()) == p1_inventory and [other.half_hearts, other.oil, other.stamina, other.state] == other_body)
	t.check("forest_batched_tonic_owner", hud.drink_count.text == "×2", hud.drink_count.text)
	t.check("forest_batched_oil_owner", hud.oil_count.text == "×5", hud.oil_count.text)
	t.check("forest_batched_backpack_owner", hud.backpack_chip.visible and hud.backpack_chip.text == TranslationServer.translate("DEXP_BACKPACK_FULL") + " 24/24" and hud.backpack_chip.get_theme_color("font_color") == preload("res://scripts/ui/theme/tt_colors.gd").HONEY, hud.backpack_chip.text)
	t.check("forest_batched_global_scope_restored", PlayerRegistry.acting_id() == &"p0")
	# The same eligible body also works without batching; it must still leave p1 untouched.
	local.state = PlayerBody2D.S.FREE
	local.half_hearts = 2
	var ordinary: bool = PlayerRegistry.for_player(&"p1", func(): return local.use_selected())
	t.check("forest_nonbatched_local_positive", ordinary and eco.count_item(&"health_tonic") == 0 and local.half_hearts == mini(local.max_half_hearts, 6) and hud.drink_count.text == "×1" and hud.oil_count.text == "×5" and hud.backpack_chip.text.ends_with("23/24"))
	t.check("forest_nonbatched_other_unchanged", PlayerRegistry.for_player(&"p1", func(): return eco.to_dict()) == p1_inventory and [other.half_hearts, other.oil, other.stamina, other.state] == other_body)
	var receipts := []
	PlayerRegistry.for_player(&"p1", func():
		eco.defer_notifications(func(): PlayerRegistry.for_player(&"p0", func(): receipts.append(eco.remove_item(&"turnip_seeds", 3 * eco.max_stack_of(&"turnip_seeds"))))))
	t.check("forest_backpack_near_owner", receipts == [true] and eco.used_slots() == 20 and hud.backpack_chip.visible and hud.backpack_chip.text == TranslationServer.translate("DEXP_BACKPACK_NEAR") + " 20/24" and hud.backpack_chip.get_theme_color("font_color") == preload("res://scripts/ui/theme/tt_colors.gd").CHALK)
	PlayerRegistry.for_player(&"p1", func():
		eco.defer_notifications(func(): PlayerRegistry.for_player(&"p0", func(): receipts.append(eco.remove_item(&"turnip_seeds", eco.max_stack_of(&"turnip_seeds"))))))
	t.check("forest_backpack_below_warning_owner", receipts == [true, true] and eco.used_slots() == 19 and not hud.backpack_chip.visible and hud.backpack_chip.text.ends_with("19/24"))
	# A genuine nested unrelated-owner event cannot overwrite the accepted local display.
	var nested := []
	var on_nested := func(id: StringName, _items: Dictionary):
		if id == &"p0":
			var display := [hud.drink_count.text, hud.oil_count.text, hud.backpack_chip.text, hud.backpack_chip.visible]
			nested.append(PlayerRegistry.acting_id())
			nested.append(eco.add_item(&"lantern_oil", 1, true))
			nested.append(PlayerRegistry.acting_id())
			nested.append(display == [hud.drink_count.text, hud.oil_count.text, hud.backpack_chip.text, hud.backpack_chip.visible])
	EventBus.player_inventory_changed.connect(on_nested)
	PlayerRegistry.for_player(&"p1", func():
		eco.defer_notifications(func(): PlayerRegistry.for_player(&"p0", func(): receipts.append(eco.add_item(&"health_tonic", 1, true))))
		nested.append(PlayerRegistry.acting_id()))
	EventBus.player_inventory_changed.disconnect(on_nested)
	t.check("forest_nested_genuine_callback_restores_scope", nested == [&"p1", true, &"p1", true, &"p1"] and PlayerRegistry.acting_id() == &"p0")
	t.check("forest_nested_unrelated_inventory_cannot_refresh", receipts == [true, true, true] and hud.drink_count.text == "×2" and hud.oil_count.text == "×5" and hud.backpack_chip.visible and hud.backpack_chip.text.ends_with("20/24") and PlayerRegistry.for_player(&"p1", func(): return eco.count_item(&"lantern_oil")) == 10)
	# Translation refresh and initial construction have no owner-labelled payload.
	PlayerRegistry.for_player(&"p1", func(): hud.notification(Node.NOTIFICATION_TRANSLATION_CHANGED))
	t.check("forest_unlabelled_refresh_owner", hud.drink_count.text == "×2" and hud.oil_count.text == "×5" and hud.backpack_chip.text.ends_with("20/24") and PlayerRegistry.acting_id() == &"p0")
	var fresh := preload("res://scripts/ui/forest_hud.gd").new()
	PlayerRegistry.for_player(&"p1", func(): hud.get_parent().add_child(fresh))
	t.check("forest_ready_under_conflicting_scope", fresh.drink_count.text == "×2" and fresh.oil_count.text == "×5" and fresh.backpack_chip.visible and fresh.backpack_chip.text.ends_with("20/24") and PlayerRegistry.acting_id() == &"p0")
	fresh.free()
	local.is_local = false
	PlayerRegistry.for_player(&"p1", func(): hud._inventory({}))
	t.check("forest_missing_registered_local_refuses_ambient", PlayerRegistry.local_player() == null and hud.drink_count.text == "×2" and hud.oil_count.text == "×5" and hud.backpack_chip.text.ends_with("20/24") and PlayerRegistry.acting_id() == &"p0")
	local.is_local = true
	local.controls.bind_default()
	local.camera.make_current()
	PlayerRegistry.for_player(&"p0", func(): eco.from_dict(before0))
	PlayerRegistry.for_player(&"p1", func(): eco.from_dict(before1))
	local.hotbar.from_dict(hotbar_before)
	local.half_hearts = health_before
	local.stamina = stamina_before
	local.state = state_before

func _actor_actions(t, w: WorldRoot2D, local: Player2D, other: Player2D) -> void:
	var eco := GameData.eco()
	var cell := Vector2i(-1, -1)
	for candidate in w.farm.farmable_cells():
		if w.farm.can_till(candidate):
			cell = candidate
			break
	t.check("actor_tool_fixture", cell != Vector2i(-1, -1) and eco.has_item(&"hoe_wooden"))
	other.facing8 = 0
	other.global_position = w.area.cell_to_global(cell - w.area.facing_step(0))
	other.hotbar.assign(0, &"hoe_wooden")
	other.hotbar.select(0)
	other.state = PlayerBody2D.S.FREE
	other.is_local = false
	other.is_local = true
	other.controls.bind_pad(2)
	var event := InputEventJoypadButton.new()
	event.device = 2
	event.button_index = JOY_BUTTON_X
	event.pressed = true
	PlayerRegistry.for_player(&"p0", func(): other._unhandled_input(event))
	t.check("local_p1_cannot_borrow_p0_tool", w.farm.state_of(cell) == FarmGrid.State.EMPTY)
	PlayerRegistry.for_player(&"p1", func(): eco.add_item(&"hoe_wooden", 1, true))
	other.state = PlayerBody2D.S.FREE
	t.check("remote_tool_otherwise_eligible", other.world_input_allowed() and PlayerRegistry.for_player(&"p1", func(): return eco.count_item(&"hoe_wooden")) > 0 and w.farm.can_till(cell))
	other.is_local = false
	t.check("remote_direct_tool_blocked", not other.use_selected() and w.farm.state_of(cell) == FarmGrid.State.EMPTY)
	other.is_local = true
	other._unhandled_input(event)
	t.check("local_p1_owned_tool_positive", w.farm.state_of(cell) == FarmGrid.State.TILLED)
	t.check("actor_scope_restored", PlayerRegistry.acting_id() == &"p0")
	other._farm_use_held = true
	other._click_buffer = cell
	other.combat.attack_held = true
	other._climb_down = true
	other.controls.detach()
	t.check("detach_releases_body_latches", not other._farm_use_held and other._click_buffer == null and not other.combat.attack_held and not other._climb_down)
	other.controls.attach(other)
	other.is_local = false
	other.oil_draining = true
	other.oil = 1.0
	eco.add_item(&"lantern_oil", 1, true)
	var flasks: int = eco.count_item(&"lantern_oil")
	var assist: Variant = DungeonRun.assist("assist_auto_refuel")
	DungeonRun.set_assist("assist_auto_refuel", 1)
	other._physics_process(0.1)
	DungeonRun.set_assist("assist_auto_refuel", assist)
	t.check("remote_tick_cannot_consume_local_flask", eco.count_item(&"lantern_oil") == flasks)
	var original := local.hotbar.current()
	EventBus.hotbar_assign_requested.emit(&"p1", 0, &"turnip_seeds")
	t.check("hotbar_assign_filters_owner", local.hotbar.current() == original and other.hotbar.current() == &"turnip_seeds")
	var hud: Node = w.game_ui.get_screen(&"hud")
	var selected: int = hud._selected
	other.hotbar.select(3)
	EventBus.player_spawned.emit(other)
	t.check("remote_signals_do_not_rebind_hud", hud._selected == selected)
	t.check("remote_spawn_keeps_forest_owner", w.game_ui.get_screen(&"forest_hud")._player == local)
	t.check("remote_spawn_keeps_badge_owner", hud.current_item_badge._player.get_ref() == local)
	other.is_local = true
	other.state = PlayerBody2D.S.FREE
	other.hotbar.assign(0, &"health_tonic")
	other.hotbar.select(0)
	other.half_hearts = 2
	local.half_hearts = 2
	eco.add_item(&"health_tonic", 2, true)
	PlayerRegistry.for_player(&"p1", func(): eco.add_item(&"health_tonic", 2, true))
	var p0_count: int = eco.count_item(&"health_tonic")
	var p1_count: int = PlayerRegistry.for_player(&"p1", func(): return eco.count_item(&"health_tonic"))
	# Parsed device events traverse both actual bodies, not only an isolated helper.
	Input.parse_input_event(ScopedInputObserver.tag_if_active(event.duplicate()))
	Input.flush_buffered_events()
	t.check("parsed_p1_tonic_heals_own_body", other.half_hearts > 2 and local.half_hearts == 2)
	t.check("parsed_p1_tonic_uses_own_inventory", eco.count_item(&"health_tonic") == p0_count and PlayerRegistry.for_player(&"p1", func(): return eco.count_item(&"health_tonic")) == p1_count - 1)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(ScopedInputObserver.tag_if_active(event))
	Input.flush_buffered_events()
	other.combat.reset()
	other.state = PlayerBody2D.S.FREE
	eco.add_item(&"wpn_spear_iron", 1, true)
	eco.equip(&"weapon", &"wpn_spear_iron")
	t.check("p1_direct_swing_cannot_borrow_p0_weapon", not other.swing())
	PlayerRegistry.for_player(&"p1", func():
		eco.add_item(&"wpn_spear_iron", 1, true)
		eco.equip(&"weapon", &"wpn_spear_iron"))
	other.combat.reset()
	other.state = PlayerBody2D.S.FREE
	t.check("p1_direct_swing_owned_positive", other.swing() and other.combat.active_weapon_id() == &"wpn_spear_iron")
	t.check("p1_direct_swing_restores_caller_scope", PlayerRegistry.acting_id() == &"p0")
	PlayerRegistry.state(&"p1").character_type = 2
	PlayerRegistry.state(&"p1").character_skin = &"hobbit_pip"
	var original_visual := local.visual.character_id
	var own_visual: String = PlayerRegistry.for_player(&"p1", func(): return GameData.visual_for_skin(&"hobbit_pip"))
	EventBus.player_character_changed.emit(&"p1", &"hobbit")
	t.check("character_signal_keeps_body_owner", other.visual.character_id == own_visual and local.visual.character_id == original_visual, "other=%s expected=%s local=%s original=%s" % [other.visual.character_id, own_visual, local.visual.character_id, original_visual])
	t.check("body_flight_perk_uses_own_profile", not other.can_fly_here())
	_owned_outfits(t, local, other)

func _owned_outfits(t, local: Player2D, other: Player2D) -> void:
	PlayerRegistry.for_player(&"p0", func():
		WardrobeManager.add("shirt_linen_cream")
		WardrobeManager.equip("shirt_linen_cream"))
	PlayerRegistry.for_player(&"p1", func():
		WardrobeManager.add("dress_sun_cream")
		WardrobeManager.equip("dress_sun_cream"))
	var p0_outfit := local.outfit_layers.current_outfit.duplicate(true)
	var p0_profile := PlayerRegistry.state(&"p0").wardrobe.duplicate(true)
	var p0_material := local.visual.sprite.material
	var p0_visual := local.visual.character_id
	var p1_outfit: Dictionary = PlayerRegistry.for_player(&"p1", func(): return WardrobeManager.outfit())
	PlayerRegistry.for_player(&"p0", func(): EventBus.outfit_changed.emit(&"p1", p1_outfit))
	t.check("outfit_signal_owned_under_conflicting_scope", other.outfit_layers.current_outfit == p1_outfit and other.outfit_layers.layers.has("dress") and p1_outfit != p0_outfit and local.outfit_layers.current_outfit == p0_outfit)
	t.check("outfits_have_distinct_owned_materials", other.outfit_layers._applied and local.outfit_layers._applied and other.visual.sprite.material != p0_material and other.outfit_layers.layers.dress.material != local.outfit_layers.layers.shirt.material)
	PlayerRegistry.state(&"p1").character_skin = &"hobbit_bodil"
	PlayerRegistry.for_player(&"p0", func(): EventBus.player_character_changed.emit(&"p1", &"hobbit"))
	var expected: String = PlayerRegistry.for_player(&"p1", func(): return GameData.visual_for_skin(&"hobbit_bodil"))
	t.check("outfit_character_refits_own_body_and_profile", other.visual.character_id == expected and other.outfit_layers.current_outfit == p1_outfit and other.outfit_layers._body_id == other.visual.resolved_id)
	t.check("outfit_character_keeps_p0_material_and_profile", local.visual.character_id == p0_visual and local.visual.sprite.material == p0_material and local.outfit_layers.current_outfit == p0_outfit and PlayerRegistry.state(&"p0").wardrobe == p0_profile)

func _pad_chords(t, local: Player2D, other: Player2D) -> void:
	other.state = PlayerBody2D.S.FREE
	other.combat.cancel_action()
	other.controls.bind_pad(2)
	var event := InputEventJoypadButton.new()
	event.device = 2
	event.pressed = true
	event.button_index = JOY_BUTTON_LEFT_STICK
	other._input(event)
	t.check("l3_runs_on_bound_pad", other.controls.is_action_pressed(&"run"))
	event.pressed = false
	other._input(event)
	var key := InputEventJoypadButton.new()
	key.pressed = true
	key.button_index = JOY_BUTTON_RIGHT_STICK
	local._unhandled_input(key)
	t.check("r3_toggles_flight", local.is_flying == local.can_fly_here())
	local._cancel_flight()
	other.is_flying = true
	event.pressed = true
	event.button_index = JOY_BUTTON_DPAD_DOWN
	other._unhandled_input(event)
	t.check("dpad_down_descends_without_hotbar", other._climb_down)
	event.pressed = false
	other._unhandled_input(event)
	other.hotbar.select(7)
	event.button_index = JOY_BUTTON_LEFT_SHOULDER
	event.pressed = true
	other._unhandled_input(event)
	event.button_index = JOY_BUTTON_DPAD_DOWN
	other._unhandled_input(event)
	t.check("shoulder_down_selects_not_descends", other.hotbar.selected == 2 and not other._climb_down)
	event.pressed = false
	other._unhandled_input(event)
	other._cancel_flight()

	for button in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_SHOULDER]:
		event.button_index = button
		event.pressed = false
		other._unhandled_input(event)
	# The same source's held edges must not survive a locality change.
	other._farm_use_held = true
	other.combat.attack_held = true
	other._climb_down = true
	other.is_local = false
	t.check("locality_change_releases_edges_and_camera", not other._farm_use_held and not other.combat.attack_held and not other._climb_down and not other.camera.enabled)

func _device_dodge(t, w: WorldRoot2D, local: Player2D, other: Player2D) -> void:
	other.reparent(w)
	w.call("_enter", &"_fixture_ortho", &"default")
	local.set_physics_process(false)
	other.is_local = true
	other.enter_area(w.area, local.global_position + Vector2(150, 0))
	other.controls.bind_pad(2)
	other.state = PlayerBody2D.S.FREE
	other.combat.reset()
	local.state = PlayerBody2D.S.FREE
	_eligible_chord(t, other)
	var axis := InputEventJoypadMotion.new()
	axis.device = 2
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 1.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	axis.device = 3
	axis.axis_value = -1.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	var button := InputEventJoypadButton.new()
	button.device = 2
	button.button_index = JOY_BUTTON_B
	button.pressed = true
	Input.parse_input_event(ScopedInputObserver.tag_if_active(button.duplicate()))
	Input.flush_buffered_events()
	t.check("parsed_bound_dodge_uses_own_stick", other.state == PlayerBody2D.S.DODGE and other.combat._dodge_direction.dot(Vector2.RIGHT) > 0.99 and local.state == PlayerBody2D.S.FREE)
	button.pressed = false
	Input.parse_input_event(ScopedInputObserver.tag_if_active(button.duplicate()))
	for device in [2, 3]:
		axis.device = device
		axis.axis_value = 0.0
		Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	other.is_local = false
	other.reparent(w)
	w.call("_enter", &"farm", &"default")
	local.set_physics_process(false)
	other.enter_area(w.area, local.global_position + Vector2(150, 0))

func _eligible_chord(t, body: Player2D) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 2
	event.pressed = true
	event.button_index = JOY_BUTTON_RIGHT_SHOULDER
	PlayerRegistry.for_player(&"p1", func(): GameData.eco().add_item(&"health_tonic", 3, true))
	body.half_hearts = 2
	body.combat.cooldowns.drink = 0.0
	var count: int = PlayerRegistry.for_player(&"p1", func(): return GameData.eco().count_item(&"health_tonic"))
	Input.parse_input_event(ScopedInputObserver.tag_if_active(event.duplicate()))
	Input.flush_buffered_events()
	t.check("bare_rb_eligible_owned_drink_positive", body._is_action_area() and body.half_hearts > 2 and body.combat.cooldowns.drink > 0.0 and PlayerRegistry.for_player(&"p1", func(): return GameData.eco().count_item(&"health_tonic")) == count - 1)
	event.pressed = false
	Input.parse_input_event(ScopedInputObserver.tag_if_active(event.duplicate()))
	Input.flush_buffered_events()
	body.half_hearts = 2
	body.combat.cooldowns.drink = 0.0
	count -= 1
	body.hotbar.select(2)
	for button in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_RIGHT]:
		event.button_index = button
		event.pressed = true
		Input.parse_input_event(ScopedInputObserver.tag_if_active(event.duplicate()))
		Input.flush_buffered_events()
	t.check("second_bank_chord_no_drink_or_cycle", body.hotbar.selected == 5 and body.half_hearts == 2 and body.combat.cooldowns.drink == 0.0)
	t.check("eligible_chord_keeps_owned_tonic", PlayerRegistry.for_player(&"p1", func(): return GameData.eco().count_item(&"health_tonic")) == count)
	for button in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_LEFT_SHOULDER]:
		event.button_index = button
		event.pressed = false
		Input.parse_input_event(ScopedInputObserver.tag_if_active(event.duplicate()))
		Input.flush_buffered_events()

## Signal-contract replay, NOT a physical unplug or an engine disconnect call.
func _disconnect_contract(t, w: WorldRoot2D, body: Player2D) -> void:
	body.is_local = true
	body.controls.bind_pad(2)
	body.state = PlayerBody2D.S.FREE
	body.combat.reset()
	var axis := InputEventJoypadMotion.new()
	axis.device = 2
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 1.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	var at := body.global_position
	body._physics_process(0.1)
	t.check("disconnect_held_sample_positive", body.controls.move_vector() == Vector2.RIGHT and body.global_position.x > at.x)
	Input.joy_connection_changed.emit(3, false)
	t.check("disconnect_unrelated_device_isolated", body.controls.move_vector() == Vector2.RIGHT)
	body._farm_use_held = true
	body._click_buffer = Vector2i.ONE
	body._climb_up = true
	body._climb_down = true
	body.combat.attack_held = true
	Input.joy_connection_changed.emit(2, false)
	t.check("disconnect_revokes_sample_without_release", body.controls.move_vector() == Vector2.ZERO)
	t.check("disconnect_revokes_body_latches", not body._farm_use_held and body._click_buffer == null and not body._climb_up and not body._climb_down and not body.combat.attack_held)
	Input.joy_connection_changed.emit(2, true)
	t.check("disconnect_reconnect_id_does_not_inherit", body.controls.move_vector() == Vector2.ZERO)
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	t.check("disconnect_new_sample_after_reconnect", body.controls.move_vector() == Vector2.RIGHT)
	var pause: Node = w.game_ui.get_screen(&"pause_menu")
	pause.open()
	t.check("disconnect_paused_fixture", GameData.gm().is_modal_open() and t.tree.paused and body.process_mode != Node.PROCESS_MODE_ALWAYS)
	Input.joy_connection_changed.emit(2, false)
	UiAudit.press_key(t, KEY_ESCAPE)
	await t.frames(2)
	t.check("disconnect_keyboard_resume_neutral", not GameData.gm().is_modal_open() and body.controls.move_vector() == Vector2.ZERO)
	t.check("disconnect_auto_pause_off_contract", not pause.auto_pause)
	axis.axis_value = 1.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	axis.axis = JOY_AXIS_RIGHT_Y
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	var held := InputEventJoypadButton.new()
	held.device = 2
	held.pressed = true
	for button in [JOY_BUTTON_LEFT_STICK, JOY_BUTTON_A, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_X]:
		held.button_index = button
		Input.parse_input_event(ScopedInputObserver.tag_if_active(held.duplicate()))
	Input.flush_buffered_events()
	t.check("disconnect_analog_and_buttons_held_positive", body.controls.action_strength(&"zoom_out") > 0.9 and body.controls.is_action_pressed(&"run") and body.controls.is_action_pressed(&"jump") and body.controls.is_action_pressed(&"fly_descend") and body.controls.is_action_pressed(&"use_tool"))
	Input.joy_connection_changed.emit(2, false)
	t.check("disconnect_all_source_holds_revoked", body.controls.move_vector() == Vector2.ZERO and body.controls.action_strength(&"zoom_out") == 0.0 and not body.controls.is_action_pressed(&"run") and not body.controls.is_action_pressed(&"jump") and not body.controls.is_action_pressed(&"fly_descend") and not body.controls.is_action_pressed(&"use_tool"))
	body.controls.bind_pad(3)
	Input.joy_connection_changed.emit(2, true)
	t.check("disconnect_rebind_does_not_restore_revoked_holds", body.controls.move_vector() == Vector2.ZERO)
	for button in [JOY_BUTTON_LEFT_STICK, JOY_BUTTON_A, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_X]:
		held.button_index = button
		held.pressed = false
		Input.parse_input_event(ScopedInputObserver.tag_if_active(held.duplicate()))
	axis.axis_value = 0.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 0.0 # cleanup singleton only; never used to establish revocation
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis))
	Input.flush_buffered_events()
	body.is_local = false

func _zoom_deadzone(t, body: Player2D, device := 2) -> void:
	var was_local := body.is_local
	body.is_local = true
	if device == 0:
		body.controls.bind_default()
	else:
		body.controls.bind_pad(device)
	body.state = PlayerBody2D.S.FREE
	var axis := InputEventJoypadMotion.new()
	axis.device = device
	axis.axis = JOY_AXIS_RIGHT_Y
	var originals := [InputMap.action_get_deadzone(&"zoom_in"), InputMap.action_get_deadzone(&"zoom_out")]
	for deadzone in [0.2, 0.35]:
		for action in [&"zoom_in", &"zoom_out"]:
			InputMap.action_set_deadzone(action, deadzone)
		for value in [-1.0, -0.6, -deadzone, -0.1, 0.0, 0.1, deadzone, 0.6, 1.0]:
			axis.axis_value = value
			Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
			Input.flush_buffered_events()
			body._set_zoom((body.area.zoom_range.x + body.area.zoom_range.y) * 0.5)
			var before := body._target_zoom
			var push := Input.get_action_strength(&"zoom_in") - Input.get_action_strength(&"zoom_out")
			var expected := clampf(before + push * float(GameData.player_cfg("zoom_stick_per_second", 0.5)) * 0.1, body.area.zoom_range.x, body.area.zoom_range.y)
			body._physics_process(0.1)
			t.check(("zoom_owned_deadzone" if device == 2 else "zoom_default_deadzone") + "_%s_%s" % [deadzone, value], is_equal_approx(body._target_zoom, expected) and body.camera.zoom.is_equal_approx(Vector2.ONE * expected), "actual=%s expected=%s engine_push=%s" % [body._target_zoom, expected, push])
	axis.axis_value = 0.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	axis.device = 3
	axis.axis_value = 1.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	var before := body._target_zoom
	body._physics_process(0.1)
	t.check("zoom_foreign_pad_isolated" + ("" if device == 2 else "_default"), body._target_zoom == before)
	axis.axis_value = 0.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis))
	Input.flush_buffered_events()
	InputMap.action_set_deadzone(&"zoom_in", originals[0])
	InputMap.action_set_deadzone(&"zoom_out", originals[1])
	body.is_local = was_local

func _unique_sources(t, first: Player2D, second: Player2D) -> void:
	first.state = PlayerBody2D.S.FREE
	second.state = PlayerBody2D.S.FREE
	first.combat.reset()
	second.combat.reset()
	second.is_local = true
	var axis := InputEventJoypadMotion.new()
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 1.0
	for kind in ["default_pad0", "same_pad2", "two_defaults"]:
		first.controls.bind_default()
		second.controls.bind_default()
		axis.device = 0
		if kind == "same_pad2":
			first.controls.bind_pad(2)
			second.controls.bind_pad(2)
			axis.device = 2
		elif kind == "default_pad0":
			second.controls.bind_pad(0)
		var p0 := first.global_position
		var p1 := second.global_position
		t.check("unique_acceptance_" + kind, first.controls.accepts_event(axis) and not second.controls.accepts_event(axis) and PlayerRegistry.for_event(axis) == first)
		Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
		Input.flush_buffered_events()
		first._physics_process(0.1)
		second._physics_process(0.1)
		t.check("unique_continuous_" + kind, first.global_position.x > p0.x and second.global_position == p1)
		axis.axis_value = 0.0
		Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
		Input.flush_buffered_events()
		axis.axis_value = 1.0
	first.controls.bind_pad(2)
	second.controls.bind_pad(2)
	axis.device = 2
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	first.is_local = false
	t.check("unique_departure_never_transfers_hold", second.controls.accepts_event(axis) and second.controls.move_vector() == Vector2.ZERO)
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	t.check("unique_successor_fresh_sample_positive", second.controls.move_vector() == Vector2.RIGHT)
	first.is_local = true
	t.check("unique_return_revokes_successor_hold", second.controls.move_vector() == Vector2.ZERO)
	first.is_local = false
	t.check("unique_return_departure_no_stale_hold", second.controls.move_vector() == Vector2.ZERO)
	first.is_local = true
	first.controls.bind_default()
	second.controls.bind_pad(2)
	axis.axis_value = 0.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis))
	Input.flush_buffered_events()
	first.camera.make_current()
	second.is_local = false

func _unique_lifetimes(t, w: WorldRoot2D, local: Player2D) -> void:
	var first := Player2D.new()
	var second := Player2D.new()
	w._register_player(first, 2, 3)
	w.add_child(first)
	w._register_player(second, 3, 4)
	w.add_child(second)
	for body in [first, second]:
		body.set_physics_process(false)
		body.controls.bind_pad(6)
		body.is_local = true
		body.enter_area(w.area, local.global_position + Vector2(0, 250 + body.player_slot * 70))
	var axis := InputEventJoypadMotion.new()
	axis.device = 6
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 1.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	t.check("unique_queued_owner_live_positive", first.controls.move_vector() == Vector2.RIGHT and second.controls.move_vector() == Vector2.ZERO)
	first.queue_free()
	t.check("unique_queued_owner_revoked", not first.controls.accepts_event(axis) and second.controls.accepts_event(axis) and second.controls.move_vector() == Vector2.ZERO)
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	var at := second.global_position
	second._physics_process(0.1)
	t.check("unique_queued_successor_moves_on_fresh_sample", second.global_position.x > at.x)
	var old_source := second.controls
	second.controls = PlayerInput.new()
	second.controls.attach(second)
	second.controls.bind_pad(6)
	t.check("unique_source_replacement_revokes_old_instance", not old_source.local_active() and old_source.move_vector() == Vector2.ZERO and second.controls.move_vector() == Vector2.ZERO)
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	second._physics_process(0.1)
	var current_velocity := second._gvel
	old_source.clear()
	old_source.detach()
	t.check("unique_stale_source_cannot_revoke_current_body", current_velocity.x > 0.0 and second._gvel == current_velocity and second.controls.move_vector() == Vector2.RIGHT)
	var replacement := Player2D.new()
	w._register_player(replacement, 3, 4)
	w.add_child(replacement)
	replacement.set_physics_process(false)
	replacement.controls.bind_pad(6)
	replacement.is_local = true
	replacement.enter_area(w.area, second.global_position + Vector2(100, 0))
	t.check("unique_registered_slot_replacement_neutral", not second.controls.accepts_event(axis) and replacement.controls.accepts_event(axis) and replacement.controls.move_vector() == Vector2.ZERO)
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	at = replacement.global_position
	replacement._physics_process(0.1)
	t.check("unique_replacement_fresh_sample_moves", replacement.global_position.x > at.x)
	axis.axis_value = 0.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis))
	Input.flush_buffered_events()
	w._unregister_player(second)
	t.check("unique_displaced_unregistered_refusal_preserves_body", is_instance_valid(second) and not second.is_queued_for_deletion() and second.is_in_group("player") and second.is_local and PlayerRegistry.registered_id(second) == &"" and not second.controls.accepts_event(axis), "unowned displaced body correctly refuses authority and is not deleted by unregister")
	# This fixture owns the displaced Node, not World._unregister_player. Retire
	# exactly that orphan after proving the negative authority contract above.
	second.queue_free()
	w._unregister_player(replacement)
	await t.frames(2)
	local.camera.make_current()

func _passive_stub(t, w: WorldRoot2D, local: Player2D) -> void:
	var listener_count := Input.get_signal_connection_list(&"joy_connection_changed").size()
	var stub := PlayerStub2D.new()
	w._register_player(stub, 2, 3)
	w.add_child(stub)
	stub.set_physics_process(false)
	stub.enter_area(w.area, local.global_position + Vector2(0, 200))
	stub._prompt = "passive sentinel"
	var frame := {"sequence": 1, "move": [1.0, 0.0], "aim": [320.0, 170.0], "actions": {"zoom_in": true, "interact": true}}
	t.check("stub_passive_frame_positive", stub.controls.submit_remote_frame(frame) and stub.controls.move_vector() == Vector2.RIGHT)
	var at := stub.global_position
	var zoom := stub.camera.zoom
	var stale := stub._prompt_stale
	stub._physics_process(0.1)
	t.check("stub_passive_frame_no_world_writes", stub.global_position == at and stub.camera.zoom == zoom and stub._prompt == "passive sentinel" and stub._prompt_stale == stale)
	await t.until(func(): return stub.controls.move_vector() == Vector2.ZERO, 1.0)
	stub._physics_process(0.1)
	t.check("stub_expired_frame_no_world_writes", stub.global_position == at and stub.camera.zoom == zoom and stub._prompt == "passive sentinel" and stub._prompt_stale == stale)
	stub.is_local = true
	stub.controls.bind_pad(5)
	var axis := InputEventJoypadMotion.new()
	axis.device = 5
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 1.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	stub._physics_process(0.1)
	t.check("stub_registered_local_movement_positive", stub.global_position.x > at.x)
	w.remove_from_group(&"world_2d")
	at = stub.global_position
	stub._physics_process(0.1)
	t.check("stub_no_world_local_fixture_positive", stub.global_position.x > at.x)
	w.add_to_group(&"world_2d")
	axis.axis_value = 0.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis))
	Input.flush_buffered_events()
	w._unregister_player(stub)
	await t.frames(2)
	t.check("disconnect_listener_freed_with_body", Input.get_signal_connection_list(&"joy_connection_changed").size() == listener_count)
	local.camera.make_current()

func _modal_origin_samples(t, body: Player2D) -> void:
	body.is_local = true
	body.controls.bind_pad(2)
	body.state = PlayerBody2D.S.FREE
	var before := body.global_position
	var clip := body.visual.current_clip
	var frame: int = body.visual._frame
	var zoom := body.camera.zoom
	GameData.gm().push_modal(&"input_origin_probe", true)
	for button in [JOY_BUTTON_A, JOY_BUTTON_DPAD_DOWN]:
		var event := InputEventJoypadButton.new()
		event.device = 2
		event.button_index = button
		event.pressed = true
		Input.parse_input_event(ScopedInputObserver.tag_if_active(event.duplicate()))
		Input.flush_buffered_events()
	await t.frames(3)
	t.check("modal_origin_capture_child_alive", body.controls.is_action_pressed(&"jump") and body.controls.is_action_pressed(&"fly_descend") and body.get_node("InputCapture").can_process())
	t.check("modal_origin_body_and_visuals_paused", body.global_position == before and body.camera.zoom == zoom and body.visual._frame == frame and body.visual.current_clip == clip and not body.visual.can_process() and not body.can_process())
	for button in [JOY_BUTTON_A, JOY_BUTTON_DPAD_DOWN]:
		var event := InputEventJoypadButton.new()
		event.device = 2
		event.button_index = button
		event.pressed = false
		Input.parse_input_event(ScopedInputObserver.tag_if_active(event))
		Input.flush_buffered_events()
	GameData.gm().pop_modal(&"input_origin_probe")
	body._physics_process(0.1)
	t.check("modal_origin_releases_resume_neutral", not body.controls.is_action_pressed(&"jump") and not body.controls.is_action_pressed(&"fly_descend") and not body._climb_up and not body._climb_down and body.global_position == before)
	body.is_local = false

func _remote_frame(t, other: Player2D) -> void:
	var frame := {"sequence": 1, "move": [1.0, 0.0], "aim": [320.0, 170.0], "actions": {"use_tool": true}}
	if other.controls.has_method("submit_remote_frame"):
		other.controls.call("submit_remote_frame", frame)
	t.check("remote_frame_offline_sample", other.controls.move_vector() == Vector2.RIGHT and other.controls.is_action_pressed(&"use_tool"))
	var at := other.global_position
	other._physics_process(0.1)
	t.check("remote_frame_not_world_write_authority", other.global_position == at and not other.use_selected())
	var bad: Array = [null, true, 1, 1.25, NAN, INF, {}, [], Vector2.ONE, Callable()]
	var rejected := true
	if other.controls.has_method("submit_remote_frame"):
		for value in bad:
			var accepted: bool = other.controls.call("submit_remote_frame", value)
			rejected = not accepted and rejected
		for value in [null, true, 2.0, -2.0, NAN, INF, {}, [], Vector2.ONE, Callable()]:
			var malformed := frame.duplicate(true)
			malformed["sequence"] = 2
			malformed["move"] = [value, 0]
			var accepted: bool = other.controls.call("submit_remote_frame", malformed)
			rejected = not accepted and rejected
	t.check("remote_frame_rejects_malformed_atomically", rejected and other.controls.move_vector() == Vector2.RIGHT)
	var next_sequence := 2
	for field in ["sequence", "aim", "actions"]:
		var all_rejected := true
		for value in [null, true, "bad", NAN, INF, [], {}, Vector2.ONE, Callable()]:
			var malformed := frame.duplicate(true)
			malformed["sequence"] = next_sequence
			next_sequence += 1
			malformed[field] = value
			var accepted: bool = other.controls.submit_remote_frame(malformed)
			# Empty actions is a legitimate zero-button frame.
			if field == "actions" and typeof(value) == TYPE_DICTIONARY and value.is_empty():
				all_rejected = accepted and all_rejected
			else:
				all_rejected = not accepted and all_rejected
		t.check("remote_frame_typed_" + field, all_rejected)
	# Use increasing sequences so malformed data reaches its own boundary, not replay rejection.
	var valid := {"sequence": 100, "move": [1.0, 1.0], "aim": [10000000, -10000000], "actions": {}}
	for action_name in other.controls.REMOTE_ACTIONS:
		valid["actions"][action_name] = true
	t.check("remote_frame_exact_bounds", other.controls.submit_remote_frame(valid) and is_equal_approx(other.controls.move_vector().length(), 1.0))
	valid["move"][0] = -1.0
	valid["actions"]["use_tool"] = false
	t.check("remote_frame_copies_payload", other.controls.move_vector().x > 0.0 and other.controls.is_action_pressed(&"use_tool"))
	t.check("remote_frame_duplicate_and_older_refused", not other.controls.submit_remote_frame(valid) and not other.controls.submit_remote_frame({"sequence": 99, "move": [0, 0], "aim": [0, 0], "actions": {}}) and other.controls.move_vector().x > 0.0)
	t.check("remote_frame_unknown_action_under_bound", not other.controls.submit_remote_frame({"sequence": 101, "move": [0, 0], "aim": [0, 0], "actions": {"unknown": true}}))
	var overflow := valid.duplicate(true)
	overflow["sequence"] = 101
	overflow["actions"]["unknown"] = false
	t.check("remote_frame_action_bound", not other.controls.submit_remote_frame(overflow))
	var boundaries := [["sequence", -1], ["sequence", 2147483648], ["sequence", 1.5], ["aim", [10000001, 0]], ["actions", {"run": 1}], ["actions", {&"run": true}]]
	for index in boundaries.size():
		var pair: Array = boundaries[index]
		var malformed := valid.duplicate(true)
		malformed["sequence"] = 101
		malformed[pair[0]] = pair[1]
		t.check("remote_frame_boundary_%d" % index, not other.controls.submit_remote_frame(malformed), str(pair))
	var expired: bool = await t.until(func(): return other.controls.move_vector() == Vector2.ZERO, 1.0)
	t.check("remote_frame_expires_without_global_poll", expired and not other.controls.is_action_pressed(&"use_tool"))
	t.check("remote_frame_expiry_keeps_replay_watermark", not other.controls.submit_remote_frame(valid) and other.controls.move_vector() == Vector2.ZERO)

func _lifetime_and_default(t, w: WorldRoot2D, local: Player2D, other: Player2D) -> void:
	other.is_local = true
	other.state = PlayerBody2D.S.FREE
	# Fresh source: earlier deliberate foreign events must not mask aggregate leakage.
	other.controls = load("res://scripts/player/player_input.gd").new()
	other.controls.attach(other)
	other.controls.bind_pad(2)
	var axis := InputEventJoypadMotion.new()
	axis.device = 2
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 1.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	t.check("bound_held_fixture", other.controls.move_vector().x > 0.9)
	var gm := GameData.gm()
	gm.push_modal(&"multiplayer_input_pause", true)
	axis.axis_value = 0.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	gm.pop_modal(&"multiplayer_input_pause")
	t.check("paused_pad_release_is_not_latched", other.controls.move_vector() == Vector2.ZERO)
	axis.axis_value = 1.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	other.controls.bind_default()
	t.check("rebind_cannot_inherit_held_aggregate", other.controls.move_vector() == Vector2.ZERO)
	axis.axis_value = 0.0
	Input.parse_input_event(ScopedInputObserver.tag_if_active(axis.duplicate()))
	Input.flush_buffered_events()
	# A forged Action has no pad identity, even when its device equals the binding.
	other.controls.bind_pad(2)
	var action := InputEventAction.new()
	action.action = &"slot_2"
	action.device = 2
	action.pressed = true
	other.hotbar.select(0)
	other._unhandled_input(action)
	t.check("action_event_cannot_forge_pad_identity", other.hotbar.selected == 0 and PlayerRegistry.for_event(action) == null)
	other.is_local = false
	var parent := other.get_parent()
	parent.remove_child(other)
	t.check("detached_body_removed_from_lookup", PlayerRegistry.by_id(&"p1") == null and PlayerRegistry.registered_id(other) == &"")
	parent.add_child(other)
	other.enter_area(w.area, other.global_position)
	t.check("remote_reentry_keeps_local_camera", local.camera.is_current() and not other.camera.enabled)
	# Only the no-world idle fixture contract is allowed to use plain group nodes.
	w.remove_from_group("world_2d")
	local.remove_from_group("player")
	other.remove_from_group("player")
	await t.frames(1) # let the queued clone leave the group before the standalone fixture
	var fixture := Node.new()
	t.root.add_child(fixture)
	fixture.add_to_group("player")
	var eligible: Array = t.tree.get_nodes_in_group("player").filter(func(body: Node): return not body.is_queued_for_deletion() and (not "is_local" in body or bool(body.get("is_local"))))
	t.check("no_world_plain_fixture_sole_eligible_group_member", eligible == [fixture], "eligible IDs=%s" % [eligible.map(func(body: Node): return body.get_instance_id())])
	t.check("no_world_plain_node_idle_compatibility", PlayerRegistry.local_player() == fixture and PlayerRegistry.for_event(null) == fixture and PlayerRegistry.registered_id(fixture) == &"")
	fixture.queue_free()
	w.add_to_group("world_2d")
	local.add_to_group("player")
	other.add_to_group("player")
	for script in ["player_2d", "player_body_2d", "player_combat_2d"]:
		var source := FileAccess.get_file_as_string("res://scripts/world2d/%s.gd" % script)
		var rx := RegEx.create_from_string(r"\bInput\.")
		t.check("no_input_singleton_" + script, rx.search(source) == null)
