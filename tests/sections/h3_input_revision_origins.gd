extends RefCounted
const SECTION := "h3_input_revision_origins"
const TIMEOUT_S := 180.0
const H1 := preload("res://tests/sections/boss_terminal_origins.gd")

func run(t) -> void:
	await _rebind(t)

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
