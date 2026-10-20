extends RefCounted
## Production garden interactions, NPC follow-up pages, real save/load and the
## complete return journey. No fake rewards or test-only quest definitions.
const SECTION := "secret_garden"
const TIMEOUT_S := 180.0
const CHOOSE_GAME_S := 10.0
const Story := preload("res://scripts/world2d/story/secret_garden_story.gd")
var world: Node
var gm: Node
var qm: Node
var ui: Node
var capture := false

func run(t) -> void:
	await _run(t, false)

func run_windowed(t) -> void:
	await _run(t, true)

func _run(t, shots: bool, skin := "") -> void:
	capture = shots
	if not await t.start_world("", "Tester", "Testgaarden", skin):
		return
	world = t.world()
	gm = t.autoload("GameManager")
	qm = t.autoload("QuestManager")
	ui = t.first(&"dialogue_ui")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.set_config_override("towns.curfew.enabled", false)
	gm.day = 2
	gm.hour = 10
	t.check("new_hero_has_no_inherited_story", Story.step() == -1 and not Story.has_evidence("garden_trail"))
	gm.set_flag(&"intro_pending", true)
	t.check("opening_is_not_interrupted", not qm.is_offerable(&"secret_garden"))
	gm.set_flag(&"intro_pending", false)
	t.check("available_to_existing_save", qm.is_offerable(&"secret_garden"))
	await _enter(t, "secret_garden")
	t.check("garden_map_builds", world.area.map.errors.is_empty() and world.area.skipped_markers.is_empty(), str(world.area.map.errors))
	t.check("all_work_markers_exist", _marker("path") != null and _marker("beds") != null and _marker("bench") != null and _marker("letter") != null)
	var nav := NavGrid.bake_area(world.area)
	var start: Vector2i = world.area.global_to_cell(world.area.spawns[&"default"])
	var unreachable: Array = []
	var bed_count := 0
	for node in world.area.objects.get_children():
		if node is SecretGardenMarker:
			if node.kind == "beds":
				bed_count += 1
			if nav.astar.get_id_path(start, node.cell).is_empty():
				unreachable.append(node.cell)
	t.check("all_work_reachable_with_inflated_body", unreachable.is_empty() and bed_count == 4, str(unreachable))
	await _work(t, "gate", "garden_start")
	t.check("quest_started_through_world_dialogue", Story.step() == 0)
	t.check("later_accounts_do_not_spoil_story", Story.choice("postman_pip").is_empty() and Story.choice("guard_oak").is_empty())
	await _position(t, _marker("path"))
	if capture:
		await t.capture("overgrown")
	_marker("path").interact(world.player)
	await t.frames(3)
	t.tap(&"ui_cancel")
	await t.frames(4)
	t.check("cancel_does_not_clear_path", Story.step() == 0 and not gm.is_modal_open() and int(world.player.state) == 0)
	_marker("path").interact(world.player)
	await t.frames(2)
	await _enter(t, "farm")
	t.check("leaving_cancels_work_and_releases_player", Story.step() == 0 and not gm.is_modal_open() and int(world.player.state) == 0)
	await _enter(t, "secret_garden")
	t.check("return_rebuilds_parked_garden", not _marker("path")._pictures.is_empty())
	t.check("out_of_order_work_refused", not Story.advance(4))
	await _work(t, "path")
	t.check("path_is_cleared", Story.step() == 1 and _marker("path")._pictures.is_empty())
	await _talk(t, "gardener_hoppe")
	t.check("seed_help_read_in_real_conversation", Story.step() == 2)
	await _talk(t, "carpenter_brumme")
	t.check("bench_help_read_in_real_conversation", Story.step() == 3)
	await _enter(t, "secret_garden")
	await _work(t, "bench")
	t.check("painted_bench_restored", Story.step() == 4 and _marker("bench")._look.begins_with("bench:"))
	await _work(t, "beds")
	await _work(t, "beds")
	t.check("beds_planted_and_watered", Story.step() == 6)
	t.check("flowers_need_one_morning", not Story.bloom_ready() and not Story.advance(6))
	var sm: Node = t.autoload("SaveManager")
	t.check("garden_save_written", sm.save_game(4))
	gm.set_flag(Story.WATER_DAY, 0)
	qm.reset()
	t.check("garden_save_loaded", sm.load_game(4))
	await t.frames(6)
	t.check("watering_and_chapter_restore_together", Story.step() == 6 and not Story.bloom_ready() and gm.flag_int(Story.WATER_DAY) == gm.total_day())
	await _enter(t, "secret_garden")
	gm.end_day()
	gm.hour = 10
	t.autoload("EventBus").time_of_day_changed.emit(10, 0)
	await t.frames(4)
	t.check("garden_grows_while_away_or_asleep", Story.bloom_ready())
	await _work(t, "beds")
	t.check("flowers_use_approved_painting", _marker("beds")._look.begins_with("crop_moonflower_3:"))
	if capture:
		t.autoload("TimeManager").set_weather(&"klart")
		await _position(t, _marker("beds"))
		await t.capture("blossoms")
	await _work(t, "letter")
	t.check("mother_letter_persisted_as_quest_evidence", Story.has_evidence("letter_watermark") and Story.step() == 8)
	var page := Story.topic_page("ghostfam_dyne")
	var key := str(page.lines[0].text_key)
	t.check("kin_branch_matches_hero", key == ("SG_FAMILY_KIN" if int(gm.character_type) == 3 else "SG_FAMILY_FRIEND"))
	await _enter(t, "moerkeskoven")
	t.check("trail_hidden_until_lift_record", _marker("trail") != null and not _marker("trail").is_enabled())
	await _talk(t, "postman_pip")
	t.check("post_account_persisted", Story.has_evidence("post_route") and Story.step() == 9)
	await _talk(t, "guard_oak")
	t.check("lift_record_persisted", Story.has_evidence("lift_record") and Story.step() == 10)
	await _enter(t, "moerkeskoven")
	t.check("trail_revealed_at_real_forest_hub", _marker("trail").is_enabled())
	await _work(t, "trail")
	t.check("mother_trail_recorded", Story.has_evidence("garden_trail") and Story.step() == 11)
	if capture:
		await t.capture("forest_trace")
	await _enter(t, "secret_garden")
	var gold_before: int = t.autoload("EconomyManager").gold
	await _work(t, "bench")
	t.check("restoration_story_completed", qm.is_completed(&"secret_garden") and Story.step() == 12)
	t.check("one_time_reward", t.autoload("EconomyManager").gold == gold_before + 150)
	t.check("replay_cannot_pay_again", not Story.advance(11) and not qm.accept_quest(&"secret_garden") and t.autoload("EconomyManager").gold == gold_before + 150)
	if capture:
		var hud: Node = world.game_ui.get_screen(&"hud")
		t.check("restoration_notifications_clear", await t.until(func() -> bool: return hud.toasts.toasts().is_empty() and hud.toasts._queue.is_empty(), 20.0))
		await t.capture("restored")
	_marker("letter").interact(world.player)
	await t.frames(2)
	await _choose(t, "close")
	t.check("evidence_can_be_reread_after_completion", qm.is_completed(&"secret_garden") and not gm.is_modal_open())
	t.check("complete_save_written", sm.save_game(4))
	qm.reset()
	t.check("complete_save_loaded", sm.load_game(4))
	await t.frames(5)
	await _enter(t, "secret_garden")
	t.check("completed_place_and_evidence_survive_load", Story.step() == 12 and Story.has_evidence("garden_trail") and _marker("bench")._look.begins_with("bench:"))
	await _walk_gate(t, "hyggebyen", Vector2.DOWN)
	if capture:
		await t.capture("town_entrance")
	await _walk_gate(t, "secret_garden", Vector2.UP)
	t.check("all_garden_art_is_real", ArtCatalog.missing().is_empty(), str(ArtCatalog.missing()))
	gm.clear_config_overrides()
	sm.delete_save(4)
	# Exercise the whole journey with both skins of each race.
	if not capture and skin == "":
		var alternate: String = {"animal": "animal_monkey", "fairy": "fairy_birk", "hobbit": "hobbit_bodil", "ghost": "ghost_hviske"}[t.character]
		await _run(t, false, alternate)

func _enter(t, id: String) -> void:
	t.check("enter_" + id, world._enter(StringName(id), &"default"))
	await t.physics(3)
	if capture:
		await world.warm_clips()

func _marker(kind: String) -> Node:
	for node in world.area.objects.get_children():
		if node is SecretGardenMarker and node.kind == kind:
			return node
	return null

func _position(t, node: Node2D) -> void:
	world.player.global_position = node.global_position + Vector2(0, 42)
	world.player.velocity = Vector2.ZERO
	world.player.facing8 = Iso.dir8_of(Vector2.UP)
	world.player.facing_vec = Vector2.UP
	await t.physics(3)

func _work(t, kind: String, action := "garden_work") -> void:
	var marker := _marker(kind)
	if marker == null:
		t.fail("missing_marker_" + kind)
		return
	await _position(t, marker)
	t.check("player_can_interact_" + kind, world.player.try_interact())
	await _choose(t, action)
	await t.frames(4)

func _talk(t, npc: String) -> void:
	var location := NpcDirector.where_is(npc)
	await _enter(t, str(location.get("area", "traetoppen")))
	var actor := NpcDirector.node_of(npc, world.area)
	if actor == null:
		t.fail("helper_present_%s: %s" % [npc, str(location)])
		return
	await _position(t, actor)
	actor.interact(world.player)
	await _choose(t, "garden_story")
	await t.frames(5)
	if capture and npc == "postman_pip":
		if ui._typing:
			ui._advance()
		await t.frames(2)
		await t.capture("post_account")
	await _choose(t, "close")
	await t.frames(4)

## Pages the dialogue on until `action` is offered and pressed: bounded by game time, the pages type by the game's delta (TEST-03).
func _choose(t, action: String) -> void:
	await t.frames(1)
	if await t.until_game(func() -> bool: return _press_choice(t, action), CHOOSE_GAME_S):
		return
	t.fail("choice_reachable_" + action)
	if ui.is_open():
		ui.close()

func _press_choice(t, action: String) -> bool:
	if not ui.is_open():
		return false
	if ui._buttons.is_empty():
		ui._advance()
		return false
	for button in ui._buttons:
		if str(button.get_meta("choice").get("action", "")) == action:
			t.press(str(button.get_path()))
			return true
	for button in ui._buttons:
		if str(button.get_meta("choice").get("action", "")) == "social_more":
			t.press(str(button.get_path()))
			break
	return false

func _walk_gate(t, destination: String, direction: Vector2) -> void:
	await t.until(func() -> bool: return not world.traveling, 5.0)
	var gate: Node2D
	for node in t.tree.get_nodes_in_group(&"warp"):
		if world.area.is_ancestor_of(node) and str(node.to_area) == destination:
			gate = node
	if gate == null:
		t.fail("missing_garden_gate_" + destination)
		return
	world.player.global_position = gate.global_position - direction * 60.0
	world.player.velocity = Vector2.ZERO
	await t.physics(3)
	var action := &"move_back" if direction.y > 0 else &"move_forward"
	t.hold(action)
	for i in 150:
		await t.physics(1)
		if str(world.area.map.id) == destination:
			break
	t.release(action)
	await t.physics(4)
	t.check("walk_through_gate_" + destination, str(world.area.map.id) == destination, "actual %s; traveling=%s" % [world.area.map.id, world.traveling])
	await t.until(func() -> bool: return not world.traveling, 5.0)
