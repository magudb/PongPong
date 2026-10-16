extends RefCounted
const SECTION := "town_loop"
const TIMEOUT_S := 240.0
var ran: Dictionary = {}
var skipped: Dictionary = {}
var probe := TownProbe.new()

func _check(t, leg: String, name: String, ok: bool, detail := "") -> void:
	ran[leg + "." + name] = ok
	t.check(name, ok, detail)

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
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.set_config_override("towns.curfew.enabled", false)
	probe.attach(t)
	await _foundation(t)
	_gate(t)
	probe.dispose()
	gm.clear_config_overrides()

func _foundation(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var saves: Node = t.autoload("SaveManager")
	var eco: Node = t.autoload("EconomyManager")
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
	for node in t.world().area.triggers.get_children():
		if node is Warp2D and node.to_area == &"traetoppen":
			warp = node
	t.check("farm_bridge_warp_exists", warp != null)
	if warp != null:
		var result: Dictionary = await LoopWalker.walk_to(t, warp.global_position, 20)
		await t.until(func(): return t.world().area.map.id == &"traetoppen" and not t.world().traveling, 8)
		t.check("walker_reaches_fixture_warp", result.ok and t.world().area.map.id == &"traetoppen", str(result))
		t.check("walker_uses_navigation_and_tick_budget", result.nav and result.ticks <= 2700, str(result))
		await t.world().travel(&"farm", &"from_traetoppen")
	var directory: String = saves.save_dir
	saves.save_dir = "user://town-loop"
	var before := LoopDigest.of_payload(saves.gather_payload())
	var start := Time.get_ticks_usec()
	var saved: bool = saves.save_game(3)
	var save_ms := (Time.get_ticks_usec() - start) / 1000.0
	gm.set_flag(&"loop_digest_probe", true)
	eco.add_gold(1)
	var world_id: int = t.world().get_instance_id()
	var loaded: bool = saves.load_and_enter(3)
	await t.until(func(): return t.world() != null and t.world().get_instance_id() != world_id and t.player() != null, 10)
	await t.physics(3)
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	_check(t, "L13", "l13_digest_roundtrip", saved and loaded and LoopDigest.of_payload(saves.gather_payload()) == before)
	_check(t, "L13", "l13_save_cost", save_ms <= 25, str(save_ms))
	saves.save_dir = directory
