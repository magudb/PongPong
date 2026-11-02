extends RefCounted
const SECTION := "persistence_file_compat"
const TIMEOUT_S := 180.0
# Calls the original file-protocol controls unchanged; no external children.
func run(t) -> void:
	await t.go_menu()
	var fixture: RefCounted = load("res://tests/sections/save.gd").new()
	fixture.t = t
	for pair in [["sm","SaveManager"],["gm","GameManager"],["tm","TimeManager"],["eco","EconomyManager"],["qm","QuestManager"],["ah","AnimalHusbandry"],["shop","ShopSystem"],["bus","EventBus"]]: fixture.set(pair[0], t.autoload(pair[1]))
	fixture.svc = load("res://scripts/data/svc.gd")
	fixture.PH = fixture.gm.GamePhase
	fixture._scratch = "user://persistence_file_compat"
	DirAccess.make_dir_recursive_absolute(fixture._scratch)
	fixture.sm.save_dir = fixture._scratch
	fixture.sm.autosave_enabled = false
	fixture._notes = fixture._listen(fixture.bus.notification_posted)
	fixture._saved_slots = fixture._listen_first(fixture.bus.save_completed)
	fixture._loaded_slots = fixture._listen_first(fixture.bus.load_completed)
	for method in ["_test_atomic_apply", "_test_slots_and_backup", "_test_backup_cache", "_test_write_failure", "_test_interrupted_replacement", "_test_auto_runs", "_test_v1_migration", "_test_world_contract", "_test_sections_without_methods"]:
		fixture.call(method)
	await fixture._test_autosave()
	fixture._clear_fakes()
	fixture.svc.clear_overrides()
	fixture._unlisten_all()
