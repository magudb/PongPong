extends RefCounted
## Extended consumers exercise installed gameplay through its real owners.
const FLOW := preload("res://scripts/social/relationships/relationship_flow.gd")
const HEARTS := preload("res://tests/sections/social_heart_content.gd")
var suite
var world: WorldRoot2D
var director: SocialEventDirector
var ui: Control
func check(t,leg: String,id: String,ok: bool,detail := "") -> void:
	suite._check(t,leg,id,ok,detail)
func date(total: int,hour := 12) -> void:
	var old := GameManager.season
	var value := CalendarUtil.date_of(total)
	GameManager.day = int(value.day)
	GameManager.season = StringName(str(value.season))
	GameManager.year = int(value.year)
	GameManager.hour = hour
	GameManager.minute = 0
	EventBus.day_started.emit(GameManager.day,GameManager.season)
	if old != GameManager.season:EventBus.season_changed.emit(GameManager.season)
	EventBus.time_of_day_changed.emit(hour,0)
	SocialManager.flush()
func finish(t) -> void:
	var ended: bool = await t.until(func() -> bool:
		if ui.is_open() and GameManager.top_modal()==&"dialogue":
			if ui._wants_focus():ui._pick(ui._choices[0])
			else:ui._advance()
		return director.runner.active=="" and director.queue.is_empty(),10.0)
	t.check("extended_scene_returns_control",ended and not GameManager.is_modal_open())
func run(t,owner) -> void:
	suite = owner
	world = t.world()
	director = SocialManager.get_node("EventDirector")
	ui = TownProbe.dialogue(t)
	if suite._leg(t,"x01_birthday_content",["birthdays"]):
		var birthday := SocialData.birthday_of("gardener_hoppe")
		date(CalendarUtil.total_day(int(birthday.day),StringName(str(birthday.season)),GameManager.year+1))
		var line := SocialTalk.pick("gardener_hoppe","GREET")
		EconomyManager.add_item(&"carrot",1,true)
		var gift := GiftFlow.give_gift("gardener_hoppe","carrot")
		var ordinary := GiftRules.points(SocialData.cfg_dict("gifts"),StringName(str(gift.get("class","neutral"))),str(ItemKinds.rarity_of("carrot")))
		check(t,"x01_birthday_content","x01_birthday_greeting_and_real_gift",line.begins_with("BDAY_GARDENER_HOPPE_") and TranslationServer.translate(line)!=line and bool(gift.get("ok",false)) and str(gift.get("birthday",""))=="day" and int(gift.get("points",0))==ordinary*4 and SocialManager.birthday_state("gardener_hoppe")=="",str(gift))
	if suite._leg(t,"x03_heart_event",["events"]):
		SocialManager.debug_set_hearts("gardener_hoppe",4)
		var scene := "ev_gardener_hoppe_h4"
		var stage = HEARTS.new()
		stage.world = world
		stage.director = director
		stage.ui = ui
		var staged: bool = await stage._stage(t,"gardener_hoppe",LuaData.dict(SocialData.event(scene).meta))
		var accepted := staged and scene in SocialManager.events_ready("gardener_hoppe") and director.request(scene)
		await finish(t)
		check(t,"x03_heart_event","x03_heart_event_real_scene_once",accepted and SocialManager.event_seen(scene) and not director.request(scene))
	if suite._leg(t,"x08_rain_fallback_scene",["events"]):
		var shops = preload("res://tests/lib/town_loop/shops.gd").new()
		shops.suite = suite
		var rain_copy := false
		var opened := true
		var keys := []
		# A first introduction legitimately takes priority over weather. Use
		# another real day for the greeting; previewing pick() would consume
		# its session no-repeat entry before the player opens the dialogue.
		for attempt in 2:
			await world.travel(&"farm",&"default")
			var selected := SocialManager.today()+1
			while CalendarUtil.weekday_of(selected)!=1 or SocialManager.roll(["merchant_pip",selected,"weather"])>=0.6:
				selected += 1
			date(selected,10)
			while SocialManager.festival_today()!=&"" or SocialManager.is_birthday("merchant_pip"):
				selected += 7
				while SocialManager.roll(["merchant_pip",selected,"weather"])>=0.6:selected += 7
				date(selected,10)
			TimeManager.set_weather(&"regn")
			await world.travel(&"int_froebutikken",&"default")
			opened = await shops.host(t,"talk") and opened
			keys = ui._lines.map(func(row):return str(row.get("text_key",""))) if ui.is_open() else []
			rain_copy = keys.any(func(key):return key.contains("WX_REGN"))
			await suite._finish_dialogue(t)
			if rain_copy:break
		check(t,"x08_rain_fallback_scene","x08_rain_fallback",opened and rain_copy and not world.weather_fx.is_emitting(),str(keys))
	if suite._leg(t,"x05_mail_screen",["post_ui"]):
		EventBus.game_event.emit(&"open_post_office",{})
		await t.frames(2)
		var panel: Control = world.game_ui.get_screen(&"post")
		var expected := Routines.where_is("merchant_pip",Routines.now_ctx())
		check(t,"x05_mail_screen","x05_mail_screen_live_locations",panel.is_open() and panel.tabs.size()==3 and panel.data.any(func(row):return str(row.id)=="merchant_pip" and row.state==expected))
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
		check(t,"x05_mail_screen","x05_mail_escape_restores_world",not panel.is_open() and not GameManager.is_modal_open())
	if suite._leg(t,"x04_relationship",["relationships"]):
		SocialManager.debug_set_hearts("gardener_hoppe",8)
		EconomyManager.add_item(&"hjertebuket",1,true)
		var before := EconomyManager.count_item(&"hjertebuket")
		var refused := GiftFlow.give_gift("gardener_hoppe","hjertebuket")
		var given := GiftFlow.give_gift("gardener_hoppe","hjertebuket",true)
		check(t,"x04_relationship","x04_relationship_consent_and_stage",not bool(refused.get("ok",false)) and bool(given.get("ok",false)) and FLOW.state("gardener_hoppe")==1 and EconomyManager.count_item(&"hjertebuket")==before-1)
	if suite._leg(t,"x06_farm_visit_scene",["visits"]):
		# A single eligible friend gives a deterministic real visitor, with the
		# same authored job-preserving route used by ordinary saves.
		for npc in SocialManager.friend_ids():
			if npc!="gardener_hoppe":SocialManager.debug_set_hearts(npc,0)
		await t.until(func():return not world.traveling and not GameManager.is_modal_open(),5)
		await world.travel(&"farm",&"default")
		HomeManager.set_tier(8)
		var weekdays := HomeData.visit_weekdays(HomeManager.guest_visits_per_week())
		# This scenario requires a delivered gift. Three ordinary loot rolls
		# may all be empty; seed this fixture without changing the game's odds.
		var loot: Node = t.autoload("LootService")
		var seed_before: int = loot.rng.seed
		var state_before: int = loot.rng.state
		loot.set_seed(424242)
		date((SocialManager.week()+1)*7+int(weekdays[0])+1,21)
		HomeManager._roll_weekly_visit()
		var visit := HomeManager.visit_today()
		await world.travel(&"home",&"default")
		var arrived := str(world.area.map.id)=="home" and not world.traveling
		check(t,"x06_farm_visit_scene","x06_farm_visit_enters_home",arrived,str([world.area.map.id,GameManager.top_modal(),world.traveling]))
		if arrived:
			var room: HomeRoom = world.area.get_node("HomeRoom")
			var visits: FarmVisits = room.get_node("FarmVisits")
			await t.until(func():return visits.actors.has("gardener_hoppe"),5)
			check(t,"x06_farm_visit_scene","x06_farm_visit_named_actor_and_saved_gift",str(visit.get("npc",""))=="gardener_hoppe" and visits.actors.has("gardener_hoppe") and SocialManager.event_stamp("home_visit:gardener_hoppe")==SocialManager.week()+1,
				"visit=%s, actors=%s, gift=%s, stamp=%d, week=%d, free slots=%d" % [visit,visits.actors.keys(),HomeManager.last_visit,SocialManager.event_stamp("home_visit:gardener_hoppe"),SocialManager.week(),EconomyManager.free_slots()])
		loot.rng.seed = seed_before
		loot.rng.state = state_before
	if suite._leg(t,"x07_seasonal_decor",["seasonal"]):
		date(CalendarUtil.total_day(2,&"vinter",GameManager.year+1))
		TimeManager.set_weather(&"sne")
		await world.travel(&"farm",&"default")
		await t.frames(3)
		var markers: Array = world.area.find_markers("dress").map(func(row):return row.node)
		var fx: FarmAmbientFx = world.area.find_markers("ambient_fx")[0].node
		check(t,"x07_seasonal_decor","x07_seasonal_decor_live_painted_family",markers.size()==16 and markers.filter(func(node):return node.params.has("season")).all(func(node):return is_instance_valid(node.prop)==(str(node.params.season)=="vinter")) and fx.leaves.amount==40)
	if suite._leg(t,"x02_festival_scene",["festivals"]):
		var fid := "hoestfesten"
		var meta := LuaData.dict(SocialData.festival(fid).meta)
		date(CalendarUtil.total_day(int(meta.day),StringName(str(meta.season)),GameManager.year+1),int(meta.from))
		GameManager.minute = 30
		TimeManager.set_weather(&"klart")
		EventBus.time_of_day_changed.emit(GameManager.hour,30)
		await world.travel(StringName(str(meta.area)),&"default")
		await t.until(func():return is_instance_valid(director._stage) and director._stage.hosts.size()==3,5)
		await finish(t)
		var festival: FestivalStage = director._stage
		var state := {"hosts":festival.hosts.size() if festival!=null else -1,"opening":SocialManager.event_stamp("ev_"+fid+"_open"),"year":GameManager.year,"sleep":world.can_sleep_now(),"shop":ShopSystem.is_open("seed_shop"),"music":AudioManager.cue_log().any(func(row):return row.kind=="music" and row.id=="festival_efteraar" and row.played)}
		check(t,"x02_festival_scene","x02_festival_scene_decor_hours_bed_music",state.hosts==3 and state.opening==state.year and not state.sleep and not state.shop and state.music,str(state))
		if suite.native_mode:
			var at := NpcDirector.post_ground(str(meta.area),StringName("fest_"+str(meta.spot)+"_host"))
			world.player.global_position = world.area.to_global(Iso.to_screen(at+Vector2(180,160)))
			world.player.camera.reset_smoothing()
			world.player.camera.force_update_scroll()
			await suite.shot(t,"S14_festival_day_city")
			check(t,"L15","l15_festival_capture",suite.native_shots.has("S14_festival_day_city"))
		GameManager.hour = int(meta.to)
		EventBus.time_of_day_changed.emit(GameManager.hour,0)
		SocialManager.flush()
		await finish(t)
		await world.travel(&"farm",&"default")
	if suite._leg(t,"x09_commitment",["relationships"]):
		date(SocialManager.today()+7)
		SocialManager.debug_set_hearts("gardener_hoppe",10)
		EconomyManager.add_item(&"loefteagern",1,true)
		var proposed := GiftFlow.give_gift("gardener_hoppe","loefteagern",true)
		var wedding := int(SocialManager.partner().get("wedding",0))
		check(t,"x09_commitment","x09_commitment_saved_safe_wedding",bool(proposed.get("ok",false)) and FLOW.state("gardener_hoppe")==2 and wedding>=SocialManager.today()+7 and CalendarUtil.weekday_of(wedding)==6 and SaveManager.save_game(3) and SaveManager.load_game(3) and int(SocialManager.partner().get("wedding",0))==wedding)
	if suite._leg(t,"L16",["audio"]):
		var next_day := SocialManager.today()+1
		while CalendarUtil.weekday_of(next_day)!=1:next_day += 1
		date(next_day,10)
		AudioManager.clear_cue_log()
		await world.travel(&"hyggebyen",&"default")
		await world.travel(&"int_froebutikken",&"default")
		check(t,"L16","l16_shop_bell_is_logged",AudioManager.cue_log().any(func(row):return row.kind=="sfx" and row.id=="shop_bell" and row.played))
		AudioManager.play_sfx("town_loop_missing_probe")
		check(t,"L16","l16_missing_cue_logged_silent",AudioManager.cue_log().any(func(row):return row.id=="town_loop_missing_probe" and not row.played))
		check(t,"L16","l16_wood_surface_follows_room",Surface.at(world.area,t.player().global_position)=="wood")
		var hosts := TownProbe.hosts(t,"shop")
		if not hosts.is_empty():await LoopWalker.walk_to(t,hosts[0].global_position,20,5)
		check(t,"L16","l16_real_movement_footsteps",AudioManager.cue_log().any(func(row):return row.kind=="sfx" and row.id.begins_with("step_wood_") and row.played))
		await world.travel(&"hyggebyen",&"default")
		var stone := false
		for y in world.area.map.ground.size():
			var x: int = world.area.map.ground[y].find("c")
			if x>=0:stone = Surface.at(world.area,world.area.cell_to_global(Vector2i(x,y)))=="stone"
			if stone:break
		check(t,"L16","l16_stone_surface_follows_ground",stone)
		await world.travel(&"traetoppen",&"default")
		var builder := CityBuilder.of(world.area)
		var bridge := builder.registry.bridges[0]
		check(t,"L16","l16_rope_surface_follows_bridge",Surface.at(world.area,bridge.gate_path[bridge.gate_path.size()/2])=="rope")
		GameManager.hour = 24
		EventBus.time_of_day_changed.emit(24,0)
		check(t,"L16","l16_night_ambience_follows_clock",AudioManager.cue_log().any(func(row):return row.kind=="amb" and row.id=="town_night" and row.played))
	await world.travel(&"farm",&"default")
