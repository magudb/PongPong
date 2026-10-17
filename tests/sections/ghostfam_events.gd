extends RefCounted
const SECTION := "ghostfam_events"
const TIMEOUT_S := 300.0
const FAMILY := ["ghostfam_dyne","ghostfam_gnist","ghostfam_silke","ghostfam_blund"]
var world: WorldRoot2D
var director: SocialEventDirector
var ui: Node
func _start(t,hero := "animal") -> void:
	await t.start_world(hero)
	world = t.world()
	director = SocialManager.get_node("EventDirector")
	ui = t.first(&"dialogue_ui")
	GameManager.set_config_override("time.minutes_per_real_second",0)
	GameManager.set_config_override("towns.curfew.enabled",false)
	for npc in FAMILY: SocialManager.debug_set_hearts(npc,10)
func run(t) -> void:
	await _start(t)
	var ids := SocialData.events().keys().filter(func(id):return str(id).begins_with("ev_ghostfam_"))
	ids.sort_custom(func(a,b):
		var ah := int(SocialData.event(a).meta.hearts)
		var bh := int(SocialData.event(b).meta.hearts)
		return ah < bh if ah != bh else str(a)<str(b))
	t.check("eleven_registered",ids.size() == 11)
	for id in ids:
		if id == "ev_ghostfam_kin_welcome": continue
		var data := SocialData.event(id)
		var meta := LuaData.dict(data.meta)
		var staged: bool = await _stage(t,meta)
		t.check(str(id)+"_real_stage",staged,str(Routines.where_is(str(meta.npc),Routines.now_ctx())))
		if not staged: return
		t.check(str(id)+"_ready",id in SocialManager.events_ready(str(meta.npc)))
		for step in LuaData.arr(data.steps):
			if str(step.act)=="camera" and str(step.get("focus","")).begins_with("mark:"):
				t.check(str(id)+"_mark",NpcDirector.post_ground(str(meta.area),StringName(str(step.focus).trim_prefix("mark:"))) != Vector2.INF)
		var oil_before := EconomyManager.count_item(&"lantern_oil")
		var missing := director.runner.skipped_directives
		t.check(str(id)+"_requested",director.request(id))
		await _finish(t)
		t.check(str(id)+"_finished_with_actors",SocialManager.event_seen(id) and director.runner.skipped_directives==missing and not GameManager.is_modal_open())
		t.check(str(id)+"_once",not director.request(id))
		if id=="ev_ghostfam_gnist_h4":t.check("door_lantern_oil",EconomyManager.count_item(&"lantern_oil")==oil_before+3)
	t.check("seat_for_friend",GameManager.get_flag(&"natlys_seat",false))
	t.check("save_all_ordinary_scenes",SaveManager.save_game(3) and SaveManager.load_game(3))
	t.check("ten_saved",ids.filter(func(id):return id!="ev_ghostfam_kin_welcome").all(func(id):return SocialManager.event_seen(id)))
	await _start(t,"ghost")
	GameManager.set_flag(&"ghostfam_kin_dyne",true)
	GameManager.set_flag(&"ghostfam_kin_blund",true)
	var boo := SocialData.event("ev_ghostfam_blund_h8")
	var kin_steps := director.runner.eligible_steps(boo)
	t.check("cousins_branch_only",kin_steps.any(func(s):return str(s.get("when",""))=="flag:ghostfam_kin_blund") and not kin_steps.any(func(s):return str(s.get("when",""))=="!flag:ghostfam_kin_blund"))
	GameManager.set_flag(&"ghostfam_kin_blund",false)
	var friend_steps := director.runner.eligible_steps(boo)
	t.check("friends_branch_only",friend_steps.any(func(s):return str(s.get("when",""))=="!flag:ghostfam_kin_blund") and not friend_steps.any(func(s):return str(s.get("when",""))=="flag:ghostfam_kin_blund"))
	var welcome := SocialData.event("ev_ghostfam_kin_welcome")
	t.check("welcome_real_family",await _stage(t,welcome.meta))
	t.check("welcome_ready_for_kin","ev_ghostfam_kin_welcome" in SocialManager.events_ready("ghostfam_dyne"))
	t.check("welcome_request",director.request("ev_ghostfam_kin_welcome"))
	await _finish(t)
	t.check("cousin_kept_seat",SocialManager.event_seen("ev_ghostfam_kin_welcome") and GameManager.get_flag(&"natlys_seat",false))
	SocialManager.mark_event_seen("ev_ghostfam_dyne_h8")
	GameManager.set_flag(&"natlys_seat",false)
	t.check("friend_seat_scene_not_repeated_for_kin",not "ev_ghostfam_dyne_h10" in SocialManager.events_ready("ghostfam_dyne"))
	var greetings := 0
	for festival in SocialData.festivals():
		for npc in FAMILY:
			var key: String = "FEST_"+str(festival).to_upper()+"_"+npc.to_upper()+"_1"
			t.check(key,TranslationServer.translate(key)!=key)
			greetings += 1
	t.check("thirty_six_festival_greetings",greetings==36)
	t.check("authored_source_reproducible",int(t.run_tool("python3",[ProjectSettings.globalize_path("res://tools/social/content/build_natlys.py"),"--check"]).code)==0)
	await t.go_menu()
func _stage(t,meta: Dictionary) -> bool:
	await world.travel(&"farm",&"default")
	var condition := "&".join(Array(str(meta.when).split("&")).filter(func(term):return not str(term).begins_with("at:")))
	var actors: Array[String] = [str(meta.npc)]
	for term in str(meta.when).split("&"):
		if term.begins_with("at:"): actors.append(term.trim_prefix("at:"))
	var found := false
	var first_day := maxi(8,GameManager.total_day()+1)
	for day in range(first_day,first_day+29):
		Fresh.jump_to_total_day(day)
		for quarter in range(24,104):
			GameManager.hour = floori(float(quarter)/4.0)
			GameManager.minute = (quarter%4)*15
			if SocialManager.festival_today()!=&"" or not SocialManager.eval_when(condition): continue
			var ctx := Routines.now_ctx()
			ctx.weather = "klart"
			found = actors.all(func(npc):
				var at := Routines.where_is(npc,ctx)
				return str(at.get("area",""))==str(meta.area) and str(at.state)=="stay" and str(at.act) not in ["inside","sleep"])
			if found:break
		if found:break
	if not found:return false
	TimeManager.set_weather(&"klart")
	EventBus.day_started.emit(GameManager.day,GameManager.season)
	EventBus.time_of_day_changed.emit(GameManager.hour,GameManager.minute)
	SocialManager.flush()
	await world.travel(StringName(str(meta.area)),&"default")
	await t.physics(4)
	return actors.all(func(npc):return NpcDirector.node_of(npc,world.area)!=null)
func _finish(t) -> void:
	var done: bool = await t.until(func() -> bool:
		if ui.is_open() and GameManager.top_modal()==&"dialogue":
			if ui._wants_focus():ui._pick(ui._choices[0])
			else:ui._advance()
		return director.runner.active=="" and director.queue.is_empty(),10.0)
	t.check("scene_finished",done)
func run_windowed(t) -> void:
	await _start(t,"ghost")
	GameManager.set_flag(&"ghostfam_kin_dyne",true)
	var data := SocialData.event("ev_ghostfam_kin_welcome")
	t.check("native_family_stage",await _stage(t,data.meta))
	var actor := NpcDirector.node_of("ghostfam_dyne",world.area) as Node2D
	world.player.global_position = actor.global_position+Vector2(100,45)
	director.request("ev_ghostfam_kin_welcome")
	await t.until(func():return ui.is_open(),5.0)
	await t.until(func():return not ui._typing,8.0)
	await t.frames(2)
	await t.capture("welcome")
	await _finish(t)
	t.check("native_welcome_complete",GameManager.get_flag(&"natlys_seat",false) and not GameManager.is_modal_open())
	await t.go_menu()
