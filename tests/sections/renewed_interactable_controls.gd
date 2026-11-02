extends RefCounted
const SECTION := "renewed_interactable_controls"
const TIMEOUT_S := 180.0

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.clear_flag(&"intro_pending")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	t.autoload("SaveManager").autosave_enabled = false
	await _ordinary(t)
	await _deferred(t)
	for kind in ["replace", "fresh", "child_transfer", "child_roundtrip", "child_replace", "child_destroy", "child_queue", "node_roundtrip", "node_queue"]:
		await _boundary(t, kind)
	await _subclass(t)
	gm.clear_config_overrides()

func _ordinary(t) -> void:
	var n := Interactable2D.new()
	n.set_enabled(false)
	t.check("legacy_offtree_setter_stores_state", not n.is_enabled())
	t.root.add_child(n)
	await t.frames(2)
	t.check("legacy_readiness_applies_stored_false", not n.visible and n._area.collision_layer == 0 and not n._area.monitorable)
	PlayerRegistry.for_player(&"p1", func(): n.set_enabled(true))
	await t.frames(2)
	t.check("legacy_p0_current_model_conflicting_scope_toggle", n.visible and n.is_enabled() and n._area.collision_layer == Iso.LAYER_INTERACTABLE and n._area.monitorable and PlayerRegistry._acting_id == &"")
	n.set_enabled(false)
	await t.frames(2)
	t.check("legacy_ordinary_false_natural_delivery", not n.visible and n._area.collision_layer == 0 and not n._area.monitorable)
	var methods := {}
	for row in n.get_method_list():
		if row.name in ["set_enabled", "_apply_enabled"]: methods[row.name] = row
	t.check("legacy_signatures_unchanged", methods.set_enabled.args.size() == 1 and methods.set_enabled.default_args.is_empty() and methods.set_enabled.args[0].type == TYPE_BOOL and methods._apply_enabled.args.is_empty() and methods._apply_enabled.default_args.is_empty())
	n.free()

func _deferred(t) -> void:
	var n := Interactable2D.new()
	t.root.add_child(n)
	await t.frames(2)
	n.set_enabled(false)
	t.check("queued_precondition_committed_layer_before_delivery", n._area.collision_layer == 0 and n._area.monitorable)
	PlayerRegistry.reset_states()
	await t.frames(3)
	t.check("queued_delivery_revalidates_original_model", n._area.monitorable)
	n.set_enabled(false)
	await t.frames(2)
	t.check("queued_independent_same_value_successor_progresses", not n._area.monitorable and n._area.collision_layer == 0)
	n.set_enabled(true)
	await t.frames(2)
	n.set_enabled(false)
	n.set_enabled(true)
	await t.frames(3)
	t.check("queued_fresh_activation_owns_final_delivery", n.visible and n._area.monitorable and n._area.collision_layer == Iso.LAYER_INTERACTABLE)
	n.free()

func _boundary(t, kind: String) -> void:
	var a := IsoArea.new()
	t.root.add_child(a)
	var n := Interactable2D.new()
	a.add_child(n)
	var holder := Node2D.new()
	t.root.add_child(holder)
	var key := StringName("zz_interactable_" + kind)
	var gm: Node = t.autoload("GameManager")
	gm.set_flag(key, true)
	a._track_when({"when": "flag:" + str(key)}, [n])
	await t.frames(2)
	var child: Area2D = n._area
	var child_ref: WeakRef = weakref(child)
	var fired: Array = []
	var successor: Array = []
	var cb := func():
		if n.visible or not fired.is_empty(): return
		fired.append([PlayerRegistry._acting_id, child.collision_layer, child.monitorable])
		match kind:
			"replace": PlayerRegistry.reset_states()
			"fresh":
				PlayerRegistry.reset_states()
				n.set_enabled(true)
				successor.append([n.visible, n.is_enabled(), n._area.collision_layer])
			"child_transfer": child.reparent(holder)
			"child_roundtrip":
				child.reparent(holder)
				child.reparent(n)
			"child_replace":
				child.reparent(holder)
				var fresh := Area2D.new()
				fresh.collision_layer = 32
				n.add_child(fresh)
				n._area = fresh
			"child_destroy": child.free()
			"child_queue": child.queue_free()
			"node_roundtrip":
				n.reparent(holder)
				n.reparent(a)
			"node_queue": n.queue_free()
	n.visibility_changed.connect(cb)
	PlayerRegistry.for_player(&"p1", func(): gm.set_flag(key, false))
	n.visibility_changed.disconnect(cb)
	t.check(kind + "_real_flag_visibility_boundary", fired == [[&"p0", Iso.LAYER_INTERACTABLE, true]] and PlayerRegistry._acting_id == &"")
	if kind == "child_destroy":
		t.check(kind + "_exact_child_really_destroyed", child_ref.get_ref() == null)
	else:
		t.check(kind + "_old_inline_collision_suffix_refused", child.collision_layer == Iso.LAYER_INTERACTABLE)
	if kind == "fresh":
		t.check(kind + "_independent_same_node_setter_admitted", successor == [[true, true, Iso.LAYER_INTERACTABLE]] and n.visible and n.is_enabled())
	if kind == "child_replace":
		t.check(kind + "_replacement_child_untouched", n._area != child and n._area.collision_layer == 32 and n._area.monitorable)
	await t.frames(3)
	if kind in ["child_destroy", "child_queue", "node_queue"]:
		t.check(kind + "_actual_queued_lifetime_settled", child_ref.get_ref() == null)
	else:
		t.check(kind + "_old_deferred_monitorable_suffix_refused", child.monitorable)
	if is_instance_valid(n) and not n.is_queued_for_deletion():
		if kind in ["replace", "fresh", "child_roundtrip", "node_roundtrip"]:
			n.set_enabled(false)
			await t.frames(2)
			t.check(kind + "_later_independent_setter_progress", not n.visible and n._area.collision_layer == 0 and not n._area.monitorable)
		if kind == "child_destroy": n._area = null
	a.free()
	holder.free()

func _subclass(t) -> void:
	var a := IsoArea.new()
	t.root.add_child(a)
	var chest := LootChest2D.new()
	a.add_child(chest)
	await t.frames(2)
	a._set_node_active(chest, false)
	await t.frames(2)
	t.check("actual_chest_override_false_dispatch", not chest.visible and not chest._area.monitorable and chest._area.collision_layer == 0 and chest._body.collision_layer == 0)
	a._set_node_active(chest, true)
	await t.frames(2)
	t.check("actual_chest_override_true_dispatch", chest.visible and chest._area.monitorable and chest._area.collision_layer == Iso.LAYER_INTERACTABLE and chest._body.collision_layer == Iso.LAYER_WORLD)
	var gm: Node = t.autoload("GameManager")
	gm.set_flag(&"zz_interactable_chest", true)
	a._track_when({"when": "flag:zz_interactable_chest"}, [chest])
	gm.set_flag(&"zz_interactable_chest", false)
	await t.frames(2)
	t.check("actual_chest_guarded_flag_override_false_dispatch", not chest.visible and not chest._area.monitorable and chest._body.collision_layer == 0)
	gm.set_flag(&"zz_interactable_chest", true)
	await t.frames(2)
	t.check("actual_chest_guarded_flag_override_true_dispatch", chest.visible and chest._area.monitorable and chest._body.collision_layer == Iso.LAYER_WORLD)
	a.free()
