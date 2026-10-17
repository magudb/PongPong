extends RefCounted
const SECTION := "social_fest_content"
const TIMEOUT_S := 300.0
const IDS := ["blomsterfesten","honningdagen","midsommerlanterner","badedagen","hoestfesten","maanemarkedet","vinterlysene","bagedagen","aarsskiftet"]
const FAMILY := ["ghostfam_dyne","ghostfam_gnist","ghostfam_silke","ghostfam_blund"]
var world: WorldRoot2D
var director: SocialEventDirector
var ui: Node
func run(t) -> void:
	await _run(t,false)
func run_windowed(t) -> void:
	await _run(t,true)
func _run(t,native: bool) -> void:
	await t.start_world()
	world = t.world()
	director = SocialManager.get_node("EventDirector")
	ui = t.first(&"dialogue_ui")
	GameManager.set_config_override("time.minutes_per_real_second",0)
	GameManager.set_config_override("towns.curfew.enabled",false)
	var items := {}
	for id in ItemKinds.all_ids(): items[id] = ItemKinds.def(id)
	var live := {"social":Svc.lua_config("social",{}),"citizens":SocialData.citizens(),"npcs":SocialData.npcs(),"gift_tastes":Svc.lua_config("gift_tastes",{}),"items":items,"festivals":SocialData.festivals(),"events":SocialData.events(),"shops":LuaRuntime.get_shops(),"time":Svc.lua_config("time",{}),"towns":Svc.lua_config("towns",{})}
	var validation := SocialValidator.validate(live,{
		"when_errors":SocialManager.when_spec_errors,
		"route_minutes":func(npc,area,spot):
			var shops := Hours.buildings_of_shop(str(SocialData.npc_row(str(npc)).get("shop_id","")))
			if shops.is_empty(): return -1.0
			return RouteTable.seconds(str(area)+".fest_"+str(spot)+"_host",str(Hours.building(shops[0]).get("post","")))*RouteTable.game_min_per_s,
		"shop_open_hour":func(shop,weekday):
			var buildings := Hours.buildings_of_shop(str(shop))
			return float(Hours.hours_on(Hours.building(buildings[0]),int(weekday))[0]) if not buildings.is_empty() else -1.0
	})
	t.check("live_social_validator_including_keeper_return_routes",validation.errors.is_empty() and validation.skipped.is_empty() and int(validation.stats.get("leave_early_measured",0)) == 9,str(validation.errors)+str(validation.skipped))
	var dates := {}
	var markets := {}
	for id in IDS:
		var festival := SocialData.festival(id)
		var meta := LuaData.dict(festival.get("meta",{}))
		var td := CalendarUtil.total_day(int(meta.day),StringName(str(meta.season)),1)
		t.check(id+"_unique_date_and_valid_window",not dates.has(td) and float(meta.to) <= 23 and float(meta.to)-float(meta.from) >= 5)
		dates[td] = true
		t.check(id+"_existing_host",SocialManager.can_befriend(str(meta.host)))
		for npc in SocialData.friend_ids():
			var birthday := SocialData.birthday_of(npc)
			var day := CalendarUtil.total_day(int(birthday.day),StringName(str(birthday.season)),1)
			t.check(id+"_birthday_clear_"+npc,mini(absi(td-day),112-absi(td-day)) > 1)
		var prizes := LuaData.dict(LuaData.dict(festival.get("rewards",{})).get("contest",{}))
		for activity in LuaData.arr(festival.get("activities",[])):
			t.check(id+"_activity_copy_"+str(activity.id),TranslationServer.translate(str(activity.name_key)) != str(activity.name_key))
			if str(activity.kind) == "contest": t.check(id+"_contest_prizes",FestivalActivities.valid_prizes(str(activity.select),prizes,items))
			if str(activity.kind) == "market":
				markets[str(activity.shop)] = true
				var shop := LuaRuntime.get_shop(str(activity.shop))
				t.check(id+"_market_definition",bool(shop.get("festival_stall",false)) and not LuaData.dict(shop.get("stock",{})).is_empty())
				for item in LuaData.dict(shop.get("stock",{})):
					t.check(id+"_market_stock_"+str(item),str(ItemKinds.rarity_of(item)) in ["normal","uncommon"] and not ItemKinds.def(item).is_empty())
		var roster := SocialManager.festival_roster(id)
		t.check(id+"_whole_family_invited",FAMILY.all(func(n):return n in roster.gather))
		GameManager.season = StringName(str(meta.season))
		GameManager.day = int(meta.day)
		GameManager.hour = floori(float(meta.from))
		GameManager.minute = 30
		EventBus.day_started.emit(GameManager.day,GameManager.season)
		EventBus.time_of_day_changed.emit(GameManager.hour,GameManager.minute)
		SocialManager.flush()
		await world.travel(StringName(str(meta.area)),&"default")
		await t.until(func():return is_instance_valid(director._stage) and director._stage.festival_id == id and director._stage.hosts.size() == 3,5.0)
		await _finish(t)
		var stage: FestivalStage = director._stage
		t.check(id+"_all_activity_posts_resolve",stage != null and stage.hosts.size() == 3 and world.area.map.errors.is_empty(),str(world.area.map.errors))
		t.check(id+"_opening_seen",SocialManager.event_stamp("ev_"+id+"_open") == 1)
		if stage == null: continue
		t.check(id+"_family_present",FAMILY.all(func(n):return NpcDirector.node_of(n) != null))
		t.check(id+"_bed_held",not world.can_sleep_now())
		for shop in LuaData.strings(meta.get("stays_open",[])):
			t.check(id+"_retained_shop_covers_weekday_"+shop,Hours.buildings_of_shop(shop).any(func(building):return int((int(meta.day)-1)%7) not in LuaData.arr(LuaData.dict(Hours.building(building).get("hours",{})).get("closed",[])).map(func(day):return int(day))))
		for activity in LuaData.arr(festival.get("activities",[])):
			if str(activity.kind) == "market": t.check(id+"_own_market_open",ShopSystem.is_open(str(activity.shop)))
		var decor: FestivalDecor
		for population in NpcDirector._active:
			if population.area == world.area: decor = population.get_node_or_null("FestivalDecor") as FestivalDecor
		t.check(id+"_painted_decor_present",decor != null and is_instance_valid(decor.art) and decor.art.get_child_count() >= 14,"decor="+str(decor)+" art="+str(decor.art if decor != null else null)+" children="+str(decor.art.get_children() if decor != null and is_instance_valid(decor.art) else []))
		if decor != null and world.area.map.id == &"traetoppen":
			t.check(id+"_decor_above_deck",decor.art.get_children().all(func(n):return n.z_index >= 10))
		if native and id in ["hoestfesten","honningdagen","badedagen"]:
			var at := NpcDirector.post_ground(str(meta.area),StringName("fest_"+str(meta.spot)+"_host"))
			world.player.global_position = world.area.to_global(Iso.to_screen(at+Vector2(180,160)))
			world.player.camera.position_smoothing_enabled = false
			world.player.camera.reset_smoothing()
			world.player.camera.force_update_scroll()
			world.game_ui.get_screen(&"hud").toasts.clear()
			await t.frames(4)
			await t.capture(id+"_gathering")
		var gift_before := EconomyManager.count_item(&"honey_cake")
		GameManager.hour = int(meta.to)-1
		GameManager.minute = 0
		EventBus.time_of_day_changed.emit(GameManager.hour,0)
		await _finish(t)
		t.check(id+"_finale_pays_once",SocialManager.event_stamp("ev_"+id+"_end") == 1 and EconomyManager.count_item(&"honey_cake") == gift_before+1)
		director._schedule()
		await t.frames(3)
		t.check(id+"_reentry_has_no_repeat_reward",EconomyManager.count_item(&"honey_cake") == gift_before+1 and director.queue.is_empty())
		GameManager.hour = int(meta.to)
		EventBus.time_of_day_changed.emit(GameManager.hour,0)
		SocialManager.flush()
		for activity in LuaData.arr(festival.get("activities",[])):
			if str(activity.kind) == "market": t.check(id+"_own_market_closes",not ShopSystem.is_open(str(activity.shop)))
		await t.frames(3)
		t.check(id+"_decor_clears_afterwards",decor != null and not is_instance_valid(decor.art))
	t.check("nine_festivals_and_five_markets",dates.size() == 9 and markets.size() == 5)
	t.check("content_export_reproducible",int(t.run_tool("python3",[ProjectSettings.globalize_path("res://tools/social/content/build_festivals.py"),"--check"]).code) == 0)
	t.check("save_all_nine_endings",SaveManager.save_game(3) and SaveManager.load_game(3))
	t.check("all_finales_stay_seen",IDS.all(func(id):return SocialManager.event_stamp("ev_"+id+"_end") == 1))
	director.reset()
	t.new_game()

func _finish(t) -> void:
	for i in 1500:
		await t.frames(1)
		if ui.is_open() and GameManager.top_modal() == &"dialogue": ui._advance()
		if i > 12 and director.runner.active == "" and director.queue.is_empty(): return
	t.fail("festival scene did not finish")
