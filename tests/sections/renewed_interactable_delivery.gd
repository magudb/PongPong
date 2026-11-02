extends RefCounted
const SECTION := "renewed_interactable_delivery"
const TIMEOUT_S := 120.0
# Supplementary delivery-time attachment controls. Primary identical 5/2 and
# 46/12 REDs remain separate and unchanged.
func run(t) -> void:
	await t.start_world()
	t.autoload("GameManager").clear_flag(&"intro_pending")
	t.autoload("GameManager").set_config_override("time.minutes_per_real_second", 0.0)
	t.autoload("SaveManager").autosave_enabled = false
	for kind in ["child_transfer", "child_roundtrip", "child_replace", "node_roundtrip", "guard_revoked"]:
		var n := Interactable2D.new()
		var holder := Node2D.new()
		t.root.add_child(n)
		t.root.add_child(holder)
		await t.frames(2)
		var child: Area2D = n._area
		var current: Array = [true]
		n.set_enabled_guarded(false, func() -> bool: return current[0])
		t.check(kind + "_queued_before_retirement", not n.visible and child.collision_layer == 0 and child.monitorable)
		match kind:
			"child_transfer": child.reparent(holder)
			"child_roundtrip":
				child.reparent(holder)
				child.reparent(n)
			"child_replace":
				var fresh := Area2D.new()
				fresh.collision_layer = 32
				n.add_child(fresh)
				n._area = fresh
			"node_roundtrip":
				n.reparent(holder)
				n.reparent(t.root)
			"guard_revoked": current[0] = false
		await t.frames(3)
		t.check(kind + "_delivery_keeps_original_child_monitorable", child.monitorable)
		if kind == "child_replace":
			t.check(kind + "_delivery_never_adopts_new_child", n._area.monitorable and n._area.collision_layer == 32)
		if kind != "child_transfer":
			n.set_enabled(false)
			await t.frames(2)
			t.check(kind + "_fresh_legacy_call_does_not_inherit_guard", not n._area.monitorable and n._area.collision_layer == 0)
		n.free()
		holder.free()
	t.autoload("GameManager").clear_config_overrides()
