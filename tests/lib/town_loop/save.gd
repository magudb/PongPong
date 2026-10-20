extends RefCounted
var owner
## Actual disk saves, full-cast state and the production loader/migrations.
func run(t, suite) -> void:
	owner = suite
	var saves: Node = t.autoload("SaveManager")
	var sm: Node = t.autoload("SocialManager")
	var gm: Node = t.autoload("GameManager")
	var eco: Node = t.autoload("EconomyManager")
	var directory: String = saves.save_dir
	saves.save_dir = "user://town-loop"
	for id in SocialData.friend_ids():
		sm.add_points(id, 100, &"debug")
		var row: Dictionary = sm.row_of(id)
		row["kn"] = {"carrot": "like", "honey": "love", "cookie": "like", "oil": "hate", "stone": "dislike", "wool": "neutral", "flour": "neutral", "cake": "love", "flower": "like", "mushroom": "like", "berry": "like", "wood": "neutral"}
	var payload: Dictionary = saves.gather_payload()
	var before := TownProbe.context_digest(t)
	var positions := _places()
	var costs: Array[float] = []
	var saved := true
	for i in 20:
		var begin := Time.get_ticks_usec()
		saved = saves.save_game(3) and saved
		costs.append((Time.get_ticks_usec() - begin) / 1000.0)
	costs.sort()
	var bytes := FileAccess.get_file_as_bytes(saves.slot_path(3)).size()
	suite._check(t, "L13", "l13_save_writes", saved, "20 disk saves of the full cast (%d)" % SocialData.friend_ids().size())
	suite._check(t, "L13", "l13_save_size", bytes <= 60 * 1024, "%d bytes <= 60 KiB" % bytes)
	# The median of 20 saves is the budget: a disk flush or a preemption moves the p95 (reported) of a loaded machine, not the cost of a save.
	suite._check(t, "L13", "l13_save_cost", t.perf_ok("l13_save_cost", costs[10], 25.0), "median %.3f ms, p95 %.3f ms (native reference 25 ms for the median, runner limit %.0f)" % [costs[10], costs[18], t.perf_limit(25.0)])
	gm.set_flag(&"loop_digest_probe", true)
	eco.add_gold(1)
	var loaded := await _load(t, 3)
	suite._check(t, "L13", "l13_digest_roundtrip", saved and loaded and TownProbe.context_digest(t) == before, "; ".join(LoopDigest.differences(LoopDigest.canon(payload.social), LoopDigest.canon(saves.gather_payload().social)).slice(0, 8)))
	suite._check(t, "L13", "l13_citizens_same_places", _places() == positions and TownProbe.director(t) != null)
	var order := -1
	for entry in saves._ordered_entries():
		if entry.name == "social":
			order = int(entry.order)
	var names: Array = saves.section_names()
	suite._check(t, "L13", "l13_social_section_order", order == 60 and names.find("social") > names.find("loot"), str(names) + " social=" + str(order))
	if suite.native_mode:
		saves.save_dir = directory
		return # Migration/drift stress loads are covered by the headless matrix.
	var legacy: Dictionary = saves.gather_payload().duplicate(true)
	legacy.erase("social")
	legacy.game.world_flags["friend_gardener_hoppe"] = 3
	_write(saves.slot_path(4), legacy)
	loaded = await _load(t, 4)
	suite._check(t, "L13", "l13_old_save_without_social", loaded and sm.hearts("gardener_hoppe") == 3)
	var drift: Dictionary = saves.gather_payload().duplicate(true)
	drift.social["npcs"]["loop_removed_citizen"] = {"p": 100, "bk": 1}
	_write(saves.slot_path(4), drift)
	var warning := "SocialManager.from_dict: unknown NPC 'loop_removed_citizen' kept in the orphans bucket"
	t.allow(warning)
	loaded = await _load(t, 4)
	suite._check(t, "L13", "l13_content_drift_is_warning", loaded and t.allowed_count(warning) == 1 and sm.to_dict().get("orphans", {}).has("loop_removed_citizen"))
	await _load(t, 3)
	saves.save_dir = directory

func _write(path: String, payload: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(payload, "\t", true, true))

func _load(t, slot: int) -> bool:
	var id: int = t.world().get_instance_id()
	var ok: bool = t.autoload("SaveManager").load_and_enter(slot)
	if ok:
		await t.until(func(): return t.world() != null and t.world().get_instance_id() != id and t.player() != null and t.world().ready_for_play, 10)
		await t.physics(3)
		owner.startup_areas.append(t.world().area.get_instance_id())
		t.autoload("GameManager").set_config_override("time.minutes_per_real_second", 0.0)
	return ok

func _places() -> Dictionary:
	var result := {}
	for id in SocialData.npcs():
		result[id] = NpcDirector.where_is(id)
	return result
