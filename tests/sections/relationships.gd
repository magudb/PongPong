extends RefCounted
const SECTION := "relationships"
const TIMEOUT_S := 240.0
const FLOW := preload("res://scripts/social/relationships/relationship_flow.gd")
const VISITS := preload("res://scripts/social/relationships/farm_visits.gd")
func _date(day: int,hour := 12,minute := 0) -> void:
	var date := CalendarUtil.date_of(day)
	GameManager.day = int(date.day)
	GameManager.season = StringName(str(date.season))
	GameManager.year = int(date.year)
	GameManager.hour = hour
	GameManager.minute = minute
func _candidates() -> Array:
	return SocialManager.friend_ids().filter(func(id):return bool(SocialData.citizen(str(id)).get("partner",false)))
func run(t) -> void:
	await t.start_world()
	GameManager.set_config_override("time.minutes_per_real_second",0)
	GameManager.set_config_override("towns.curfew.enabled",false)
	_date(2)
	var candidates := _candidates()
	t.check("eleven_adult_candidates",candidates.size()==11 and not candidates.has("ghostfam_blund"))
	for item in FLOW.TOKENS:
		var d := EconomyManager.item_def(item)
		t.check(item+"_crafted_special_icon",str(d.get("category",""))=="special" and int(d.get("sell_price",1))==0 and not TTItemIcon.resolve_path(item).is_empty())
		EconomyManager.add_item(StringName(item),5,true)
	for id in FLOW.TOKENS:
		var recipe := CraftingSystem.get_recipe(id)
		for ingredient in recipe.ingredients:EconomyManager.add_item(StringName(str(ingredient)),int(recipe.ingredients[ingredient]),true)
		var count := EconomyManager.count_item(StringName(str(id)))
		var needs: Dictionary = recipe.ingredients
		var before := {}
		for ingredient in needs:before[str(ingredient)] = EconomyManager.count_item(StringName(str(ingredient)))
		var crafted := CraftingSystem.craft(id)
		var exact := true
		for ingredient in needs:exact = exact and EconomyManager.count_item(StringName(str(ingredient)))==int(before[str(ingredient)])-int(needs[ingredient])
		t.check(str(id)+"_real_recipe_exact_consumption",crafted and exact and EconomyManager.count_item(StringName(str(id)))==count+1)
		EconomyManager.remove_item(StringName(str(id)),1)
		t.check(str(id)+"_never_sold_in_a_shop",not LuaRuntime.get_shops().values().any(func(shop):return LuaData.arr(shop.get("stock",shop.get("items",[]))).any(func(r):return str(r.get("id",r.get("item","")))==id)))
	for npc in candidates:
		var lines := FLOW.reaction_lines(npc,{"relationship":1})
		t.check(str(npc)+"_authored_or_archetype_scene_localized",lines.size()==2 and lines.all(func(line):return TranslationServer.translate(str(line.text_key))!=str(line.text_key)))
	var n := EconomyManager.count_item(&"hjertebuket")
	t.check("child_refusal_keeps_bouquet",not FLOW.give("ghostfam_blund","hjertebuket",true).ok and EconomyManager.count_item(&"hjertebuket")==n)
	t.check("low_hearts_refusal",FLOW.reason("gardener_hoppe","hjertebuket")=="PARTNER_WAIT")
	SocialManager.debug_set_hearts("gardener_hoppe",8)
	t.check("programmatic_gift_requires_consent",not GiftFlow.give_gift("gardener_hoppe","hjertebuket").ok and EconomyManager.count_item(&"hjertebuket")==n)
	var limits := SocialManager.gift_limits("gardener_hoppe")
	var row := SocialManager.row_of("gardener_hoppe")
	row.gd = SocialManager.today()
	row.gwk = SocialManager.week()
	row.gw = 2
	t.check("special_shown_after_ordinary_limits",GiftFlow.gift_options("gardener_hoppe").any(func(r):return str(r.id)=="hjertebuket" and bool(r.special)))
	var observed: Array = []
	var observer := func(_pack):observed.append(FLOW.state("gardener_hoppe")==1 and EconomyManager.count_item(&"hjertebuket")==n-1)
	EventBus.player_inventory_changed.connect(observer)
	var result := GiftFlow.give_gift("gardener_hoppe","hjertebuket",true)
	EventBus.player_inventory_changed.disconnect(observer)
	t.check("bouquet_atomic_heartfriend",bool(result.ok) and str(SocialManager.stage("gardener_hoppe"))=="hjertven" and observed==[true])
	t.check("ordinary_gift_ledger_untouched",int(row.gd)==2 and int(row.gw)==2 and row.ls.is_empty() and int(SocialManager.gift_limits("gardener_hoppe").left_today)==0)
	t.check("repeated_bouquet_not_consumed",not GiftFlow.give_gift("gardener_hoppe","hjertebuket",true).ok and EconomyManager.count_item(&"hjertebuket")==n-1)
	SocialManager.debug_set_hearts("carpenter_brumme",8)
	t.check("several_heartfriends",GiftFlow.give_gift("carpenter_brumme","hjertebuket",true).ok and FLOW.state("gardener_hoppe")==1)
	SocialManager.debug_set_hearts("gardener_hoppe",10)
	t.check("seven_days_required",FLOW.reason("gardener_hoppe","loefteagern")=="PARTNER_DAYS")
	_date(9)
	t.check("home_three_required",FLOW.reason("gardener_hoppe","loefteagern")=="PARTNER_HOME")
	HomeManager.set_tier(3)
	result = GiftFlow.give_gift("gardener_hoppe","loefteagern",true)
	var wedding := int(SocialManager.partner().get("wedding",0))
	t.check("proposal_committed_once",bool(result.ok) and FLOW.state("gardener_hoppe")==2 and wedding>=16 and EconomyManager.count_item(&"loefteagern")==4)
	t.check("wedding_safe_sunday",CalendarUtil.weekday_of(wedding)==6 and not FLOW.fixed_on(wedding-1) and not FLOW.fixed_on(wedding) and not FLOW.fixed_on(wedding+1))
	SocialManager.debug_set_hearts("carpenter_brumme",10)
	t.check("one_engagement",FLOW.reason("carpenter_brumme","loefteagern")=="PARTNER_OTHER_PROMISE")
	var date := CalendarUtil.date_of(wedding)
	t.check("calendar_dynamic_wedding",SocialManager.calendar_entries(date.season,int(date.year)).any(func(e):return str(e.id)==FLOW.WEDDING and int(e.day)==int(date.day)))
	t.check("fixed_calendar_still_nine",SocialData.festivals().size()==9)
	t.check("real_save_reload",SaveManager.save_game(3) and SaveManager.load_game(3))
	t.check("proposal_dates_and_stages_saved",int(SocialManager.partner().get("wedding",0))==wedding and SocialManager.event_stamp("heartfriend:gardener_hoppe")==2 and FLOW.state("gardener_hoppe")==2)
	_date(wedding,20)
	FLOW.flush()
	var delayed := int(SocialManager.partner().get("wedding",0))
	t.check("missed_wedding_reschedules_without_penalty",delayed>=wedding+7 and FLOW.state("gardener_hoppe")==2 and EconomyManager.count_item(&"loefteagern")==4)
	_date(delayed,12)
	t.check("dynamic_wedding_roster_spouse_first",str(SocialManager.festival_today())==FLOW.WEDDING and SocialManager.festival_roster(FLOW.WEDDING).first==["gardener_hoppe"] and SocialManager.festival_roster(FLOW.WEDDING).gather.size()<=19)
	t.check("cannot_marry_without_scene",not FLOW.marry())
	SocialManager.mark_event_seen("ev_bryllupsfesten_open")
	SocialManager.mark_event_seen("day:ev_bryllupsfesten_open",SocialManager.today())
	t.check("wedding_commits_once",FLOW.marry() and not FLOW.marry() and str(SocialManager.stage("gardener_hoppe"))=="gift")
	var errors: Array[String] = []
	var morning: Dictionary = {}
	var evenings := 0
	var route_evidence: Array = []
	for npc in candidates:
		for wd in 7:
			for weather in ["klart","regn"]:
				var ctx := Routines.make_ctx(wd,12,weather,{"total_day":99,"hearts":{npc:10},"done":{"lost_cat":true},"home_guests":[npc],"home_partner":npc})
				var base := Routines.timeline(npc,Routines.plan_name(npc,ctx),weather=="regn")
				var over := VISITS.timeline(npc,ctx,base)
				if not VISITS._covered(VISITS._protected(npc,ctx,base),over):errors.append(str(npc)+"/"+str(wd)+" "+weather)
				if wd==0 and weather=="klart":
					morning[npc] = over[0].t1 if str(over[0].get("act",""))=="home" else 6.0
					if over.any(func(s):return str(s.get("act",""))=="home" and float(s.t0)>=18):evenings += 1
				route_evidence.append({"npc":npc,"weekday":wd,"weather":weather,"morning_until":over[0].t1 if str(over[0].get("act",""))=="home" else 6.0,"visits":over.filter(func(s):return str(s.get("act",""))=="home")})
				for s in over:
					if str(s.kind)=="move" and s.legs.any(func(l):return bool(l.get("estimated",false))):errors.append(str(npc)+" estimated home route")
	t.check("all_eleven_jobs_covered_seven_days_two_weathers",errors.is_empty(),str(errors))
	t.check("computed_early_baker_no_morning",float(morning.get("baker_maja",0))==6.0,str(morning))
	t.check("computed_morning_and_evening_visits",float(morning.get("bathkeeper_sofus",6))>6.0 and float(morning.get("postman_pip",6))>6.0 and evenings>=8,str(morning)+" evening="+str(evenings))
	for i in 336:
		var d := FLOW.next_wedding(i+1)
		if CalendarUtil.weekday_of(d)!=6 or FLOW.fixed_on(d-1) or FLOW.fixed_on(d) or FLOW.fixed_on(d+1):errors.append("unsafe date "+str(d))
	t.check("year_boundary_safe_wedding_dates",errors.is_empty(),str(errors))
	var handle := FileAccess.open("res://docs/qa/mechanics/social/partner-routes.json",FileAccess.WRITE)
	handle.store_string(JSON.stringify({"basis":"live baked routes; raw 06:00–02:00 clock; all eleven candidates, seven weekdays, two weathers","work_coverage_errors":errors,"routes":route_evidence},"  "))
	handle.close()
	_festival_jobs(t)

	_date(delayed+1,6)
	var farm: FarmGrid = t.world().farm
	var cells := farm.farmable_cells()
	farm.plots.clear()
	for i in 15:
		var plot := FarmGrid.PlotData.new()
		plot.state = FarmGrid.State.PLANTED
		plot.crop_id = &"turnip"
		farm.plots[cells[i]] = plot
	var water_observed: Array = []
	# the partner's watering is EventBus.crop_auto_watered(plot, &"partner"), never the player's crop_watered (GAP4-03)
	var water_obs := func(_id, source):water_observed.append(source == &"partner" and farm.plots.values().filter(func(p):return p.watered).size()==12 and int(SocialManager.partner().get("chore_day",0))==SocialManager.today())
	EventBus.crop_auto_watered.connect(water_obs)
	VISITS.daily_chore()
	EventBus.crop_auto_watered.disconnect(water_obs)
	t.check("daily_help_water_twelve_atomic",water_observed.size()==12 and water_observed.all(func(v):return v) and int(SocialManager.partner().get("chore_count",0))==12)
	VISITS.daily_chore()
	t.check("daily_help_cannot_repeat",farm.plots.values().filter(func(p):return p.watered).size()==12)
	farm.plots.clear()
	_date(delayed+2,6)
	AnimalHusbandry.build_building(&"coop",true)
	EconomyManager.add_item(&"baby_chick",2,true)
	AnimalHusbandry.adopt_animal(&"baby_chick")
	AnimalHusbandry.adopt_animal(&"baby_chick")
	for animal in AnimalHusbandry.get_all_animals():animal.hunger = 40.0
	EconomyManager.add_item(&"chicken_feed",2,true)
	var feed := EconomyManager.count_item(&"chicken_feed")
	VISITS.daily_chore()
	t.check("daily_help_feeds_real_animals_from_supplies",str(SocialManager.partner().get("chore_kind",""))=="feed" and EconomyManager.count_item(&"chicken_feed")==feed-2 and AnimalHusbandry.get_all_animals().all(func(a):return a.last_fed_day==SocialManager.today()))
	_date(delayed+3,6)
	VISITS.daily_chore()
	t.check("no_work_leaves_note",str(SocialManager.partner().get("chore_kind",""))=="note")
	t.check("chore_save_reload",SaveManager.save_game(3) and SaveManager.load_game(3))
	var stamp := SocialManager.partner()
	VISITS.daily_chore()
	t.check("daily_help_saved_idempotent",SocialManager.partner()==stamp)
	for npc in ["baker_maja","merchant_pip","postman_pip","bathkeeper_sofus","beekeeper_birk","appraiser_fru_ugle","fairy_lily"]:SocialManager.debug_set_hearts(npc,4)
	var party := SocialManager.start_house_party()
	t.check("party_names_six_real_friends",party.size()==6 and party.all(func(npc):return SocialManager.can_befriend(npc) and SocialManager.hearts(npc)>=4))
	var guests: Array[String] = []
	for i in 3:guests.append(SocialManager.pick_visitor(10,i))
	t.check("weekly_visits_deterministic_without_repeats",guests.size()==3 and not guests.has("") and guests[0]!=guests[1] and guests[1]!=guests[2] and guests[0]!=guests[2] and SocialManager.pick_visitor(10,0)==guests[0])
	var picked := guests[0]
	SocialManager.mark_event_seen("home_visit:"+picked,11)
	SocialManager.debug_set_hearts("farmer_rosa",4)
	t.check("new_friend_cannot_repeat_earlier_weekly_visitor",SocialManager.pick_visitor(10,1)!=picked)
	HomeManager.set_tier(8)
	var days := HomeData.visit_weekdays(HomeManager.guest_visits_per_week())
	_date(20*7+int(days[0])+1,19)
	LootService.set_seed(4242)
	HomeManager._roll_weekly_visit()
	var visit := HomeManager.visit_today()
	var named := str(visit.get("npc",""))
	t.check("real_weekly_gift_names_a_friend",named!="" and SocialManager.hearts(named)>=4 and SocialManager.event_stamp("home_visit:"+named)==SocialManager.week()+1)
	var inventory := EconomyManager.to_dict()
	HomeManager._roll_weekly_visit()
	t.check("real_weekly_gift_not_replayed",EconomyManager.to_dict()==inventory and HomeManager.visit_today()==visit)
	t.check("named_visit_and_history_saved",SaveManager.save_game(3) and SaveManager.load_game(3) and HomeManager.visit_today()==visit and SocialManager.event_stamp("home_visit:"+named)==SocialManager.week()+1)
	for npc in candidates:
		if not SocialManager.can_befriend(npc):t.check("hero_twin_not_a_partner",FLOW.reason(npc,"hjertebuket")=="PARTNER_NOT_ADULT")
	var gen: Dictionary = t.run_tool("python3",[ProjectSettings.globalize_path("res://tools/social/content/build_relationships.py"),"--check"])
	t.check("authored_relationship_data_current",int(gen.code)==0,str(gen.output))
	await t.go_menu()

func _finish_dialogue(t) -> void:
	var ui: Node = t.first(&"dialogue_ui")
	await t.until(func() -> bool:
		if ui.is_open():ui._advance()
		return not ui.is_open() and not GameManager.is_modal_open(),10.0)

func _select_gift(t,picker: Node,item: String) -> bool:
	var index: int = picker.options.find_custom(func(r):return str(r.id)==item)
	if index<0:return false
	picker._activate(index)
	await t.frames(2)
	return not picker.give.disabled

func run_windowed(t) -> void:
	await t.start_world()
	GameManager.set_config_override("time.minutes_per_real_second",0)
	GameManager.set_config_override("towns.curfew.enabled",false)
	_native_date(2,10)
	SocialManager.debug_set_hearts("gardener_hoppe",8)
	EconomyManager.add_item(&"hjertebuket",2,true)
	EconomyManager.add_item(&"loefteagern",1,true)
	var world: Node = t.world()
	await world.travel(&"traetoppen",&"default")
	await t.physics(4)
	var actor := NpcDirector.node_of("gardener_hoppe",world.area) as Npc2D
	t.check("native_candidate_present",actor!=null)
	if actor==null:return
	var city := CityBuilder.of(world.area)
	var floor := city.registry.level_at(actor.global_position)
	var approached := false
	for turn in 24:
		var point := actor.global_position+Iso.to_screen(Vector2.from_angle(TAU*turn/24.0)*55.0)
		var candidate := city.registry.level_at(point)
		if candidate!=null and floor!=null and candidate.id==floor.id:
			world.player.global_position = point
			approached = true
			break
	await t.physics(4)
	t.check("native_approach_same_floor",approached)
	await world.player.camera_focus(actor,0.9,0.1)
	await t.seconds(3.5)
	actor.interact(world.player)
	var ui: Node = t.first(&"dialogue_ui")
	var choices_ready: bool = await t.until(func() -> bool:
		if ui.is_open() and not ui._wants_focus():ui._advance()
		return ui._wants_focus(),10.0)
	var choices: Array = ui._choices.filter(func(c):return str(c.get("action",""))=="give_gift")
	t.check("native_real_talk_offers_gift",choices_ready and not choices.is_empty())
	if choices.is_empty():return
	ui._pick(choices[0])
	await t.frames(4)
	var picker: Node = world.game_ui.get_screen(&"gift_ui")
	t.check("native_special_bouquet_selectable",picker.is_open() and await _select_gift(t,picker,"hjertebuket"))
	t.check("native_special_description_without_birthday_multiplier",picker.detail_description.visible and not picker.birthday.visible and picker.detail_stock.text==TranslationServer.translate("STORE_OWNED_FMT") % 2)
	await t.capture("relationship_bouquet_picker")
	picker._give()
	await t.frames(3)
	var dialogs: Array = picker.get_children().filter(func(n):return n is UiConfirm)
	t.check("native_bouquet_default_stay_friends",dialogs.size()==1 and picker.get_viewport().gui_get_focus_owner()==dialogs[0].get_node("%CancelButton"))
	await t.capture("relationship_bouquet_confirm")
	if not dialogs.is_empty():dialogs[0]._finish(false)
	await t.frames(3)
	t.check("native_decline_keeps_bouquet_and_friendship",EconomyManager.count_item(&"hjertebuket")==2 and FLOW.state("gardener_hoppe")==0)
	picker._give()
	await t.frames(3)
	dialogs = picker.get_children().filter(func(n):return n is UiConfirm)
	if not dialogs.is_empty():dialogs[0]._finish(true)
	await t.until(func():return ui.is_open(),3.0)
	ui._advance()
	await t.frames(2)
	await t.capture("relationship_heartfriend_scene")
	t.check("native_short_authored_scene",ui.is_open() and ui._lines.size()==2 and str(ui._lines[0].get("text_key",""))=="PARTNER_HOPPE_1" and FLOW.state("gardener_hoppe")==1)
	await _finish_dialogue(t)
	_native_date(9,10)
	SocialManager.debug_set_hearts("gardener_hoppe",10)
	HomeManager.set_tier(3)
	picker.open_for("gardener_hoppe")
	await t.frames(3)
	t.check("native_promise_acorn_selectable",await _select_gift(t,picker,"loefteagern"))
	await t.capture("relationship_acorn_picker")
	picker._give()
	await t.frames(3)
	dialogs = picker.get_children().filter(func(n):return n is UiConfirm)
	if not dialogs.is_empty():dialogs[0]._finish(true)
	await _finish_dialogue(t)
	var wedding := int(SocialManager.partner().get("wedding",0))
	t.check("native_proposal_announced",wedding>9 and FLOW.state("gardener_hoppe")==2)
	_native_date(wedding,12)
	SocialManager.flush()
	await world.travel(&"hyggebyen",&"default")
	var director := SocialManager.get_node("EventDirector") as SocialEventDirector
	var started: bool = await t.until(func():return director.runner.active=="ev_bryllupsfesten_open" and ui.is_open(),10.0)
	t.check("native_wedding_scene_starts_on_arrival",started)
	if started:
		ui._advance()
		await t.frames(3)
		await t.capture("relationship_wedding_scene")
		var finished: bool = await t.until(func() -> bool:
			if ui.is_open():ui._advance()
			return director.runner.active=="" and not GameManager.is_modal_open(),15.0)
		t.check("native_wedding_scene_finishes_married",finished and FLOW.state("gardener_hoppe")==3)
	_native_date(wedding+1,19)
	EventBus.time_of_day_changed.emit(19,0)
	await world.travel(&"home",&"default")
	await t.frames(6)
	await t.seconds(5.0)
	var room := world.area.get_node("HomeRoom") as HomeRoom
	var visits := room.get_node("FarmVisits") as FarmVisits
	t.check("native_partner_physically_home",visits.actors.has("gardener_hoppe") and SocialManager.partner_in_home()=="gardener_hoppe")
	await t.capture("relationship_partner_home")
	await world.travel(&"farm",&"default")
	HomeManager.set_tier(8)
	for npc in ["baker_maja","merchant_pip","postman_pip","carpenter_brumme","beekeeper_birk","appraiser_fru_ugle","bathkeeper_sofus"]:SocialManager.debug_set_hearts(npc,4)
	EconomyManager.add_gold(500)
	var party := HomeManager.hold_festival()
	t.check("native_real_house_party_names_friends",bool(party.get("ok",false)) and party.guests.size()==6)
	await world.travel(&"home",&"default")
	await t.seconds(5.0)
	room = world.area.get_node("HomeRoom") as HomeRoom
	visits = room.get_node("FarmVisits") as FarmVisits
	t.check("native_party_guests_present_without_replacing_jobs",visits.actors.size()>=3 and visits.actors.keys().all(func(npc):return str(Routines.where_is(str(npc),Routines.now_ctx()).get("act",""))=="home"))
	var points: Array = visits.actors.values().map(func(actor):return actor.global_position)
	var stable: Array = visits.actors.values().map(func(actor):return [weakref(actor),actor.global_position])
	await t.seconds(5.0)
	t.check("native_home_guests_keep_assigned_positions",stable.all(func(row):return row[0].get_ref()!=null and row[0].get_ref().global_position.distance_to(row[1])<2.0))
	var spaced := true
	for i in points.size():
		for j in range(i+1,points.size()):spaced = spaced and Iso.to_ground(points[i]-points[j]).length()>=120.0
	t.check("native_home_guests_have_space",spaced)
	await t.capture("relationship_house_party")
	await t.go_menu()

func _native_date(day: int,hour: int) -> void:
	_date(day,hour)
	EventBus.day_started.emit(GameManager.day,GameManager.season)
	EventBus.time_of_day_changed.emit(hour,0)

func _festival_jobs(t) -> void:
	var errors: Array[String] = []
	var ids: Array = SocialData.festivals().keys()+[FLOW.WEDDING]
	for id in ids:
		var meta := LuaData.dict(SocialData.festival(str(id)).get("meta",{}))
		var day := int(SocialManager.partner().wedding) if id==FLOW.WEDDING else CalendarUtil.total_day(int(meta.day),StringName(str(meta.season)),1)
		var end := float(meta.to)
		for bid in Hours.registry():
			var b := Hours.building(str(bid))
			var npc := str(b.get("keeper",""))
			if not b.has("hours") or CalendarUtil.weekday_of(day) in Hours.closed_days(b) or not SocialManager.can_befriend(npc):continue
			var hours := Hours.hours_on(b,CalendarUtil.weekday_of(day))
			if float(hours[1])<=end:continue
			var ctx := Routines.make_ctx(CalendarUtil.weekday_of(day),maxf(end,float(hours[0])),"klart",{"total_day":day,"hearts":{npc:10},"done":{"lost_cat":true},"fest":{"id":str(id),"from":GameManager.game_hour(float(meta.from)),"to":GameManager.game_hour(end)},"override_fn":Callable(SocialManager,"override_for")})
			var where := Routines.where_is(npc,ctx)
			if str(where.get("place",""))!=str(b.get("post","")) or str(where.state) not in ["stay","inside"]:errors.append(str(id)+" "+npc+" "+str(ctx.hour)+" "+str(where))
	t.check("festival_keepers_physically_back_for_evening_work",errors.is_empty(),str(errors))
	var original := {"day":GameManager.day,"year":GameManager.year,"season":GameManager.season,"hour":GameManager.hour,"minute":GameManager.minute}
	var day := int(SocialManager.partner().wedding)
	var gaps: Array[String] = []
	for minute in range(6*60,26*60,15):
		_date(day,minute/60,minute%60)
		var ctx := Routines.now_ctx()
		ctx["fest_closed_fn"] = Callable(SocialManager,"shop_closed_by_festival")
		for bid in Hours.registry():
			var b := Hours.building(str(bid))
			var npc := str(b.get("keeper",""))
			if not b.has("hours") or not SocialManager.can_befriend(npc) or SocialManager.override_for(npc,day).is_empty() or not Hours.is_open(str(bid),ctx):continue
			var where := Routines.where_is(npc,ctx)
			if str(where.get("place",""))!=str(b.get("post","")) or str(where.state) not in ["stay","inside"]:gaps.append(str(bid)+" "+str(minute)+" "+str(where))
	t.check("wedding_shops_never_open_while_keeper_is_travelling",gaps.is_empty(),str(gaps))
	GameManager.day = original.day
	GameManager.year = original.year
	GameManager.season = original.season
	GameManager.hour = original.hour
	GameManager.minute = original.minute

