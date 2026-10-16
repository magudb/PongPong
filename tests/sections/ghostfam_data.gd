extends RefCounted
const SECTION := "ghostfam_data"
const TIMEOUT_S := 240.0
const IDS := ["ghostfam_dyne", "ghostfam_gnist", "ghostfam_silke", "ghostfam_blund"]
const Hook := preload("res://scripts/ghostfam/hook/ghostfam_hook.gd")

class HookActor extends Node:
	var npc_id := ""

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.set_config_override("towns.curfew.enabled", false)
	var lr: Node = t.autoload("LuaRuntime")
	var routines := Routines.registry()
	var room := InteriorRoom.load_spec("int_gaestehytten")
	t.check("building_row_hours", Hours.hours_on(Hours.building("gaestehytten"), 0) == [17.0, 25.0] and Hours.closed_days(Hours.building("gaestehytten")) == [2])
	t.check("shop_loads_and_stock_exists", lr.get_shop("lantern_house").keeper == "ghostfam_gnist" and not t.autoload("ShopSystem").get_shop_inventory("lantern_house").is_empty())
	t.check("room_has_family_bed_and_guest_bed", room.items.filter(func(row): return row.id == "bed_birch_single").size() == 2)
	t.check("sidecar_door_and_post_added", RouteTable.has_anchor("traetoppen.door_gaestehytten") and RouteTable.has_anchor("traetoppen.f_porch") and RouteTable.has_anchor("int_gaestehytten.table"))
	for id in IDS:
		var npc: Dictionary = lr.get_npc(id)
		var citizen := SocialData.citizen(id)
		t.check(id + "_registered", npc.get("visual") == id and bool(npc.get("friendship", false)) and routines.has(id) and not citizen.derived and not citizen.partner)
		t.check(id + "_visual_without_fallback", CharacterCatalog.resolve(id) == id)
		var wraps := true
		for plan in routines[id].plans:
			var blocks: Array = routines[id].plans[plan].blocks
			wraps = wraps and blocks[0].at == blocks[-1].at
		t.check(id + "_plans_wrap", wraps)
		for hero in ["rasmus", "kiki", "kloevermynte", "birk", "bertil", "bodil", "bu", "hviske"]:
			var where := Routines.where_is(id, Routines.make_ctx(0, 6.1, "klart", {"hero": hero, "total_day": 1}))
			t.check(id + "_present_for_" + hero, where.state == "stay" and where.area == "traetoppen" and (where.act != "sleep" or id == "ghostfam_blund"), str(where))
		for weather in ["klart", "regn"]:
			for wd in 7:
				for hour in [24.5, 25.0, 25.5]:
					var where := Routines.where_is(id, Routines.make_ctx(wd, hour, weather, {"total_day": 99}))
					var ok: bool = where.state in ["stay", "move"] and where.area != ""
					if id == "ghostfam_dyne":
						ok = ok and where.place == "traetoppen.f_bench"
					if id == "ghostfam_gnist" and wd != 2 and hour == 24.5:
						ok = ok and where.place == "int_gaestehytten.counter"
					if id == "ghostfam_gnist" and hour == 25.5:
						ok = ok and where.place == "traetoppen.f_porch"
					if id == "ghostfam_silke":
						ok = ok and where.place == ("traetoppen.f_lamp" if wd == 2 or hour >= 25 else "traetoppen.b_lamp")
					if id == "ghostfam_blund" and hour >= 25.0:
						ok = ok and where.place == "traetoppen.f_porch" and where.act == "sleep"
					t.check("presence_" + id + "_%d_%s_%.1f" % [wd, weather, hour], ok, str(where))
	var errors := TownsValidate.keepers_cover_hours()
	t.check("keeper_covers_hours_every_open_day", errors.is_empty(), str(errors))
	errors = TownsValidate.post_capacity()
	t.check("post_capacity_with_family", errors.is_empty(), str(errors.slice(0, 5)))
	var visuals := {}
	for id in lr.get_npcs():
		visuals[id] = str(lr.get_npc(id).get("visual", id))
	errors = TownsValidate.visual_budget(visuals)
	t.check("visual_budget_with_family", errors.is_empty(), str(errors.slice(0, 5)))
	var slowed := routines.duplicate(true)
	for id in IDS:
		slowed[id]["speed_mult"] = float(slowed[id].get("speed_mult", 1.0)) / 1.4
	Routines.override_registry = slowed
	Routines.clear_cache()
	errors = TownsValidate.routines_feasible()
	t.check("late_round_is_robust", errors.is_empty(), str(errors.slice(0, 5)))
	Routines.override_registry = {}
	Routines.clear_cache()
	_dialogue(t)
	_hiding(t)
	await _gathering(t)
	await _kin(t)
	_hook(t)
	var copy: Dictionary = t.run_tool("python3", [ProjectSettings.globalize_path("res://tools/ghostfam/prepare_copy.py")])
	t.check("copy_regenerates_identically", copy.code == 0, copy.output)
	copy = t.run_tool("python3", [ProjectSettings.globalize_path("res://tools/ghostfam/check_copy.py")])
	t.check("tone_gender_barks_and_literal_keys", copy.code == 0, copy.output)
	gm.clear_config_overrides()

func _hiding(t) -> void:
	var slots := {0: ["traetoppen.g_planter2", "traetoppen.c_lamp"], 1: ["traetoppen.c_logs", "traetoppen.u_lamp"], 3: ["traetoppen.a_beds2", "traetoppen.b_mailbox"], 4: ["traetoppen.e_bench", "hyggebyen.market_row3"], 5: ["traetoppen.g_bench", "hyggebyen.torv_playground"], 6: ["traetoppen.u_terrace", "hyggebyen.forge_front"]}
	var plans: Dictionary = Routines.registry().ghostfam_blund.plans
	for wd in slots:
		var blocks: Array = plans["hide_%d" % wd].blocks.filter(func(row): return str(row.act) == "hide")
		t.check("hiding_slots_%d" % wd, blocks.size() == 2 and blocks[0].at == slots[wd][0] and blocks[1].at == slots[wd][1])
		for slot in 2:
			var page: Dictionary = t.autoload("LuaRuntime").get_dialogue("ghostfam_silke", {"race": "animal", "weekday": wd, "hour": 18 if slot == 0 else 22})
			var key := "DLG_GHOSTFAM_SILKE_SEEK_%d_%s" % [wd, "A" if slot == 0 else "B"]
			t.check("silke_hint_%d_%d" % [wd, slot], page.choices.any(func(choice): return str(choice.get("info_key", "")) == key))

func _gathering(t) -> void:
	var gm: Node = t.autoload("GameManager")
	gm.day = 3
	gm.hour = 19
	gm.minute = 30
	t.autoload("EventBus").day_started.emit(gm.day, gm.season)
	t.autoload("EventBus").time_of_day_changed.emit(gm.hour, gm.minute)
	await LoopClock.settle(t)
	await t.world().travel(&"traetoppen", &"default")
	var positions: Array[Vector2] = []
	var all_here := true
	for id in IDS:
		var actor: Node = NpcDirector.node_of(id)
		var where := NpcDirector.where_is(id)
		all_here = all_here and actor != null and str(where.place).begins_with("traetoppen.t_fire_")
		if actor != null:
			positions.append(Iso.to_ground(actor.global_position))
	t.check("wednesday_family_evening_four_at_fire", all_here and positions.size() == 4)
	var min_gap := INF
	for i in positions.size():
		for j in range(i + 1, positions.size()):
			min_gap = minf(min_gap, positions[i].distance_to(positions[j]))
	t.check("family_gathering_has_distinct_body_positions", min_gap >= 40, "minimum ground gap=" + str(min_gap))
	gm.day = 1
	t.autoload("EventBus").day_started.emit(gm.day, gm.season)

func _dialogue(t) -> void:
	var lr: Node = t.autoload("LuaRuntime")
	var locale: Node = t.autoload("LocalizationManager")
	for id in IDS:
		for race in ["animal", "fairy", "hobbit", "ghost"]:
			var ok := true
			var count := 0
			for wd in 7:
				for hour in [6, 12, 17, 20, 24, 25]:
					var ctx := {"race": race, "hero": "bu", "weekday": wd, "hour": hour, "daypart": "nat", "shop_opens_at": 17, "shop_closes_at": 25}
					ctx["ghostfam_kin_" + id.trim_prefix("ghostfam_")] = true
					ctx["ghostfam_kin_look_" + id.trim_prefix("ghostfam_")] = true
					var page: Dictionary = lr.get_dialogue(id, ctx)
					ok = ok and not LuaData.arr(page.get("lines", [])).is_empty()
					for row in LuaData.arr(page.get("lines", [])) + LuaData.arr(page.get("choices", [])):
						var key := str(row.get("text_key", ""))
						ok = ok and key != "" and locale.has_key(key)
						if race != "ghost":
							ok = ok and not key.contains("_KIN_")
					count += 1
			t.check("dialogue_" + id + "_" + race, ok and count == 42)
	for wd in 7:
		var page: Dictionary = lr.get_dialogue("ghostfam_dyne", {"race": "animal", "weekday": wd, "hour": 24})
		t.check("midnight_story_%d" % wd, page.lines[0].text_key == "DLG_GHOSTFAM_DYNE_MIDNIGHT_%d" % wd)
	var row := Hours.building("gaestehytten").duplicate(true)
	var registry := Hours.registry().duplicate(true)
	row.hours.close = 23
	registry.gaestehytten = row
	Hours.override_registry = registry
	var ctx := NpcDialogue.context("ghostfam_gnist", t.player())
	ctx.hour = 24
	ctx.race = "animal"
	var page: Dictionary = lr.get_dialogue("ghostfam_gnist", ctx)
	t.check("gnist_hours_equal_building_row", float(ctx.shop_closes_at) == 23 and page.lines[0].text_key == "DLG_GHOSTFAM_GNIST_CLOSED_NIGHT_1" and not page.choices.any(func(c): return str(c.action) == "open_shop"))
	Hours.override_registry = {}
	t.check("no_double_reaction", not LuaData.dict(t.autoload("GameManager").config_value("race_reactions.ghost", {})).keys().any(func(id): return str(id).begins_with("ghostfam_")))

func _kin(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SocialManager")
	var eco: Node = t.autoload("EconomyManager")
	var starting: int = gm.character_type
	var starting_skin: StringName = gm.character_skin
	gm.character_type = gm.CharacterType.GHOST
	gm.character_skin = &"ghost_bu"
	gm.hour = 6
	gm.minute = 10
	await t.world().travel(&"traetoppen", &"default")
	for id in IDS:
		gm.clear_flag(StringName("ghostfam_kin_" + id.trim_prefix("ghostfam_")))
		var actor: Node = NpcDirector.node_of(id)
		t.check(id + "_live_at_dawn", actor != null)
		if actor == null:
			continue
		var before: int = sm.hearts(id)
		var shirt: int = eco.count_item(&"shirt_knit_cream")
		actor.interact(t.player())
		await t.frames(2)
		var screen := TownProbe.dialogue(t)
		var expected: int = {"ghostfam_dyne": 5, "ghostfam_gnist": 2, "ghostfam_silke": 2, "ghostfam_blund": 3}[id]
		t.check(id + "_kin_scene_without_stranger", screen.is_open() and screen._lines.size() == expected and str(screen._lines[0].text_key).contains("_KIN_1_1"))
		await preload("res://tests/sections/town_loop.gd").new()._finish_dialogue(t)
		var gift_hearts: int = 2 if id in ["ghostfam_dyne", "ghostfam_blund"] else 1
		t.check(id + "_kin_is_met_and_weekly_heart", sm.met(id) and sm.hearts(id) == before + gift_hearts + 1)
		if id == "ghostfam_dyne":
			t.check("granny_knit_gift_once", eco.count_item(&"shirt_knit_cream") == shirt + 1)
		var hearts: int = sm.hearts(id)
		var page := NpcDialogue.build(id, id, NpcDialogue.context(id, t.player()))
		t.check(id + "_kin_once", bool(page.get("social", true)) and not page.lines.any(func(line): return str(line.get("text_key", "")).contains("_KIN_1_")) and sm.hearts(id) == hearts)
		var value: Variant = gm.get_flag(StringName("ghostfam_kin_" + id.trim_prefix("ghostfam_")))
		t.check(id + "_flags_json_safe", value is bool or value is int)
	gm.character_type = starting
	gm.character_skin = starting_skin

func _hook(t) -> void:
	var glow := Hook.glow_path
	var seek := Hook.seek_path
	Hook.glow_path = "res://tests/fixtures/ghostfam/hook_target.gd"
	Hook.seek_path = Hook.glow_path
	for id in ["gardener_hoppe"] + IDS:
		var actor := HookActor.new()
		actor.npc_id = id
		Hook.attach(actor)
		var expected := 0 if id == "gardener_hoppe" else (2 if id == "ghostfam_blund" else 1)
		t.check("hook_" + id, int(actor.get_meta("hook_calls", 0)) == expected)
		actor.free()
	Hook.glow_path = glow
	Hook.seek_path = seek

func run_windowed(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.set_config_override("towns.curfew.enabled", false)
	TownProbe.dialogue(t).chars_per_second = 100000
	var shots := [{"name": "dawn", "day": 1, "hour": 6, "minute": 10, "area": "traetoppen", "focus": "ghostfam_dyne"}, {"name": "lantern_house", "day": 2, "hour": 17, "minute": 30, "area": "int_gaestehytten", "focus": "ghostfam_gnist"}, {"name": "wednesday_fire", "day": 3, "hour": 19, "minute": 30, "area": "traetoppen", "focus": "ghostfam_dyne"}, {"name": "forest_lift_vigil", "day": 2, "hour": 24, "minute": 30, "area": "traetoppen", "focus": "ghostfam_silke"}, {"name": "midnight_bench", "day": 2, "hour": 25, "minute": 0, "area": "traetoppen", "focus": "ghostfam_dyne"}]
	for shot in shots:
		gm.day = shot.day
		gm.hour = shot.hour
		gm.minute = shot.minute
		t.autoload("EventBus").day_started.emit(gm.day, gm.season)
		t.autoload("TimeManager").set_weather(&"klart")
		t.autoload("EventBus").time_of_day_changed.emit(gm.hour, gm.minute)
		# Advancing to Wednesday can close the room we're leaving and start
		# its production eviction. Finish that travel before setting up a shot.
		await LoopClock.settle(t)
		await t.world().travel(StringName(shot.area), &"default")
		var actor: Node = NpcDirector.node_of(shot.focus)
		t.check("native_" + shot.name + "_present", actor != null)
		if actor != null and shot.area == "traetoppen":
			t.check("native_" + shot.name + "_player_on_safe_deck", _stand_near(t, actor))
			t.player().camera.reset_smoothing()
		await t.world().warm_clips()
		await t.frames(8)
		TownProbe.screens(t).get_screen(&"hud").toasts.clear()
		# Let arrival/closing messages expire so the review shows the artwork.
		await t.frames(210)
		await t.capture(shot.name)
		if shot.name == "dawn" and actor != null:
			actor.interact(t.player())
			await t.frames(8)
			TownProbe.screens(t).get_screen(&"hud").toasts.clear()
			await t.frames(2)
			await t.capture("granny_kin_dialogue")
			t.tap_key(KEY_ESCAPE)
			await t.frames(3)
	gm.clear_config_overrides()

func _stand_near(t, actor: Node2D) -> bool:
	var area: IsoArea = t.world().area
	var registry := CityBuilder.of(area).registry
	var query := PhysicsShapeQueryParameters2D.new()
	var body := ConvexPolygonShape2D.new()
	body.points = Npc2D._ellipse(Vector2(25, 14.8))
	query.shape = body
	var space := area.get_world_2d().direct_space_state
	for radius in [180.0, 140.0, 100.0]:
		for turn in 16:
			var angle := TAU * turn / 16.0
			var point: Vector2 = actor.global_position + Iso.to_screen(Vector2(cos(angle), sin(angle)) * float(radius))
			var level := registry.level_at(point)
			if level == null or Array(body.points).any(func(edge): return not area.walkable_test.call(point + edge)):
				continue
			if TownProbe.director(t).live.values().any(func(npc): return npc.global_position.distance_to(point) < 120):
				continue
			query.transform = Transform2D(0, point)
			query.collision_mask = Iso.LAYER_WORLD | Iso.LAYER_NPC | level.mask_bit()
			if not space.intersect_shape(query, 1).is_empty():
				continue
			t.player().global_position = point
			ActorLevel.set_level(t.player(), level)
			return true
	return false
