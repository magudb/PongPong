extends RefCounted
const SECTION := "towns_routines"
const TIMEOUT_S := 180.0

func run(t) -> void:
	await t.go_menu()
	t.check("route_table_ready", RouteTable.load_table())
	var reg := Routines.registry()
	var core_files := 0
	for file in DirAccess.get_files_at("res://lua/routines/core"):
		if file.ends_with(".lua"):
			core_files += 1
	t.check("core_files_load", reg.size() >= core_files and core_files >= 23)
	var buildings := Hours.registry().duplicate(true)
	var lr: Node = t.autoload("LuaRuntime")
	var visuals := {}
	for npc in lr.get_npcs():
		visuals[npc] = str(lr.get_npcs()[npc].get("visual", npc))
	var checks := {
		"routines_feasible": TownsValidate.routines_feasible(),
		"places_exist": TownsValidate.places_exist(),
		"keeper_covers_hours": TownsValidate.keepers_cover_hours(),
		"hours_consistency": TownsValidate.hours_consistency(lr.get_shops().keys()),
		"post_capacity": TownsValidate.post_capacity(),
		"visual_budget": TownsValidate.visual_budget(visuals),
		"no_short_visits": TownsValidate.no_short_visits(),
		"day_wrap": TownsValidate.day_wrap(),
		"visits_inside_hours": TownsValidate.visits_inside_hours(),
	}
	for rule in checks:
		t.check("rule_" + rule, checks[rule].is_empty(), str(checks[rule]))
	for npc in Routines.npc_ids():
		var def: Dictionary = reg[npc]
		t.expect(not LuaData.arr(def.get("select", [])).is_empty() and def.has("plans") and def.has("home"), str(npc) + " routine schema")
		for hour in [2.0, 3.5, 5.99, 6.0, 24.5, 25.5]:
			var state := Routines.where_is(npc, Routines.make_ctx(2, hour, "klart", {"total_day": 99, "done": {"lost_cat": true}}))
			t.expect(state.get("state") in ["stay", "inside", "move", "absent"], "%s resolves at raw hour %.2f" % [npc, hour])
	var total := 0
	var invalid := 0
	for weekday in 7:
		for weather in ["klart", "regn"]:
			var ctx := Routines.make_ctx(weekday, 6.0, weather, {"total_day": 99, "done": {"lost_cat": true}})
			for minute in range(360, 1560):
				ctx["hour"] = float(minute) / 60.0
				for npc in reg:
					var state := Routines.where_is(npc, ctx)
					total += 1
					invalid += int(state.get("state") not in ["stay", "inside", "move", "absent"] or (state.get("state") in ["stay", "inside", "move"] and str(state.get("place", "")) == ""))
	t.check("sweep_every_citizen_once", invalid == 0 and total == reg.size() * 7 * 2 * 1200, "%d citizen-minutes over the complete 20-hour day, clear and rainy" % total)
	var ctx := Routines.make_ctx(2, 15.5, "klart", {"total_day": 3, "hearts": {"gardener_hoppe": 2}})
	t.expect(Routines.where_is("gardener_hoppe", ctx).place == "farm.hoppe_fence", "Hoppe visits the farm on Wednesday from two hearts")
	ctx.hearts.gardener_hoppe = 0
	t.expect(Routines.where_is("gardener_hoppe", ctx).place != "farm.hoppe_fence", "The farm visit respects its friendship gate")
	for weekday in range(6):
		var morning := Routines.make_ctx(weekday, 7.25, "klart", {"total_day": weekday + 8})
		t.expect(Routines.where_is("postman_pip", morning).place == "farm.pip_mailbox", "Pip's measured morning courier round on weekday %d" % weekday)
		morning.hour = 9.0
		t.expect(Routines.where_is("postman_pip", morning).place == "int_postkontoret.counter", "Pip covers his counter at opening on weekday %d" % weekday)
	ctx = Routines.make_ctx(0, 12.0, "klart", {"total_day": 59})
	t.expect(Routines.is_unavailable("cat_morfar_mis", ctx), "Morfar Mis is gated before the rescue/day sixty")
	ctx.total_day = 60
	t.expect(not Routines.is_unavailable("cat_morfar_mis", ctx), "Morfar Mis unlocks by day sixty")
	ctx.total_day = 1
	ctx.done = {"lost_cat": true}
	t.expect(not Routines.is_unavailable("cat_morfar_mis", ctx), "The rescue unlocks Morfar Mis earlier")
	var mutant := reg.duplicate(true)
	mutant.gardener_hoppe["hero_twin"] = "probe_hero"
	Routines.override_registry = mutant
	ctx.hero = "probe_hero"
	t.expect(Routines.is_unavailable("gardener_hoppe", ctx) and Routines.where_is("gardener_hoppe", ctx).state == "absent", "A chosen hero twin is absent")
	Routines.override_registry = {}
	Routines.clear_cache()
	ctx = Routines.make_ctx(2, 12.0, "klart", {"total_day": 99, "done": {"lost_cat": true}})
	Routines.where_is("gardener_hoppe", ctx)
	var started := Time.get_ticks_usec()
	for i in 10000:
		Routines.where_is("gardener_hoppe", ctx)
	var micros := float(Time.get_ticks_usec() - started) / 10000.0
	t.check("where_is_under_20us", micros < 20.0, "%.2f us per cached routine lookup" % micros)
	_festivals(t)
	_mutants(t, reg, buildings, visuals, lr.get_shops().keys())
	Hours.override_registry = {}
	Routines.clear_cache()

func _festivals(t) -> void:
	Routines.clear_cache()
	var calls := [0]
	var override := func(_npc: String, _day: int, _hour: int) -> Dictionary:
		calls[0] += 1
		return {"area": "hyggebyen", "post": "fest_hyggetorv_gather_1", "state": "stay"}
	var ctx := Routines.make_ctx(2, 12.5, "klart", {"total_day": 99, "done": {"lost_cat": true}, "fest": {"id": "probe", "from": 12.0, "to": 14.0, "area": "hyggebyen", "spot": "hyggetorv"}, "override_fn": override})
	var guest := Routines.where_is("gardener_hoppe", ctx)
	t.check("festival_overlay_attendee_on_post", guest.state == "stay" and guest.place == "hyggebyen.fest_hyggetorv_gather_1")
	Routines.where_is("gardener_hoppe", ctx)
	t.expect(calls[0] == 1, "Festival override is resolved once per citizen and date")
	ctx.hour = 25.5
	var home := Routines.where_is("gardener_hoppe", ctx)
	t.check("festival_home_afterwards", home.place == ("int_hoppe_hut.bed" if RouteTable.has_anchor("int_hoppe_hut.bed") else "traetoppen.door_hoppe_hut"))
	var late := Routines.where_is("mapseller_natteblik", ctx)
	t.expect(late.state in ["stay", "move", "inside", "absent"], "An off-stage citizen has a defined festival tail")
	Routines.clear_cache()

func _prove(t, name: String, routines: Dictionary, buildings: Dictionary, guard: Callable) -> void:
	Routines.override_registry = routines
	Hours.override_registry = buildings
	Routines.clear_cache()
	var problems: Array = guard.call()
	t.check("mutant_" + name, not problems.is_empty(), str(problems.slice(0, 2)))

func _mutants(t, base: Dictionary, buildings: Dictionary, visuals: Dictionary, shops: Array) -> void:
	var r := base.duplicate(true)
	r.baker_maja.plans.work.blocks[1].at = "hyggebyen.torv_fountain_e"
	_prove(t, "keeper_leaves_counter", r, buildings, TownsValidate.keepers_cover_hours)
	r = base.duplicate(true)
	r.postman_pip.plans.work.blocks[1].leave = 7.2
	r.postman_pip.plans.work.blocks[2]["from"] = 7.21
	_prove(t, "impossible_arrival", r, buildings, TownsValidate.routines_feasible)
	r = base.duplicate(true)
	r.gardener_hoppe.plans = {"work": {"blocks": [{"from": 6.0, "at": "int_bageriet.counter", "act": "stand"}]}}
	r.gardener_hoppe.select = [{"plan": "work"}]
	_prove(t, "capacity_one_post", r, buildings, TownsValidate.post_capacity)
	r = base.duplicate(true)
	r.gardener_hoppe.plans.work.blocks[1].at = "traetoppen.unknown_bed"
	_prove(t, "unknown_post", r, buildings, TownsValidate.places_exist)
	r = base.duplicate(true)
	r.gardener_hoppe.plans.work.blocks.insert(3, {"at": "int_postkontoret.door", "act": "stand", "stay": 0.03})
	_prove(t, "short_visit", r, buildings, TownsValidate.no_short_visits)
	r = base.duplicate(true)
	var looks := visuals.duplicate()
	for i in 8:
		var id := "crowd_%d" % i
		r[id] = {"home": "extra", "priority": 1, "plans": {"work": {"blocks": [{"from": 6.0, "at": "hyggebyen.well", "act": "stand"}]}}, "select": [{"plan": "work"}]}
		looks[id] = "extra_look_%d" % i
	_prove(t, "visual_cap", r, buildings, func() -> Array: return TownsValidate.visual_budget(looks))
	var b := buildings.duplicate(true)
	b.bageriet.hours.close = 11.0
	_prove(t, "short_shop_hours", base, b, func() -> Array: return TownsValidate.hours_consistency(shops))
	r = base.duplicate(true)
	r.smith_thorin.plans.work.blocks[-1].at = "hyggebyen.door_bageriet"
	_prove(t, "day_does_not_wrap", r, buildings, TownsValidate.day_wrap)
	r = base.duplicate(true)
	r.erase("farmer_rosa")
	_prove(t, "keeper_without_routine", r, buildings, func() -> Array: return TownsValidate.hours_consistency(shops))
	r = base.duplicate(true)
	r.gardener_hoppe.plans = {"work": {"blocks": [{"from": 6.0, "at": "int_bageriet.cust3", "act": "stand", "stay": 0.2}, {"from": 8.0, "at": "traetoppen.a_bench", "act": "sit"}]}}
	r.gardener_hoppe.select = [{"plan": "work"}]
	_prove(t, "customer_before_opening", r, buildings, TownsValidate.visits_inside_hours)
	r = base.duplicate(true)
	r.gardener_hoppe.plans.work.blocks[1].act = "teleport_through_wall"
	_prove(t, "unknown_act", r, buildings, TownsValidate.routines_feasible)
	r = base.duplicate(true)
	r.gardener_hoppe.plans.work.blocks[1].act = "hide"
	Routines.override_registry = r
	Hours.override_registry = buildings
	Routines.clear_cache()
	t.check("act_vocabulary_accepts_hide", TownsValidate.routines_feasible().is_empty())
	Routines.override_registry = {}
	Hours.override_registry = buildings
	Routines.clear_cache()
