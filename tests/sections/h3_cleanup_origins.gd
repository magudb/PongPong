extends RefCounted
const SECTION := "h3_cleanup_origins"
const TIMEOUT_S := 180.0
const H1 := preload("res://tests/sections/boss_terminal_origins.gd")

func run(t) -> void:
	var selected := OS.get_environment("H3_CLEANUP_CASE")
	if selected in ["", "swing"]:
		for mode in ["child_visual", "texture_both", "shake_camera"]:
			await _replacement(t, mode)
	if selected in ["", "pool"]:
		for kind in ["spark", "ring"]:
			for mode in ["transfer", "detach", "queued", "new_lease", "normal"]:
				await _finish(t, kind, mode)

func _replacement(t, mode: String) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version", 0)
	var player: Player2D = t.player()
	var combat := player.combat
	EconomyManager.add_item(&"sword_rusty", 1)
	player.global_position = boss.home + Vector2(-60, 0)
	# Enable real actor ticks before admission; never repair state after the callback.
	player.set_physics_process(true)
	await t.physics(2)
	var other := Node2D.new()
	t.world().add_child(other)
	var old_visual := player.visual
	var old_camera := player.camera
	var replacement := IsoChibiSprite2D.create(old_visual.character_id)
	player.add_child(replacement)
	replacement.set_spin(.73)
	var camera := Camera2D.new()
	camera.enabled = false
	player.add_child(camera)
	camera.position = Vector2(71, 73)
	var visual_changed := mode != "shake_camera"
	var camera_changed := mode != "child_visual"
	old_visual.play_loop(&"idle")
	var before := EventBus.combat_receipt(EventBus.combat_origin(player))
	var seen: Array = []
	var notices: Array = []
	var change := func():
		if not seen.is_empty(): return
		seen.append(true)
		if visual_changed:
			old_visual.reparent(other)
			player.visual = replacement
		if camera_changed:
			old_camera.reparent(other)
			player.camera = camera
		seen.append(combat._action_serial)
		seen.append(combat._remaining)
	var child := func(node):
		if node is Slash2D: change.call()
	var texture := func(): change.call()
	var notice := func(_id): notices.append(true)
	combat.weapon_drawn.connect(notice)
	t.check(mode + "_enabled_registered_unpaused_eligible", player.is_physics_processing() and player.world_input_allowed() and player.state == PlayerBody2D.S.FREE and PlayerRegistry.registered_id(player) == &"p0" and replacement.sprite != null)
	if mode == "child_visual": player.child_entered_tree.connect(child)
	elif mode == "texture_both": old_visual.sprite.texture_changed.connect(texture)
	t.check(mode + "_actual_swing_admitted", combat.swing(&"sword_rusty", boss.global_position))
	if mode == "shake_camera":
		t.check(mode + "_real_hitstop_and_shake_reached", await t.until_game(func(): return combat.hit_stop > 0 and combat._shake > 0, 1.0))
		old_visual.sprite.texture_changed.connect(texture)
		# Public presentation call reaches its actual texture notification while the
		# original hit's stored shake is live. No forced combat tick/cleanup.
		old_visual.play_loop(&"idle")
	if mode == "child_visual": player.child_entered_tree.disconnect(child)
	else: old_visual.sprite.texture_changed.disconnect(texture)
	combat.weapon_drawn.disconnect(notice)
	t.check(mode + "_legal_callback_exact_old_action_model_unchanged", seen.size() == 3 and seen[1] == combat._action_serial and seen[2] > 0 and EventBus.combat_current(before) and player.state == PlayerBody2D.S.SWING)
	t.check(mode + "_eligible_replacement_attached", (not visual_changed or player.visual == replacement and replacement.get_parent() == player) and (not camera_changed or player.camera == camera and camera.get_parent() == player))
	if mode != "shake_camera": t.check(mode + "_old_immediate_publication_refused", notices.is_empty())
	var hp := boss.hp
	await t.frames(3)
	t.check(mode + "_three_frames_replacement_presentation_preserved", (not visual_changed or is_equal_approx(replacement._spin, .73)) and (not camera_changed or camera.position == Vector2(71, 73)))
	await t.seconds(1.0)
	t.check(mode + "_later_than_old_timer_and_hitstop_no_adoption", (not visual_changed or is_equal_approx(replacement._spin, .73)) and (not camera_changed or camera.position == Vector2(71, 73)) and boss.hp == hp)
	t.check(mode + "_obsolete_swing_retired_naturally_not_stalled", player.state == PlayerBody2D.S.FREE and combat.hit_stop == 0 and combat._shake == 0 and player.is_physics_processing() and player.world_input_allowed())
	# A genuine future current action must run using the replacement, without
	# fixture writes to timers/state/physics/buffers after the observer.
	var fresh: Array = []
	var drawn := func(_id): fresh.append(true)
	combat.weapon_drawn.connect(drawn)
	combat.request(&"slash", &"sword_rusty", boss.global_position)
	combat.weapon_drawn.disconnect(drawn)
	t.check(mode + "_future_current_press_publishes", fresh.size() == 1 and player.state == PlayerBody2D.S.SWING and combat._action_serial > seen[1])
	t.check(mode + "_future_current_action_hits", await t.until_game(func(): return boss.hp < hp, 1.0))
	await t.seconds(1.0)
	t.check(mode + "_future_action_completes_on_real_ticks", player.state == PlayerBody2D.S.FREE and player.world_input_allowed())
	await t.go_menu()

func _play(parent: Node, kind: String) -> Variant:
	return DungeonSpark2D.play(parent, Vector2(20, 30), Color.WHITE) if kind == "spark" else TelegraphRing2D.play(parent, Vector2(20, 30), {"duration":20.0})

func _clock(slot: Node, kind: String) -> float:
	return float(slot.get("age" if kind == "spark" else "elapsed"))

func _finish(t, kind: String, mode: String) -> void:
	if not await t.start_world(): return
	TimeManager.pause_time()
	t.on_cleanup(func(): TimeManager.resume_time())
	var parent := Node2D.new()
	t.world().area.ground_fx.add_child(parent)
	var receiver := Node2D.new()
	t.world().area.ground_fx.add_child(receiver)
	var slot: Variant = _play(parent, kind)
	var tag := kind + "_false_finish_" + mode
	t.check(tag + "_real_activation_live", is_instance_valid(slot) and slot.active and slot.visible and slot.is_processing())
	if not is_instance_valid(slot): return
	var lease: int = slot.serial
	var seen: Array = []
	var observer := func():
		if slot.visible or not seen.is_empty(): return
		seen.append(slot.serial)
		match mode:
			"transfer": slot.reparent(receiver)
			"detach": slot.get_parent().remove_child(slot)
			"queued": slot.queue_free()
			"new_lease": seen.append(_play(parent, kind))
		if mode in ["transfer", "detach", "queued"]: slot.set_process(true)
		seen.append([slot.serial, slot.is_processing(), slot.active, slot.visible])
	slot.visibility_changed.connect(observer)
	slot.finish()
	slot.visibility_changed.disconnect(observer)
	t.check(tag + "_actual_false_notification_retired_before_callback", not seen.is_empty() and seen[0] != lease)
	var endpoint: Array = seen.back() if not seen.is_empty() else []
	t.check(tag + "_callback_process_and_lease_survive_unwind", [slot.serial, slot.is_processing(), slot.active, slot.visible] == endpoint)
	if mode == "queued":
		var ref: WeakRef = weakref(slot)
		await t.frames(3)
		t.check(tag + "_actual_queued_destruction", not is_instance_valid(ref.get_ref()))
	else:
		if mode == "detach":
			t.check(tag + "_detached_endpoint_preserved", slot.get_parent() == null and not slot.is_inside_tree())
			receiver.add_child(slot)
		var clock := _clock(slot, kind)
		await t.frames(3)
		if mode in ["transfer", "detach"]:
			t.check(tag + "_receiving_owner_process_observable_later_frames", slot.get_parent() == receiver and slot.is_processing() and _clock(slot, kind) > clock and not slot.active and not slot.visible)
		elif mode == "new_lease":
			t.check(tag + "_genuine_unique_successor_keeps_processing", seen.size() == 3 and seen[1] == slot and slot.serial != seen[0] and slot.active and slot.visible and slot.is_processing() and _clock(slot, kind) > clock)
		else:
			t.check(tag + "_ordinary_finish_stays_stopped", not slot.active and not slot.visible and not slot.is_processing() and _clock(slot, kind) == clock)
	await t.go_menu()
