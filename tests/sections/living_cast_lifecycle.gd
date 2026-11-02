extends RefCounted
const SECTION := "living_cast_lifecycle"
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
	var picker: RefCounted = load("res://tests/sections/living_encounters.gd").new()
	for mode in ["normal", "failed", "same", "depart", "unread_depart"]:
		await t.start_world()
		var gm: Node = t.autoload("GameManager")
		var sm: Node = t.autoload("SocialManager")
		var saves: Node = t.autoload("SaveManager")
		gm.set_config_override("time.minutes_per_real_second", 0.0)
		var actor := Npc2D.create({"id": "carpenter_brumme", "wander": "0"})
		actor.area = t.player().area
		actor.position = t.player().position + Vector2(25, 0)
		t.player().get_parent().add_child(actor)
		var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
		actor.interact(t.player())
		await t.frames(3)
		t.check(mode + "_real_cast_motivation_page", await picker.pick(t, screen, "living_motivation"))
		var late := RejectLate.new()
		t.root.add_child(late)
		saves.register_section("living_cast_late", late, 999)
		var payload: Dictionary = saves.gather_payload()
		if mode == "failed": payload.living_cast_late["reject"] = true
		var observed: Array = []
		var armed := [true]
		var body: Node = t.player()
		var callback := func(action, _choice):
			if action != "living_listen" or not armed[0]: return
			armed[0] = false
			if mode in ["failed", "same"]: observed.append(saves._apply_payload(payload))
			elif mode == "depart": t.world()._unregister_player(body)
		screen.choice_selected.connect(callback)
		if mode == "unread_depart":
			t.world()._unregister_player(body)
			await t.frames(3)
			t.tap_key(KEY_ENTER)
			await t.frames(3)
		else:
			t.check(mode + "_actual_read_repeatback_choice", await picker.pick(t, screen, "living_listen"))
		screen.choice_selected.disconnect(callback)
		await t.frames(3)
		var response: Dictionary = sm.living_snapshot().get("encounters", {}).get("p0", {}).get("carpenter_brumme", {})
		t.check(mode + "_exact_terminal_lifecycle_result", response.get("response") == "listen" if mode in ["normal", "failed", "depart"] else response.is_empty(), str(response))
		if mode == "failed": t.check("genuine_failed_full_apply_retains_already_earned_cast_prefix", observed.size() == 1 and not observed[0].ok)
		if mode == "same": t.check("successful_same_valued_apply_revokes_old_cast_suffix", observed.size() == 1 and observed[0].ok)
		saves.unregister_section("living_cast_late")
		late.queue_free()
		actor.queue_free()
		await t.frames(2)
		gm.clear_config_overrides()
