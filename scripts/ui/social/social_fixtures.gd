extends RefCounted
## Deterministic preview state, reachable only through the development fixture registry.
static var _translations: Array[Translation] = []
static func seed(preview := false) -> void:
	if preview:
		GameManager.year = 1
		QuestManager.reset()
		EconomyManager.inventory.clear()
		for item in EconomyManager.STARTER_KIT:
			EconomyManager.add_item(StringName(str(item[0])), int(item[1]), true)
	# reset intentionally migrates old friendship flags; a pristine fixture must
	# clear those too, otherwise repeated previews accumulate points.
	for id in SocialData.friend_ids():
		GameManager.clear_flag(StringName("friend_" + id))
		GameManager.clear_flag(StringName("friend_last_" + id))
	SocialManager.reset()
	SocialManager.set_seed(777)
	GameManager.season = &"efteraar"
	GameManager.day = 9
	GameManager.hour = 14
	GameManager.minute = 0
	for entry in [["gardener_hoppe", 850], ["fairy_lily", 750], ["carpenter_brumme", 600], ["smith_thorin", 500], ["baker_maja", 450], ["postman_pip", 300], ["mayor_lyra", 200], ["bathkeeper_sofus", 120], ["beekeeper_birk", 40]]:
		SocialManager.add_points(entry[0], entry[1], &"fixture", {"toast": false})
		SocialManager.row_of(entry[0])["bk"] = 1
	var hoppe := SocialManager.row_of("gardener_hoppe")
	hoppe["kn"] = {"carrot": "love", "moonflower": "love", "strawberry": "like", "stone": "dislike"}
	for item in ["carrot", "turnip", "moonflower", "strawberry", "stone", "wood", "honey", "blueberry", "pumpkin", "honey_cake", "flour", "sugar"]:
		if not ItemKinds.def(item).is_empty() and EconomyManager.count_item(item) < 3:
			EconomyManager.add_item(item, 3)

static func festival() -> void:
	for translation in _translations:
		TranslationServer.remove_translation(translation)
	_translations.clear()
	for locale in ["da", "en"]:
		var translation := Translation.new()
		translation.locale = locale
		translation.add_message(&"REL_CAL_FIXTURE_FESTIVAL", "Høstfesten" if locale == "da" else "Harvest festival")
		TranslationServer.add_translation(translation)
		_translations.append(translation)
	var path := "user://social-ui-festival.lua"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('kind = "registry"\nregistry = "festivals"\nfestivals = { social_ui_fixture = { meta = {name_key = "REL_CAL_FIXTURE_FESTIVAL", area = "traetoppen", season = "%s", day = %d, from = 12, to = 20, closes = "none"} } }\n' % [GameManager.season, GameManager.day])
	file.close()
	LuaRuntime.load_file(path)

static func cleanup() -> void:
	LuaRuntime.reload_scripts()
	for translation in _translations:
		TranslationServer.remove_translation(translation)
	_translations.clear()
