extends RefCounted
const SECTION := "living_encounter_lifecycle"
const TIMEOUT_S := 180.0
class RejectLate extends Node:
	var data := {"reject": false}
	func to_dict() -> Dictionary: return data.duplicate(true)
	func reset() -> void: data = {"reject": false}
	func from_dict(d: Dictionary) -> bool:
		if d.get("reject", false): return false
		data = d.duplicate(true)
		return true

func run(t) -> void:
	var helper: RefCounted = load("res://tests/sections/living_encounters.gd").new()
	for mode in ["normal", "failed", "same", "depart"]:
		await t.start_world()
		var gm: Node = t.autoload("GameManager")
		var sm: Node = t.autoload("SocialManager")
		var saves: Node = t.autoload("SaveManager")
		gm.set_config_override("time.minutes_per_real_second", 0.0)
		gm.set_config_override("towns.curfew.enabled", false)
		gm.day = 2
		gm.set_clock(18, 42)
		await t.world().travel(&"hyggebyen", &"default")
		await t.frames(6)
		var actor: Npc2D = NpcDirector.node_of("baker_maja")
		var ui: Control = t.tree.get_first_node_in_group("dialogue_ui")
		await load("res://tests/lib/town_loop/walker.gd").walk_to(t, actor.global_position, 65.0)
		actor.interact(t.player())
		await t.frames(3)
		t.check(mode + "_actual_pause_page", await helper.pick(t, ui, "living_pause"))
		var late := RejectLate.new()
		t.root.add_child(late)
		saves.register_section("living_late", late, 999)
		var payload: Dictionary = saves.gather_payload()
		if mode == "failed": payload.living_late["reject"] = true
		var observed: Array = []
		var origin: Dictionary = sm.living_encounter_origin(&"p0")
		var pending: RefCounted = actor._lease
		var armed := [true]
		var body: Node = t.player()
		var callback := func(action, _choice):
			if action != "living_help" or not armed[0]: return
			armed[0] = false
			if mode in ["failed", "same"]:
				observed.append(saves._apply_payload(payload))
				print("LIVING_ROLLBACK ", mode, " ", {"world": origin.world == sm._accounting_world, "model": is_same(origin.model, sm._living), "profile": origin.profile == PlayerRegistry._states.get(&"p0"), "ui_optional": ui.optional_allowed(pending), "suspended": sm._accounting_suspended, "day": origin.day == sm.today()})
			elif mode == "depart": t.world()._unregister_player(body)
		ui.choice_selected.connect(callback)
		t.check(mode + "_actual_help_selected", await helper.pick(t, ui, "living_help"))
		ui.choice_selected.disconnect(callback)
		await t.frames(3)
		var response: Dictionary = sm.living_snapshot().get("responses", {}).get("p0", {})
		if mode in ["normal", "failed", "depart"]:
			t.check(mode + "_earned_terminal_intent_survives", response.get("choice") == "help" and response.get("attended_day") == 0, str(response))
		else:
			t.check(mode + "_old_optional_intent_revoked", response.is_empty(), str(response))
		if mode == "failed": t.check("genuine_failed_apply_restored", observed.size() == 1 and not observed[0].ok, str(observed))
		if mode == "same": t.check("successful_same_value_apply_replaces_origin", observed.size() == 1 and observed[0].ok, str(observed))
		saves.unregister_section("living_late")
		late.queue_free()
		gm.clear_config_overrides()
