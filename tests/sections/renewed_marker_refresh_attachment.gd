extends RefCounted
const SECTION := "renewed_marker_refresh_attachment"
const TIMEOUT_S := 180.0
const SETUP := preload("res://tests/sections/renewed_marker_refresh_director.gd")

func run(t) -> void:
	var setup := SETUP.new()
	var director: Node = await setup._prepare(t)
	# Make a normal current anchored set; then exercise an already-ready marker,
	# not the engine-locked add_child/tree-entry removal case.
	director._area_ready(&"secret_garden")
	await t.physics(4)
	var victim: Node = director.anchors[0].node
	victim.set_enabled(false)
	var objects: Node = victim.get_parent()
	var detached: Array = []
	var observer := func():
		if not victim.visible or not detached.is_empty(): return
		detached.append(true)
		objects.remove_child(victim)
	victim.visibility_changed.connect(observer)
	var original: PlayerState = PlayerRegistry._states[&"p0"]
	director._area_ready(&"secret_garden")
	await t.physics(4)
	victim.visibility_changed.disconnect(observer)
	t.check("attachment_actual_same_model_marker_departure", detached == [true] and not victim.is_inside_tree() and victim.get_parent() == null and PlayerRegistry._states[&"p0"] == original)
	t.check("attachment_old_director_cannot_record_detached_marker_after_refresh_callback", director.anchors.all(func(a): return is_instance_valid(a.node) and a.node.is_inside_tree() and a.node.get_parent() == objects) and not director.anchors.any(func(a): return a.node == victim))
	victim.free()
	director._area_ready(&"secret_garden")
	await t.physics(4)
	t.check("attachment_independent_current_root_repairs_exact_live_anchor_set", director.anchors.size() == 2 and director.anchors.all(func(a): return a.node.is_inside_tree() and a.node.get_parent() == objects))
	t.check("attachment_no_profile_or_scope_adoption", PlayerRegistry._states.size() == 1 and not PlayerRegistry._states.has(&"p1") and PlayerRegistry._acting_id == &"")
	t.autoload("GameManager").clear_config_overrides()
