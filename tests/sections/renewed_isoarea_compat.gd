extends RefCounted
const SECTION := "renewed_isoarea_compat"
const TIMEOUT_S := 180.0
# Only the three original functional when subprocedures. Do not invoke area.run:
# it also reaches boot-cost/perf_ok workloads, outside this execution authority.
func run(t)->void:
	await t.start_world()
	t.autoload("GameManager").clear_flag(&"intro_pending")
	t.autoload("SaveManager").autosave_enabled=false
	var original:RefCounted=load("res://tests/sections/area.gd").new()
	await original._when_conditions(t)
	var service: Node = GameData.autoload("SocialManager")
	var root: Node = service.get_parent()
	var old_name: StringName = service.name
	var hidden_name := "RenewedAbsentSocial_%d" % service.get_instance_id()
	var admitted: bool = Svc.node("SocialManager") == service and root == t.root and not root.has_node(hidden_name)
	t.check("absence_fixture_exact_real_service_admitted", admitted)
	if not admitted: return
	var service_ref: WeakRef = weakref(service)
	var root_ref: WeakRef = weakref(root)
	var world_ref: WeakRef = weakref(t.world())
	var body_ref: WeakRef = weakref(t.player())
	var registry: Dictionary = PlayerRegistry._states
	var values := {}
	for id in registry: values[id] = registry[id].to_dict().duplicate(true)
	var graph: Array = []
	var retain: RefCounted = load("res://tests/sections/renewed_marker_refresh_model.gd").new()
	retain._retain(registry, graph)
	var service_values := _service_values(service)
	retain._retain(service_values, graph)
	var social_before: Dictionary = service.to_dict().duplicate(true)
	var acting: StringName = PlayerRegistry._acting_id
	var restored: Array = []
	var restore := func() -> void:
		var live: Node = service_ref.get_ref()
		var parent: Node = root_ref.get_ref()
		var absent: bool = Svc.node("SocialManager") == null and GameData.autoload("SocialManager") == null
		# Restore the same in-tree object before checks, fake installation or await.
		if live != null: live.name = old_name
		var exact: bool = live != null and parent != null and live.get_parent() == parent and live.is_inside_tree() and live.name == old_name and Svc.node("SocialManager") == live and GameData.autoload("SocialManager") == live
		var model_ok: bool = is_same(PlayerRegistry._states, registry) and PlayerRegistry._acting_id == acting
		for id in registry: model_ok = model_ok and registry[id].to_dict() == values[id]
		var aliases_ok := true
		for edge in graph: aliases_ok = aliases_ok and is_same(edge.parent[edge.key] if edge.parent is Dictionary or edge.parent is Array else edge.parent.get(edge.key), edge.value)
		var service_ok: bool = live != null and _service_values(live) == service_values and live.to_dict() == social_before
		var bodies_ok: bool = world_ref.get_ref() == t.world() and body_ref.get_ref() == t.player() and PlayerRegistry.by_id(&"p0") == body_ref.get_ref()
		restored.append(exact)
		t.check("original_absence_probe_both_resolvers_really_absent", absent)
		t.check("exact_service_restored_synchronously_before_await", exact)
		t.check("absence_probe_service_models_values_aliases_bodies_preserved", model_ok and aliases_ok and service_ok and bodies_ok)
	service.name = hidden_name
	await original._when_grammar(t, restore)
	t.check("service_present_after_original_await", restored == [true] and service_ref.get_ref() == GameData.autoload("SocialManager") and Svc.node("SocialManager") == service_ref.get_ref())
	await original._when_hides_whole_props(t)

func _service_values(service: Node) -> Dictionary:
	var values := {}
	for property in service.get_script().get_script_property_list():
		var value: Variant = service.get(property.name)
		if value is Dictionary or value is Array: values[property.name] = value
	return values
