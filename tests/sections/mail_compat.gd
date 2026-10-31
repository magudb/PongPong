extends RefCounted
const SECTION := "mail_compat"
const TIMEOUT_S := 60.0

## Explicit no-tool canonical helper coverage, NOT the complete quests section.
func run(t) -> void:
	var fixture := preload("res://tests/sections/quests.gd").new()
	fixture.t = t
	fixture.qm = QuestManager
	fixture.gm = GameManager
	fixture.eco = EconomyManager
	fixture.bus = EventBus
	fixture.lr = LuaRuntime
	fixture.lm = LocalizationManager
	fixture._locale_before = TranslationServer.get_locale()
	fixture._game_events()
	fixture._forste_dage()
	fixture._cleanup()
