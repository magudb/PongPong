extends RefCounted
const SECTION := "h3_input_revision_origins"
const TIMEOUT_S := 180.0
const H1 := preload("res://tests/sections/boss_terminal_origins.gd")

func run(t) -> void:
	await _rebind(t)
	await _current_dodge(t, true)
	await _current_dodge(t, false)
	await _replacement(t)

func _rebind(t) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version", 0)
	var player: Player2D = t.player()
	var combat := player.combat
	EconomyManager.add_item(&"sword_rusty", 1)
	player.global_position = boss.home + Vector2(-60, 0)
	player.controls.bind_default()
	player.set_physics_process(true)
	await t.physics(2)
	var original_visual := player.visual
	var original_camera := player.camera
	var model := EventBus.combat_receipt(EventBus.combat_origin(player))
	var revision := player.controls.revision
	var seen: Array = []
	var notices: Array = []
	var child := func(node):
		if not node is Slash2D or not seen.is_empty(): return
		seen.append({"serial":combat._action_serial, "remaining":combat._remaining, "duration":combat._swing_duration, "cooldown":combat.cooldowns.slash, "root":combat._swing_action.root})
		# Public synchronous revocation at real early Slash admission. No fixture
		# writes to action state/timers/serials, or repairs after this callback.
		player.controls.bind_default()
		seen.append(player.controls.revision)
	var notice := func(_id): notices.append(true)
	player.child_entered_tree.connect(child)
	combat.weapon_drawn.connect(notice)
	t.check("default_enabled_registered_unpaused_eligible", player.is_physics_processing() and player.controls.local_active() and player.world_input_allowed() and player.state == PlayerBody2D.S.FREE and PlayerRegistry.registered_id(player) == &"p0")
	t.check("real_swing_admitted", combat.swing(&"sword_rusty", boss.global_position))
	player.child_entered_tree.disconnect(child)
	combat.weapon_drawn.disconnect(notice)
	t.check("public_bind_default_callback_reached_once", seen.size() == 2 and seen[1] > revision and seen[1] == player.controls.revision)
	if seen.size() != 2:
		await t.go_menu()
		return
	t.check("early_full_swing_committed_before_rebind", seen[0].remaining > 0 and seen[0].remaining == seen[0].duration and player.state == PlayerBody2D.S.SWING and combat._remaining == seen[0].remaining)
	t.check("model_body_component_and_presentation_unchanged", EventBus.combat_current(model) and PlayerRegistry.by_id(&"p0") == player and combat.get_parent() == player and player.combat == combat and player.visual == original_visual and player.camera == original_camera)
	t.check("old_input_admission_and_immediate_publication_revoked", seen[0].root.input_revision == revision and not combat._root_current(seen[0].root) and notices.is_empty() and combat._buffer == &"" and not combat.attack_held)
	var hp := boss.hp
	var start_frame := Engine.get_physics_frames()
	await t.seconds(seen[0].duration + .6)
	print("H3_C1_TRACE ", JSON.stringify({"phase":"beyond_original_duration", "physics_frames":Engine.get_physics_frames() - start_frame, "state":player.state, "remaining":combat._remaining, "cooldown":combat.cooldowns.slash, "original":seen[0].remaining, "revision":player.controls.revision}))
	t.check("enabled_natural_physics_beyond_original_duration", Engine.get_physics_frames() > start_frame + 20 and player.is_physics_processing() and player.controls.local_active() and player.world_input_allowed())
	t.check("obsolete_swing_retires_without_fixture_repair", player.state == PlayerBody2D.S.FREE and combat._remaining <= 0 and combat._swing_action.is_empty() and combat._action_serial > seen[0].serial)
	t.check("fresh_tick_cooldown_clocks_progress", combat.cooldowns.slash < seen[0].cooldown and combat.cooldowns.slash == 0)
	t.check("revoked_attack_never_hits_or_publishes_later", boss.hp == hp and notices.is_empty())
	var fresh: Array = []
	var drawn := func(_id): fresh.append(true)
	combat.weapon_drawn.connect(drawn)
	combat.request(&"slash", &"sword_rusty", boss.global_position)
	combat.weapon_drawn.disconnect(drawn)
	t.check("genuine_next_current_request_publishes", fresh.size() == 1 and player.state == PlayerBody2D.S.SWING and combat._action_serial > seen[0].serial)
	t.check("genuine_next_current_request_hits", await t.until_game(func(): return boss.hp < hp, 1.0))
	await t.seconds(1.0)
	t.check("genuine_next_action_completes_on_natural_frames", player.state == PlayerBody2D.S.FREE and player.world_input_allowed() and player.is_physics_processing())
	await t.go_menu()

func _current_dodge(t, buffered: bool) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version", 0)
	var player: Player2D = t.player()
	var combat := player.combat
	var tag := "current_buffer" if buffered else "newer_dodge"
	EconomyManager.add_item(&"sword_rusty", 1)
	player.global_position = boss.home + Vector2(-60, 0)
	player.controls.bind_default()
	player.set_physics_process(true)
	await t.physics(2)
	var seen: Array = []
	var notices: Array = []
	var child := func(node):
		if not buffered or not node is Slash2D or not seen.is_empty(): return
		seen.append(combat._action_serial)
		player.controls.bind_default()
		combat.request(&"dodge")
		seen.append(combat._buffer_serial)
		seen.append(combat._buffer_origin)
	var dodged := func(): notices.append([combat._action_serial, combat._remaining, combat.cooldowns.dodge])
	player.child_entered_tree.connect(child)
	player.dodged.connect(dodged)
	t.check(tag + "_real_swing_enabled_eligible", player.is_physics_processing() and player.world_input_allowed() and combat.swing(&"sword_rusty", boss.global_position))
	player.child_entered_tree.disconnect(child)
	if buffered:
		t.check(tag + "_public_new_revision_press_buffered", seen.size() == 3 and player.state == PlayerBody2D.S.SWING and combat._buffer == &"dodge" and combat._buffer_serial == seen[1] and combat._root_current(seen[2]))
	else:
		t.check(tag + "_natural_late_swing_admits_dodge_phase", await t.until_game(func(): return player.state == PlayerBody2D.S.SWING and 1.0 - combat._remaining / combat._swing_duration >= .4, 1.0))
		seen.append(combat._action_serial)
		player.controls.bind_default()
		t.check(tag + "_public_dodge_replaces_obsolete_serial", combat.dodge() and player.state == PlayerBody2D.S.DODGE and combat._action_serial > seen[0])
	t.check(tag + "_genuine_dodge_publication_on_current_root", await t.until_game(func(): return notices.size() == 1, .3))
	player.dodged.disconnect(dodged)
	var position := player.global_position
	await t.physics(3)
	t.check(tag + "_new_serial_timer_iframes_and_motion_survive", notices.size() == 1 and player.state == PlayerBody2D.S.DODGE and combat._action_serial == notices[0][0] and combat._remaining > 0 and combat._remaining < notices[0][1] and combat.cooldowns.dodge < notices[0][2] and combat._iframes > 0 and player.invulnerable and combat.extra_altitude > 0 and player.global_position != position)
	await t.seconds(1.0)
	t.check(tag + "_natural_completion_and_clocks_not_stalled", player.state == PlayerBody2D.S.FREE and combat.cooldowns.dodge == 0 and combat._iframes == 0 and not player.invulnerable and player.is_physics_processing())
	await t.go_menu()

func _replacement(t) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version", 0)
	var player: Player2D = t.player()
	var combat := player.combat
	EconomyManager.add_item(&"sword_rusty", 1)
	player.global_position = boss.home + Vector2(-60, 0)
	player.controls.bind_default()
	player.set_physics_process(true)
	await t.physics(2)
	var receiver := Node2D.new()
	t.world().add_child(receiver)
	var old_visual := player.visual
	var old_camera := player.camera
	var visual := IsoChibiSprite2D.create(old_visual.character_id)
	player.add_child(visual)
	visual.set_spin(.73)
	var camera := Camera2D.new()
	camera.enabled = false
	player.add_child(camera)
	camera.position = Vector2(71, 73)
	var seen: Array = []
	var notices: Array = []
	var child := func(node):
		if not node is Slash2D or not seen.is_empty(): return
		seen.append(combat._action_serial)
		player.controls.bind_default()
		old_visual.reparent(receiver)
		old_camera.reparent(receiver)
		player.visual = visual
		player.camera = camera
	var drawn := func(_id): notices.append(true)
	combat.weapon_drawn.connect(drawn)
	player.child_entered_tree.connect(child)
	t.check("rebind_replacement_real_enabled_swing_admitted", player.is_physics_processing() and player.world_input_allowed() and combat.swing(&"sword_rusty", boss.global_position))
	player.child_entered_tree.disconnect(child)
	t.check("rebind_replacement_actual_callback_and_old_suffix_refused", seen.size() == 1 and notices.is_empty() and player.visual == visual and player.camera == camera)
	var hp := boss.hp
	await t.seconds(1.0)
	t.check("rebind_replacement_natural_retirement_no_presentation_adoption", player.state == PlayerBody2D.S.FREE and is_equal_approx(visual._spin, .73) and camera.position == Vector2(71, 73) and boss.hp == hp and notices.is_empty())
	combat.request(&"slash", &"sword_rusty", boss.global_position)
	t.check("rebind_replacement_genuine_current_action_publishes", notices.size() == 1 and player.state == PlayerBody2D.S.SWING and combat._action_serial > seen[0])
	t.check("rebind_replacement_genuine_current_action_hits", await t.until_game(func(): return boss.hp < hp, 1.0))
	combat.weapon_drawn.disconnect(drawn)
	await t.seconds(1.0)
	t.check("rebind_replacement_future_natural_completion", player.state == PlayerBody2D.S.FREE and visual._spin == 0 and player.world_input_allowed())
	await t.go_menu()
