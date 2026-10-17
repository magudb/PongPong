extends RefCounted
const SECTION := "social_heart_content"
const TIMEOUT_S := 300.0
const CAST := ["gardener_hoppe","carpenter_brumme","baker_maja","merchant_pip","mayor_lyra","postman_pip","bathkeeper_sofus","beekeeper_birk","smith_thorin","farmer_rosa"]
var world: WorldRoot2D
var director: SocialEventDirector
var ui: Node
class Present extends Node:
	func is_present(_npc: String) -> bool: return true
func _start(t) -> void:
	await t.start_world()
	world = t.world()
	director = SocialManager.get_node("EventDirector")
	ui = t.first(&"dialogue_ui")
	GameManager.set_config_override("time.minutes_per_real_second",0)
	GameManager.set_config_override("towns.curfew.enabled",false)
func run(t) -> void:
	await _start(t)
	GameManager.hour = 24
	GameManager.minute = 29
	EventBus.time_of_day_changed.emit(24,29)
	t.check("half_hour_window_before_boundary",not SocialManager.eval_when("hour:24.5-25"))
	GameManager.minute = 30
	EventBus.time_of_day_changed.emit(24,30)
	t.check("half_hour_window_at_boundary",SocialManager.eval_when("hour:24.5-25"))
	GameManager.hour = 25
	GameManager.minute = 50
	EventBus.time_of_day_changed.emit(25,50)
	var day_before := GameManager.total_day()
	var clock_scene := {"meta":{"trigger":"automatic"},"steps":[{"act":"time","minutes":20},{"act":"end"}]}
	t.check("overnight_time_directive",await director.runner.play("test_overnight_clock",clock_scene) and GameManager.hour == 25 and GameManager.minute == 59 and GameManager.total_day() == day_before)
	var all_ids: Array[String] = []
	for npc in CAST:
		var seen_before := ""
		for hearts in [4,6,8,10]:
			var id: String = "ev_"+str(npc)+"_h"+str(hearts)
			all_ids.append(id)
			var data := SocialData.event(id)
			var meta := LuaData.dict(data.get("meta",{}))
			t.check(id+"_authored",not data.is_empty() and int(meta.get("hearts",0)) == hearts and str(meta.get("after","")) == seen_before)
			t.check(id+"_bounded_rewards",int(LuaData.dict(data.get("rewards",{})).get("points",0)) == 40 and LuaData.arr(data.get("steps",[])).filter(func(s):return str(s.act) == "give").all(func(s):return str(ItemKinds.rarity_of(str(s.item))) in ["normal","uncommon"]))
			SocialManager.debug_set_hearts(npc,10)
			var ready: bool = await _stage(t,npc,meta)
			t.check(id+"_real_stage",ready and NpcDirector.node_of(npc,world.area) != null,str(Routines.where_is(npc,Routines.now_ctx())))
			if not ready: return
			for step in LuaData.arr(data.steps):
				if str(step.act) == "camera" and str(step.get("focus","")).begins_with("mark:"):
					t.check(id+"_real_mark",NpcDirector.post_ground(str(meta.area),StringName(str(step.focus).trim_prefix("mark:"))) != Vector2.INF)
			var available := SocialManager.events_ready(npc)
			t.check(id+"_only_next_scene",available == [id],str(available))
			var gift: Dictionary = LuaData.arr(data.steps).filter(func(step):return str(step.act) == "give")[0]
			var before := EconomyManager.count_item(StringName(str(gift.item)))
			var skipped := director.runner.skipped_directives
			t.check(id+"_request",director.request(id))
			await _finish(t)
			t.check(id+"_ends_with_real_actors",SocialManager.event_seen(id) and director.runner.skipped_directives == skipped and not world.player._event_active and GameManager.top_modal() == &"",str([director.runner.active,director.queue,director._starting,GameManager.current_phase,GameManager.top_modal(),ui.is_open()]))
			if not SocialManager.event_seen(id):
				director.reset()
				await t.go_menu()
				return
			t.check(id+"_gift_once",EconomyManager.count_item(StringName(str(gift.item))) == before+int(gift.amount) and not director.request(id))
			EconomyManager.remove_item(StringName(str(gift.item)),int(gift.amount))
			t.check(id+"_one_scene_per_day",SocialManager.events_ready(npc).is_empty())
			seen_before = id
	t.check("forty_scenes_registered",all_ids.size() == 40 and all_ids.all(func(id):return not SocialData.event(id).is_empty()))
	t.check("save_and_reload_all_scenes",SaveManager.save_game(3) and SaveManager.load_game(3))
	t.check("all_seen_survive_save",all_ids.all(func(id):return SocialManager.event_seen(id)))
	await world.travel(&"farm",&"default")
	SocialManager.reset()
	SocialManager.debug_set_hearts("gardener_hoppe",10)
	var fake := Present.new()
	Svc.override("NpcDirector",fake)
	t.check("area_guard_even_if_presence_reports_true",SocialManager.events_ready("gardener_hoppe").is_empty())
	Svc.clear_overrides()
	fake.free()
	t.check("source_reproducible",int(t.run_tool("python3",[ProjectSettings.globalize_path("res://tools/social/content/build_hearts.py"),"--check"]).code) == 0)
	director.reset()
	await t.go_menu()
func _stage(t,npc: String,meta: Dictionary) -> bool:
	await t.until(func():return not world.traveling and not GameManager.is_modal_open(),5.0)
	await world.travel(&"farm",&"default")
	var found := false
	var first_day := maxi(8,GameManager.total_day()+1)
	for total_day in range(first_day,first_day+15):
		var date := CalendarUtil.date_of(total_day)
		GameManager.day = int(date.day)
		GameManager.season = StringName(str(date.season))
		GameManager.year = int(date.year)
		for hour in range(8,18):
			GameManager.hour = hour
			GameManager.minute = 0
			if SocialManager.festival_today() != &"": continue
			var ctx := Routines.now_ctx()
			ctx.weather = "klart"
			var where := Routines.where_is(npc,ctx)
			if str(where.get("area","")) == str(meta.area) and str(where.state) == "stay" and str(where.act) not in ["sleep","inside"]:
				found = true
				break
		if found: break
	if not found: return false
	EventBus.day_started.emit(GameManager.day,GameManager.season)
	EventBus.time_of_day_changed.emit(GameManager.hour,0)
	TimeManager.set_weather(&"klart")
	SocialManager.flush()
	await world.travel(StringName(str(meta.area)),&"default")
	await t.frames(8)
	return str(world.area.map.id) == str(meta.area) and NpcDirector.node_of(npc,world.area) != null
func _finish(t) -> void:
	var ended: bool = await t.until(func() -> bool:
		if ui.is_open() and GameManager.top_modal() == &"dialogue":
			if ui._wants_focus(): ui._pick(ui._choices[0])
			else: ui._advance()
		return director.runner.active == "" and director.queue.is_empty(),10.0)
	t.check("authored_scene_finished",ended,str([director.runner.active,GameManager.top_modal()]))
func run_windowed(t) -> void:
	await _start(t)
	SocialManager.debug_set_hearts("gardener_hoppe",4)
	var id := "ev_gardener_hoppe_h4"
	var meta := LuaData.dict(SocialData.event(id).meta)
	t.check("native_stage",await _stage(t,"gardener_hoppe",meta))
	t.check("native_ready",id in SocialManager.events_ready("gardener_hoppe"))
	var actor := NpcDirector.node_of("gardener_hoppe",world.area) as Node2D
	world.player.global_position = actor.global_position+Vector2(110,55)
	director.request(id)
	await t.until(func():return ui.is_open(),5.0)
	# Let the real typewriter finish before reviewing the dialogue capture.
	await t.until(func():return not ui._typing,8.0)
	await t.frames(2)
	t.check("native_cinematic_hides_hud",not world.game_ui.get_screen(&"hud").visible and not world.game_ui.get_screen(&"forest_hud").visible)
	var city := CityBuilder.of(world.area)
	t.check("native_speaker_has_clear_stage",director.runner._stage_clear(city.stage.fade.targets,actor.global_position,actor.z_index))
	var doors := world.area.find_children("Door_*","Door2D",true,false)
	t.check("native_cinematic_hides_door_signs",doors.all(func(d):return d.sign_label==null or not d.sign_label.visible))
	await t.capture("hoppe_h4")
	await _finish(t)
	t.check("native_scene_finishes",SocialManager.event_seen(id) and not GameManager.is_modal_open() and world.game_ui.get_screen(&"hud").visible)
	await t.go_menu()
