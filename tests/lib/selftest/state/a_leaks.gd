extends RefCounted
## Harness self-test: a section changes shared state, registers a cleanup and then dies of a script error before it restores
## anything. The cleanup still runs, and the harness puts back what was left (see b_checks).
const SECTION := "a_leaks"

func run(t) -> void:
	t.on_cleanup(func() -> void: print("CLEANUP-RAN-SECOND"))
	t.on_cleanup(func() -> void:
		await t.frames(1)
		print("CLEANUP-RAN-FIRST"))
	t.autoload("LocalizationManager").set_locale("en", false)
	t.autoload("GameManager").set_config_override("selftest.leaked_key", 7)
	Engine.set_meta(&"st_leaked_meta", 1)
	t.autoload("LootService").delegate_path = "user://selftest_leaked_delegate.gd"
	t.autoload("GameManager").push_modal(&"selftest_leaked_modal", false)
	await t.frames(1)
	var nothing = null
	nothing.no_such_method()
	t.check("AFTER_ERROR_SHOULD_NOT_RUN", true)
