extends RefCounted
const SECTION := "persistence_save_variants"
const TIMEOUT_S := 180.0

class Counter extends Node:
	var reads := 0
	func to_dict() -> Dictionary:
		reads += 1
		return {"v":1}
	func from_dict(_d: Dictionary) -> bool: return true
	func reset() -> void: pass

class Lexical extends Node:
	var inside := false
	var invalid := true
	var outer := false
	var driver: Node
	var save: Node
	var observation := {}
	var inner_failures := []
	func to_dict() -> Variant:
		if not invalid: return {"v":1}
		if outer: return {"v":1} if driver.inside else []
		if inside: return []
		inside = true
		observation = save.gather_payload()
		inner_failures = save._gather_failures.duplicate()
		inside = false
		return {"v":1}
	func from_dict(_d: Dictionary) -> bool: return true
	func reset() -> void: pass

class QuarantineProbe extends "res://scripts/autoload/save_manager.gd":
	var callback: Callable
	func _replace_file(source: String, destination: String) -> Error:
		var result: Error = super._replace_file(source, destination)
		if destination.contains("save_auto.damaged-") and callback.is_valid(): callback.call()
		return result

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func _files(dir: String) -> Dictionary:
	var out := {}
	for name in DirAccess.get_files_at(dir): out[name] = FileAccess.get_sha256(dir.path_join(name))
	return out

func run(t) -> void:
	var sm: Node = t.autoload("SaveManager")
	var previous_dir: String = sm.save_dir
	t.on_cleanup(func(): sm.save_dir = previous_dir)
	await _invalid_auto(t)
	await _lexical(t)
	await _quarantine(t)
	await _tails(t)

func _invalid_auto(t) -> void:
	for kind in ["absent", "same", "foreign", "corrupt"]:
		for invalid in ["detached", "missing_host"]:
			for via_old in [false, true]:
				for sidecars in [false, true]:
					await _invalid_auto_case(t, kind, invalid, via_old, sidecars)

func _invalid_auto_case(t, kind: String, invalid: String, via_old: bool, sidecars: bool) -> void:
	await t.start_world()
	var sm: Node = t.autoload("SaveManager")
	var w: Node = t.world()
	sm.autosave_enabled = false
	sm.replace_via_old = via_old
	var label := kind+"_"+invalid+"_old"+str(via_old)+"_sidecars"+str(sidecars)
	sm.save_dir = "user://persistence_save_variants/invalid/"+label
	DirAccess.make_dir_recursive_absolute(sm.save_dir)
	var counter := Counter.new()
	t.root.add_child(counter)
	sm.register_section("pb_auto_counter", counter, 999)
	t.check("PB20_"+label+"_healthy_primary_backup_auto", sm.save_game(0) and sm.save_game(0) and sm.autosave())
	var payload: Dictionary = sm.gather_payload()
	if kind == "foreign": payload.meta.run_id = "different-persistence-run"
	if kind == "absent": DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT))
	else: _write(sm.slot_path(sm.AUTO_SLOT), "broken auto" if kind == "corrupt" else JSON.stringify(payload))
	if sidecars:
		_write(sm.slot_path(sm.AUTO_SLOT)+".tmp", "existing temp")
		_write(sm.slot_path(sm.AUTO_SLOT)+".old", "existing old")
		_write(sm.slot_path(sm.PREV_AUTO_SLOT), "existing previous")
		_write(sm.backup_path(0)+".tmp", "existing backup temp")
		_write(sm.backup_path(0)+".old", "existing backup old")
	var before := _files(sm.save_dir)
	var reads: int = counter.reads
	var body: Node = w.player
	var parent: Node = body.get_parent()
	var profile: Variant = PlayerRegistry._states[&"p0"]
	sm.pending_world = payload.world.duplicate(true)
	if invalid == "detached": parent.remove_child(body)
	else: PlayerRegistry._states.erase(&"p0")
	var saved: bool = sm.autosave()
	t.check("PB20_"+label+"_auto_refuses_before_codecs_and_all_file_effects", not saved and counter.reads == reads and _files(sm.save_dir) == before and sm.last_error.code == "gather" and sm.last_error.detail.contains("world") and not t.autoload("GameManager").lifecycle_busy())
	t.check("PB20_"+label+"_no_pending_fallback_or_lazy_host", sm.pending_world == payload.world and (PlayerRegistry._states.get(&"p0") == profile if invalid == "detached" else not PlayerRegistry._states.has(&"p0")))
	if invalid == "detached": parent.add_child(body)
	else: PlayerRegistry._states[&"p0"] = profile
	t.check("PB20_"+label+"_later_healthy_auto", sm.autosave() and not sm.save_failing and sm.last_error.is_empty())
	sm.unregister_section("pb_auto_counter")
	counter.free()
	sm.replace_via_old = false

func _lexical(t) -> void:
	await t.start_world()
	var sm: Node = t.autoload("SaveManager")
	sm.autosave_enabled = false
	sm.save_dir = "user://persistence_save_variants/lexical"
	t.check("PB28_healthy_file_before_invalid_serializers", sm.save_game(0))
	var before := _files(sm.save_dir)
	var inner := Lexical.new()
	var outer := Lexical.new()
	inner.name = "PBInnerSerializer"
	outer.name = "PBOuterSerializer"
	inner.save = sm
	outer.outer = true
	outer.driver = inner
	t.root.add_child(inner); t.root.add_child(outer)
	sm.register_section("pb_inner", inner, 998)
	sm.register_section("pb_outer", outer, 999)
	# Reuse the original Save negative-codec diagnostic rule, not a new kind.
	t.allow("did not return a Dictionary")
	var result: bool = sm.save_game(0)
	t.check("PB28_invalid_inner_observation_returns_dictionary_without_issuer", inner.observation.has("players") and inner.observation.has("world") and not inner.observation.has("pb_inner") and inner.observation.has("pb_outer") and inner.inner_failures == ["pb_inner"])
	t.check("PB28_independent_outer_failure_is_lexical", not result and sm.last_error.code == "gather" and sm.last_error.detail == "to_dict() failed for pb_outer" and _files(sm.save_dir) == before)
	t.expect_allowed("did not return a Dictionary", 2, "actual inner observation and outer write serializer refusals")
	outer.invalid = false
	t.check("PB28_invalid_inner_observation_cannot_poison_healthy_outer_write", sm.save_game(0) and sm.last_error.is_empty() and not sm.save_failing)
	t.expect_allowed("did not return a Dictionary", 3, "the independent successful outer write still reports its invalid inner observation")
	inner.invalid = false
	t.check("PB28_later_healthy_save_after_both_failures", sm.save_game(0) and sm.last_error.is_empty() and not sm.save_failing)
	sm.unregister_section("pb_inner"); sm.unregister_section("pb_outer")
	inner.free(); outer.free()

func _quarantine(t) -> void:
	for seam in ["quarantine", "pre_prune"]:
		for replace in [false, true]:
			await t.start_world()
			var sm: Node = t.autoload("SaveManager")
			var gm: Node = t.autoload("GameManager")
			var bus: Node = t.autoload("EventBus")
			sm.autosave_enabled = false
			var probe := QuarantineProbe.new()
			probe.save_dir = "user://persistence_save_variants/"+seam+str(replace)
			probe.autosave_enabled = false
			probe.clock_override = 100.0
			t.root.add_child(probe)
			_write(probe.slot_path(probe.AUTO_SLOT), "actual corrupt auto")
			for i in probe.QUARANTINE_KEEP + 2: _write(probe.save_dir.path_join("save_auto.damaged-%d.json" % i), "prior-%d" % i)
			var before := _files(probe.save_dir)
			var observed := []
			var saved_events := []
			var trigger := func():
				if not observed.is_empty(): return
				observed.append(gm.lifecycle_busy())
				observed.append(probe.save_game(2))
				observed.append(probe.try_load_game(0).code)
				observed.append(gm.try_start_new_game("nested", 0).code)
				if replace: PlayerRegistry.reset_states()
			var notice := func(title, _message, _icon):
				if seam == "pre_prune" and title == TranslationServer.translate("NOTIF_AUTO_SET_ASIDE_TITLE"): trigger.call()
			var saved := func(slot): saved_events.append(slot)
			bus.notification_posted.connect(notice)
			bus.save_completed.connect(saved)
			if seam == "quarantine": probe.callback = trigger
			var result: bool = probe.autosave()
			bus.notification_posted.disconnect(notice)
			bus.save_completed.disconnect(saved)
			var prefix: String = "PB29_"+seam+str(replace)
			t.check(prefix+"_actual_seam_cooperative_roots_busy", observed == [true, false, "busy", "busy"])
			t.check(prefix+"_immutable_precommit_bool_and_root_release", result == (not replace) and not gm.lifecycle_busy() and not FileAccess.file_exists(probe.slot_path(2)))
			var after := _files(probe.save_dir)
			if replace:
				before.erase(probe.slot_path(probe.AUTO_SLOT).get_file())
				after.erase("save_auto.damaged-100.json")
				t.check(prefix+"_raw_replacement_stops_prune_and_commit", after == before and saved_events.is_empty() and FileAccess.get_file_as_string(probe.save_dir.path_join("save_auto.damaged-100.json")) == "actual corrupt auto" and probe.current_slot == -1 and probe.last_error.is_empty() and not probe.save_failing)
			else:
				var quarantined: Array = Array(DirAccess.get_files_at(probe.save_dir)).filter(func(n): return n.begins_with("save_auto.damaged-"))
				t.check(prefix+"_ordinary_quarantine_prunes_and_commits", quarantined.size() == probe.QUARANTINE_KEEP and saved_events == [probe.AUTO_SLOT] and probe.inspect_slot(probe.AUTO_SLOT).state == &"ok")
			probe.callback = Callable()
			if replace: await t.start_world()
			t.check(prefix+"_next_healthy_save", probe.save_game(1) and not gm.lifecycle_busy())
			probe.free()

func _tails(t) -> void:
	for seam in ["failure_notice", "failure_signal", "success_notice"]:
		for auto in [false, true]:
			if seam == "success_notice" and auto: continue # autosaves have no success toast
			await t.start_world()
			var sm: Node = t.autoload("SaveManager")
			var gm: Node = t.autoload("GameManager")
			var bus: Node = t.autoload("EventBus")
			sm.autosave_enabled = false
			sm.save_dir = "user://persistence_save_variants/tails/"+seam+str(auto)
			t.check("PB30_"+seam+str(auto)+"_initial_primary", sm.save_game(0))
			var slot: int = sm.AUTO_SLOT if auto else 0
			var old: String = sm._file_digest(sm.slot_path(slot))
			if seam != "success_notice": DirAccess.make_dir_recursive_absolute(sm.slot_path(slot)+".tmp")
			var observations := []
			var failures := []
			var toasts := []
			var mutate := func():
				observations.append(gm.lifecycle_busy())
				observations.append(sm.autosave())
				PlayerRegistry.reset_states()
				# A raw replacement's own presentation must not be overwritten by old suffixes.
				sm.last_error = {"code":"successor"}
				sm.current_slot = 4
				sm.save_failing = false
				sm._auto_save_timer = 17.0
				t.world().game_ui.get_screen(&"hud")._show_save_state()
			var notice := func(title, _msg, _icon):
				toasts.append(title)
				if seam.ends_with("notice"): mutate.call()
			var failure := func(s, code):
				failures.append([s, code])
				if seam == "failure_signal": mutate.call()
			bus.notification_posted.connect(notice)
			bus.save_failed.connect(failure)
			var result: bool = sm.autosave() if auto else sm.save_game(slot)
			bus.notification_posted.disconnect(notice)
			bus.save_failed.disconnect(failure)
			var prefix: String = "PB30_"+seam+str(auto)
			t.check(prefix+"_actual_observer_busy_and_durability_bool", observations == [true, false] and result == (seam == "success_notice") and not gm.lifecycle_busy())
			t.check(prefix+"_successor_status_timer_immutable", sm.last_error == {"code":"successor"} and sm.current_slot == 4 and not sm.save_failing and sm._auto_save_timer == 17.0)
			t.check(prefix+"_successor_hud_not_replaced_by_old_failure_tail", t.world().game_ui.get_screen(&"hud").save_chip.get_node("SaveText").text == TranslationServer.translate("HUD_SAVED"))
			t.check(prefix+"_exact_notification_tails", toasts.size() == 1 and failures.size() == (1 if seam == "failure_signal" else 0))
			if seam != "success_notice":
				t.check(prefix+"_failed_write_keeps_actual_primary", sm._file_digest(sm.slot_path(slot)) == old)
				DirAccess.remove_absolute(sm.slot_path(slot)+".tmp")
			else: t.check(prefix+"_postcommit_actual_readback", sm.inspect_slot(slot).state == &"ok")
			await t.start_world()
			sm.autosave_enabled = false
			t.check(prefix+"_later_healthy_save_and_hud", sm.save_game(1) and sm.last_error.is_empty() and not sm.save_failing and t.world().game_ui.get_screen(&"hud").save_chip.get_node("SaveText").text == TranslationServer.translate("HUD_SAVED"))
