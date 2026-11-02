extends RefCounted
const SECTION := "npc_terminal_scope"
const TIMEOUT_S := 120.0

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SocialManager")
	var saves: Node = t.autoload("SaveManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	saves.autosave_enabled = false
	saves.save_dir = "user://npc_terminal_scope"
	var actor := Npc2D.create({"id":"carpenter_brumme", "wander":"0"})
	actor.area = t.player().area
	actor.position = t.player().position + Vector2(25, 0)
	t.player().get_parent().add_child(actor)
	var ui: Control = t.tree.get_first_node_in_group("dialogue_ui")
	actor.interact(t.player())
	t.check("actual_canonical_p0_motivation_page", await load("res://tests/sections/living_encounters.gd").new().pick(t, ui, "living_motivation"))
	await t.page_to_choices(ui)
	var selected: Button
	for button in ui._buttons:
		if button.get_meta("choice", {}).get("action") == "living_listen": selected = button
	t.check("actual_read_cast_terminal_choice", selected != null and ui._shown == ui._lines.size() and not ui._typing)
	if selected == null:
		actor.free()
		gm.clear_config_overrides()
		return
	# Create a valid, initially sparse profile only after all awaits. Never call
	# a Quest facade for p1 before either whole-row comparator.
	var unrelated: PlayerState = PlayerRegistry.state(&"p1")
	var before: Dictionary = unrelated.to_dict().duplicate(true)
	t.check("valid_initially_sparse_p1", before.quests.is_empty() and t.world().roster.validate_dict({"v":1,"rows":{"p0":PlayerRegistry._states[&"p0"].to_dict(),"p1":before}}))
	var observed: Array = []
	ui.closed.connect(func():
		# The very first close observer checks the entire row BEFORE gathering.
		observed.append({"p1":unrelated.to_dict().duplicate(true), "acting":PlayerRegistry._acting_id})
		PlayerRegistry.for_player(&"p0", func():
			observed[0]["living"] = saves.gather_payload().social.living.duplicate(true)
			observed[0]["saved"] = saves.save_game(0)), CONNECT_ONE_SHOT)
	var scoped: Array = []
	PlayerRegistry.for_player(&"p1", func():
		selected.pressed.emit() # real production callback, synchronous scope
		scoped.append(PlayerRegistry._acting_id))
	t.check("first_close_whole_sparse_p1_unchanged", observed.size() == 1 and observed[0].p1 == before, str({"before":before,"observed":observed}))
	t.check("whole_sync_unwind_sparse_p1_unchanged", unrelated.to_dict() == before and PlayerRegistry._states[&"p1"] == unrelated and PlayerRegistry._states.size() == 2, str(unrelated.to_dict()))
	t.check("caller_scope_restored_inside_and_outside", observed.size() == 1 and observed[0].acting == &"p1" and scoped == [&"p1"] and PlayerRegistry._acting_id == &"")
	var response: Dictionary = observed[0].living.get("encounters", {}).get("p0", {}).get("carpenter_brumme", {}) if observed.size() == 1 else {}
	t.check("first_close_saved_actual_p0_response", response.get("response") == "listen" and observed[0].saved == true and not observed[0].living.get("encounters", {}).has("p1"), str(response))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(saves.slot_path(0)))
	t.check("actual_disk_contains_exact_p0_response", parsed is Dictionary and parsed.social.living.encounters.p0.carpenter_brumme.response == "listen")
	t.check("exact_terminal_ui_released", ui._barrier == 0 and ui._records.is_empty() and not ui.is_open() and not gm.lifecycle_busy())
	actor.free()
	gm.clear_config_overrides()
