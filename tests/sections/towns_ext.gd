extends RefCounted
const SECTION := "towns_ext"
const TIMEOUT_S := 180.0
const ROOMS := ["torvekroen","fekongens_hus","hoppe_hut","brummes_hus","vagthytten","kikis_hytte","musikstuen","hyldeblomsts_hus","pippins_hus","birks_bistade"]
const TWINS := {"rasmus":"rasmus","lamplighter_kiki":"kiki","bertil":"bertil","bodil":"bodil"}
func run(t) -> void:
	await t.go_menu()
	await t.start_world()
	GameManager.set_config_override("time.minutes_per_real_second",0)
	GameManager.set_config_override("towns.curfew.enabled",false)
	RouteTable.load_table()
	Routines.clear_cache()
	for room in ROOMS:
		var spec := InteriorRoom.load_spec("int_"+room)
		var building := Hours.building(room)
		t.check(room+"_installed",not spec.is_empty() and str(building.get("interior","")) == "int_"+room and RouteTable.has_anchor("int_"+room+".door"))
		await t.world().travel(StringName("int_"+room),&"default")
		await t.frames(4)
		t.check(room+"_builds_with_painted_art",str(t.world().area.map.id) == "int_"+room and t.world().area.map.errors.is_empty() and InteriorRoom.stats.get("placeholders",1) == 0 and InteriorRoom.stats.get("stand_ins",1) == 0,str(InteriorRoom.stats))
		var owner := str(building.get("owner",""))
		if owner != "":
			var door := Door2D.new()
			door.building_id = room
			door.owner_npc = owner
			door.ctx_override = Routines.make_ctx(0,6.5,"klart",{"total_day":120,"hero":"","hearts":{owner:0}})
			t.check(room+"_friend_gate",not door.is_open() and door.last_reason == "stranger")
			door.ctx_override.hearts[owner] = 1
			t.check(room+"_awake_owner_opens",door.is_open(),door.last_reason)
			door.free()
	for npc in TWINS:
		var ctx := Routines.make_ctx(2,14.0,"klart",{"total_day":120,"hero":TWINS[npc]})
		t.check("hero_twin_"+npc,Routines.where_is(npc,ctx).state == "absent")
		ctx.hero = ""
		t.check("meet_"+npc,Routines.where_is(npc,ctx).state != "absent")
	var looks := {}
	for npc in SocialData.npcs(): looks[npc] = str(SocialData.npc_row(npc).get("visual",npc))
	for rule in [["feasible",TownsValidate.routines_feasible],["places",TownsValidate.places_exist],["hours",func():return TownsValidate.hours_consistency(LuaRuntime.get_shops().keys())],["keepers",TownsValidate.keepers_cover_hours],["capacity",TownsValidate.post_capacity],["looks",func():return TownsValidate.visual_budget(looks)],["visits",TownsValidate.visits_inside_hours],["short_visits",TownsValidate.no_short_visits],["wrap",TownsValidate.day_wrap]]:
		var errors: Array = rule[1].call()
		t.check("full_roster_"+str(rule[0]),errors.is_empty(),str(errors.slice(0,12)))
	t.check("content_reproducible",int(t.run_tool(t.python(), [ProjectSettings.globalize_path("res://tools/towns/authoring/build_ext_content.py"),"--check"]).code) == 0)
	GameManager.season = &"foraar"
	GameManager.day = 5
	GameManager.hour = 20
	GameManager.minute = 0
	EventBus.day_started.emit(5,&"foraar")
	EventBus.time_of_day_changed.emit(20,0)
	await t.frames(3)
	await t.until(func():return not t.world().traveling and not GameManager.is_modal_open(),5.0)
	await t.world().travel(&"int_torvekroen",&"default")
	await t.frames(10)
	var keeper := NpcDirector.node_of("innkeeper_kvak",t.world().area)
	var population: Dictionary = t.world().area.get_node("TownDirector").live
	var entry: Vector2 = t.world().area.get_spawn("default")
	t.check("inn_entry_kept_clear",population.values().all(func(actor):return Iso.ground_dist(actor.global_position,entry) >= 100.0))
	t.check("inn_live_keeper",keeper != null,str(Routines.where_is("innkeeper_kvak",Routines.now_ctx()))+" area="+str(t.world().area.map.id)+" modal="+str(GameManager.top_modal())+" traveling="+str(t.world().traveling)+" active="+str(NpcDirector._active))
	EventBus.game_event.emit(&"open_inn_menu",{"npc":"innkeeper_kvak","building":"torvekroen"})
	await t.frames(3)
	var ui: Node = t.first(&"dialogue_ui")
	t.check("inn_counter_talks",ui.is_open())
	ui.close()
	await t.go_menu()
func run_windowed(t) -> void:
	await t.start_world()
	GameManager.set_config_override("time.minutes_per_real_second",0)
	GameManager.set_config_override("towns.curfew.enabled",false)
	for row in [["torvekroen",5,20,0],["fekongens_hus",3,11,0],["hoppe_hut",1,6,36],["kikis_hytte",1,7,0],["pippins_hus",2,8,0]]:
		# Change the fixture clock outside rooms: closing a public room normally
		# starts an automatic exit, which must finish before another travel.
		await t.until(func():return not t.world().traveling,5.0)
		await t.world().travel(&"farm",&"default")
		await t.until(func():return not t.world().traveling and t.world().area.map.id == &"farm",5.0)
		GameManager.day = int(row[1])
		GameManager.hour = int(row[2])
		GameManager.minute = int(row[3])
		EventBus.day_started.emit(GameManager.day,GameManager.season)
		EventBus.time_of_day_changed.emit(GameManager.hour,GameManager.minute)
		await t.frames(3)
		var id := "int_"+str(row[0])
		await t.world().travel(StringName(id),&"default")
		var arrived: bool = await t.until(func():return not t.world().traveling and str(t.world().area.map.id) == id,8.0)
		t.check(str(row[0])+"_native_arrived",arrived,str(t.world().area.map.id))
		if not arrived: continue
		await t.frames(10)
		t.world().game_ui.get_screen(&"hud").toasts.clear()
		await t.capture(str(row[0]))
		var building := Hours.building(str(row[0]))
		var owner := str(building.get("keeper",building.get("owner","")))
		t.check(str(row[0])+"_native_owner",NpcDirector.node_of(owner,t.world().area) != null)
		if str(row[0]) == "torvekroen":
			var live: Dictionary = t.world().area.get_node("TownDirector").live
			t.check("inn_friday_crowd",live.size() >= 10 and live.size() <= 12,str(live.keys()))
	await t.go_menu()
