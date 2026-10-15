extends RefCounted
## Review-only reproductions. These assert intended behavior and deliberately fail on 863a583.
## Run separately from the shipping suite:
## tests/run_playtest.sh --no-import --strict --no-boot --sections-dir=res://tests/review_codex --only=review_defects
const SECTION := "review_defects"
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
	payload["quests"]["active"] = {"bad": {"id": "bad", "objectives": []}}
	_write(sm.slot_path(0), JSON.stringify(payload))
	var inspected: Dictionary = sm.inspect_slot(0)
	# This engine error is the failure being probed; SaveManager's own ApplyGuard also observes it.
	t.allow("Invalid assignment")
	var loaded: bool = sm.load_game(0)
	t.check("invalid_quest_primary_uses_good_backup", loaded and bool(inspected["from_backup"]),
		"inspect=%s, loaded=%s, last_error=%s" % [inspected["state"], loaded, sm.last_error])

func _roof_charges_twice() -> void:
	_fresh()
	t.check("roof_quest_accepts", qm.accept_quest(&"fix_roof"), "")
	eco.add_item(&"wood", 16, true)
	eco.add_item(&"moss", 8, true)
	var area := IsoArea.new()
	var marker := {"quest": "fix_roof", "objective": "repair_roof", "needs": "wood:8,moss:4", "consume": "1"}
	area.call("_on_quest_spot", null, marker)
	var after_first: int = eco.count_item(&"wood")
	area.call("_on_quest_spot", null, marker)
	t.check("completed_roof_objective_does_not_charge_again", eco.count_item(&"wood") == after_first,
		"wood after first=%s, after second=%s; quest remains active=%s" % [after_first, eco.count_item(&"wood"), qm.is_active(&"fix_roof")])
	area.free()

func _housing_required() -> void:
	_fresh()
	eco.add_item(&"baby_chick", 1, true)
	var adopted: bool = ah.adopt_animal(&"baby_chick")
	t.check("chicken_requires_a_coop", not adopted, "adopted=%s, buildings=%s, animals=%s" % [adopted, ah.buildings.size(), ah.animals.size()])

func _product_snapshot() -> void:
	_fresh()
	ah.from_dict({"v": 2, "counter": 1, "animals": {"animal_1": {"id": "animal_1", "species": "chicken", "is_baby": false,
		"age_days": 10, "happiness": 60.0, "hunger": 100.0, "products_ready": 2}}, "buildings": {}})
	var saved: Array = []
	var on_gain := func(id: StringName, _amount: int) -> void:
		if id == &"egg":
			saved.append(sm.gather_payload())
	bus.item_gained.connect(on_gain)
	ah.collect_product(&"animal_1")
	bus.item_gained.disconnect(on_gain)
	t.check("product_snapshot_captured", saved.size() == 1, "")
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
	audio.free()

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
