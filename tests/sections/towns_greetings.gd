extends RefCounted
const SECTION := "towns_greetings"
const SHOPS := ["seed_shop","bakery","smithy","animal_store","magic_store","furniture_shop","tailor_shop","builder_yard","flea_market","timber_yard","natteblik_maps","lantern_house"]
func run(t) -> void:
	await t.go_menu()
	t.new_game()
	for shop_id in SHOPS:
		var shop := LuaRuntime.get_shop(shop_id)
		t.check(shop_id+"_exists",not shop.is_empty())
		for band in 4:
			SocialManager.debug_set_hearts(str(shop.keeper),[0,2,5,8][band])
			var line := SocialTalk.greeting_for_shop(shop_id)
			var key: String = "KEEP_"+shop_id.to_upper()+"_GREET_H%d_1" % band
			t.check(shop_id+"_band_"+str(band),str(line.get("text_key","")) == key and TranslationServer.translate(key) != key)
		for suffix in ["SAMPLE_1"]:
			var key: String = "KEEP_"+shop_id.to_upper()+"_"+suffix
			t.check(shop_id+"_sample",TranslationServer.translate(key) != key)
	for key in ["KEEP_ANY_THANKS","KEEP_ANY_CANNOT_PAY","KEEP_ANY_SOLD_OUT","KEEP_ANY_FAREWELL_1","KEEP_ANY_FAREWELL_2","KEEP_ANY_FAREWELL_3"]:
		t.check(key.to_lower(),TranslationServer.translate(key) != key)
	var old := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	t.check("english_complete",SHOPS.all(func(shop):return TranslationServer.translate("KEEP_"+shop.to_upper()+"_GREET_H0_1") != "KEEP_"+shop.to_upper()+"_GREET_H0_1"))
	TranslationServer.set_locale(old)
	t.new_game()
func run_windowed(t) -> void:
	await t.start_world()
	GameManager.set_config_override("time.minutes_per_real_second",0)
	GameManager.day = 2
	GameManager.hour = 10
	GameManager.minute = 0
	EventBus.day_started.emit(2,&"foraar")
	EventBus.time_of_day_changed.emit(10,0)
	await t.world().travel(&"int_bageriet",&"default")
	ShopSystem.open_shop(&"bakery")
	await t.frames(5)
	var panel: Node = t.world().game_ui.get_screen(&"shop_ui")
	t.check("native_keeper_greeting",panel.is_open() and panel.keeper_speech.text == TranslationServer.translate("KEEP_BAKERY_GREET_H0_1"))
	await t.capture("bakery_greeting")
	panel.close()
	await t.go_menu()
