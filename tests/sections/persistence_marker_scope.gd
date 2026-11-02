extends RefCounted
const SECTION := "persistence_marker_scope"
const TIMEOUT_S := 180.0

func run(t) -> void:
	for kind in ["garden", "mother", "work"]:
		for populated in [false, true]:
			for complete in [false, true]:
				await _case(t, kind, populated, complete)

func _case(t, kind: String, populated: bool, complete: bool) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var saves: Node = t.autoload("SaveManager")
	var eco: Node = t.autoload("EconomyManager")
	saves.autosave_enabled = false
	saves.save_dir = "user://persistence_marker_scope"
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.clear_flag(&"intro_pending")
	var label := kind + ("_existing" if populated else "_absent") + ("_complete" if complete else "_cancel")
	t.check(label+"_authored_p0_garden_admitted", qm.accept_quest(&"secret_garden"))
	if kind != "garden":
		for i in 11: qm.complete_manual(&"secret_garden", StringName(SecretGardenStory.STEPS[i].id))
	# Force Mother admission to depend on p0's genuine garden evidence, not a
	# shared version fallback that could mask the wrong-profile query.
	gm.clear_flag(&"forest_mother_version")
	var marker: Node
	if kind == "garden":
		marker = SecretGardenMarker.new()
		marker.kind = "path"
	else:
		marker = MotherEvidenceMarker.new()
		marker.evidence_id = "marked_lamp" if kind == "mother" else "memory_lamp"
	marker.area = t.world().area
	t.world().area.objects.add_child(marker)
	await t.frames(2)
	var body: Node = t.player()
	t.check(label+"_enabled_intree_registered_actual_owner", marker.is_inside_tree() and marker.is_enabled() and PlayerRegistry.registered_id(body) == &"p0" and PlayerRegistry.by_id(&"p0") == body and SecretGardenStory.step() == (0 if kind == "garden" else 11) and not gm.is_modal_open())
	var unrelated: PlayerState
	var before: Dictionary = {}
	var graph: Array = []
	if populated:
		unrelated = PlayerRegistry.state(&"p1")
		PlayerRegistry.for_player(&"p1", func():
			eco.from_dict(eco.to_dict())
			qm.to_dict()
			eco.add_item(&"wood", 7, true))
		unrelated.name = "Unrelated marker control"
		unrelated.gold = 713
		unrelated.max_half_hearts = 38
		unrelated.max_stamina = 137.0
		unrelated.max_oil = 211.0
		before = unrelated.to_dict().duplicate(true)
		_retain(unrelated, graph)
		t.check(label+"_valid_complete_unrelated_preimage", t.world().roster.validate_dict({"v":1,"rows":{"p0":PlayerRegistry._states[&"p0"].to_dict(),"p1":before}}))
	else:
		t.check(label+"_sparse_preimage_p1_absent", not PlayerRegistry._states.has(&"p1") and PlayerRegistry._states.size() == 1)
	var registry: Dictionary = PlayerRegistry._states
	var caller: Array = []
	PlayerRegistry.for_player(&"p1", func():
		marker.interact(body)
		caller.append(PlayerRegistry._acting_id))
	t.check(label+"_admission_preserves_unrelated_complete_profile_and_aliases", _unchanged(populated, unrelated, before, graph, registry))
	t.check(label+"_admission_restores_conflicting_caller", caller == [&"p1"] and PlayerRegistry._acting_id == &"")
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	await t.page_to_choices(ui)
	var key := "SG_SCENE_CLEAR_PATH" if kind == "garden" else ("FM_E_MARKED_LAMP_TEXT" if kind == "mother" else "FM_WORK_LAMP")
	var action := "garden_work" if kind == "garden" else ("mother_record" if kind == "mother" else "stitch_0")
	t.check(label+"_actual_owner_authored_page_and_choice", ui.is_open() and ui._lines[0].get("text_key") == key and ui._choices.any(func(c): return c.get("action") == action), str({"lines":ui._lines,"choices":ui._choices}))
	t.check(label+"_before_answer_and_after_frames_unrelated_unchanged", _unchanged(populated, unrelated, before, graph, registry))
	var quest_before: Dictionary = qm.to_dict().duplicate(true)
	var gold_before: int = eco.gold
	if complete:
		if kind == "work":
			for i in 3:
				await t.page_to_choices(ui)
				t.check(label+"_resumption_"+str(i)+"_exact_remaining_choices", ui.is_open() and ui._choices.any(func(c): return c.get("action") == "stitch_"+str(i)) and not ui._choices.any(func(c): return str(c.get("action", "")).begins_with("stitch_") and int(str(c.action).trim_prefix("stitch_")) < i))
				_press_scoped(t, ui, "stitch_"+str(i), label+"_stitch_"+str(i))
				t.check(label+"_sync_resumption_"+str(i)+"_unrelated_unchanged", _unchanged(populated, unrelated, before, graph, registry))
			await t.page_to_choices(ui)
			t.check(label+"_work_resumes_into_actual_evidence_page", ui.is_open() and ui._lines[0].get("text_key") == "FM_E_MEMORY_LAMP_TEXT" and ui._choices.any(func(c): return c.get("action") == "mother_record"))
			_press_scoped(t, ui, "mother_record", label+"_record")
		else:
			_press_scoped(t, ui, action, label+"_answer")
	else:
		var cancel_scope: Array = []
		PlayerRegistry.for_player(&"p1", func():
			ui.close()
			cancel_scope.append(PlayerRegistry._acting_id))
		t.check(label+"_real_cancel_restores_caller", cancel_scope == [&"p1"] and PlayerRegistry._acting_id == &"")
	t.check(label+"_terminal_synchronous_unrelated_unchanged", _unchanged(populated, unrelated, before, graph, registry))
	await t.frames(3)
	t.check(label+"_terminal_after_frames_unrelated_complete_values_and_aliases", _unchanged(populated, unrelated, before, graph, registry))
	if kind == "garden":
		t.check(label+"_actual_p0_authored_progress", SecretGardenStory.step() == (1 if complete else 0))
	else:
		t.check(label+"_actual_p0_evidence_and_work", MotherStory.has("marked_lamp" if kind == "mother" else "memory_lamp") == complete and (kind != "work" or MotherMemoryWork.state("memory_lamp") == (7 if complete else 0)))
	if not complete:
		t.check(label+"_cancel_no_quest_or_award", qm.to_dict() == quest_before and eco.gold == gold_before)
	t.check(label+"_exact_ui_hold_and_scope_released", not ui.is_open() and not marker._busy and body.state != PlayerBody2D.S.TALKING and PlayerRegistry._acting_id == &"" and not gm.is_modal_open())
	marker.free()
	gm.clear_config_overrides()

func _press_scoped(t, ui: Node, action: String, label: String) -> void:
	var selected: Button
	for button in ui._buttons:
		if button.get_meta("choice", {}).get("action") == action: selected = button
	t.check(label+"_real_authored_button", selected != null)
	var restored: Array = []
	PlayerRegistry.for_player(&"p1", func():
		if selected != null: selected.pressed.emit()
		elif ui.is_open(): ui.close()
		restored.append(PlayerRegistry._acting_id))
	t.check(label+"_synchronous_caller_restored", restored == [&"p1"] and PlayerRegistry._acting_id == &"")

# Retain every nested container/property edge, not just a profile pointer or
# gold balance. These checks do not call any lazy p1 manager reader.
func _retain(value: Variant, graph: Array) -> void:
	if value is Dictionary or value is Array:
		for key in (value.keys() if value is Dictionary else range(value.size())):
			var child: Variant = value[key]
			if child is Dictionary or child is Array or child is RefCounted:
				graph.append({"parent":value,"key":key,"value":child})
				_retain(child, graph)
	elif value is RefCounted:
		for row in value.get_script().get_script_property_list():
			var child: Variant = value.get(row.name)
			if child is Dictionary or child is Array:
				graph.append({"parent":value,"key":row.name,"value":child})
				_retain(child, graph)

func _unchanged(populated: bool, profile: PlayerState, before: Dictionary, graph: Array, registry: Dictionary) -> bool:
	if not is_same(PlayerRegistry._states, registry): return false
	if not populated: return not registry.has(&"p1") and registry.size() == 1
	if registry.get(&"p1") != profile or registry.size() != 2 or profile.to_dict() != before: return false
	if profile.max_half_hearts != 38 or profile.max_stamina != 137.0 or profile.max_oil != 211.0: return false
	for edge in graph:
		var current: Variant = edge.parent.get(edge.key) if edge.parent is Object else edge.parent[edge.key]
		if not is_same(current, edge.value): return false
	return true
