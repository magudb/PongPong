extends RefCounted
const SECTION := "renewed_marker_refresh_roots"
const TIMEOUT_S := 180.0
const OLD := preload("res://tests/sections/persistence_marker_scope.gd")

func run(t) -> void:
	for mother in [false, true]:
		for populated in [false, true]:
			for root in ["ready", "refresh", "translation", "quest", "day", "deferred"]:
				await _root(t, mother, populated, root)

func _root(t, mother: bool, populated: bool, root: String) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var sm: Node = t.autoload("SaveManager")
	var eco: Node = t.autoload("EconomyManager")
	sm.autosave_enabled = false
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.clear_flag(&"intro_pending")
	var label := ("mother" if mother else "garden") + ("_existing_" if populated else "_sparse_") + root
	t.check(label+"_genuine_garden_accepted", qm.accept_quest(&"secret_garden"))
	if mother:
		for i in 11: qm.complete_manual(&"secret_garden", StringName(SecretGardenStory.STEPS[i].id))
	gm.clear_flag(&"forest_mother_version")
	var marker: Node
	if mother:
		marker = MotherEvidenceMarker.new()
		marker.evidence_id = "memory_lamp"
	else:
		marker = SecretGardenMarker.new()
		marker.kind = "path"
	marker.area = t.world().area
	# Each non-ready root starts from a normal host-owned readiness, so a
	# previous bad ready callback cannot prime/hide this root's sparse reader.
	if root != "ready": t.world().area.objects.add_child(marker)
	var unrelated: PlayerState
	var before: Dictionary = {}
	var graph: Array = []
	var old := OLD.new()
	if populated:
		unrelated = PlayerRegistry.state(&"p1")
		PlayerRegistry.for_player(&"p1", func():
			eco.from_dict(eco.to_dict())
			qm.to_dict()
			eco.add_item(&"wood", 7, true))
		unrelated.name = "Unrelated refresh control"
		unrelated.gold = 713
		unrelated.max_half_hearts = 38
		unrelated.max_stamina = 137.0
		unrelated.max_oil = 211.0
		before = unrelated.to_dict().duplicate(true)
		old._retain(unrelated, graph)
	var registry: Dictionary = PlayerRegistry._states
	t.check(label+"_precondition_unrelated_whole_graph", old._unchanged(populated, unrelated, before, graph, registry))
	var restored: Array = []
	PlayerRegistry.for_player(&"p1", func():
		match root:
			"ready": t.world().area.objects.add_child(marker)
			"refresh": marker.refresh()
			"translation": marker.notification(Node.NOTIFICATION_TRANSLATION_CHANGED)
			"quest":
				if mother: t.world().get_node("MotherStory")._refresh()
				else: marker._quest(&"p0", &"secret_garden")
			"day":
				if mother: marker.refresh()
				else: marker._morning(gm.day, gm.season)
			"deferred":
				var objects: Node = marker.get_parent()
				objects.remove_child(marker)
				objects.add_child(marker)
		restored.append(PlayerRegistry._acting_id))
	t.check(label+"_synchronous_complete_unrelated_values_aliases", old._unchanged(populated, unrelated, before, graph, registry))
	await t.frames(3)
	t.check(label+"_actual_p0_projection", marker.is_enabled() and (mother or marker._look == "bush_farm:6"))
	t.check(label+"_after_frames_complete_unrelated_values_aliases", old._unchanged(populated, unrelated, before, graph, registry))
	t.check(label+"_conflicting_caller_restored", restored == [&"p1"] and PlayerRegistry._acting_id == &"")
	# Real ordinary p0 objective/day producers remain active and update art.
	if not mother:
		t.check(label+"_ordinary_real_objective_progress", SecretGardenStory.advance(0) and marker._pictures.is_empty() and marker._look == ":6")
	else:
		MotherMemoryWork.apply("memory_lamp", "stitch_0")
		t.check(label+"_ordinary_work_progress", MotherMemoryWork.state("memory_lamp") == 1)
		marker.refresh()
		t.check(label+"_ordinary_work_presentation", marker._stitches[0].default_color == Color("f5d393") and not marker._lamp_light.visible)
	gm.end_day()
	await t.frames(3)
	t.check(label+"_ordinary_real_day_preserves_unrelated_graph", old._unchanged(populated, unrelated, before, graph, registry))
	marker.free()
	gm.clear_config_overrides()
