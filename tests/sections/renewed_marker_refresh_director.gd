extends RefCounted
const SECTION := "renewed_marker_refresh_director"
const TIMEOUT_S := 180.0
const OLD := preload("res://tests/sections/persistence_marker_scope.gd")
const ROLLBACK := preload("res://tests/sections/persistence_rollback.gd")

func run(t) -> void:
	for populated in [false, true]:
		for root in ["quest", "objective", "event", "load", "area"]:
			await _root(t, populated, root)
	for mode in ["replace", "complete", "partial", "child"]:
		await _resumption(t, mode)

func _prepare(t) -> Node:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	t.autoload("SaveManager").autosave_enabled = false
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.clear_flag(&"intro_pending")
	t.check("director_real_garden_admitted", qm.accept_quest(&"secret_garden"))
	for i in 11: qm.complete_manual(&"secret_garden", StringName(SecretGardenStory.STEPS[i].id))
	t.check("director_actual_area_entry", t.world()._enter(&"secret_garden", &"default"))
	await t.physics(4)
	var director: Node = t.world().get_node("MotherStory")
	t.check("director_ordinary_real_anchors_created", director.anchors.size() == 2 and director.anchors.all(func(a): return a.node is MotherEvidenceMarker and a.node.is_inside_tree()))
	for child in t.world().area.objects.get_children():
		if child is MotherEvidenceMarker: child.free()
	director.anchors.clear()
	gm.clear_flag(&"forest_mother_version")
	return director

func _root(t, populated: bool, root: String) -> void:
	var director: Node = await _prepare(t)
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var label := ("existing_" if populated else "sparse_")+root
	var other: PlayerState
	var before: Dictionary = {}
	var graph: Array = []
	var old := OLD.new()
	if populated:
		other = PlayerRegistry.state(&"p1")
		PlayerRegistry.for_player(&"p1", func():
			eco.from_dict(eco.to_dict())
			qm.to_dict()
			eco.add_item(&"wood", 7, true))
		other.gold = 713
		other.max_half_hearts = 38
		other.max_stamina = 137.0
		other.max_oil = 211.0
		before = other.to_dict().duplicate(true)
		old._retain(other, graph)
	var registry: Dictionary = PlayerRegistry._states
	t.check(label+"_genuinely_independent_unrelated_preimage", old._unchanged(populated, other, before, graph, registry))
	var restored: Array = []
	PlayerRegistry.for_player(&"p1", func():
		match root:
			"quest": director._quest(&"p0", &"secret_garden")
			"objective": director._objective(&"p0", &"secret_garden", &"follow_trace", 1, 1)
			"event": director._event(&"dungeon_boss_defeated", {})
			"load": director._loaded(0)
			"area": director._area_ready(&"secret_garden")
		restored.append(PlayerRegistry._acting_id))
	t.check(label+"_synchronous_complete_unrelated_values_aliases", old._unchanged(populated, other, before, graph, registry))
	t.check(label+"_current_p0_story_sync_and_conflicting_caller_restoration", gm.flag_int(&"forest_mother_version") == 1 and restored == [&"p1"] and PlayerRegistry._acting_id == &"")
	await t.physics(4)
	t.check(label+"_after_await_complete_unrelated_values_aliases", old._unchanged(populated, other, before, graph, registry))
	if root in ["load", "area"]:
		t.check(label+"_ordinary_reachable_unique_anchors_and_readiness", director.anchors.size() == 2 and director.anchors[0].cell != director.anchors[1].cell and director.anchors.all(func(a): return a.node.is_inside_tree() and a.node.area == t.world().area and a.node.is_enabled() == MotherStory.can_read(str(a.id))))
	gm.clear_config_overrides()

func _resumption(t, mode: String) -> void:
	var director: Node = await _prepare(t)
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SaveManager")
	var eco: Node = t.autoload("EconomyManager")
	eco.from_dict(eco.to_dict())
	t.autoload("LootService").from_dict(t.autoload("LootService").to_dict())
	var late: Node
	if mode in ["complete", "partial"]:
		late = ROLLBACK.Reject.new()
		t.root.add_child(late)
		sm.register_section("refresh_director_late", late, 999)
		late.restore_bad = mode == "partial"
	# Finish legitimate current reconciliation before capturing the wire.
	director._quest(&"p0", &"secret_garden")
	var payload: Dictionary = sm.gather_payload()
	if late != null: payload.refresh_director_late.reject = true
	var profile: PlayerState = PlayerRegistry._states[&"p0"]
	var incarnation: RefCounted = t.autoload("SocialManager")._accounting_world
	var result: Array = []
	var first_marker: Array = []
	var child_observer := func(child: Node):
		if not child is MotherEvidenceMarker or not first_marker.is_empty(): return
		first_marker.append(child)
		var applied: Dictionary = sm._apply_payload(payload)
		result.append(applied.ok)
	var objects: Node = t.world().area.objects
	if mode == "child": objects.child_entered_tree.connect(child_observer)
	PlayerRegistry.for_player(&"p1", func(): director._area_ready(&"secret_garden"))
	if mode != "child":
		var applied: Dictionary = sm._apply_payload(payload)
		result.append(applied.ok)
	await t.physics(4)
	if mode == "child": objects.child_entered_tree.disconnect(child_observer)
	t.check(mode+"_real_apply_outcome", result == [mode in ["replace", "child"]])
	var complete := mode == "complete"
	t.check(mode+"_exact_model_and_accounting_restoration_distinguished", (PlayerRegistry._states[&"p0"] == profile) == complete and (t.autoload("SocialManager")._accounting_world == incarnation) == complete)
	if complete:
		t.check(mode+"_full_rollback_preserves_original_await_and_anchors", director.anchors.size() == 2)
	elif mode == "child":
		t.check(mode+"_old_loop_and_child_readiness_do_not_adopt_successor", first_marker.size() == 1 and director.anchors.is_empty() and not first_marker[0].is_enabled())
	else:
		t.check(mode+"_old_await_does_not_allocate_successor_anchors", director.anchors.is_empty() and not objects.get_children().any(func(n): return n is MotherEvidenceMarker))
	# Independent, policy-authorized reconciliation of the actual current model
	# remains available even though the old physical host is now incoherent.
	director._area_ready(&"secret_garden")
	await t.physics(4)
	t.check(mode+"_fresh_current_root_makes_exact_two_live_anchors", director.anchors.size() == 2 and director.anchors.all(func(a): return a.node.is_inside_tree()) and objects.get_children().filter(func(n): return n is MotherEvidenceMarker).size() == 2)
	t.check(mode+"_sparse_unrelated_and_scope_preserved", PlayerRegistry._states.size() == 1 and not PlayerRegistry._states.has(&"p1") and PlayerRegistry._acting_id == &"")
	if late != null:
		sm.unregister_section("refresh_director_late")
		late.free()
	gm.clear_config_overrides()
