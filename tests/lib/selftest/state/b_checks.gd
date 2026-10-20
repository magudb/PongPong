extends RefCounted
## Harness self-test: what a_leaks left behind was restored before this section started, and a restore keeps the modals that were
## open before a section.
const SECTION := "b_checks"

func run(t) -> void:
	t.check("locale_restored", str(t.autoload("LocalizationManager").current_locale) == "da", str(t.autoload("LocalizationManager").current_locale))
	t.check("config_override_cleared", t.autoload("GameManager").config_value("selftest.leaked_key", null) == null)
	t.check("engine_meta_removed", not Engine.has_meta(&"st_leaked_meta"))
	var loot: Node = t.autoload("LootService")
	t.check("service_path_restored", loot.delegate_path == loot.DELEGATE_PATH, loot.delegate_path)
	t.check("modal_stack_emptied", not t.autoload("GameManager").is_modal_open())
	# the restore pops only the modals a section opened, never one that was open before it started
	var gm: Node = t.autoload("GameManager")
	gm.push_modal(&"st_open_before", false)
	var before: Dictionary = t.tree._snapshot_state()
	gm.push_modal(&"st_opened_inside", false)
	t.tree._restore_state(before, "modal_probe")
	t.check("modal_opened_inside_is_popped", not gm.is_modal_open(&"st_opened_inside"), gm.modal_stack())
	t.check("modal_open_before_is_kept", gm.is_modal_open(&"st_open_before"), gm.modal_stack())
	gm.pop_modal(&"st_open_before")
