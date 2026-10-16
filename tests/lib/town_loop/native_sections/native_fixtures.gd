extends RefCounted
const SECTION := "native_fixtures"
const TIMEOUT_S := 90.0
func run_windowed(t) -> void:
	var suite := preload("res://tests/sections/town_loop.gd").new()
	suite.native_mode=true
	var helper := preload("res://tests/lib/town_loop/native.gd").new()
	await helper._crowd(t,suite,true)
	var city: Image = await t.capture("city_hud")
	var city_hud: Control = TownProbe.screens(t).get_screen(&"hud")
	for row in [["date","%DatePanel"],["chip","%MoneyChip"],["hotbar","%HotbarTray"]]:
		city.get_region(Rect2i(city_hud.get_node(row[1]).get_global_rect())).save_png(t.out_dir.path_join("hud_v2_"+row[0]+".png"))
	Routines.override_registry={}
	Routines.clear_cache()
	await t.clear_scene()
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second",0.0)
	gm.set_config_override("towns.curfew.enabled",false)
	await LoopClock.at(t,1,10)
	await t.world().travel(&"int_froebutikken",&"default")
	t.check("prefetched_room_build",t.world().area.build_ms<=60,str(t.world().area.build_ms))
	var shops := preload("res://tests/lib/town_loop/shops.gd").new()
	shops.suite=suite
	await shops.host(t,"talk")
	await suite._finish_dialogue(t)
	await shops.host(t,"shop")
	await suite.shot(t,"S08_shop_panel")
	for id in ["shop_backdrop","S08_shop_panel"]:
		suite.native_shots[id].save_png(t.out_dir.path_join("town_loop_"+id+".png"))
	await t.clear_scene()
	await helper._guide_fixtures(t,suite)
	RenderingServer.render_loop_enabled=false
	var image: Image = await t.capture("forced_static_frame")
	RenderingServer.render_loop_enabled=true
	t.check("capture_forces_a_frame_when_render_loop_is_idle",image!=null and not image.is_empty())
