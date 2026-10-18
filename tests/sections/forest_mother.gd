extends RefCounted
const SECTION := "forest_mother"
const TIMEOUT_S := 240.0
var world: WorldRoot2D
var ui: Node
var native := false
func run(t) -> void:
	await _run(t,false)
func run_windowed(t) -> void:
	await _run(t,true)
func _run(t,shots: bool,skin := "") -> void:
	native = shots
	await t.start_world("","Tester","Testgaarden",skin)
	world = t.world()
	ui = t.first(&"dialogue_ui")
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var sm: Node = t.autoload("SaveManager")
	gm.set_config_override("time.minutes_per_real_second",0)
	gm.set_config_override("towns.curfew.enabled",false)
	gm.set_flag(&"intro_pending",false)
	t.check("no_inherited_evidence",not MotherStory.enabled() and MotherStory.entries().is_empty() and not MotherStory.record("marked_lamp"))
	qm.accept_quest(SecretGardenStory.QUEST)
	for index in SecretGardenStory.STEPS.size():
		if index == 6: gm.set_flag(SecretGardenStory.WATER_DAY,gm.total_day()-1)
		SecretGardenStory.advance(index)
	t.check("garden_trail_starts_investigation",MotherStory.enabled() and qm.is_active(MotherStory.quest_id("s03")))
	t.check("authored_quest_caption_is_localized",qm.get_title(MotherStory.quest_id("s03")) == TranslationServer.translate("FM_CHAPTER_S03_TITLE"))
	t.check("future_chapters_cannot_be_offered_early",not qm.is_offerable(MotherStory.quest_id("s08")) and not qm.accept_quest(MotherStory.quest_id("s08")))
	t.check("all_essential_quests_have_no_paid_or_random_rewards",MotherStory.CHAPTERS.all(func(row):return LuaData.dict(qm.get_quest_def(MotherStory.quest_id(row.id)).get("rewards",{})).is_empty()))
	await _floor(t,11)
	await _read(t,"last_journey")
	t.check("out_of_order_evidence_is_kept",MotherStory.has("last_journey") and not qm.is_completed(MotherStory.quest_id("s07")))
	await _floor(t,12)
	var root := _marker("mother_fate")
	t.check("finale_waits_for_real_checkpoints",root != null and not MotherStory.can_read("mother_fate") and not MotherStory.record("mother_fate"))
	await _floor(t,1)
	var lamp := _marker("marked_lamp")
	lamp.interact(world.player)
	await t.frames(3)
	await t.tap(&"ui_cancel")
	await t.frames(3)
	t.check("cancel_records_nothing_and_releases_player",not MotherStory.has("marked_lamp") and world.player.state == PlayerBody2D.S.FREE and not gm.is_modal_open())
	lamp.interact(world.player)
	await t.frames(2)
	await world.travel(&"farm",&"default")
	t.check("travel_cancels_evidence_dialogue",not MotherStory.has("marked_lamp") and not gm.is_modal_open())
	await _floor(t,1)
	eco.inventory.clear()
	for index in 24: eco.inventory.append({"id":&"wood","amount":99,"meta":{}})
	await _read(t,"marked_lamp")
	t.check("full_pack_cannot_block_evidence",MotherStory.has("marked_lamp") and eco.used_slots() == 24 and eco.count_item(&"wood") == 2376)
	t.check("evidence_save_written",sm.save_game(4))
	gm.clear_flag(StringName(MotherStory.PREFIX+"marked_lamp"))
	t.check("evidence_save_loaded",sm.load_game(4))
	await t.frames(3)
	t.check("evidence_restored_with_quest_progress",MotherStory.has("marked_lamp") and qm.get_objective_progress(MotherStory.quest_id("s03"),&"marked_lamp").done)
	gm.hour = 12
	await _floor(t,2)
	var keepers := world.area.find_markers("hulen_keeper")
	t.check("daytime_witness_marker_exists", keepers.size() == 1)
	if keepers.is_empty(): return
	var sleeping: Node = keepers[0].node
	t.check("daytime_visit_does_not_consume_account",sleeping is Interactable2D and not sleeping is Npc2D and not MotherStory.has("map_account"))
	await world.travel(&"farm",&"default")
	gm.hour = 22
	await _floor(t,2)
	await _talk(t,"mapseller_natteblik")
	t.check("night_retry_uses_real_topic",MotherStory.has("map_account") and not qm.is_completed(MotherStory.quest_id("s03")))
	_checkpoint(4)
	t.check("first_checkpoint_completes_s03",qm.is_completed(MotherStory.quest_id("s03")) and qm.is_active(MotherStory.quest_id("s04")))
	await _floor(t,5)
	var nav := NavGrid.bake_area(world.area)
	var start := world.area.global_to_cell(world.area.get_spawn("default"))
	var ids := ["memory_lamp","memory_map","memory_basket","memory_table"]
	for id in ids:
		var marker := _marker(id)
		t.check("memory_clue_reachable_"+id,marker != null and not nav.astar.get_id_path(start,marker.cell).is_empty())
		await _read(t,id)
	if native: await _capture_place(t,"memory_clearing",_marker("memory_table"))
	var owl_page := MotherStory.topic_page("appraiser_fru_ugle")
	t.check("free_owl_topic_available_beside_services",owl_page.mother_evidence == "echo_account" and not MotherStory.choice("appraiser_fru_ugle").is_empty())
	MotherStory.finish_topic("appraiser_fru_ugle",owl_page,false,2)
	t.check("cancelled_witness_page_does_not_record",not MotherStory.has("echo_account"))
	await world.travel(&"secret_garden",&"default")
	await t.physics(4)
	await t.frames(3)
	await _read(t,"echo_account")
	t.check("free_written_owl_account_has_no_calendar_gate",MotherStory.has("echo_account") and qm.is_completed(MotherStory.quest_id("s04")))
	await _floor(t,7)
	await _read(t,"traveller_account")
	_checkpoint(8)
	t.check("own_name_and_second_checkpoint_complete_s05",qm.is_completed(MotherStory.quest_id("s05")))
	gm.hour = 22
	await _floor(t,9)
	await _read(t,"return_promise")
	await _floor(t,10)
	await _read(t,"route_stone")
	await _talk(t,"mapseller_natteblik")
	t.check("witness_account_completes_s06",qm.is_completed(MotherStory.quest_id("s06")))
	var hearts := DungeonRun.hearts_bonus()
	_checkpoint(12)
	MotherStory.sync()
	t.check("earlier_last_journey_catches_up",qm.is_completed(MotherStory.quest_id("s07")) and MotherStory.can_read("mother_fate"))
	var after_hearts := DungeonRun.hearts_bonus()
	MotherStory.sync()
	t.check("story_sync_never_regrants_boss_hearts",DungeonRun.hearts_bonus() == after_hearts and after_hearts >= hearts)
	await _floor(t,12)
	await _read(t,"mother_fate")
	t.check("bittersweet_truth_and_keepsake_commit_together",MotherStory.has("mother_fate") and gm.flag_int(StringName(MotherStory.PREFIX+"seed_tin_homeward")) == 1 and gm.flag_int(StringName(MotherStory.PREFIX+"own_name_restored")) == 1 and gm.flag_int(StringName(MotherStory.PREFIX+"role_refused")) == 1 and eco.used_slots() == 24)
	t.check("finale_answers_fate_explicitly",TranslationServer.translate("FM_FINAL_TRUTH").contains("døde") or TranslationServer.translate("FM_FINAL_TRUTH").contains("died"))
	var version := MotherStory.entries().size()
	await _read(t,"mother_fate","close")
	t.check("reread_never_duplicates_progress",MotherStory.entries().size() == version and not MotherStory.record("mother_fate"))
	gm.end_day()
	gm.hour = 10
	await world.travel(&"secret_garden",&"default")
	await t.physics(4)
	await t.frames(3)
	await _read(t,"legacy_home")
	t.check("legacy_planted_and_story_finished",MotherStory.has("legacy_home") and qm.is_completed(MotherStory.quest_id("s08")) and _marker("legacy_home")._flowers.size() == 3)
	if native: await _capture_place(t,"legacy_garden",_marker("legacy_home"))
	var journal: TTScreen = world.game_ui.get_screen(&"quest_journal")
	journal.open()
	await t.frames(3)
	journal._mother_tab.grab_focus()
	await t.frames(3)
	t.check("journal_has_all_confirmed_accounts",journal._mother_journal.buttons.size() == MotherStory.entries().size() and MotherStory.entries().size() == 18 and journal._mother_journal.is_visible_in_tree())
	var selected: Control = journal._mother_journal.initial_focus()
	var viewport: Control = journal._mother_journal._rows.get_parent()
	t.check("journal_reveals_selected_account_on_first_open",viewport.get_global_rect().grow(1).encloses(selected.get_global_rect()))
	t.check("journal_reveal_keeps_tab_focus",journal.get_viewport().gui_get_focus_owner() == journal._mother_tab)
	if native: await t.capture("evidence_journal")
	if native:
		var locale := TranslationServer.get_locale()
		TranslationServer.set_locale("en")
		journal._refresh_texts()
		await t.frames(3)
		t.check("evidence_book_translates_with_locale",journal._mother_journal._title.text == TranslationServer.translate("FM_JOURNAL_TITLE"))
		await t.capture("evidence_journal_en")
		TranslationServer.set_locale(locale)
	journal.close()
	t.check("ending_save_written",sm.save_game(4))
	var old_world := world.get_instance_id()
	t.check("ending_save_reentered",sm.load_and_enter(4))
	await t.until(func():return t.world() != null and t.world().get_instance_id() != old_world and t.world().ready_for_play,12)
	world = t.world()
	ui = t.first(&"dialogue_ui")
	await t.physics(4)
	await t.frames(3)
	t.check("legacy_survives_world_rebuild",MotherStory.has("legacy_home") and _marker("legacy_home") != null and _marker("legacy_home")._flowers.size() == 3)
	await world.travel(&"farm",&"default")
	await _floor(t,1)
	t.check("ordinary_forest_play_remains_available",world.area.map.id == &"moerkeskoven_f1" and world.player.world_input_allowed() and MotherStory.chapter() == "complete")
	sm.delete_save(4)
	if not native and skin == "":
		var alternate: String = {"animal":"animal_monkey","fairy":"fairy_birk","hobbit":"hobbit_bodil","ghost":"ghost_hviske"}[t.character]
		await _run(t,false,alternate)
func _checkpoint(number: int) -> void:
	# Invoke the real persistent boss owner; combat itself has separate native
	# bot coverage. The story must accept these already-cleared checkpoints.
	var kind := str(DungeonSpec.spec_for(LuaData.dict(Svc.lua_config("dungeon",{})),number).boss_kind)
	DungeonRun.boss_killed(kind,number)
	EventBus.game_event.emit(&"dungeon_boss_defeated",{"kind":kind,"floor":number})
func _marker(id: String) -> MotherEvidenceMarker:
	for node in world.area.objects.get_children():
		if node is MotherEvidenceMarker and node.evidence_id == id: return node
	return null
func _floor(t,number: int) -> void:
	DungeonFloors.inst().enter(number)
	await t.until(func():return DungeonFloors.floor_of(world.area) == number and not world.traveling,12)
	world.player.invulnerable = true
	await t.physics(4)
	await t.frames(3)
func _read(t,id: String,action := "mother_record") -> void:
	var marker := _marker(id)
	if marker == null:
		t.fail("missing_story_marker_"+id)
		return
	world.player.global_position = marker.global_position+Vector2(0,22)
	world.player.camera.reset_smoothing()
	world.player.camera.force_update_scroll()
	marker.interact(world.player)
	if id in MotherMemoryWork.IDS and not MotherMemoryWork.complete(id):
		if native:
			for index in 5:
				await t.frames(1)
				if ui._buttons.is_empty(): ui._advance()
			await t.capture("work_"+id)
			var locale := TranslationServer.get_locale()
			TranslationServer.set_locale("en")
			ui._refresh_texts()
			await t.frames(2)
			if id == "traveller_account": t.check("traveller_world_label_translates", marker._name_label.text == TranslationServer.translate("FM_WORK_NAME_GUEST"))
			await t.capture("work_"+id+"_en")
			TranslationServer.set_locale(locale)
			ui._refresh_texts()
		for work_action in {"memory_lamp":["stitch_0", "stitch_1", "stitch_2"], "traveller_account":["name_iva"], "route_stone":["stone_right", "stone_match"]}[id]:
			await _choose(t, work_action)
			await t.frames(2)
	if native and id in ["marked_lamp","return_promise"]:
		if ui._typing: ui._advance()
		await t.frames(3)
		await t.capture(id)
	if native and id == "mother_fate" and action == "mother_record":
		while ui._line < 1 or ui._typing:
			ui._advance()
			await t.frames(1)
		await t.capture("mother_final_account")
	await _choose(t,action)
	await t.frames(3)
func _capture_place(t,name: String,marker: MotherEvidenceMarker) -> void:
	var player: Player2D = world.player
	player.global_position = marker.global_position+Vector2(170,100)
	player.camera.position_smoothing_enabled = false
	player.camera.reset_smoothing()
	player.camera.force_update_scroll()
	for id in [&"hud",&"forest_hud"]:
		var hud: Control = world.game_ui.get_screen(id)
		if hud != null and hud.get("toasts") != null: hud.toasts.clear()
	await t.frames(4)
	await t.capture(name)
	player.camera.position_smoothing_enabled = true
func _talk(t,id: String) -> void:
	var npc: Npc2D
	for node in t.tree.get_nodes_in_group("npc"):
		if node is Npc2D and node.npc_id == StringName(id) and world.area.is_ancestor_of(node): npc = node
	if npc == null:
		t.fail("missing_story_helper_"+id+" in "+str(world.area.map.id))
		return
	world.player.global_position = npc.global_position+Vector2(0,32)
	npc.interact(world.player)
	await _choose(t,"mother_story")
	await t.frames(3)
	await _choose(t,"close")
	await t.frames(3)
func _choose(t,action: String) -> void:
	for index in 150:
		await t.frames(1)
		if not ui.is_open(): continue
		if ui._buttons.is_empty(): ui._advance()
		else:
			for button in ui._buttons:
				if str(button.get_meta("choice").get("action","")) == action:
					t.press(str(button.get_path()))
					return
			for button in ui._buttons:
				if str(button.get_meta("choice").get("action","")) == "social_more":
					t.press(str(button.get_path()))
					break
	t.fail("story_choice_reachable_"+action+" "+str({"open":ui.is_open(),"lines":ui._lines,"choices":ui._choices,"modal":t.autoload("GameManager").top_modal()}))
	if ui.is_open(): ui.close()
