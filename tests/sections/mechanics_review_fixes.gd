extends RefCounted
const SECTION := "mechanics_review_fixes"
const TIMEOUT_S := 180.0
var native := false

func run(t) -> void:
	await _run(t)

func run_windowed(t) -> void:
	native = true
	await _run(t)

func _run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0)
	gm.set_config_override("towns.curfew.enabled", false)
	gm.set_flag(&"intro_pending", false)
	_witness(t)
	await _animals(t)
	_guardians(t)
	await _story_work(t)

func _witness(t) -> void:
	var cfg := LuaData.dict(Svc.lua_config("dungeon", {}))
	var spec := DungeonSpec.spec_for(cfg, 10)
	var generated := DungeonGen.build_text(cfg, 10, 3275138988032679373, {"day": 1})
	t.check("missing_witness_seed_retries_successfully", generated.ok and int(generated.stats.attempts) > 1)
	var map := AreaMap.parse_text(str(generated.text))
	var tally := {"checks": {}, "bad": {}, "first": {}}
	DungeonVerify.verify(map, spec, cfg, {}, tally)
	t.check("repaired_layout_passes_independent_verifier", tally.bad.is_empty(), str(tally.first))
	# A verifier must reject an exported layout with the witness removed, even
	# when ordinary geometry/resource invariants still pass.
	for ch in map.markers:
		if str(map.markers[ch].get("marker", "")) == "hulen_keeper":
			for y in map.height: map.objects[y] = map.objects[y].replace(str(ch), ".")
	tally = {"checks": {}, "bad": {}, "first": {}}
	DungeonVerify.verify(map, spec, cfg, {}, tally)
	t.check("independent_verifier_catches_deleted_witness", tally.bad.has("required_story_witnesses_present"))

func _animals(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var eco: Node = t.autoload("EconomyManager")
	var ah: Node = t.autoload("AnimalHusbandry")
	eco.add_gold(5000)
	eco.add_item(&"wood", 100, true)
	eco.add_item(&"stone", 100, true)
	eco.add_item(&"brush", 1, true)
	eco.add_item(&"baby_chick", 1, true)
	t.check("paid_coop_and_real_adoption", ah.build_building(&"coop") and ah.adopt_animal(&"baby_chick"))
	var hen: Variant = ah.get_animals_by_species(&"chicken")[0]
	var late_eggs := 0
	for day in 30:
		ah.brush_animal(hen.id)
		ah.play_with_animal(hen.id)
		gm.end_day()
		var eggs: int = ah.collect_product(hen.id)
		if day >= 15: late_eggs += eggs
	t.check("free_care_cannot_replace_food", hen.hunger == 0 and hen.happiness >= 80 and late_eggs == 0 and hen.last_fed_day == 0)
	eco.add_item(&"chicken_feed", 30, true)
	t.check("feeding_restarts_production", ah.feed_animal(hen.id, &"chicken_feed"))
	gm.end_day()
	t.check("fed_hen_produces_again", ah.collect_product(hen.id) > 0)
	eco.add_item(&"baby_calf", 1, true)
	t.check("paid_barn_and_real_calf_adoption", ah.build_building(&"barn") and ah.adopt_animal(&"baby_calf"))
	var cow: Variant = ah.get_animals_by_species(&"cow")[0]
	for day in 8:
		ah.brush_animal(cow.id)
		ah.play_with_animal(cow.id)
		if cow.hunger < 70: ah.feed_animal(cow.id, &"chicken_feed")
		gm.end_day()
	var milk: int = cow.products_ready
	t.check("cow_has_milk_after_fed_maturation", milk > 0)
	t.check("missing_pail_retains_every_product", ah.collect_product(cow.id) == 0 and cow.products_ready == milk and ah.collection_reason(cow.id) == "ANIMAL_NEED_PAIL")
	var care: TTScreen = t.world().game_ui.get_screen(&"animal_care_ui")
	care._selected_animal = cow.id
	care.open()
	await t.frames(2)
	t.check("care_explains_missing_pail", care.collect_btn.disabled and care.status_label.text == TranslationServer.translate("ANIMAL_NEED_PAIL"))
	if native: await t.capture("milk_waiting_for_pail")
	care.close()
	eco.add_item(&"milking_pail", 1, true)
	t.check("owned_pail_allows_milk_collection", ah.collection_reason(cow.id) == "" and ah.collect_product(cow.id) >= milk and cow.products_ready == 0 and eco.count_item(&"milking_pail") == 1)
	gm.end_day()
	await t.frames(3)
	var world: WorldRoot2D = t.world()
	var yard: Node = world.area.find_markers("animal_yard")[0].node
	var actor: Animal2D = yard.actors[cow.id]
	var center: Vector2i = world.area.find_markers("animal_yard")[0].cell
	for other in yard.actors.values():
		other.set_physics_process(false)
		other.global_position = world.area.cell_to_global(center + Vector2i(-2, -2))
	world.player.facing8 = 0
	world.player.global_position = world.area.cell_to_global(center)
	actor.global_position = world.area.cell_to_global(center + world.area.facing_step(0))
	world.player.hotbar.assign(0, &"milking_pail")
	world.player.hotbar.select(0)
	await t.physics(2)
	var old_milk: int = eco.count_item(&"milk")
	t.check("held_pail_targets_real_cow", world.player.nearest_interactable() == actor)
	t.check("held_pail_milks_and_remains_owned", world.player.use_selected() and eco.count_item(&"milk") > old_milk and eco.count_item(&"milking_pail") == 1 and world.player._using_item == &"milking_pail")
	if native:
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		await t.frames(2)
		await t.capture("held_pail_collects_milk")
	await t.frames(25)
	var sheep: Dictionary = ah.species_data.sheep
	var rabbit: Dictionary = ah.species_data.rabbit
	t.check("sheep_has_higher_wool_yield_per_day", (float(sheep.product_amount[0]) + float(sheep.product_amount[1]) + 2.0) / 6.0 > (float(rabbit.product_amount[0]) + float(rabbit.product_amount[1]) + 2.0) / 4.0)
	for species in ["rabbit", "sheep", "cow", "deer"]:
		t.check("basic_feed_for_" + species, "chicken_feed" in ah.species_data[species].feed_types)

func _guardians(t) -> void:
	var qm: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var offer: Dictionary = t.autoload("LuaRuntime").get_dialogue("guard_oak", {"quest_offer_bossernes_vej":true})
	t.check("guardian_goal_is_clear_without_changing_recording", LuaData.arr(offer.get("lines", [])).any(func(line): return str(line.get("text_key", "")) == "QUEST_BOSSERNES_VEJ_DESC" and not line.has("voice_key")))
	for entry in [["snurresvamp", 4], ["snurresvamp_gloed", 8], ["snurresvamp_konge", 12]]:
		DungeonRun.boss_killed(entry[0], entry[1])
	t.check("guardian_quest_accepts_after_prior_victories", qm.accept_quest(&"bossernes_vej"))
	for id in [&"snurresvamp", &"snurresvamp_gloed", &"snurresvamp_konge"]:
		t.check("prior_victory_counts_" + str(id), qm.get_objective_progress(&"bossernes_vej", id).done)
	t.check("guardian_report_still_required", not qm.is_completed(&"bossernes_vej"))
	var gold: int = eco.gold
	EventBus.start_dialogue(&"guard_oak", &"guard_oak")
	t.check("guardian_report_pays_once", qm.is_completed(&"bossernes_vej") and eco.gold == gold + 800)
	EventBus.start_dialogue(&"guard_oak", &"guard_oak")
	t.check("repeated_guardian_report_cannot_pay_twice", eco.gold == gold + 800)

func _story_work(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var saves: Node = t.autoload("SaveManager")
	gm.set_flag(&"forest_mother_version", 1)
	MotherStory.sync()
	t.check("memory_map_waits_for_lamp_work", not MotherStory.can_read("memory_map") and not MotherStory.record("memory_lamp"))
	var world: WorldRoot2D = t.world()
	DungeonFloors.inst().enter(5)
	await t.until(func(): return world.area.map.id == &"moerkeskoven_f5" and not world.traveling, 12)
	world.player.invulnerable = true
	await t.physics(4)
	var lamp: MotherEvidenceMarker
	var hidden_map: MotherEvidenceMarker
	for object in world.area.objects.get_children():
		if object is MotherEvidenceMarker and object.evidence_id == "memory_lamp": lamp = object
		if object is MotherEvidenceMarker and object.evidence_id == "memory_map": hidden_map = object
	t.check("unrepaired_lamp_keeps_map_hidden", lamp != null and hidden_map != null and not hidden_map.is_enabled() and not hidden_map._picture.visible)
	world.player.global_position = lamp.global_position + Vector2(0, 22)
	lamp.interact(world.player)
	await t.frames(3)
	var dialogue: Control = t.first(&"dialogue_ui")
	t.check("repair_uses_its_own_painted_portrait", dialogue._speaker.get("portrait") == lamp._picture.texture)
	await t.tap(&"ui_cancel")
	await t.frames(3)
	t.check("cancel_repair_records_nothing_and_releases_player", MotherMemoryWork.state("memory_lamp") == 0 and not MotherStory.has("memory_lamp") and not gm.is_modal_open() and world.player.state == PlayerBody2D.S.FREE)
	MotherMemoryWork.apply("memory_lamp", "stitch_1")
	var wire: Dictionary = JSON.parse_string(JSON.stringify(saves.gather_payload()))
	gm.clear_flag(StringName(MotherStory.PREFIX+"work_memory_lamp"))
	t.check("partial_repair_roundtrips", saves._apply_payload(wire).ok and MotherMemoryWork.state("memory_lamp") == 2 and not MotherMemoryWork.complete("memory_lamp"))
	MotherMemoryWork.apply("memory_lamp", "stitch_1")
	t.check("repeating_stitch_never_finishes_other_stitches", MotherMemoryWork.state("memory_lamp") == 2)
	MotherMemoryWork.apply("memory_lamp", "stitch_0")
	MotherMemoryWork.apply("memory_lamp", "stitch_2")
	t.check("all_stitches_relight_lamp_and_reveal_map", MotherMemoryWork.complete("memory_lamp") and MotherStory.can_read("memory_map") and MotherStory.record("memory_lamp"))
	t.check("repair_visibly_relights_and_exposes_map", lamp._lamp_light.visible and hidden_map._picture.visible and hidden_map.is_enabled())
	t.check("role_answer_is_retryable_without_progress", MotherMemoryWork.apply("traveller_account", "name_guest") == "FM_WORK_NAME_RETRY" and not MotherStory.record("traveller_account") and MotherMemoryWork.state("traveller_account") == 0)
	MotherMemoryWork.apply("traveller_account", "name_iva")
	t.check("traveller_own_name_releases_evidence", MotherMemoryWork.complete("traveller_account") and MotherStory.record("traveller_account"))
	t.check("wrong_stone_match_is_retryable", MotherMemoryWork.apply("route_stone", "stone_match") == "FM_WORK_STONE_RETRY" and not MotherStory.record("route_stone"))
	MotherMemoryWork.apply("route_stone", "stone_left")
	MotherMemoryWork.apply("route_stone", "stone_right")
	t.check("stone_turns_both_directions", MotherMemoryWork.state("route_stone") == 0)
	MotherMemoryWork.apply("route_stone", "stone_right")
	MotherMemoryWork.apply("route_stone", "stone_match")
	t.check("matching_map_unlocks_stone_evidence", MotherMemoryWork.complete("route_stone") and MotherStory.record("route_stone"))
	t.check("early_route_observation_has_no_assembled_conclusion", MotherStory.record("last_journey") and MotherStory.evidence_text_key("last_journey") == "FM_E_LAST_JOURNEY_OBSERVATION")
	var qtext := preload("res://scripts/ui/theme/tt_quest_text.gd")
	for chapter in MotherStory.CHAPTERS:
		var quest := MotherStory.quest_id(str(chapter.id))
		t.check("investigation_source_"+str(chapter.id), qtext.giver_id(quest) == "" and qtext.giver_name(quest) == TranslationServer.translate("FM_INVESTIGATION"))
	var journal: TTScreen = t.world().game_ui.get_screen(&"quest_journal")
	journal.open()
	journal._select(MotherStory.quest_id("s03"))
	t.check("self_directed_chapter_has_no_false_portrait", journal.get_node("%GiverPortrait").texture == null)
	journal.close()
	# Reproduce an old save with already-recorded evidence, but no new work
	# flags: its discoveries remain usable and never need doing a second time.
	gm.clear_flag(StringName(MotherStory.PREFIX+"work_memory_lamp"))
	t.check("old_recorded_lamp_preserves_map_access", MotherMemoryWork.complete("memory_lamp") and MotherStory.can_read("memory_map"))
	for evidence in MotherStory.EVIDENCE:
		if evidence.id not in ["mother_fate", "legacy_home"]:
			gm.set_flag(StringName(MotherStory.PREFIX+str(evidence.id)), gm.total_day())
	MotherStory.sync()
	t.check("assembled_route_text_waits_for_actual_prior_chapters", qm.is_completed(MotherStory.quest_id("s06")) and MotherStory.evidence_text_key("last_journey") == "FM_E_LAST_JOURNEY_TEXT")
	for race in ["animal", "fairy", "hobbit", "ghost"]:
		var opening: Dictionary = t.autoload("LuaRuntime").get_dialogue("fairy_king", {"intro":true, "race":race})
		t.check("common_mother_lead_"+race, LuaData.arr(opening.get("lines", [])).any(func(line): return str(line.get("text_key", "")) == "FM_OPENING_LEAD"))
	var floors := DungeonFloors.inst()
	var legacy := floors.to_dict()
	legacy.merge({"gen":1, "active":true, "floor":10, "deepest":10, "stones":[3,6,9], "seed_day":gm.total_day(), "seen":[10], "done":{"10":[2,3]}}, true)
	t.check("old_generator_keeps_runes_and_story", floors.from_dict(legacy) and not floors.active and floors.stones.has(9) and floors.deepest == 10 and floors.done.is_empty() and MotherStory.has("memory_lamp") and MotherStory.has("last_journey"))
