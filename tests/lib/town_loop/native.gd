extends RefCounted
const Perf := preload("res://tests/perf_world.gd")
func run(t, suite) -> void:
	await _crowd(t, suite)
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/checkpoints/town/shots.json"))
	var missing: Array[String] = []
	for row in manifest.core:
		if not suite.native_shots.has(str(row)):missing.append(str(row))
	t.check("l15_shots_not_blank", missing.is_empty(), str(missing))
	t.check("l15_real_festival_capture",suite.native_shots.has("S14_festival_day_city"))
	await _guide_fixtures(t, suite)
	var python := ProjectSettings.globalize_path("res://tools/art/.venv/bin/python")
	var result: Dictionary = t.run_tool(python,[ProjectSettings.globalize_path("res://tools/town/check_native.py"),"--shots",t.out_dir])
	t.check("l15_guide_and_live_blur", result.code==0, result.output)

func _crowd(t, suite, keep_world := false) -> void:
	await t.start_world()
	# Include the maximum seven worn layers in the existing equipment budget.
	for id in ["hat_straw_plain","necklace_acorn","earrings_copper","shirt_linen_cream","pants_dungarees_blue","bracelet_string","shoes_boots_brown"]:
		if WardrobeManager.count_total(id) == 0:
			EconomyManager.add_item(StringName(id),1,true)
		WardrobeManager.equip(id)
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second",0.0)
	gm.set_config_override("towns.curfew.enabled",false)
	gm.hour=12
	gm.day=2
	# A returning visitor avoids unlock notifications in the steady crowd probe.
	gm.unlocked_zones.append(&"traetoppen")
	t.autoload("EventBus").day_started.emit(2,gm.season)
	t.autoload("EventBus").time_of_day_changed.emit(12,0)
	t.autoload("TimeManager").set_weather(&"klart")
	await t.world().travel(&"traetoppen", &"from_farm")
	var director := TownProbe.director(t)
	var registry := {}
	var looks := {}
	for id in Routines.npc_ids():
		var look := str(t.autoload("LuaRuntime").get_npc(id).get("visual", "fairy"))
		if looks.has(look):continue
		looks[look]=true
		registry[id]={"priority":50-registry.size(),"plans":{"day":{"blocks":[{"from":6.0,"at":"traetoppen.fest_torvet_gather_"+str(registry.size()+1),"act":"stand"}]}},"select":[{"plan":"day"}]}
		if registry.size()==16:break
	Routines.override_registry=registry
	Routines.clear_cache()
	director.resync()
	await t.physics(3)
	var safe := false
	for actor in director.live.values():
		if preload("res://tests/sections/ghostfam_data.gd").new()._stand_near(t,actor,75.0,[400.0,300.0,200.0,160.0,120.0]):
			safe=true
			break
	t.player().camera.reset_smoothing()
	t.check("l15_crowd_player_on_safe_deck",safe)
	for citizen in director.live.values():
		await citizen.visual.warm_clips(["idle","talk","hover"] if citizen.visual.flyer else ["idle","talk","walk"])
	# This controlled fixture measures steady crowd readability. Arrival and
	# notification behaviour remain visible in the separate real S03 capture.
	var hud: Control = TownProbe.screens(t).get_screen(&"hud")
	hud.toasts.clear()
	hud.get_node("AreaBanner")._dismiss()
	await t.frames(6)
	var visible := 0
	for citizen in director.live.values():
		var position: Vector2 = citizen.get_global_transform_with_canvas().origin
		if Rect2(120,140,1040,420).has_point(position):visible+=1
	t.check("l15_city_citizen_count",visible>=6 and looks.size()==16,"%d visible / %d distinct looks; controlled fixture, normal schedules checked by L02/L12" % [visible,looks.size()])
	await suite.shot(t,"S04_city_crowd_readability")
	var memory := Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)/1048576.0
	t.check("l15_city_peak_under_320mb",memory<=320,"%.2fMB / 16 warmed looks" % memory)
	var cap := Perf.uncap()
	await t.frames(12)
	var frames: Dictionary = await Perf.measure_frames(t.tree,0.5,t.tree.root.get_viewport_rid())
	t.check("l15_city_frame",float(frames.ms)<=6,str(frames))
	var with_equipment := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var held: HeldEquipment2D = t.player().held_equipment
	var clothes: WardrobeLayers = t.player().outfit_layers
	# Preserve the original 250-draw city gate, and measure equipment's approved
	# <=16 additional draws separately (docs/art/equipment/design.txt), including
	# the seven clothing layers and their body occluder. Full
	# frame-time and total texture-memory gates above still include equipment.
	var was_processing := held.is_processing()
	held.set_process(false)
	held.rear.hide()
	held.front.hide()
	clothes.root.hide()
	hud.current_item_badge.hide()
	hud.tool_name_label.show()
	await t.frames(4)
	var without_equipment := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	t.check("l15_city_draw_calls", without_equipment <= 250, "original city/HUD: %d <=250; with equipment: %d" % [without_equipment, with_equipment])
	t.check("l15_equipment_draw_increment", with_equipment - without_equipment <= 16, "%d additional draws <=16" % (with_equipment - without_equipment))
	hud.tool_name_label.hide()
	hud.current_item_badge.show()
	clothes.root.show()
	held.set_process(was_processing)
	held.sync_pose()
	Perf.restore_cap(cap)
	if not keep_world:
		Routines.override_registry={}
		Routines.clear_cache()
		gm.clear_config_overrides()
		await t.clear_scene()

func _guide_fixtures(t, _suite) -> void:
	# The historical mocks prescribe particular content. Use their existing
	# owning fixtures for style scoring; retain the real gameplay shots above.
	var factory := preload("res://scripts/ui/dev/ui_fixtures.gd")
	for id in ["shop","dialogue_guide"]:
		var host := Control.new()
		host.process_mode=Node.PROCESS_MODE_ALWAYS
		t.root.add_child(host)
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var screen: Control = await factory.make(id,host)
		await t.frames(4)
		var picture: Image = await t.capture("guide_"+id)
		if id=="shop":
			picture.save_png(t.out_dir.path_join("shop_ui_shop_fixture.png"))
		else:
			var rect: Rect2 = screen.get_node("%Box").get_global_rect()
			picture.get_region(Rect2i(Vector2i(rect.position)-Vector2i(10,10),Vector2i(680,300))).save_png(t.out_dir.path_join("npc_dialogue_crop.png"))
		screen.close()
		host.free()
		await t.frames(2)
