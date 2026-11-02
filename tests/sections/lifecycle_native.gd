extends RefCounted
const SECTION := "lifecycle_native"
const TIMEOUT_S := 120.0
func run_windowed(t) -> void:
	if not await t.boot(): return
	var gm: Node = t.autoload("GameManager")
	var saves: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	var social: Node = t.autoload("SocialManager")
	saves.save_dir = "user://admission_native"
	saves.autosave_enabled = false
	t.check("real_select_bootstrap_finished_idle",t.world().ready_for_play and not gm.lifecycle_busy())
	gm.set_config_override("time.minutes_per_real_second",0.0)
	gm.set_clock(19,0)
	var earned: int = social.points("smith_thorin",&"p0")
	var snapshots: Array = []
	var on_day := func(_day,_season):
		var living: Dictionary = social.to_dict().get("living",{}).duplicate(true)
		var ok: bool = saves.save_game(0)
		snapshots.append({"ok":ok,"day":gm.day,"living":living,"hash":FileAccess.get_sha256(saves.slot_path(0)) if ok else ""})
	bus.day_started.connect(on_day,CONNECT_ONE_SHOT)
	await t.world().sleep()
	t.check("real_sleep_day_started_synchronous_save",snapshots.size() == 1 and snapshots[0].ok and snapshots[0].day == gm.day)
	var file := FileAccess.open(saves.slot_path(0),FileAccess.READ)
	var payload: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	# The real load validator canonicalizes JSON's whole floats to ints. Raw
	# Dictionary equality with an in-memory int codec is not a valid disk oracle.
	var checked: Dictionary = saves.validate_payload(payload)
	t.check("sleep_file_validated_projection_matches_observer",checked.ok and checked.payload.game.day == snapshots[0].day and checked.payload.has("social") and checked.payload.social.get("living",{}) == snapshots[0].living)
	await t.go_menu()
	var observer: Array = []
	bus.load_completed.connect(func(_slot):observer.append(gm.try_start_new_game("Refused native",gm.character_type)),CONNECT_ONE_SHOT)
	var menu: Node = t.tree.current_scene
	t.check("native_title_continue_enabled",not menu.get_node("%ContinueButton").disabled)
	if not t.press("%ContinueButton"): return
	t.check("native_continue_click_reserves_root",gm.lifecycle_busy())
	await t.until(func():return t.world() != null and t.world().ready_for_play,20.0)
	await t.frames(3)
	t.check("native_continue_observer_busy_until_world_ready",observer.size() == 1 and observer[0].code == "busy" and not gm.lifecycle_busy())
	t.check("native_continue_exact_saved_day_no_extra_reward",gm.day == snapshots[0].day and social.points("smith_thorin",&"p0") == earned and FileAccess.get_sha256(saves.slot_path(0)) == snapshots[0].hash)
	await t.capture("admission_native_continue")
	gm.clear_config_overrides()
