extends SceneTree
# Controlled playback-retirement sentinel exercises the REAL production
# prepare_shutdown frame loop, not a claim about a native mixer stall.
# Baseline's actual SceneTree.quit(44) is isolated to this throwaway driver.
var result := {"mode":"headless controlled playback-retirement await; no native acceptance", "checks":{}, "completed":false}
var report_path := ""
var marker: RefCounted
var positive := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--positive": positive = true
		if arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
	_run.call_deferred()

func check(id: String, value: bool) -> void:
	result.checks[id] = value
	print(("ok " if value else "FAIL ")+id)

func _run() -> void:
	var gm: Node = root.get_node("GameManager")
	var registry: Script = load("res://scripts/world2d/player_registry.gd")
	var audio: Node = root.get_node("AudioManager")
	var sm: Node = root.get_node("SaveManager")
	sm.autosave_enabled = false
	# A no-World bootstrap must not manufacture p0 just to authorize closing.
	registry._states.clear()
	var rows: int = registry._states.size()
	if positive:
		await gm.quit_game(46,false)
		check("CS_POS_same_origin_real_shutdown_dispatch_retains_pause_audio_and_no_profile_creation", gm._quitting and audio._shutting_down and paused and registry._states.size() == rows and not gm.lifecycle_busy())
		result.completed = true
		result["success"] = result.checks.values().all(func(value): return value)
		result["expected_actual_exit"] = 46
		return # ORIGINAL production SceneTree.quit(46), not a terminal seam
	marker = RefCounted.new()
	audio._playbacks.clear()
	audio._playbacks.append(weakref(marker))
	var returned := []
	var close := func():
		await gm.quit_game(44, false)
		returned.append(true)
	close.call()
	check("CS01_real_shutdown_await_entered_without_lifecycle_or_profile_creation", gm._quitting and audio._shutting_down and returned.is_empty() and not gm.lifecycle_busy() and registry._states.size() == rows)
	# Supported model-only operation, while the actual shutdown loop is awaiting.
	var replacement: Dictionary = gm.try_start_new_game("Shutdown replacement",gm.CharacterType.ANIMAL,"retained driver")
	check("CS02_supported_model_replacement_during_real_audio_await", replacement.ok and not gm.lifecycle_busy())
	gm.push_modal(&"successor_pause",true)
	# Fresh audio entry must revoke the old global silence gate BEFORE its old
	# await wakes, and its later cleanup must not clear the new deduplication ids.
	audio.play_ambience("farm_day",0.0)
	audio.play_rain(true)
	check("CS07_fresh_audio_during_old_await_is_not_silently_dropped", not audio._shutting_down and audio._ambient_id == "farm_day" and audio._rain_id == "rain")
	marker = null
	for frame in 5: await process_frame
	check("CS03_old_shutdown_returned_instead_of_actual_exit44", returned == [true])
	check("CS04_exact_old_shutdown_cleanup_preserves_new_pause_releases_audio_gate", not gm._quitting and not gm._quit_asking and not audio._shutting_down and gm.is_modal_open(&"successor_pause") and paused and not gm.is_modal_open(&"quit_shutdown") and audio._ambient_id == "farm_day" and audio._rain_id == "rain")
	# Later ordinary quit through the retained public safe terminal seam progresses.
	var codes := []
	gm.quit_seam = func(code): codes.append(code)
	await gm.quit_game(45,false)
	check("CS05_next_fresh_request_progresses_and_preserves_new_pause", codes == [45] and not gm._quitting and paused)
	gm.quit_seam = Callable()
	gm.pop_modal(&"successor_pause")
	check("CS06_no_old_pause_or_admission_leak", not paused and not gm.lifecycle_busy())
	# The DRIVER now closes itself. Retire the fresh real Ogg streams through
	# production shutdown before its own exit; do not confuse teardown leaks with
	# the already-observed old-request ownership oracle above.
	await audio.prepare_shutdown()
	result.completed = true
	var success: bool = result.checks.values().all(func(value): return value)
	result["success"] = success
	quit(0 if success else 1)

func _finalize() -> void:
	# This endpoint runs even when baseline's ORIGINAL quit(44) wins. The external
	# receipt retains the real process code, so missing normal completion is RED.
	result["finalized"] = true
	if not result.completed: result["success"] = false
	if not report_path.is_empty():
		var file := FileAccess.open(report_path,FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"  ")); file.close()
	print("SHUTDOWN_DRIVER_RESULT "+JSON.stringify(result))
