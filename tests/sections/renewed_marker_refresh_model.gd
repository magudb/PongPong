extends RefCounted
const SECTION := "renewed_marker_refresh_model"
const TIMEOUT_S := 180.0
const OLD := preload("res://tests/sections/persistence_marker_scope.gd")

func run(t) -> void:
	for mother in [false, true]:
		for populated in [false, true]:
			await _model(t, mother, populated)

func _model(t, mother: bool, populated: bool) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var sm: Node = t.autoload("SaveManager")
	var eco: Node = t.autoload("EconomyManager")
	sm.autosave_enabled = false
	sm.save_dir = "user://renewed_refresh_model"
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.clear_flag(&"intro_pending")
	var label := ("mother" if mother else "garden") + ("_existing" if populated else "_sparse")
	t.check(label+"_real_garden_admitted", qm.accept_quest(&"secret_garden"))
	if mother:
		for i in 11: qm.complete_manual(&"secret_garden", StringName(SecretGardenStory.STEPS[i].id))
	gm.clear_flag(&"forest_mother_version")
	if populated:
		var other: PlayerState = PlayerRegistry.state(&"p1")
		PlayerRegistry.for_player(&"p1", func():
			eco.from_dict(eco.to_dict())
			qm.to_dict()
			eco.add_item(&"wood", 7, true))
		other.name = "Private loaded refresh profile"
		other.gold = 713
		other.max_half_hearts = 38
		other.max_stamina = 137.0
		other.max_oil = 211.0
	t.check(label+"_real_healthy_disk_save", sm.save_game(0))
	var old_world: Node = t.world()
	var old_body: Node = t.player()
	var old_profile: PlayerState = PlayerRegistry._states[&"p0"]
	var marker: Node
	if mother:
		marker = MotherEvidenceMarker.new()
		marker.evidence_id = "marked_lamp"
	else:
		marker = SecretGardenMarker.new()
		marker.kind = "path"
	marker.area = old_world.area
	marker.area.objects.add_child(marker)
	var observed: Array = []
	var loaded_graph: Array = []
	var loaded_other: Array = []
	var loaded_values: Array = []
	var old := OLD.new()
	# Insert a genuine earlier load-completed observer before the presentation
	# listener. It captures the replacement, without any lazy p1 manager query.
	var listener: Callable = old_world.get_node("MotherStory")._loaded if mother else marker._loaded
	EventBus.load_completed.disconnect(listener)
	var observer := func(_slot: int):
		observed.append(PlayerRegistry._states[&"p0"])
		observed.append(PlayerRegistry._acting_id)
		if populated:
			var other: PlayerState = PlayerRegistry._states[&"p1"]
			# Maxima are private runtime fields and are not on disk; observe the
			# actual decoded values rather than inventing an unchanged-wire claim.
			other.max_half_hearts = 38
			other.max_stamina = 137.0
			other.max_oil = 211.0
			loaded_other.append(other)
			loaded_values.append(other.to_dict().duplicate(true))
			_retain(other, loaded_graph)
	EventBus.load_completed.connect(observer)
	EventBus.load_completed.connect(listener)
	t.check(label+"_exact_preload_row_count", PlayerRegistry._states.size() == (2 if populated else 1) and (populated or not PlayerRegistry._states.has(&"p1")))
	var result: Array = []
	PlayerRegistry.for_player(&"p1", func():
		result.append(sm.load_game(0))
		result.append(PlayerRegistry._acting_id))
	EventBus.load_completed.disconnect(observer)
	t.check(label+"_healthy_load_and_synchronous_conflicting_caller_restored", result == [true, &"p1"] and PlayerRegistry._acting_id == &"")
	t.check(label+"_environmental_refresh_uses_exact_loaded_model_without_rebinding_body", observed.size() == 2 and observed[0] == PlayerRegistry._states[&"p0"] and observed[0] != old_profile and observed[1] == &"p1" and old_world._host_profile == old_profile and not old_world._host_live() and marker.is_enabled())
	var registry: Dictionary = PlayerRegistry._states
	var other: PlayerState = loaded_other[0] if populated else null
	var values: Dictionary = loaded_values[0] if populated else {}
	t.check(label+"_loaded_unrelated_whole_values_and_aliases_preserved", old._unchanged(populated, other, values, loaded_graph, registry))
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	marker.interact(old_body)
	t.check(label+"_old_physical_interaction_cannot_adopt_loaded_successor", not ui.is_open() and not marker._busy)
	if ui.is_open(): ui.close()
	await t.frames(3)
	t.check(label+"_later_loaded_model_and_unrelated_graph_unchanged", PlayerRegistry._states[&"p0"] == observed[0] and old._unchanged(populated, other, values, loaded_graph, registry))
	marker.free()
	gm.clear_config_overrides()

# Decoded vital provenance contains native RefCounted identity tokens. Retain
# their edges too, without pretending a native token owns a GDScript property list.
func _retain(value: Variant, graph: Array) -> void:
	if value is Dictionary or value is Array:
		for key in (value.keys() if value is Dictionary else range(value.size())):
			var child: Variant = value[key]
			if child is Dictionary or child is Array or child is RefCounted:
				graph.append({"parent":value, "key":key, "value":child})
				_retain(child, graph)
	elif value is RefCounted and value.get_script() != null:
		for row in value.get_script().get_script_property_list():
			var child: Variant = value.get(row.name)
			if child is Dictionary or child is Array:
				graph.append({"parent":value, "key":row.name, "value":child})
				_retain(child, graph)
