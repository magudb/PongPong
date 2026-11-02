extends RefCounted
const SECTION := "dialogue_load_lifecycle"
const TIMEOUT_S := 90.0
class Section extends Node:
	var invalid_snapshot := false
	var data := {"v": 1, "reject": false}
	func to_dict() -> Variant: return null if invalid_snapshot else data.duplicate(true)
	func reset() -> void: data = {"v": 1, "reject": false}
	func from_dict(d: Dictionary) -> bool:
		if d.get("reject", false): return false
		data = d.duplicate(true)
		return true
func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var saves: Node = t.autoload("SaveManager")
	var sm: Node = t.autoload("SocialManager")
	var bus: Node = t.autoload("EventBus")
	var section := Section.new()
	t.tree.root.add_child(section)
	saves.register_section("dialogue_load_section", section, 999)
	saves.save_dir = "user://dialogue_load_lifecycle"
	saves.autosave_enabled = false
	for mode in ["load", "failed", "snapshot", "backup"]:
		# Persistence host bindings are established by a real fresh World, not
		# a model-only reset leaving an old body's profile behind (D09).
		await t.start_world("", "Loaded", "Loaded")
		gm.set_config_override("time.minutes_per_real_second", 0.0)
		saves.delete_save(0)
		t.check(mode + "_save_ready", saves.save_game(0))
		if mode in ["failed", "backup"]:
			var payload: Dictionary = saves.gather_payload()
			payload.dialogue_load_section["reject"] = true
			var file := FileAccess.open(saves.slot_path(0), FileAccess.WRITE)
			file.store_string(JSON.stringify(payload))
			file.close()
			if mode == "backup":
				payload.dialogue_load_section["reject"] = false
				var backup := FileAccess.open(saves.backup_path(0), FileAccess.WRITE)
				backup.store_string(JSON.stringify(payload))
				backup.close()
		gm.set_flag(&"dialogue_load_probe", true)
		var actor := Npc2D.create({"id": "smith_thorin", "wander": "0"})
		t.world().add_child(actor)
		var ui: Control = t.tree.get_first_node_in_group("dialogue_ui")
		actor.interact(t.player())
		await t.page_to_choices(ui)
		var ticket: RefCounted = actor._lease
		var shown: int = ui._shown
		t.check(mode + "_live_page_held_before_load", ui.is_open() and actor.is_talking and actor._held and ticket != null)
		var starts: Array = []
		var claims: Array = []
		var on_start := func(_npc, _module): starts.append(true)
		var on_flag := func(flag, value):
			if flag != &"dialogue_load_probe" or value != false: return
			var candidate: RefCounted = ui.request_page(null, {"id": "mayor_lyra"}, [{"text_key": "DLG_LYRA_HELLO"}], [], {"replace": true})
			claims.append(candidate)
		bus.dialogue_started.connect(on_start)
		bus.flag_changed.connect(on_flag)
		section.invalid_snapshot = mode == "snapshot"
		var loaded: bool = saves.load_game(0)
		section.invalid_snapshot = false
		bus.flag_changed.disconnect(on_flag)
		bus.dialogue_started.disconnect(on_start)
		t.check(mode + "_load_return_contract", loaded == (mode in ["load", "backup"]))
		if mode == "snapshot":
			t.check("snapshot_preflight_leaves_exact_page_untouched", ui._active == ticket and ui._shown == shown and actor._held and claims.is_empty() and not ticket.resolved)
		else:
			t.check(mode + "_claims_fenced_during_apply", claims.size() == (2 if mode == "backup" else 1) and claims.all(func(candidate): return candidate.resolved and bool(candidate._result.get("refused", false))))
		if mode in ["load", "backup"]:
			t.check(mode + "_old_page_cancelled_without_rewards", ticket.resolved and not ui.is_open() and not actor.is_talking and not actor._held and sm.points("smith_thorin") == 0)
		else:
			t.check(mode + "_rollback_restores_same_page_without_replay", ui._active == ticket and ui._shown == shown and actor._held and starts.is_empty() and not ticket.resolved)
			if ui._active == ticket:
				for button in ui._buttons:
					if button.get_meta("choice").get("action") == "close":
						button.pressed.emit()
						break
				t.check(mode + "_earned_completion_once_after_refusal", sm.points("smith_thorin") == 100 and ticket.resolved and not actor._held)
		if ui.is_open(): ui.close()
		actor.free()
		await t.frames(2)
	saves.unregister_section("dialogue_load_section")
	section.free()
	gm.clear_config_overrides()
