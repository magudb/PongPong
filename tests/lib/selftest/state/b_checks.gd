extends RefCounted
## Harness self-test: what a_leaks left behind was restored before this section started.
const SECTION := "b_checks"

func run(t) -> void:
	t.check("locale_restored", str(t.autoload("LocalizationManager").current_locale) == "da", str(t.autoload("LocalizationManager").current_locale))
	t.check("config_override_cleared", t.autoload("GameManager").config_value("selftest.leaked_key", null) == null)
	t.check("engine_meta_removed", not Engine.has_meta(&"st_leaked_meta"))
	var loot: Node = t.autoload("LootService")
	t.check("service_path_restored", loot.delegate_path == loot.DELEGATE_PATH, loot.delegate_path)
	t.check("modal_stack_emptied", not t.autoload("GameManager").is_modal_open())
