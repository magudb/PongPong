extends RefCounted
## Small, explicit state fixtures for defects found by the separate continuous
## journey. These fixtures are not evidence of earning progression.
const SECTION := "journey_regressions"
var native := false

class Target extends Node2D:
	var damage := 0
	func take_hit(amount: int, _origin: Vector2, _source: Node) -> void: damage += amount

func run_windowed(t) -> void:
	native = true
	await run(t)

func run(t) -> void:
	await t.start_world()
	_warp_actions(t)
	await _physical_warp(t)
	await _spear_aim(t)
	QuestManager.accept_quest(SecretGardenStory.QUEST)
	for step in 9:
		if step == 6: GameManager.end_day()
		t.check("garden_fixture_step_"+str(step),SecretGardenStory.advance(step))
	var source := {"lines":[],"choices":[]}
	for i in 8:
		source.choices.append({"id":"side_"+str(i),"action":"open_journal","text_key":"UI_JOURNAL"})
	var page := DialogueBridge.decorate("guard_oak",source)
	t.check("pending_garden_reply_is_first",page.choices[0].action == "garden_story")
	t.check("overflow_stays_bounded",page.choices.size() == 5 and page.choices[-1].action == "close")
	var all := _flatten(page.choices)
	t.check("all_eight_other_options_survive",range(8).all(func(i):return all.has("side_"+str(i))))
	t.check("required_reply_is_not_duplicated",all.count("secret_garden") == 1)
	SecretGardenStory.advance(9)
	page = DialogueBridge.decorate("guard_oak",source)
	t.check("old_garden_reply_does_not_displace_new_quests",page.choices[0].id == "side_0")
	SecretGardenStory.advance(10)
	t.check("witness_fixture_available",MotherStory.record("marked_lamp"))
	page = DialogueBridge.decorate("mapseller_natteblik",source)
	t.check("pending_mother_evidence_is_first",page.choices[0].action == "mother_story")
	t.check("witness_options_are_preserved",range(8).all(func(i):return _flatten(page.choices).has("side_"+str(i))))
	MotherStory.record("map_account")
	page = DialogueBridge.decorate("mapseller_natteblik",source)
	t.check("recorded_witness_recall_does_not_displace_new_quests",page.choices[0].id == "side_0")
	var scripted := {"social":false,"lines":[],"choices":source.choices.duplicate(true)}
	t.check("scripted_pages_remain_exact",DialogueBridge.decorate("guard_oak",scripted) == scripted)

func _warp_actions(t) -> void:
	var warp := Warp2D.new()
	warp.to_area = &"journey_warp_contract"
	var requests := []
	var listen := func(area_id,spawn): requests.append([area_id,spawn])
	EventBus.area_change_requested.connect(listen)
	for state in [PlayerBody2D.S.DODGE,PlayerBody2D.S.SWING,PlayerBody2D.S.HURT,PlayerBody2D.S.FAINTED,PlayerBody2D.S.TALKING,PlayerBody2D.S.USING]:
		t.player().state = state
		warp._on_body_entered(t.player())
		t.check("action_cannot_trigger_travel_"+str(state),requests.is_empty())
	t.player().state = PlayerBody2D.S.FREE
	warp._on_body_entered(t.player())
	t.check("ordinary_walking_still_triggers_travel",requests == [[&"journey_warp_contract",&"default"]])
	EventBus.area_change_requested.disconnect(listen)
	warp.free()

func _physical_warp(t) -> void:
	var ground := PackedStringArray()
	var objects := PackedStringArray()
	for y in 8:
		ground.append("m".repeat(12))
		objects.append("...@........" if y == 4 else ".".repeat(12))
	var map := AreaMap.parse_text("@id _journey_warp\n@projection ortho\n@ambient forest\n@theme forest\n@ground\n"+"\n".join(ground)+"\n@objects\n"+"\n".join(objects)+"\n")
	WorldRoot2D.register_map(&"_journey_warp",map)
	await t.world().travel(&"_journey_warp",&"default")
	var area: IsoArea = t.world().area
	var warp := Warp2D.new()
	warp.setup({"to":"journey_warp_contract","r":"0"},area,Vector2i(6,4))
	warp.position = t.player().global_position+Vector2(190,0)
	area.triggers.add_child(warp)
	var requests := []
	var entries := []
	warp.body_entered.connect(func(body):
		if body == t.player(): entries.append(int(body.state)))
	var listen := func(id,_spawn):
		if id == &"journey_warp_contract": requests.append(id)
	EventBus.area_change_requested.connect(listen)
	await t.physics(4)
	t.hold(&"move_right")
	await t.physics(2)
	t.tap(&"dodge")
	await t.physics(18)
	t.release_all()
	await t.physics(8)
	t.check("real_dodge_enters_stair_trigger",PlayerBody2D.S.DODGE in entries,str(entries))
	t.check("real_dodge_cannot_change_area",requests.is_empty() and area.map.id == &"_journey_warp")
	if native: await t.capture("dodge_across_stair_keeps_encounter")
	var away: StringName = &"move_right" if t.player().global_position.x >= warp.global_position.x else &"move_left"
	t.hold(away)
	await t.physics(55)
	t.release_all()
	await t.physics(4)
	t.check("player_can_step_back_off_stair",not warp.overlaps_body(t.player()))
	t.hold(&"move_left" if away == &"move_right" else &"move_right")
	await t.physics(100)
	t.release_all()
	await t.physics(4)
	t.check("real_walk_reentry_requests_travel",not requests.is_empty())
	EventBus.area_change_requested.disconnect(listen)
	await t.world().travel(&"farm",&"default")
	WorldRoot2D.unregister_map(&"_journey_warp")

func _flatten(choices: Array) -> Array:
	var ids := []
	for choice in choices:
		ids.append(str(choice.get("id","")))
		ids.append_array(_flatten(LuaData.arr(choice.get("choices",[]))))
	return ids

func _spear_aim(t) -> void:
	EconomyManager.add_item(&"wpn_spear_iron",1,true)
	EconomyManager.equip(&"weapon",&"wpn_spear_iron")
	var player: Player2D = t.player()
	player.mouse_aim = false
	for angle in [30.0,22.5]:
		var target := Target.new()
		t.world().area.objects.add_child(target)
		target.add_to_group("enemy")
		target.global_position = player.global_position+Iso.to_screen(Vector2.from_angle(deg_to_rad(angle))*200)
		var body := Area2D.new()
		body.collision_layer = Iso.LAYER_ENEMY
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 10
		shape.shape = circle
		body.add_child(shape)
		target.add_child(body)
		await t.physics(2)
		if angle == 30:
			t.hold(&"move_right",cos(deg_to_rad(30)))
			t.hold(&"move_back",sin(deg_to_rad(30)))
			await t.physics(4)
			t.release_all()
			await t.physics(6)
		else:
			player.event_face(Vector2.RIGHT)
		if angle == 30: t.check("precise_controller_aim_survives_pose_quantization",absf(player.combat.aim_ground().angle()-deg_to_rad(30)) < .001)
		t.check("real_spear_swing_"+str(angle),player.combat.swing())
		await t.physics(32)
		t.check("spear_hits_between_drawing_directions_"+str(angle),target.damage > 0,str(target.damage))
		target.queue_free()
		await t.frames(2)
