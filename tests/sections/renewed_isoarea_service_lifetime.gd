extends RefCounted
const SECTION := "renewed_isoarea_service_lifetime"
const TIMEOUT_S := 120.0

class Service extends Node:
	var _accounting_suspended := false
	var _accounting_world := RefCounted.new()

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.clear_flag(&"intro_pending")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	t.autoload("SaveManager").autosave_enabled = false
	gm.set_flag(&"zz_iso_service_lifetime", true)
	var actual: Node = Svc.node("SocialManager")
	for kind in ["freed_absent", "freed_replacement", "freed_replacement_removed", "live_replacement", "originally_absent", "absent_new_service", "present_current", "suspended", "incarnation"]:
		var a := IsoArea.new()
		t.root.add_child(a)
		var n := Interactable2D.new()
		a.add_child(n)
		await t.frames(2)
		a._track_when({"when":"flag:zz_iso_service_lifetime"}, [n])
		await t.frames(2)
		var fake := Service.new()
		var fake_ref: WeakRef = weakref(fake)
		var replacement := Service.new()
		# Equal accounting identity cannot authorize a different service object.
		replacement._accounting_world = fake._accounting_world
		if kind in ["originally_absent", "absent_new_service"]:
			t.root.remove_child(actual)
		else:
			Svc.override("SocialManager", fake)
		var origin: Dictionary = a._begin_when()
		t.check(kind + "_valid_original_receipt", IsoArea._when_current(origin))
		a._set_node_active(n, false, origin)
		t.check(kind + "_actual_guarded_enqueue_before_service_change", not n.visible and n._area.collision_layer == 0 and n._area.monitorable)
		match kind:
			"freed_absent":
				Svc.clear_overrides()
				fake.free()
				t.root.remove_child(actual)
			"freed_replacement":
				Svc.override("SocialManager", replacement)
				fake.free()
			"freed_replacement_removed":
				Svc.override("SocialManager", replacement)
				fake.free()
				Svc.clear_overrides()
				t.root.remove_child(actual)
			"live_replacement": Svc.override("SocialManager", replacement)
			"absent_new_service": Svc.override("SocialManager", replacement)
			"suspended": fake._accounting_suspended = true
			"incarnation": fake._accounting_world = RefCounted.new()
		var positive: bool = kind in ["originally_absent", "present_current"]
		if kind.begins_with("freed_"):
			t.check(kind + "_real_idle_service_destroyed", fake_ref.get_ref() == null)
		t.check(kind + "_retained_identity_not_recaptured", IsoArea._when_current(origin) == positive)
		await t.frames(3)
		t.check(kind + "_actual_deferred_monitorable_result", n._area.monitorable == not positive)
		Svc.clear_overrides()
		if actual.get_parent() == null: t.root.add_child(actual)
		if is_instance_valid(fake): fake.free()
		replacement.free()
		n.set_enabled(true)
		await t.frames(2)
		var fresh: Dictionary = a._begin_when()
		a._set_node_active(n, false, fresh)
		await t.frames(3)
		t.check(kind + "_independent_fresh_current_root_delivers", not n._area.monitorable and n._area.collision_layer == 0 and Svc.node("SocialManager") == actual and PlayerRegistry._acting_id == &"")
		a.free()
	gm.clear_config_overrides()
