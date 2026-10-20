extends RefCounted
const SECTION := "ghostfam_seek"
const TIMEOUT_S := 180.0
var world: WorldRoot2D
var actor: Npc2D
var seek: GhostSeek
var ui: Node
func _start(t) -> void:
	await t.start_world()
	world = t.world()
	ui = t.first(&"dialogue_ui")
	GameManager.set_config_override("time.minutes_per_real_second",0)
	GameManager.set_config_override("towns.curfew.enabled",false)
	GameManager.set_flag(&"ghostfam_kin_blund",true)
func _stage(t,day: int,hour: int,minute := 0) -> void:
	await world.travel(&"farm",&"default")
	Fresh.jump_to_total_day(day)
	GameManager.hour = hour
	GameManager.minute = minute
	TimeManager.set_weather(&"klart")
	EventBus.day_started.emit(GameManager.day,GameManager.season)
	EventBus.time_of_day_changed.emit(hour,minute)
	SocialManager.flush()
	var at := GhostSeek.slot_now()
	await world.travel(StringName(str(at.get("area","traetoppen"))),&"default")
	await t.physics(4)
	actor = NpcDirector.node_of("ghostfam_blund",world.area) as Npc2D
	seek = actor.get_node("HideSeek") if actor!=null else null
	if seek!=null:seek._refresh()
func _near(distance: float) -> void:
	world.player.global_position = actor.global_position+Iso.to_screen(Vector2(distance,0))
	seek._refresh()
func _finish(t) -> void:
	var done: bool = await t.until(func() -> bool:
		if ui.is_open() and GameManager.top_modal()==&"dialogue":
			if ui._wants_focus():ui._pick(ui._choices.filter(func(c):return str(c.get("action",""))=="close")[0])
			else:ui._advance()
		return not actor.is_talking and not GameManager.is_modal_open(),6.0)
	t.check("dialogue_finished",done)
func run(t) -> void:
	await _start(t)
	var config := GhostSeek.cfg()
	t.check("six_json_safe_flags",LuaData.dict(config.get("flags",{})).size()==6 and LuaData.dict(config.flags).values().all(func(v):return str(v)=="int"))
	t.check("old_save_without_flags_is_zero",GameManager.flag_int(&"ghostfam_seek_total",0)==0 and GameManager.flag_int(&"ghostfam_seek_claimed",0)==0)
	for day in LuaData.arr(config.slots):
		for name in ["a","b"]:
			var context := Routines.make_ctx(int(day.weekday),19.0 if name=="a" else 22.0)
			context.total_day = 113+int(day.weekday)
			var slot := GhostSeek.slot_now(context)
			t.check("routine_"+str(day.weekday)+name,not slot.is_empty() and str(slot.area)==str(day[name].area) and str(slot.post)==str(day[name].post))
			t.check("hint_matches_real_"+str(day.weekday)+name,GhostSeek.hint_key(context)=="DLG_GHOSTFAM_SILKE_SEEK_"+str(day.weekday)+"_"+name.to_upper())
	t.check("family_evening_has_no_seek",GhostSeek.slot_now(Routines.make_ctx(2,20)).is_empty())
	var festive := Routines.make_ctx(6,19,"klart",{"total_day":70,"season":"efteraar","festival":"hoestfesten"})
	t.check("festival_has_no_hiding_slots",GhostSeek.slot_now(festive).is_empty())
	t.check("festival_hint_is_honest",GhostSeek.hint_key(festive)=="SEEK_GHOSTFAM_HINT_FESTIVAL")
	t.check("moving_between_slots_hint",GhostSeek.hint_key(Routines.make_ctx(0,20.75))=="SEEK_GHOSTFAM_HINT_MOVING")
	t.check("after_game_hint",GhostSeek.hint_key(Routines.make_ctx(0,24))=="SEEK_GHOSTFAM_HINT_REST")
	var silke_choice := GhostSeek.hint_choice("ghostfam_silke",{"id":"ask_blund","action":"show_info"})
	t.check("silke_uses_live_hint_action",str(silke_choice.action)=="seek_hint" and bool(DialogueBridge.action("ghostfam_silke","seek_hint",{}).handled))
	await _stage(t,8,19)
	t.check("real_hidden_actor",seek!=null and not seek._live_slot().is_empty() and is_zero_approx(actor.visual.modulate.a))
	if seek==null:return
	t.check("three_existing_effect_dots",seek._dots.size()==3 and seek._dots.all(func(dot):return dot.texture==Glow.halo_texture()))
	t.check("no_added_seek_lights",seek.find_children("*","PointLight2D",true,false).is_empty())
	_near(410)
	t.check("shimmer_hidden_from_far",not seek.shimmer.visible)
	_near(300)
	t.check("cousin_range_only",seek.shimmer.visible==(GameManager.character_type==GameManager.CharacterType.GHOST))
	_near(250)
	t.check("ordinary_shimmer_range",seek.shimmer.visible)
	var whispers: Array[String] = []
	var listen := func(text):whispers.append(str(text))
	EventBus.whisper_requested.connect(listen)
	GhostSeek.reset_feedback()
	_near(270)
	_near(130)
	for i in 6:seek._refresh()
	t.check("warm_whisper_once",whispers.count(TranslationServer.translate("SEEK_GHOSTFAM_HINT_WARM"))==1)
	t.check("hot_whisper_once",whispers.count(TranslationServer.translate("SEEK_GHOSTFAM_HINT_HOT"))==1)
	EventBus.whisper_requested.disconnect(listen)
	_near(73)
	t.check("outside_find_radius_not_counted",not seek.before_talk(world.player) and GameManager.flag_int(&"ghostfam_seek_total",0)==0)
	_near(65)
	var before := SocialManager.points("ghostfam_blund")
	actor.interact(world.player)
	await t.until(func():return ui.is_open(),3.0)
	t.check("real_interaction_counts_find",GameManager.flag_int(&"ghostfam_seek_total",0)==1 and GhostSeek.found_slot(1))
	t.check("find_pays_five_points",SocialManager.points("ghostfam_blund")==before+5)
	t.check("lua_found_branch_and_cleared_transients",ui._lines.any(func(line):return str(line.get("text_key","")).begins_with("SEEK_GHOSTFAM_FOUND_")) and GameManager.flag_int(&"ghostfam_seek_found_now",0)==0 and GameManager.flag_int(&"ghostfam_seek_gift_now",0)==0)
	await _finish(t)
	seek._refresh()
	t.check("found_actor_reappears",is_equal_approx(actor.visual.modulate.a,1) and not seek.shimmer.visible)
	_near(65)
	actor.interact(world.player)
	await t.until(func():return ui.is_open(),3.0)
	t.check("second_talk_same_slot",GameManager.flag_int(&"ghostfam_seek_total",0)==1 and ui._lines.any(func(line):return str(line.get("text_key",""))=="SEEK_GHOSTFAM_FOUND_AGAIN_1"))
	await _finish(t)
	await _stage(t,8,22)
	_near(65)
	t.check("second_slot_counts",seek.before_talk(world.player) and GameManager.flag_int(&"ghostfam_seek_total",0)==2 and GameManager.flag_int(&"ghostfam_seek_today",0)==3)
	t.check("same_slot_cannot_repeat",not seek._find(2) and not seek._find(1))
	GameManager.hour = 24
	GameManager.minute = 30
	t.check("midnight_keeps_same_date_mask",GhostSeek.found_slot(1) and GhostSeek.found_slot(2) and GameManager.total_day()==8)
	t.check("midnight_save_load",SaveManager.save_game(3) and SaveManager.load_game(3))
	t.check("counter_and_mask_survive",GameManager.flag_int(&"ghostfam_seek_total",0)==2 and GameManager.flag_int(&"ghostfam_seek_today",0)==3 and GameManager.flag_int(&"ghostfam_seek_day",0)==8)
	await _stage(t,9,19)
	t.check("new_day_has_fresh_slots",not GhostSeek.found_slot(1) and not GhostSeek.found_slot(2))
	var untouched := [GameManager.flag_int(&"ghostfam_seek_total",0),GameManager.flag_int(&"ghostfam_seek_claimed",0)]
	await t.frames(5)
	t.check("missing_a_slot_has_no_penalty",untouched==[GameManager.flag_int(&"ghostfam_seek_total",0),GameManager.flag_int(&"ghostfam_seek_claimed",0)])
	var ladder := LuaData.arr(config.ladder)
	GameManager.set_flag(&"ghostfam_seek_claimed",0)
	for i in ladder.size():
		var item := str(ladder[i].item)
		var count := EconomyManager.count_item(StringName(item))
		GameManager.set_flag(&"ghostfam_seek_total",int(ladder[i].finds))
		var gift := seek.claim_rewards()
		t.check("ladder_"+str(i+1)+"_one_payload",gift==i+1 and EconomyManager.count_item(StringName(item))==count+1 and (GameManager.flag_int(&"ghostfam_seek_claimed",0)&(1<<i))!=0)
		t.check("ladder_"+str(i+1)+"_no_replay",seek.claim_rewards()==0 and EconomyManager.count_item(StringName(item))==count+1)
		if ItemKinds.is_one_of_a_kind(item):t.check("ladder_"+str(i+1)+"_registry",LootService.found(item))
		var weeks := float(ladder[i].finds)/4.0
		t.check("pace_"+str(i+1),is_equal_approx(weeks,[.75,2.5,6.0,12.0,20.0][i]))
	for i in [3,4]:
		var fallback := str(ladder[i].fallback)
		var count := EconomyManager.count_item(StringName(fallback))
		GameManager.set_flag(&"ghostfam_seek_claimed",31&~(1<<i))
		t.check("owned_keepsake_fallback_"+str(i),seek.claim_rewards()==i+11 and EconomyManager.count_item(StringName(fallback))==count+1)
		EconomyManager.remove_item(StringName(str(ladder[i].item)),1)
		GameManager.set_flag(&"ghostfam_seek_claimed",31&~(1<<i))
		t.check("registry_only_keepsake_fallback_"+str(i),seek.claim_rewards()==i+11 and EconomyManager.count_item(StringName(fallback))==count+2)
	# A placed keepsake counts even without a registry entry or stock copy.
	HomeManager.set_tier(3)
	FurnitureManager.ensure_grid()
	var unique_lamp := "floor_lamp_glowshroom"
	LootService.dungeon["found"].erase(unique_lamp)
	t.check("placed_fixture_item",EconomyManager.add_item(StringName(unique_lamp),1,true))
	var placed_uid := -1
	for cell in FurnitureManager.grid.floor_cells:
		var placement := FurnitureManager.place_from_stock(unique_lamp,cell)
		if bool(placement.ok):
			placed_uid = int(placement.uid)
			break
	t.check("actual_home_placement",placed_uid>0 and FurnitureManager.count_stock(unique_lamp)==0 and FurnitureManager.count_placed(unique_lamp)==1 and not LootService.found(unique_lamp))
	var rare_before := EconomyManager.count_item(&"table_lamp_brass")
	GameManager.set_flag(&"ghostfam_seek_total",48)
	GameManager.set_flag(&"ghostfam_seek_claimed",31&~8)
	t.check("placed_keepsake_pays_fallback",seek.claim_rewards()==14 and EconomyManager.count_item(&"table_lamp_brass")==rare_before+1 and FurnitureManager.count_placed(unique_lamp)==1)
	# Full target store: defer instead of silently selling the prize.
	var clay := &"table_lamp_clay"
	FurnitureManager.stock[str(clay)] = FurnitureManager.max_stack_of(clay)
	GameManager.set_flag(&"ghostfam_seek_total",3)
	GameManager.set_flag(&"ghostfam_seek_claimed",0)
	var gold := EconomyManager.gold
	t.check("full_store_defers_gift",seek.claim_rewards()==0 and GameManager.flag_int(&"ghostfam_seek_claimed",0)==0 and EconomyManager.gold==gold)
	FurnitureManager.remove(clay,1)
	var snapshots: Array = []
	var observe := func(_why):
		snapshots.append([GameManager.flag_int(&"ghostfam_seek_claimed",0),EconomyManager.count_item(clay)])
		seek.claim_rewards()
	EventBus.furniture_changed.connect(observe)
	t.check("retry_accepts_once",seek.claim_rewards()==1)
	EventBus.furniture_changed.disconnect(observe)
	t.check("store_observers_see_committed_reward",snapshots.size()==1 and int(snapshots[0][0])==1 and int(snapshots[0][1])==FurnitureManager.max_stack_of(clay))
	t.check("all_keys_da_en",TranslationServer.translate("SEEK_GHOSTFAM_CARD_TITLE")!="SEEK_GHOSTFAM_CARD_TITLE")
	var page := GhostSeek.card_page()
	t.check("card_has_real_count_and_next_step",UiHints.format_line(page.lines[1]).contains("3") and page.lines.size()==3)
	var locale := TranslationServer.get_locale()
	TranslationServer.set_locale("da")
	t.check("card_count_danish",UiHints.format_line(page.lines[1])=="3 fund")
	TranslationServer.set_locale("en")
	t.check("card_count_english",UiHints.format_line(page.lines[1])=="3 finds")
	TranslationServer.set_locale(locale)
	var choices := DialogueBridge.decorate("ghostfam_blund",{"lines":[{"text_key":"DLG_NEUTRAL"}]})
	var direct: Array = choices.choices
	var card := direct.filter(func(choice):return str(choice.get("action",""))=="seek_card")
	if card.is_empty():
		for choice in direct:
			if str(choice.get("action",""))=="social_more":card=LuaData.arr(choice.choices).filter(func(c):return str(c.get("action",""))=="seek_card")
	t.check("progress_card_in_real_dialogue",not card.is_empty() and bool(DialogueBridge.action("ghostfam_blund","seek_card",{}).handled))
	_economy(t,config)
	await t.go_menu()
func _economy(t,config: Dictionary) -> void:
	var items := {}
	for id in ItemKinds.all_ids():items[id] = ItemKinds.def(id)
	var base_rate := float(LuaRuntime.get_config("time.minutes_per_real_second",2.0))
	var week_minutes := 7.0*(GameManager.day_end_hour()-GameManager.day_start_hour())/base_rate
	t.check("pace_reads_base_clock_while_fixture_is_frozen",is_equal_approx(week_minutes,70.0))
	var data := {"seek":config,"items":items,"recipes":LuaRuntime.get_recipes(),"set_rewards":LootService.loot_cfg().get("set_rewards",[]),"week_real_minutes":week_minutes}
	var source := "res://docs/qa/mechanics/social/seek-economy-source.json"
	var handle := FileAccess.open(source,FileAccess.WRITE)
	handle.store_string(JSON.stringify(data,"  "))
	handle.close()
	var tool := ProjectSettings.globalize_path("res://tools/ghostfam_seek/economy_check.py")
	var result: Dictionary = t.run_tool(t.python(), [tool,"--input",ProjectSettings.globalize_path(source),"--out",ProjectSettings.globalize_path("res://docs/qa/mechanics/social/seek-economy.json")])
	t.check("independent_live_economy",int(result.code)==0,str(result.output))
	var changed: Dictionary = data.duplicate(true)
	changed.items.floor_lamp_honey.rarity = "legendary"
	var mutant := "user://seek-mutant.json"
	handle = FileAccess.open(mutant,FileAccess.WRITE)
	handle.store_string(JSON.stringify(changed))
	handle.close()
	result = t.run_tool(t.python(), [tool,"--input",ProjectSettings.globalize_path(mutant)])
	t.check("independent_checker_catches_rarity_mutant",int(result.code)==1 and str(result.output).contains("rarity mismatch"))
	changed = data.duplicate(true)
	changed.recipes.test_lamp_loop = {"ingredients":{"table_lamp_clay":1}}
	handle = FileAccess.open(mutant,FileAccess.WRITE)
	handle.store_string(JSON.stringify(changed))
	handle.close()
	result = t.run_tool(t.python(), [tool,"--input",ProjectSettings.globalize_path(mutant)])
	t.check("independent_checker_catches_recipe_mutant",int(result.code)==1 and str(result.output).contains("recipe ingredient"))
func _native_near(t,distance: float) -> void:
	var city := CityBuilder.of(world.area)
	var floor := city.registry.level_at(actor.global_position)
	var found := false
	for turn in 24:
		var angle := TAU*turn/24.0
		var point := actor.global_position+Iso.to_screen(Vector2(cos(angle),sin(angle))*distance)
		var candidate := city.registry.level_at(point)
		if candidate!=null and floor!=null and candidate.id==floor.id:
			world.player.global_position = point
			found = true
			break
	t.check("native_approach_on_real_floor",found)
	await t.physics(4)
	seek._refresh()
func run_windowed(t) -> void:
	await _start(t)
	await _stage(t,8,19)
	await _native_near(t,130)
	await world.player.camera_focus(actor,.9,.01)
	# Let the area-arrival toast and the first hint settle before reviewing the clue.
	await t.seconds(4.5)
	t.check("native_shimmer",seek.shimmer.visible and is_zero_approx(actor.visual.modulate.a))
	await t.capture("shimmer")
	await _native_near(t,55)
	GameManager.set_flag(&"ghostfam_seek_total",2)
	actor.interact(world.player)
	await t.until(func():return ui.is_open(),3.0)
	await t.until(func():return not ui._typing,8.0)
	while ui._line<ui._lines.size()-1 and not str(ui._lines[ui._line].get("text_key","")).begins_with("SEEK_GHOSTFAM_GIFT_"):
		ui._typing = false
		ui._advance()
		await t.frames(1)
	await t.until(func():return not ui._typing,8.0)
	await t.capture("found_gift")
	await _finish(t)
	t.check("native_find_and_prize",GameManager.flag_int(&"ghostfam_seek_total",0)==3 and GameManager.flag_int(&"ghostfam_seek_claimed",0)==1)
	actor._begin_followup(world.player,DialogueBridge.action("ghostfam_blund","seek_card",{}).page)
	await t.until(func():return ui.is_open(),3.0)
	ui._typing = false
	ui._advance()
	await t.until(func():return not ui._typing,4.0)
	await t.capture("progress_card")
	await _finish(t)
	await t.go_menu()
