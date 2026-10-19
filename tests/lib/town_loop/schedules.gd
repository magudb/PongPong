extends RefCounted
func run(t, suite) -> void:
	var sm: Node = t.autoload("SocialManager")
	var gm: Node = t.autoload("GameManager")
	var tm: Node = t.autoload("TimeManager")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/lib/town_loop/loop.json"))
	sm.add_points("gardener_hoppe", maxi(0, 200 - sm.points("gardener_hoppe")), &"debug")
	for row in data.routine_probes:
		var places: Array[String] = []
		var live := true
		for stamp in [row.a, row.b]:
			var hour := int(stamp.hour)
			await LoopClock.at(t, int(stamp.weekday), hour, roundi((float(stamp.hour) - hour) * 60))
			tm.set_weather(&"klart")
			var where := NpcDirector.where_is(str(row.npc))
			places.append(str(where.place))
			if str(where.area) != "":
				await t.world().travel(StringName(str(where.area)), &"default")
				await t.physics(3)
				live = live and NpcDirector.node_of(str(row.npc)) != null
			else:
				live = false
		suite._check(t, "L12", "l12_citizens_moved_by_routine_" + str(row.npc), places.size() == 2 and places[0] != places[1] and live, str(places))
	var ctx := Routines.now_ctx()
	ctx.merge({"weekday": 1, "total_day": 9, "hour": 10.0, "weather": "klart", "fest": {}}, true)
	ctx.erase("override_fn")
	var segments := Routines.timeline("gardener_hoppe", "work", false)
	var found := false
	for segment in segments:
		if str(segment.kind) != "move" or float(segment.t1) - float(segment.t0) < 0.01:
			continue
		ctx.hour = (float(segment.t0) + float(segment.t1)) / 2
		var midway := NpcDirector.where_is("gardener_hoppe", ctx)
		found = str(midway.state) == "move" and float(midway.leg.frac) > 0 and float(midway.leg.frac) < 1 and RouteTable.has_anchor(str(segment.from)) and RouteTable.has_anchor(str(segment.to))
		break
	suite._check(t, "L12", "l12_route_takes_time", found)
	ctx.hour = 12.0
	ctx.weather = "regn"
	var sheltered := NpcDirector.where_is("gardener_hoppe", ctx)
	suite._check(t, "L12", "l12_weather_override", str(sheltered.area).begins_with("int_") or str(sheltered.state) == "inside", str(sheltered))
	ctx.weather = "klart"
	ctx.weekday = 5
	ctx.total_day = 6
	ctx.hour = 12.0
	ctx["flags"] = {"brumme_at_stall": 1, "brumme_at_work": 0}
	var weekend := NpcDirector.where_is("carpenter_brumme", ctx)
	suite._check(t, "L12", "l12_weekend_variant", str(weekend.place).contains("brumme_stall") or str(weekend.place).contains("stall"), str(weekend))
	ctx.weekday = 0
	ctx.total_day = 1
	ctx.hour = 7.25
	var first := NpcDirector.where_is("postman_pip", ctx)
	ctx.weekday = 1
	ctx.total_day = 2
	var second := NpcDirector.where_is("postman_pip", ctx)
	suite._check(t, "L12", "l12_pip_visits_farm_from_day_2", str(first.area) != "farm" and str(second.place) == "farm.pip_mailbox", str(first) + " / " + str(second))
	ctx.weekday = 2
	ctx.total_day = 3
	ctx.hour = 15.5
	ctx["hearts"] = {"gardener_hoppe": 1}
	var locked := NpcDirector.where_is("gardener_hoppe", ctx)
	# A live day keeps the plan it started with (SIM-06): the second heart opens the visit from the next Wednesday.
	ctx.hearts.gardener_hoppe = 2
	ctx.total_day = 10
	var unlocked := NpcDirector.where_is("gardener_hoppe", ctx)
	suite._check(t, "L12", "l12_hoppe_wednesday_visit", str(locked.area) != "farm" and str(unlocked.place) == "farm.hoppe_fence", str(locked) + " / " + str(unlocked))
	ctx.hour = 25.99
	var awake: Array[String] = []
	for id in Routines.registry():
		# Nocturnal family schedules are tested at 24/25/25.5 in ghostfam_data.
		if str(t.autoload("LuaRuntime").get_npc(id).get("family", "")) == "natlys":
			continue
		var at_night := NpcDirector.where_is(str(id), ctx)
		if str(at_night.area) in ["traetoppen", "hyggebyen", "farm"] and str(at_night.state) != "inside":
			awake.append(str(id) + ":" + str(at_night.place))
	suite._check(t, "L12", "l12_night_presence", awake.is_empty(), str(awake))
	await LoopClock.at(t, 0, 10)
	tm.set_weather(&"klart")
	await t.world().travel(&"traetoppen", &"from_farm")
	await suite.shot(t,"S12_city_next_morning")
