extends RefCounted
const SECTION := "home_services"
const TIMEOUT_S := 120.0
func _start(t) -> void:
	await t.start_world()
	GameManager.set_config_override("time.minutes_per_real_second",0)
	GameManager.set_config_override("towns.curfew.enabled",false)
func run(t) -> void:
	await _start(t)
	await _forecast(t)
	HomeManager.set_tier(1)
	EconomyManager.add_item(&"flour",20,true)
	EconomyManager.add_item(&"honey",20,true)
	t.check("oven_recipe_locked_at_one",not CraftingSystem.can_craft("home_cookies").ok and not CraftingSystem.craft("home_cookies"))
	HomeManager.set_tier(2)
	var flour := EconomyManager.count_item(&"flour")
	var honey := EconomyManager.count_item(&"honey")
	var cookies := EconomyManager.count_item(&"cookie")
	t.check("oven_recipe_cooks",CraftingSystem.craft("home_cookies") and EconomyManager.count_item(&"flour")==flour-1 and EconomyManager.count_item(&"honey")==honey-1 and EconomyManager.count_item(&"cookie") in [cookies+2,cookies+3])
	await t.world().travel(&"home",&"default")
	var ui: Control = t.world().game_ui.get_screen(&"home_amenities")
	EventBus.game_event.emit(&"open_home_amenities",{})
	await t.frames(3)
	t.check("kitchen_screen_opens_at_home",ui.is_open() and ui.recipes.size()>=2)
	t.check("forecast_locked_until_tower",ui.forecast.text==TranslationServer.translate("HOME_AMENITIES_FORECAST_LOCKED"))
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	t.check("kitchen_escape_closes",not ui.is_open() and not GameManager.is_modal_open())
	await t.world().travel(&"farm",&"from_home")
	HomeManager.set_tier(10)
	GameManager.hour = 19
	GameManager.day = 2
	await t.world().travel(&"home",&"default")
	ui.open()
	await t.frames(3)
	t.check("all_eight_unlocks_real",HomeManager.unlock_rows().all(func(row):return row.status=="real"))
	t.check("tower_forecast_visible",ui.forecast.text.contains(TimeManager.weather_name(TimeManager.forecast_weather())))
	ui._invite()
	await t.frames(3)
	t.check("royal_consent_default_cancel",GameManager.top_modal()==&"confirm")
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	t.check("royal_cancel_has_no_effect",not SocialManager.event_seen(HomeServices.ROYAL) and ui.is_open())
	ui.close()
	await t.frames(3)
	GameManager.hour = 18
	t.check("royal_respects_evening_window",HomeServices.royal_reason()=="hours")
	GameManager.hour = 19
	t.check("royal_available_at_palace",HomeServices.royal_reason()=="",HomeServices.royal_reason())
	var done := [false]
	var result := [false]
	var play := func() -> void:
		result[0] = await HomeServices.invite_king()
		done[0] = true
	play.call()
	var dialogue: Control = t.world().game_ui.get_screen(&"dialogue_ui")
	var deadline := Time.get_ticks_msec()+8000
	var texts: Array[String] = []
	while not done[0] and Time.get_ticks_msec()<deadline:
		if dialogue.is_open():
			for line in dialogue._lines:
				if not texts.has(str(line.text_key)):texts.append(str(line.text_key))
			t.tap(&"interact")
		await t.frames(2)
	t.check("royal_scene_finishes",done[0] and result[0] and texts.size()==3)
	await t.frames(3)
	t.check("royal_guest_disposed",t.world().area.find_children("RoyalHomeGuest","",true,false).is_empty())
	t.check("royal_once_saved",SocialManager.event_seen(HomeServices.ROYAL) and SaveManager.save_game(3) and SaveManager.load_game(3) and SocialManager.event_seen(HomeServices.ROYAL))
	t.check("royal_cannot_repeat",HomeServices.royal_reason()=="done")
	await t.go_menu()
func _forecast(t) -> void:
	var old_game := GameManager.to_dict()
	var old_time := TimeManager.to_dict()
	var old_rolls := TimeManager.weather_rolls
	for season in GameManager.seasons():
		GameManager.season = StringName(str(season))
		GameManager.day = GameManager.days_per_season()
		GameManager.year = 2
		var forecast := TimeManager.forecast_weather()
		var future := CalendarUtil.date_of(GameManager.total_day()+1)
		t.check("forecast_stable_"+str(season),forecast==TimeManager.forecast_weather() and TimeManager.weather_rolls==old_rolls)
		var saved: Dictionary = JSON.parse_string(JSON.stringify(TimeManager.to_dict()))
		TimeManager.from_dict(saved)
		t.check("forecast_json_roundtrip_"+str(season),TimeManager.forecast_weather()==forecast)
		GameManager.day = int(future.day)
		GameManager.season = StringName(str(future.season))
		GameManager.year = int(future.year)
		TimeManager.roll_weather_for_day()
		t.check("forecast_matches_actual_roll_"+str(season),TimeManager.weather==forecast)
		if future.season!=&"vinter":t.check("no_out_of_season_snow_"+str(season),forecast!=&"sne")
		old_rolls = TimeManager.weather_rolls
	GameManager.from_dict(old_game)
	TimeManager.from_dict(old_time)
func run_windowed(t) -> void:
	await _start(t)
	HomeManager.set_tier(10)
	GameManager.hour = 19
	GameManager.day = 2
	EconomyManager.add_item(&"flour",4,true)
	EconomyManager.add_item(&"honey",4,true)
	await t.world().travel(&"home",&"default")
	var ui: Control = t.world().game_ui.get_screen(&"home_amenities")
	ui.open()
	await t.frames(5)
	await t.capture("kitchen_forecast_and_royal_visit")
	t.check("native_home_menu",ui.is_open() and not ui.royal_button.disabled)
	ui.close()
	await t.frames(3)
	var done := [false]
	var play := func() -> void:
		await HomeServices.invite_king()
		done[0] = true
	play.call()
	var dialogue: Control = t.world().game_ui.get_screen(&"dialogue_ui")
	await t.until(func():return dialogue.is_open(),4.0)
	await t.seconds(0.5)
	t.tap(&"interact")
	await t.frames(3)
	await t.capture("royal_evening_visit")
	t.check("native_king_guest",not t.world().area.find_children("RoyalHomeGuest","",true,false).is_empty())
	var deadline := Time.get_ticks_msec()+8000
	while not done[0] and Time.get_ticks_msec()<deadline:
		if dialogue.is_open():t.tap(&"interact")
		await t.frames(2)
	t.check("native_royal_scene_complete",done[0] and SocialManager.event_seen(HomeServices.ROYAL))
	await t.go_menu()
