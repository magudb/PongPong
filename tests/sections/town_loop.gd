extends RefCounted
const SECTION := "town_loop"
const TIMEOUT_S := 240.0
var ran: Dictionary = {}
var skipped: Dictionary = {}
var probe := TownProbe.new()
var build_samples: Dictionary = {}
var raw_copy: Array[String] = []
var text_samples := 0
var startup_areas: Array[int] = []
var native_mode := false
var native_shots: Dictionary = {}
var native_city_bytes := 0.0
var native_farm_bytes := 0.0

func shot(t, id: String) -> void:
	if not native_mode or native_shots.has(id):
		return
	await t.frames(3)
	var picture: Image = await t.capture(id)
	native_shots[id] = picture
	t.expect_not_blank(picture, Rect2i(0,0,1280,720), "l15_" + id + "_not_blank")
	if id == "S03_city_arrival":
		var hud: Control = TownProbe.screens(t).get_screen(&"hud")
		for spec in [["date","%DatePanel"],["chip","%MoneyChip"],["hotbar","%HotbarTray"]]:
			var rect: Rect2 = hud.get_node(spec[1]).get_global_rect()
			picture.get_region(Rect2i(rect)).save_png(t.out_dir.path_join("hud_v2_"+spec[0]+".png"))

func run_windowed(t) -> void:
	native_mode = true
	var started := Time.get_ticks_usec()
	await run(t)
	await preload("res://tests/lib/town_loop/native.gd").new().run(t, self)
	var elapsed := (Time.get_ticks_usec()-started)/1000000.0
	t.check("l15_window_budget", elapsed<=110, "%.3fs <=110s" % elapsed)
	t.check("l15_free_on_exit_vram", native_city_bytes-native_farm_bytes>=40*1048576, "%.2fMB city -> %.2fMB farm (%.2fMB freed)" % [native_city_bytes/1048576,native_farm_bytes/1048576,(native_city_bytes-native_farm_bytes)/1048576])

func _check(t, leg: String, name: String, ok: bool, detail := "") -> void:
	ran[leg + "." + name] = ok
	t.check(name, ok, detail)
	if t.world() != null and t.world().area != null:
		var area: IsoArea = t.world().area
		if area.get_instance_id() not in startup_areas:
			build_samples[area.get_instance_id()] = {"area": str(area.map.id), "ms": area.build_ms}
	_observe_text(t.tree.root)

func _observe_text(node: Node) -> void:
	if node is Control and node.is_visible_in_tree() and (node is Label or node is Button or node is RichTextLabel):
		var value := str(node.text)
		if value != "":
			text_samples += 1
			var key := RegEx.create_from_string("^[A-Z][A-Z0-9]*_[A-Z0-9_]+$")
			# Godot's auto-translated Labels retain the key in .text.
			if key.search(value) != null and tr(value) == value and value not in raw_copy:
				raw_copy.append(value)
	for child in node.get_children():
		_observe_text(child)

func _leg(t, id: String, needs: Array) -> bool:
	var missing := LoopCaps.missing(needs, t.tree)
	if missing.is_empty():
		return true
	skipped[id] = "Missing capability: " + ", ".join(missing)
	t.skip(id + ": " + str(skipped[id]))
	return false

func _gate(t) -> void:
	var wave := OS.get_environment("TOWN_LOOP_WAVE")
	if wave == "":
		t.info("Town loop wave unset; capability skips remain explicit: " + str(skipped))
		return
	var missing: Array[String] = []
	for requirement in LoopCaps.required(wave):
		if not ran.keys().any(func(key): return str(key) == requirement or (not requirement.contains(".") and str(key).begins_with(requirement + "."))):
			missing.append(requirement + ": " + str(skipped.get(requirement.get_slice(".", 0), "did not run")))
	t.check("gate_leg_not_skipped", missing.is_empty(), str(missing))

func run(t) -> void:
	await t.clear_scene()
	await t.frames(3)
	var started := Time.get_ticks_usec()
	var orphans: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var messages: int = t.log_mark()
	var gm: Node = t.autoload("GameManager")
	probe.attach(t)
	_schema(t)
	await _first_morning(t)
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.set_config_override("towns.curfew.enabled", false)
	await preload("res://tests/lib/town_loop/mail.gd").new().farm_day_two(t, self)
	await _foundation(t)
	await preload("res://tests/lib/town_loop/copy.gd").new().run(t, self)
	_extended(t)
	_external_proofs(t)
	probe.dispose()
	gm.clear_config_overrides()
	await t.clear_scene()
	await t.frames(3)
	var elapsed := (Time.get_ticks_usec() - started) / 1000000.0
	var limit := 15.0 if OS.get_environment("GODOT_EXTRA_ARGS").contains("--fixed-fps") else 120.0
	_check(t, "L14", "l14_wall_time", elapsed <= limit, "%.3fs <= %.0fs" % [elapsed, limit])
	_check(t, "L14", "l14_area_switch_times", not build_samples.is_empty() and build_samples.values().all(func(row): return int(row.ms) <= 150), str(build_samples.values()))
	var growth: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) - orphans
	_check(t, "L14", "l14_no_orphans", growth <= 5, "growth=" + str(growth))
	_check(t, "L14", "l14_zero_engine_messages", t.log_since(messages).is_empty(), str(t.log_since(messages)))
	_gate(t)
	var reporting: Dictionary = t.run_tool("python3",[ProjectSettings.globalize_path("res://tools/town/loop_report.py"),"--selftest"])
	t.check("report_lists_every_required_leg",reporting.code==0,reporting.output)

func _extended(t) -> void:
	var legs := {"x01_birthday_content": "birthdays", "x02_festival_scene": "festivals", "x03_heart_event": "events", "x04_relationship": "relationships", "x05_mail_screen": "post_ui", "x06_farm_visit_scene": "visits", "x07_seasonal_decor": "seasonal", "x08_rain_fallback_scene": "events", "x09_commitment": "relationships", "L16": "audio"}
	for id in legs:
		if _leg(t, id, [legs[id]]):
			_check(t, id, id + "_consumer_required", false, "Capability is now installed: implement this extended consumer before accepting its wave")
	t.check("extended_legs_listed_with_reasons", legs.keys().all(func(id): return skipped.has(id) or ran.keys().any(func(key): return str(key).begins_with(id + "."))))

func _first_morning(t) -> void:
	var bus: Node = t.autoload("EventBus")
	var gm: Node = t.autoload("GameManager")
	var starts: Array[String] = []
	var endings: Array = []
	var started := func(npc, _module): starts.append(str(npc))
	var ended := func(): endings.append(true)
	bus.dialogue_started.connect(started)
	bus.dialogue_ended.connect(ended)
	await t.start_world("", "Tester", "Testgaarden", "", true)
	_check(t,"L00","l00_selected_race_and_skin",gm.character_type==t.character_type() and str(gm.character_skin)==CharacterCatalog.default_skin(t.character),
		"requested %s / actual type %s, skin %s" % [t.character,gm.character_type,gm.character_skin])
	startup_areas.append(t.world().area.get_instance_id())
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	await t.until(func(): return TownProbe.dialogue(t).is_open(), 10)
	var courier: WeakRef
	for actor in t.tree.get_nodes_in_group("npc"):
		if str(actor.npc_id) == "postman_pip" and actor.guest:
			courier = weakref(actor)
	var deadline := Time.get_ticks_msec() + 60000
	var copy_ok := true
	var checked := {}
	while not bool(gm.get_flag(&"intro_done", false)) and Time.get_ticks_msec() < deadline:
		var screen := TownProbe.dialogue(t)
		if screen != null and screen.is_open():
			screen.chars_per_second = 100000
			if str(screen._speaker.get("id", "")) == "fairy_king":
				await shot(t, "S01_farm_intro")
			for row in screen._lines:
				var key := str(row.get("text_key", ""))
				if checked.has(key):
					continue
				checked[key] = true
				for locale in ["da", "en"]:
					t.autoload("LocalizationManager").set_locale(locale)
					copy_ok = copy_ok and key != "" and tr(key) != key
				t.autoload("LocalizationManager").set_locale("da")
			t.tap(&"ui_accept" if screen._wants_focus() else &"interact")
			await t.frames(2)
		else:
			await t.physics(2)
	await t.frames(3)
	_check(t, "L00", "l00_new_game_on_farm", str(t.world().area.map.id) == "farm" and gm.current_phase == gm.GamePhase.PLAYING and not bool(gm.get_flag(&"intro_pending", false)))
	_check(t, "L00", "l00_first_morning_order", starts == ["postman_pip", "fairy_king", "postman_pip"] and endings.size() == 3 and courier != null and courier.get_ref() == null, str(starts) + " / " + str(endings.size()))
	_check(t, "L00", "l00_no_raw_keys", copy_ok and checked.size() >= 6)
	var count := starts.size()
	await preload("res://scripts/world2d/intro_sequence.gd").run(t.world())
	_check(t, "L00", "l00_first_morning_runs_once", starts.size() == count)
	_check(t, "L00", "l00_hud_and_banner", TownProbe.screens(t).get_screen(&"hud").visible and t.world().area.map.title == "ZONE_FARM" and not tr("ZONE_FARM").contains("Trætoppen"))
	bus.dialogue_started.disconnect(started)
	bus.dialogue_ended.disconnect(ended)
	if native_mode:
		return # The second-game Escape stress path runs in the four-race headless gate.
	# A second actual new game proves the skip path without forging its flags.
	await t.start_world("", "Tester", "Testgaarden", "", true)
	startup_areas.append(t.world().area.get_instance_id())
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	await t.until(func(): return TownProbe.dialogue(t).is_open(), 10)
	t.tap_key(KEY_ESCAPE)
	await t.frames(4)
	_check(t, "L00", "l00_first_morning_esc_skips", bool(gm.get_flag(&"intro_done", false)) and t.autoload("QuestManager").is_active(&"intro_lottery") and t.autoload("QuestManager").is_active(&"forste_dage") and not gm.is_modal_open())
	var pos: Vector2 = t.player().global_position
	t.hold(&"move_right")
	await t.physics(5)
	t.release_all()
	await t.physics(5)
	_check(t, "L00", "l00_player_control_returns", t.player().state == PlayerBody2D.S.FREE and pos.distance_to(t.player().global_position) > 0)

func _foundation(t) -> void:
	var saves: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	t.check("capability_probes_match_live_packages", LoopCaps.missing(["farm", "city", "intro", "npc", "player", "shop", "save", "bed", "social", "director", "interiors", "hours", "gifts", "post", "copy"], t.tree).is_empty())
	t.check("capability_unknown_is_missing", not LoopCaps.has("absent_package", t.tree))
	t.check("unknown_wave_fails_closed", LoopCaps.required("invalid") == ["INVALID_WAVE:invalid"])
	t.check("gate_includes_full_usable_towns", "L18" in LoopCaps.required("5b") and "L03.l03b_keeper_weekly_heart_at_counter" in LoopCaps.required("5b"))
	var paths := ["/game/play_time_seconds", "/meta/saved_at", "/meta/timestamp", "/meta/summary"]
	t.check("digest_volatile_paths_are_exactly_the_named_ones", LoopDigest.volatile() == paths)
	t.check("digest_rounds_only_to_four_decimals", absf(LoopDigest.canon(5000.01) - 5000.01) < 1e-8 and absf(LoopDigest.canon(1.234567) - 1.2346) < 1e-8)
	var baseline: Dictionary = saves.gather_payload()
	var digest := LoopDigest.of_payload(baseline)
	var moved := baseline.duplicate(true)
	moved.economy.gold += 1
	t.check("digest_has_teeth_gold", LoopDigest.of_payload(moved) != digest)
	moved = baseline.duplicate(true)
	moved.game.world_flags["loop_digest_probe"] = 1
	t.check("digest_has_teeth_flags", LoopDigest.of_payload(moved) != digest)
	OS.delay_msec(1100)
	t.check("digest_stable_over_wall_clock", LoopDigest.of_payload(saves.gather_payload()) == digest)
	# A real walk, not a position/velocity assignment, must enter the bridge warp.
	var warp: Warp2D
	var farm_before := LoopDigest.of_payload(t.world().farm.to_dict())
	for node in t.world().area.triggers.get_children():
		if node is Warp2D and node.to_area == &"traetoppen":
			warp = node
	t.check("farm_bridge_warp_exists", warp != null)
	if warp != null:
		if native_mode:
			var back := Iso.to_ground(t.player().global_position-warp.global_position).normalized()
			await LoopWalker.walk_to(t, warp.global_position+Iso.to_screen(back*180), 10)
			var hour: int = gm.hour
			var minute: int = gm.minute
			gm.hour = 21
			t.autoload("EventBus").time_of_day_changed.emit(21,0)
			t.world().day_night.snap()
			await shot(t,"S02_farm_bridge_end")
			gm.hour = hour
			gm.minute = minute
			t.autoload("EventBus").time_of_day_changed.emit(hour,minute)
			t.world().day_night.snap()
		var result: Dictionary = await LoopWalker.walk_to(t, warp.global_position, 20)
		await t.until(func(): return t.world().area.map.id == &"traetoppen" and not t.world().traveling, 8)
		t.check("walker_reaches_fixture_warp", result.ok and t.world().area.map.id == &"traetoppen", str(result))
		t.check("walker_uses_navigation_and_tick_budget", result.nav and result.ticks <= 2700, str(result))
		_check(t, "L01", "l01_bridge_arrival_without_pingpong", t.world().area.map.id == &"traetoppen" and not t.world().traveling)
		await shot(t,"S03_city_arrival")
		await t.physics(40)
		var bridge_progress: Dictionary = t.autoload("QuestManager").get_objective_progress(&"intro_lottery", &"cross_bridge")
		_check(t, "L01", "l01_unlock_toast_and_objective", gm.is_zone_unlocked(&"traetoppen") and int(bridge_progress.get("current", 0)) == 1 and t.world().area.map.id == &"traetoppen", str(bridge_progress))
		await _first_citizen(t)
		await preload("res://tests/lib/town_loop/shops.gd").new().run(t, self)
		await preload("res://tests/lib/town_loop/mail.gd").new().office(t, self)
		await t.world().travel(&"traetoppen", &"from_farm")
		if native_mode:
			await t.frames(6)
			native_city_bytes = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
		var citizens: Array[WeakRef] = []
		for actor in TownProbe.director(t).live.values():
			citizens.append(weakref(actor))
		for trigger in t.world().area.triggers.get_children():
			if trigger is Warp2D and trigger.to_area == &"farm":
				var back := await LoopWalker.walk_to(t, trigger.global_position, 5, 10)
				await t.until(func(): return not t.world().traveling and t.world().area.map.id == &"farm", 8)
				_check(t, "L09", "l09_walk_back_to_farm", back.ok and t.world().area.map.id == &"farm", str(back) + " area=" + str(t.world().area.map.id) + " travel=" + str(t.world().traveling))
				break
		await t.frames(3)
		if native_mode:
			await t.frames(6)
			native_farm_bytes = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
		_check(t, "L09", "l09_farm_state_intact", LoopDigest.of_payload(t.world().farm.to_dict()) == farm_before)
		_check(t, "L02", "l02_citizens_freed_on_exit", not citizens.is_empty() and citizens.all(func(w): return w.get_ref() == null))
		await preload("res://tests/lib/town_loop/farm_day.gd").new().run(t, self)
	await preload("res://tests/lib/town_loop/schedules.gd").new().run(t, self)
	await preload("res://tests/lib/town_loop/save.gd").new().run(t, self)

func _schema(t) -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/lib/town_loop/loop.json"))
	var lr: Node = t.autoload("LuaRuntime")
	var problems: Array[String] = []
	for id in [data.citizen, data.shop.keeper, data.bakery.keeper, data.builder.keeper, data.gifts.npc]:
		if lr.get_npc(id).is_empty():
			problems.append("npc:" + str(id))
	for item in [data.shop.item] + data.gifts.items:
		if lr.get_item_def(item).is_empty():
			problems.append("item:" + str(item))
	for id in [data.shop.building, data.bakery.building, data.builder.building, data.post_office]:
		if Hours.building(id).is_empty():
			problems.append("building:" + str(id))
	for row in data.routine_probes:
		if lr.get_npc(row.npc).is_empty():
			problems.append("routine:" + str(row.npc))
	t.check("loop_json_ids_exist", problems.is_empty() and not lr.get_shop(data.shop.id).is_empty(), str(problems))

func _population(t) -> void:
	var director := TownProbe.director(t)
	var expected: Array = NpcDirector.population(str(t.world().area.map.id))
	var actual: Array = director.live.keys()
	var consistent := true
	for id in actual:
		var where := NpcDirector.where_is(str(id))
		consistent = consistent and str(where.area) == str(t.world().area.map.id) and id in expected
	_check(t, "L02", "l02_population_equals_schedule", consistent and not actual.is_empty() and actual.size() == mini(expected.size(), director.max_live), str(actual) + " expected=" + str(expected))
	_check(t, "L02", "l02_visual_cap_16", actual.size() <= 16)
	_check(t, "L02", "l02_area_populated_event", not probe.named("area_populated").is_empty())

func _finish_dialogue(t, action := "close") -> Dictionary:
	var screen := TownProbe.dialogue(t)
	var selected := {}
	for step in 100:
		if screen == null or not screen.is_open():
			break
		screen.chars_per_second = 100000
		if screen._wants_focus():
			var index := -1
			for i in screen._choices.size():
				if str(screen._choices[i].get("action", "")) == action:
					index = i
					break
			if index < 0:
				index = screen._choices.size() - 1
			selected = screen._choices[index].duplicate()
			screen._buttons[index].grab_focus()
			t.tap(&"ui_accept")
		else:
			t.tap(&"interact")
		await t.frames(2)
	return selected

func _first_citizen(t) -> void:
	await LoopClock.to(t, 10)
	_population(t)
	var actor := NpcDirector.node_of("gardener_hoppe")
	_check(t, "L02", "l02_live_citizen_at_routine_post", actor != null)
	if actor == null:
		return
	var route := await LoopWalker.walk_to(t, actor.global_position, 65)
	_check(t, "L03", "l03_walk_reaches_citizen", bool(route.ok), str(route))
	var sm: Node = t.autoload("SocialManager")
	var before: int = sm.hearts("gardener_hoppe")
	t.tap(&"interact")
	await t.frames(3)
	var screen := TownProbe.dialogue(t)
	_check(t, "L03", "l03_walk_and_talk", screen.is_open() and actor.is_talking and t.autoload("GameManager").top_modal() == &"dialogue")
	if not screen.is_open():
		return
	_check(t, "L03", "l03_first_meeting_copy", screen._lines.any(func(row): return str(row.get("text_key", "")).begins_with("SOC_GARDENER_HOPPE_FIRST_")))
	await shot(t,"S05_dialogue_hoppe_hearts")
	await _finish_dialogue(t)
	_check(t, "L03", "l03_weekly_heart_once", sm.hearts("gardener_hoppe") == before + 1)
	t.tap(&"interact")
	await t.frames(3)
	await _finish_dialogue(t)
	_check(t, "L03", "l03_repeat_chat_no_extra_heart", sm.hearts("gardener_hoppe") == before + 1)
	t.tap(&"interact")
	await t.frames(3)
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	_check(t, "L03", "l03_esc_first_line_no_heart", sm.hearts("gardener_hoppe") == before + 1 and not actor.is_talking)
	t.tap_key(KEY_P)
	await t.frames(3)
	var people: Control = TownProbe.screens(t).get_screen(&"people")
	_check(t, "L03", "l03_people_book_shows_heart", people.is_open() and people.data.any(func(row): return row.id == "gardener_hoppe" and int(row.hearts) == before + 1))
	await shot(t,"S13_people_book")
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	if native_mode:
		t.tap(&"journal")
		await t.frames(3)
		var journal: Control = TownProbe.screens(t).get_screen(&"quest_journal")
		_check(t,"L15","l15_calendar_opens_from_journal",journal.is_open())
		journal.get_node("%TabCalendar").grab_focus()
		t.tap(&"ui_accept")
		await shot(t,"S13b_calendar")
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
	await preload("res://tests/lib/town_loop/gifts.gd").new().run(t, self)

func _external_proofs(t) -> void:
	for item in [["prove_extension.py","L18"],["prove_mutants.py","mutants"]]:
		var result: Dictionary = t.run_tool("python3",[ProjectSettings.globalize_path("res://tools/town/"+item[0]),"--check"])
		var proof: Variant = JSON.parse_string(str(result.output))
		if result.code!=0 or not proof is Dictionary or str(proof.get("result",""))!="pass":
			skipped[item[1]]=str(result.output)
			t.skip(item[1]+": source-bound proof absent/stale; "+str(result.output))
			if item[1]=="mutants" and OS.get_environment("TOWN_LOOP_WAVE")!="":
				t.check("selftest_mutants_caught",false,str(result.output))
			continue
		if item[1]=="L18":
			for id in proof.checks:_check(t,"L18",id,bool(proof.checks[id]))
		else:
			t.check("selftest_mutants_caught",proof.mutants.size()==9 and proof.mutants.values().all(func(row):return row.caught),"Eight real producer mutants plus a clean baseline, including audio playback without logging")
