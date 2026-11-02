extends RefCounted
const SECTION := "npc_terminal_atomicity"
const TIMEOUT_S := 240.0

func run(t) -> void:
	var picker: RefCounted = load("res://tests/sections/living_encounters.gd").new()
	for mode in ["save", "depart", "actor_free", "cancel"]:
		await t.start_world()
		var gm: Node = t.autoload("GameManager")
		var sm: Node = t.autoload("SocialManager")
		var saves: Node = t.autoload("SaveManager")
		gm.set_config_override("time.minutes_per_real_second", 0.0)
		var actor := Npc2D.create({"id": "carpenter_brumme", "wander": "0"})
		actor.area = t.player().area
		actor.position = t.player().position + Vector2(25, 0)
		t.player().get_parent().add_child(actor)
		var ui: Control = t.tree.get_first_node_in_group("dialogue_ui")
		actor.interact(t.player())
		t.check(mode + "_cast_actual_motivation", await picker.pick(t, ui, "living_motivation"))
		var observed: Array = []
		var body: Node = t.player()
		var on_modal := func(stack):
			if stack.has(&"dialogue") or not observed.is_empty(): return
			observed.append(saves.gather_payload().social.living.duplicate(true))
			if mode == "save":
				saves.save_dir = "user://npc_terminal_atomicity"
				saves.autosave_enabled = false
				observed.append(saves.save_game(0))
			elif mode == "depart": t.world()._unregister_player(body)
			elif mode == "actor_free": actor.free()
		t.autoload("EventBus").modal_changed.connect(on_modal)
		if mode == "cancel":
			t.tap_key(KEY_ESCAPE)
			await t.frames(3)
		else: t.check(mode + "_cast_actual_listen", await picker.pick(t, ui, "living_listen"))
		t.autoload("EventBus").modal_changed.disconnect(on_modal)
		var response: Dictionary = sm.living_snapshot().get("encounters", {}).get("p0", {}).get("carpenter_brumme", {})
		var first: Dictionary = observed[0].get("encounters", {}).get("p0", {}).get("carpenter_brumme", {}) if not observed.is_empty() else {}
		t.check(mode + "_earliest_modal_observer_has_exact_terminal", first.get("response") == "listen" if mode != "cancel" else first.is_empty(), str(first))
		t.check(mode + "_earned_cast_survives_departure", response.get("response") == "listen" if mode != "cancel" else response.is_empty(), str(response))
		if mode == "save":
			t.check("earliest_observer_actual_save", observed.size() == 2 and observed[1] == true)
			t.check("earliest_observer_actual_load", saves.try_load_game(0).get("ok", false))
			t.check("earliest_saved_exact_response_survives_load", sm.living_snapshot().get("encounters", {}).get("p0", {}).get("carpenter_brumme", {}).get("response") == "listen")
		if is_instance_valid(actor): actor.free()
		gm.clear_config_overrides()
	for mode in ["normal", "depart", "actor_free", "cancel", "profile_flag"]:
		await t.start_world()
		var gm: Node = t.autoload("GameManager")
		var sm: Node = t.autoload("SocialManager")
		gm.set_config_override("time.minutes_per_real_second", 0.0)
		var actor := Npc2D.create({"id": "mayor_lyra", "wander": "0"})
		actor.area = t.player().area
		t.world().add_child(actor)
		var ui: Control = t.tree.get_first_node_in_group("dialogue_ui")
		actor.interact(t.player())
		t.check(mode + "_actual_authored_welcome", ui._lines.any(func(row): return row.get("text_key") == "DLG_LYRA_GREET_1"))
		await t.page_to_choices(ui)
		var body: Node = t.player()
		var observed: Array = []
		var on_close := func():
			if mode == "depart": t.world()._unregister_player(body)
			elif mode == "actor_free": actor.free()
		var on_flag := func(flag, value):
			if mode != "profile_flag" or flag != &"mayor_welcome_seen" or value != true or not observed.is_empty(): return
			var roster_node := PlayerRoster.new()
			var roster: Dictionary = roster_node.to_dict()
			roster_node.from_dict(roster)
			roster_node.free()
			observed.append({"social": sm.to_dict().duplicate(true), "profile": PlayerRegistry._states[&"p0"].to_dict().duplicate(true), "flags": gm.world_flags.duplicate(true)})
		ui.closed.connect(on_close, CONNECT_ONE_SHOT)
		t.autoload("EventBus").flag_changed.connect(on_flag)
		if mode == "cancel": t.tap_key(KEY_ESCAPE)
		else:
			await t.until_game(func(): return ui._choice_grace <= 0.0, 1.0)
			ui._buttons[-1].grab_focus()
			t.tap_key(KEY_ENTER)
		await t.frames(3)
		t.autoload("EventBus").flag_changed.disconnect(on_flag)
		if mode == "profile_flag":
			t.check("mayor_flag_actual_profile_replacement_reached", observed.size() == 1)
			t.check("mayor_flag_no_old_social_or_profile_suffix", observed.size() == 1 and observed[0] == {"social": sm.to_dict(), "profile": PlayerRegistry._states[&"p0"].to_dict(), "flags": gm.world_flags}, str(sm.to_dict()))
		else:
			t.check(mode + "_essential_welcome_completion", bool(gm.get_flag(&"mayor_welcome_seen", false)) == (mode != "cancel") and bool(gm.get_flag(&"mayor_welcome_pending", false)) == (mode == "cancel"))
			t.check(mode + "_appropriate_once_social_accounting", sm.points("mayor_lyra") == (0 if mode == "cancel" else 100), str(sm.points("mayor_lyra")))
		if is_instance_valid(actor): actor.free()
		gm.clear_config_overrides()
	await _preterminal_area_guard(t)
	await _replacement_controls(t)
	await _pilot_and_cast_choices(t)

class RejectLate extends Node:
	var partial := false
	var data := {"reject": false}
	func to_dict() -> Dictionary: return data.duplicate(true)
	func reset() -> void: data = {"reject": false}
	func from_dict(d: Dictionary) -> bool:
		if partial or d.get("reject", false): return false
		data = d.duplicate(true)
		return true

func _replacement_controls(t) -> void:
	for seam in ["closed", "flag"]:
		for mode in ["depart_failed", "actor_removed", "failed", "partial", "same", "primary", "backup", "profile", "reset"]:
			await t.start_world()
			var gm: Node = t.autoload("GameManager")
			var sm: Node = t.autoload("SocialManager")
			var saves: Node = t.autoload("SaveManager")
			gm.set_config_override("time.minutes_per_real_second", 0.0)
			saves.autosave_enabled = false
			saves.save_dir = "user://npc_terminal_replacement"
			var late := RejectLate.new()
			t.root.add_child(late)
			saves.register_section("npc_terminal_late", late, 999)
			# Canonical saved-profile controls, without a second physical local
			# fallback when the original p0 body genuinely departs.
			PlayerRegistry.state(&"p1")
			PlayerRegistry.for_player(&"p1", func():
				var economy: Node = t.autoload("EconomyManager")
				economy.from_dict(economy.to_dict())
				t.autoload("QuestManager").to_dict())
			var actor := Npc2D.create({"id": "mayor_lyra", "wander": "0"})
			actor.area = t.player().area
			t.world().add_child(actor)
			var ui: Control = t.tree.get_first_node_in_group("dialogue_ui")
			actor.interact(t.player())
			await t.page_to_choices(ui)
			var payload: Dictionary = saves.gather_payload()
			var p1: Dictionary = PlayerRegistry._states[&"p1"].to_dict().duplicate(true)
			var original: Variant = PlayerRegistry._states[&"p0"]
			if mode in ["primary", "backup"]:
				t.check(seam + "_" + mode + "_actual_save", saves.save_game(0) and saves.save_game(0))
				if mode == "backup":
					var f := FileAccess.open(saves.slot_path(0), FileAccess.WRITE)
					f.store_string("not json"); f.close()
			var observed: Array = []
			var body: Node = t.player()
			var transition := func():
				if not observed.is_empty(): return
				observed.append({})
				if mode == "depart_failed": t.world()._unregister_player(body)
				if mode == "actor_removed": t.world().remove_child(actor)
				if mode in ["depart_failed", "failed", "partial", "same"]:
					var incoming: Dictionary = payload.duplicate(true)
					if mode != "same": incoming.npc_terminal_late.reject = true
					late.partial = mode == "partial"
					observed[0]["result"] = saves._apply_payload(incoming)
				elif mode in ["primary", "backup"]: observed[0]["result"] = saves.try_load_game(0)
				elif mode == "profile": observed[0]["replaced"] = t.world().roster.from_dict(payload.players)
				elif mode == "reset": gm.start_new_game("Terminal new", gm.character_type, "New")
				observed[0]["winner"] = {"social": sm.to_dict().duplicate(true), "p0": PlayerRegistry._states[&"p0"].to_dict().duplicate(true), "p1": PlayerRegistry._states[&"p1"].to_dict().duplicate(true) if PlayerRegistry._states.has(&"p1") else {}, "flags": gm.world_flags.duplicate(true)}
			var on_close := func():
				if seam == "closed": PlayerRegistry.for_player(&"p0", transition)
			var on_flag := func(flag, value):
				if seam == "flag" and flag == &"mayor_welcome_seen" and value == true: PlayerRegistry.for_player(&"p0", transition)
			ui.closed.connect(on_close, CONNECT_ONE_SHOT)
			t.autoload("EventBus").flag_changed.connect(on_flag)
			await t.until_game(func(): return ui._choice_grace <= 0.0, 1.0)
			ui._buttons[-1].grab_focus()
			# Dispatch the real button callback synchronously so the deliberately
			# conflicting scope and the immediate unwind snapshot are meaningful;
			# Input.parse_input_event is queued (real Enter is covered above).
			var selected: Button = ui._buttons[-1]
			PlayerRegistry.for_player(&"p1", func(): selected.pressed.emit())
			# Judge the old synchronous unwind before independent next-frame
			# simulation is allowed to make healthy progress in a reset winner.
			t.autoload("EventBus").flag_changed.disconnect(on_flag)
			var label: String = seam + "_" + mode
			var earned: bool = mode in ["depart_failed", "actor_removed", "failed"]
			t.check(label + "_actual_transition_once", observed.size() == 1)
			if earned:
				t.check(label + "_exact_original_essential_completion", PlayerRegistry._states[&"p0"] == original and bool(gm.get_flag(&"mayor_welcome_seen", false)) and not bool(gm.get_flag(&"mayor_welcome_pending", false)) and sm.points("mayor_lyra") == 100, str({"same_profile":PlayerRegistry._states[&"p0"] == original,"seen":gm.get_flag(&"mayor_welcome_seen", false),"pending":gm.get_flag(&"mayor_welcome_pending", false),"points":sm.points("mayor_lyra")}))
				if mode != "actor_removed": t.check(label + "_verified_complete_failed_apply", not observed[0].result.ok and not sm._accounting_suspended)
			else:
				var winner: Dictionary = {"social": sm.to_dict(), "p0": PlayerRegistry._states[&"p0"].to_dict(), "p1": PlayerRegistry._states[&"p1"].to_dict() if PlayerRegistry._states.has(&"p1") else {}, "flags": gm.world_flags}
				t.check(label + "_no_old_suffix_in_winner", observed.size() == 1 and observed[0].winner == winner, str({"before":observed[0].winner,"after":winner}))
				if mode in ["same", "primary", "backup"]: t.check(label + "_successful_real_replacement", observed[0].result.ok and PlayerRegistry._states[&"p0"] != original)
			if mode != "reset": t.check(label + "_whole_unrelated_p1_unchanged", PlayerRegistry._states[&"p1"].to_dict() == p1, str({"before":p1,"after":PlayerRegistry._states[&"p1"].to_dict()}))
			t.check(label + "_exact_ui_cleanup", ui._barrier == 0 and ui._records.is_empty() and not ui._session and not gm.lifecycle_busy() and PlayerRegistry._acting_id == &"")
			late.partial = false
			saves.unregister_section("npc_terminal_late")
			late.free(); actor.free()
			gm.clear_config_overrides()

func _pilot_and_cast_choices(t) -> void:
	var picker: RefCounted = load("res://tests/sections/living_encounters.gd").new()
	for action in ["living_space", "living_confirm", "living_help", "living_defer", "living_decline"]:
		await t.start_world()
		var gm: Node = t.autoload("GameManager")
		var sm: Node = t.autoload("SocialManager")
		gm.set_config_override("time.minutes_per_real_second", 0.0)
		gm.set_config_override("towns.curfew.enabled", false)
		var pilot: bool = action in ["living_help", "living_defer", "living_decline"]
		var actor: Npc2D
		if pilot:
			gm.day = 2; gm.set_clock(18, 42)
			await t.world().travel(&"hyggebyen", &"default")
			await t.frames(6)
			actor = NpcDirector.node_of("baker_maja")
			await load("res://tests/lib/town_loop/walker.gd").walk_to(t, actor.global_position, 65.0)
		else:
			actor = Npc2D.create({"id": "carpenter_brumme", "wander": "0"})
			actor.area = t.player().area
			actor.position = t.player().position + Vector2(25, 0)
			t.player().get_parent().add_child(actor)
		var ui: Control = t.tree.get_first_node_in_group("dialogue_ui")
		actor.interact(t.player())
		t.check(action + "_actual_page_reached", await picker.pick(t, ui, "living_pause" if pilot else "living_motivation"))
		if action == "living_confirm": t.check("confirm_actual_correction_page_reached", await picker.pick(t, ui, "living_correct"))
		var before: Dictionary = sm.living_snapshot()
		ui.choice_selected.emit(action, {"action": action, "player_id": "p1"})
		actor.handle_choice(action, {"action": action, "player_id": "p1"})
		t.check(action + "_public_notifications_not_authority", sm.living_snapshot() == before)
		var observations: Array = []
		var on_close := func(): observations.append(t.autoload("SaveManager").gather_payload().social.living.duplicate(true))
		ui.closed.connect(on_close, CONNECT_ONE_SHOT)
		t.check(action + "_actual_ui_selection", await picker.pick(t, ui, action))
		var snapshot: Dictionary = observations[0] if observations.size() == 1 else {}
		var response: Dictionary = snapshot.get("responses", {}).get("p0", {}) if pilot else snapshot.get("encounters", {}).get("p0", {}).get("carpenter_brumme", {})
		t.check(action + "_earliest_closed_saved_exact_choice", response.get("choice" if pilot else "response") == ("clarify" if action == "living_confirm" else action.trim_prefix("living_")), str(response))
		t.check(action + "_does_not_authorize_p1", not snapshot.get("responses", {}).has("p1") and not snapshot.get("encounters", {}).has("p1"))
		if not pilot: actor.free()
		gm.clear_config_overrides()

func _preterminal_area_guard(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SocialManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	var actor := Npc2D.create({"id": "mayor_lyra", "wander": "0"})
	actor.area = t.player().area
	t.world().add_child(actor)
	var ui: Control = t.tree.get_first_node_in_group("dialogue_ui")
	actor.interact(t.player())
	await t.page_to_choices(ui)
	t.check("area_negative_actual_authored_page", ui._lines.any(func(row): return row.get("text_key") == "DLG_LYRA_GREET_1"))
	actor.area = null
	var removed: Array = []
	ui.closed.connect(func():
		actor.free()
		removed.append(true), CONNECT_ONE_SHOT)
	ui._buttons[-1].pressed.emit()
	t.check("area_negative_actual_actor_removal_after_terminal", removed == [true])
	t.check("area_negative_cannot_earn_from_changed_original_area", not bool(gm.get_flag(&"mayor_welcome_seen", false)) and bool(gm.get_flag(&"mayor_welcome_pending", false)) and sm.points("mayor_lyra") == 0)
	gm.clear_config_overrides()
