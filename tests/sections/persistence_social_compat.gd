extends RefCounted
const SECTION := "persistence_social_compat"
const TIMEOUT_S := 180.0
func run(t) -> void:
	await t.go_menu()
	var fixture: RefCounted = load("res://tests/sections/social.gd").new()
	fixture.t = t
	fixture.gm = t.autoload("GameManager")
	fixture.sm = t.autoload("SocialManager")
	fixture.sv = t.autoload("SaveManager")
	fixture._spy = fixture.Spy.new()
	fixture._autoload()
	fixture._gifts() # original unchanged no_forward_class_refs assertion
	fixture._save()
	fixture._cleanup()
	var sm: Node = t.autoload("SocialManager")
	var key := "res://scripts/towns/routines.gd::now_ctx"
	var present: bool = Svc._resolved.has(key)
	var previous: Variant = Svc._resolved.get(key)
	Svc._resolved[key] = null
	t.check("PB36_absent_context_fails_closed", sm._living_pair_context().is_empty())
	var invalid := GDScript.new()
	invalid.source_code = "extends RefCounted\nstatic func now_ctx():\n\treturn {\"hour\":12}\n"
	t.check("PB36_invalid_context_driver_compiles", invalid.reload() == OK)
	Svc._resolved[key] = invalid
	t.check("PB36_invalid_context_fails_before_pair_helpers", sm._living_pair_context().is_empty())
	if present: Svc._resolved[key] = previous
	else: Svc._resolved.erase(key)
	t.check("PB36_normal_late_context_preserved", not sm._living_pair_context().is_empty())
