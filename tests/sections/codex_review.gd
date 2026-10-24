extends RefCounted
## Regressions promoted from the isolated review reproductions on 863a583.
const SECTION := "codex_review"
const TIMEOUT_S := 120.0

class ProbeAudio extends "res://scripts/autoload/audio_manager.gd":
	var streams: Dictionary = {}
	func _load_stream(_base_dir: String, id: String) -> AudioStream:
		if not streams.has(id):
			var wav := AudioStreamWAV.new()
			wav.format = AudioStreamWAV.FORMAT_8_BITS
			wav.mix_rate = 8000
			var bytes := PackedByteArray()
			bytes.resize(24000)
			bytes.fill(128)
			wav.data = bytes
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_end = bytes.size()
			streams[id] = wav
		return streams[id]

class FailedReplacement extends "res://scripts/autoload/save_manager.gd":
	func _replace_file(_source: String, _destination: String) -> Error:
		return ERR_FILE_CANT_WRITE

var t
var gm: Node
var eco: Node
var qm: Node
var sm: Node
var ah: Node
var bus: Node

func run(p_t) -> void:
	t = p_t
	gm = t.autoload("GameManager")
	eco = t.autoload("EconomyManager")
	qm = t.autoload("QuestManager")
	sm = t.autoload("SaveManager")
	ah = t.autoload("AnimalHusbandry")
	bus = t.autoload("EventBus")
	await t.go_menu()
	var keep_dir: String = sm.save_dir
	var keep_auto: bool = sm.autosave_enabled
	var scratch := "user://codex_review_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(scratch)
	sm.save_dir = scratch
	sm.autosave_enabled = false
	_config(scratch)
	_missing_primary()
	_malformed_primary()
	_quest_validation()
	_replacement_failure(scratch)
	_roof_charges_twice()
	_housing_required()
	_product_snapshot()
	await _music_races()
	await _midnight_in_transit()
	await t.go_menu()
	gm.clear_config_overrides()
	t.autoload("LuaRuntime").reload_scripts()
	_fresh()
	sm.save_dir = keep_dir
	sm.autosave_enabled = keep_auto
	for f in DirAccess.get_files_at(scratch):
		DirAccess.remove_absolute(scratch.path_join(f))
	DirAccess.remove_absolute(scratch)

func _fresh() -> void:
	gm.start_new_game("Review", gm.CharacterType.ANIMAL, "Review farm")
	gm.change_phase(gm.GamePhase.MENU)
	eco.inventory.clear()

func _write(path: String, value: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(value)
	f.close()

func _config(scratch: String) -> void:
	gm.invalidate_config_cache()
	var first: Variant = gm.config_value("codex_review.value", 11)
	var second: Variant = gm.config_value("codex_review.value", 22)
	t.check("config_fallback_is_per_call", second == 22, "first=%s, second=%s, expected second=22" % [first, second])
	var path := scratch.path_join("config.lua")
	_write(path, "kind = \"config\"\nconfig = { codex_review = { value = 99 } }\n")
	var lr: Node = t.autoload("LuaRuntime")
	lr.load_file(path)
	t.check("config_sees_loaded_key", gm.config_value("codex_review.value", 0) == 99,
		"Lua=%s, GameManager=%s" % [lr.get_config("codex_review.value"), gm.config_value("codex_review.value", 0)])
	_write(path, "kind = \"config\"\nconfig = { codex_review = { value = 101 } }\n")
	lr.load_file(path)
	t.check("config_refreshes_cached_value", gm.config_value("codex_review.value", 0) == 101, "incremental load invalidates an existing cached value")
	lr.reload_scripts()

func _missing_primary() -> void:
	_fresh()
	t.check("backup_first_save", sm.save_game(0), "")
	t.check("backup_second_save", sm.save_game(0), "")
	DirAccess.remove_absolute(sm.slot_path(0))
	var state: String = str(sm.inspect_slot(0)["state"])
	t.check("missing_primary_recovers_backup", sm.load_game(0), "backup exists=%s, inspect=%s" % [FileAccess.file_exists(sm.backup_path(0)), state])

func _malformed_primary() -> void:
	_fresh()
	t.check("malformed_backup_created", sm.save_game(0) and sm.save_game(0), "")
	var payload: Dictionary = sm.gather_payload()
	payload["players"]["rows"]["p0"]["quests"]["active"] = {"bad": {"id": "bad", "objectives": []}}
	_write(sm.slot_path(0), JSON.stringify(payload))
	var inspected: Dictionary = sm.inspect_slot(0)
	var loaded: bool = sm.load_game(0)
	t.check("invalid_quest_primary_uses_good_backup", loaded and bool(inspected["from_backup"]),
		"inspect=%s, loaded=%s, last_error=%s" % [inspected["state"], loaded, sm.last_error])

func _quest_validation() -> void:
	_fresh()
	qm.accept_quest(&"fix_roof")
	var good: Dictionary = qm.to_dict()
	var bad: Array = []
	for objectives in [[], "broken", {"repair_roof": []}, {"repair_roof": {"current": "bad", "target": 1, "done": false}},
		{"repair_roof": {"current": 0, "target": -1, "done": false}}, {"repair_roof": {"current": 0, "target": 1, "done": "false"}}]:
		var data := good.duplicate(true)
		data["active"]["fix_roof"]["objectives"] = objectives
		bad.append(data)
	for field in ["id", "state", "meta", "started_day"]:
		var data := good.duplicate(true)
		data["active"]["fix_roof"][field] = []
		bad.append(data)
	for i in bad.size():
		t.check("invalid_quest_record_%d" % i, not qm.validate_dict(bad[i]) and not qm.from_dict(bad[i])
			and qm.to_dict() == good, "rejected before replacing live state")

func _replacement_failure(scratch: String) -> void:
	_fresh()
	var manager := FailedReplacement.new()
	manager.save_dir = scratch
	manager.autosave_enabled = false
	t.root.add_child(manager)
	var target := scratch.path_join("replacement.json")
	_write(target, "old bytes")
	t.check("failed_replacement_keeps_target", not manager._write_atomic(target, "new bytes")
		and FileAccess.get_file_as_string(target) == "old bytes" and not FileAccess.file_exists(target + ".tmp"), "rename failure never unlinks the old file")
	sm.save_game(0)
	sm.save_game(0)
	var backup: PackedByteArray = FileAccess.get_file_as_bytes(sm.backup_path(0))
	manager._roll_backup(0)
	t.check("failed_backup_replacement_keeps_backup", FileAccess.get_file_as_bytes(sm.backup_path(0)) == backup
		and not FileAccess.file_exists(sm.backup_path(0) + ".tmp"), "last good backup survives rename failure")
	manager.free()

func _roof_charges_twice() -> void:
	_fresh()
	t.check("roof_quest_accepts", qm.accept_quest(&"fix_roof"), "")
	eco.add_item(&"wood", 16, true)
	eco.add_item(&"moss", 8, true)
	var area := IsoArea.new()
	var marker := {"quest": "fix_roof", "objective": "repair_roof", "needs": "wood:8,moss:4", "consume": "1"}
	var snapshots: Array = []
	var on_change := func(_player_id: StringName, _inventory: Dictionary) -> void:
		snapshots.append(sm.gather_payload())
		area.call("_on_quest_spot", null, marker)
	bus.player_inventory_changed.connect(on_change)
	area.call("_on_quest_spot", null, marker)
	bus.player_inventory_changed.disconnect(on_change)
	var after_first: int = eco.count_item(&"wood")
	t.check("roof_cost_and_progress_commit_together", after_first == 8 and eco.count_item(&"moss") == 4 and snapshots.size() == 1
		and snapshots[0]["players"]["rows"]["p0"]["quests"]["active"]["fix_roof"]["objectives"]["repair_roof"]["done"], "inventory callback sees the complete transaction and cannot reenter it")
	area.call("_on_quest_spot", null, marker)
	t.check("completed_roof_objective_does_not_charge_again", eco.count_item(&"wood") == after_first,
		"wood after first=%s, after second=%s; quest remains active=%s" % [after_first, eco.count_item(&"wood"), qm.is_active(&"fix_roof")])
	_fresh()
	qm.accept_quest(&"fix_roof")
	eco.add_item(&"wood", 8, true)
	eco.add_item(&"moss", 3, true)
	area.call("_on_quest_spot", null, marker)
	t.check("short_roof_cost_changes_nothing", eco.count_item(&"wood") == 8 and eco.count_item(&"moss") == 3
		and not qm.get_quest_progress(&"fix_roof")["objectives"]["repair_roof"]["done"], "missing the second resource does not take the first")
	area.free()

func _housing_required() -> void:
	_fresh()
	eco.add_item(&"baby_chick", 1, true)
	var adopted: bool = ah.adopt_animal(&"baby_chick")
	t.check("chicken_requires_a_coop", not adopted and eco.count_item(&"baby_chick") == 1, "missing housing keeps the item")
	ah.from_dict({"v": 2, "counter": 0, "animals": {}, "buildings": {"coop_1": {"id": "coop_1", "building_type": "coop", "is_built": false}}})
	t.check("unfinished_coop_refuses_adoption", not ah.adopt_animal(&"baby_chick") and eco.count_item(&"baby_chick") == 1, "")
	ah.buildings[&"coop_1"].is_built = true
	var snapshots: Array = []
	var on_change := func(_player_id: StringName, _inventory: Dictionary) -> void: snapshots.append(sm.gather_payload())
	bus.player_inventory_changed.connect(on_change)
	adopted = ah.adopt_animal(&"baby_chick")
	bus.player_inventory_changed.disconnect(on_change)
	t.check("adoption_uses_selected_housing", adopted and ah.animals.size() == 1 and ah.animals.values()[0].building_id == &"coop_1"
		and ah.buildings[&"coop_1"].animals_inside.size() == 1, "")
	t.check("adoption_snapshot_is_committed", snapshots.size() == 1 and snapshots[0]["husbandry"]["animals"].size() == 1
		and eco.count_item(&"baby_chick") == 0, "inventory listener sees both the consumed item and its housed animal")
	var capacity: int = ah.get_building_capacity(&"coop")
	eco.add_item(&"baby_chick", capacity, true)
	for i in range(1, capacity):
		ah.adopt_animal(&"baby_chick")
	t.check("full_coop_refuses_adoption", not ah.adopt_animal(&"baby_chick") and eco.count_item(&"baby_chick") == 1
		and ah.buildings[&"coop_1"].animals_inside.size() == capacity, "housing occupancy matches adoption capacity")

func _product_snapshot() -> void:
	_fresh()
	ah.from_dict({"v": 2, "counter": 1, "animals": {"animal_1": {"id": "animal_1", "species": "chicken", "is_baby": false,
		"age_days": 10, "happiness": 60.0, "hunger": 100.0, "products_ready": 2}}, "buildings": {}})
	var saved: Array = []
	var reentrant: Array = []
	var on_gain := func(_player_id: StringName, id: StringName, _amount: int) -> void:
		if id == &"egg":
			saved.append(sm.gather_payload())
			reentrant.append(ah.collect_product(&"animal_1"))
	bus.item_gained.connect(on_gain)
	ah.collect_product(&"animal_1")
	bus.item_gained.disconnect(on_gain)
	t.check("product_snapshot_captured", saved.size() == 1, "")
	t.check("product_collection_blocks_reentry", reentrant == [0], "")
	if saved.is_empty():
		return
	sm.call("_apply_payload", saved[0])
	var recollected: int = ah.collect_product(&"animal_1")
	t.check("product_snapshot_cannot_be_claimed_twice", recollected == 0 and eco.count_item(&"egg") == 2,
		"after loading the item_gained snapshot: recollected=%s, total eggs=%s" % [recollected, eco.count_item(&"egg")])

func _music_races() -> void:
	var audio := ProbeAudio.new()
	t.root.add_child(audio)
	audio.play_music("first", 0.0)
	audio.play_music("stale", 0.4)
	audio.play_music("latest", 0.0)
	await t.tree.create_timer(0.35).timeout
	t.check("latest_music_request_wins", audio._music_player.stream == audio.streams["latest"],
		"older request resumed after its fade and replaced the latest stream")
	audio.stop_music(0.15)
	audio.play_music("new_after_stop", 0.0)
	await t.tree.create_timer(0.25).timeout
	t.check("old_stop_cannot_stop_new_track", audio._music_player.playing, "old stop callback ran against new track")
	audio.play_music("discarded", 0.2)
	audio.stop_music(0.0)
	await t.tree.create_timer(0.3).timeout
	t.check("stop_cancels_pending_music", not audio._music_player.playing, "a queued stream cannot restart playback after stop")
	audio.play_music("same", 0.0)
	audio.play_music("discarded", 0.2)
	audio.play_music("same", 0.0)
	await t.tree.create_timer(0.3).timeout
	t.check("same_track_cancels_replacement", audio._music_player.stream == audio.streams["same"]
		and is_equal_approx(audio._music_player.volume_db, audio.music_volume_db) and is_equal_approx(audio._fader_db(audio._music_fader), 0.0)
		and audio._music_fader != AudioManager._music_fader, "requesting the playing track cancels pending replacement and restores volume (on the probe's own fader bus)")
	var fader: String = audio._music_fader
	audio.free()
	t.check("probe_fader_bus_removed", AudioServer.get_bus_index(fader) == -1, fader)

func _midnight_in_transit() -> void:
	await t.start_world("animal")
	var world: Node = t.world()
	t.autoload("TimeManager").pause_time()
	gm.hour = 23
	gm.minute = 59
	world.travel(&"traetoppen", &"default")
	gm.advance_time(1)
	await t.until(func() -> bool: return not world.traveling, 10.0)
	await t.frames(3)
	t.check("midnight_during_travel_still_wakes_at_morning", gm.hour >= gm.day_start_hour(),
		"day=%s, hour=%s, sleeping=%s, traveling=%s" % [gm.day, gm.hour, world.sleeping, world.traveling])
