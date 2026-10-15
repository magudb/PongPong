extends RefCounted
## Section "loc" (P03-loc-core): runtime CSV localization, locale persistence, lint, key ownership, loc_check, tools.
##
## Named checks (plan 7.3 task 7): loc.csv_keep_imports, loc.ownership_lint. Everything else is listed in run().
## V1-cast-data (carved out of P03): loc.core_csv_pins (ZONE_FARM 'Min Trækronsgård', ZONE_TRAETOPPEN, ZONE_CITY, the NPC names of the v2 cast and the towns citizens).
## The fixtures (tiny localization folders and project roots) are written to the user dir and removed again.

const SECTION := "loc"
const TIMEOUT_S := 180.0

const LM := preload("res://scripts/autoload/localization_manager.gd")
const KEEP := "[remap]\n\nimporter=\"keep\"\n"
## The harness pattern of a raw translation key (tests/lib/t.gd RAW_KEY_PATTERN), applied to what a node DISPLAYS.
const RAW_KEY := "^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$"
const TRANSLATION_IMPORT := "[remap]\n\nimporter=\"csv_translation\"\ntype=\"Translation\"\n"

var _t
var _lm: Node
var _bus: Node
var _toasts: Array = []
var _fixtures: Array[String] = []


## Stand-in for the AudioManager autoload (the voice forwarder test swaps it in for a moment).
class FakeAudio extends Node:
	var calls: Array = []

	func play_voice(key: String, volume_db: float = NAN) -> void:
		calls.append([key, volume_db])

	func voice_exists(key: String) -> bool:
		return key == "voice/x/y"


func run(t) -> void:
	_t = t
	_lm = t.autoload("LocalizationManager")
	_bus = t.autoload("EventBus")
	if _lm == null or _bus == null:
		return
	var settings_before := _snapshot_settings()
	var locale_before: String = _lm.current_locale
	if _bus.has_signal("notification_posted"):
		_bus.connect("notification_posted", _on_toast)
	_check_loader()
	_check_core_copy()
	await _check_runtime_switch()
	_check_toast_and_persistence()
	_check_t_and_lookups()
	_check_static_helpers()
	_check_lua_reader()
	_check_lint_real_tree()
	_check_lint_fixtures()
	_check_ownership()
	_check_voice_forwarder()
	_check_python_tools()
	_check_loc_check_cli()
	# restore the user's state
	if _bus.has_signal("notification_posted") and _bus.is_connected("notification_posted", _on_toast):
		_bus.disconnect("notification_posted", _on_toast)
	_restore_settings(settings_before)
	_lm.boot()
	if _lm.current_locale != locale_before:
		_lm.set_locale(locale_before, false)
		_restore_settings(settings_before)
	for f in _fixtures:
		_rm_rf(f)


func _on_toast(title: String, message: String, icon: String) -> void:
	_toasts.append([title, message, icon])


# ---------------------------------------------------------------- loader

func _check_loader() -> void:
	var t = _t
	var files: PackedStringArray = _lm.loaded_files()
	var rest: Array[String] = []
	for f in files:
		if f != "da.csv":
			rest.append(f)
	var sorted_rest := rest.duplicate()
	sorted_rest.sort()
	t.check("loader_order_da_first_then_alphabetical", files.size() > 0 and files[0] == "da.csv" and rest == sorted_rest, "files %s" % str(files))
	t.check("loader_has_core_and_no_legacy_en_csv", "core.csv" in files and not ("en.csv" in files) and not FileAccess.file_exists("res://localization/en.csv"), str(files))
	var junk: Array[String] = []
	var da := DirAccess.open("res://localization")
	for f in da.get_files():
		if f.ends_with(".translation") and not f.begins_with("da."):
			junk.append(f)
	t.check("no_translation_junk_for_non_legacy_csv", junk.is_empty(), "found %s (a CSV without keep-import was imported)" % str(junk))
	# the project must not list translations (runtime loader, plan D6)
	var listed: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations", PackedStringArray())
	t.check("project_has_no_translations_list", listed.is_empty(), "locale/translations must stay empty (runtime loader, plan D6): %s" % str(listed))
	t.check("fallback_locale_is_en", str(ProjectSettings.get_setting("internationalization/locale/fallback")) == "en")
	# key count: independent count (python csv module) must equal the loader's; the plan's floor of 480 holds once ui.csv exists
	var n: int = _lm.all_keys().size()
	var floor_n := 480 if FileAccess.file_exists("res://localization/ui.csv") else 415
	t.check("loader_finds_keys", n >= floor_n, "%d keys (floor %d%s)" % [n, floor_n, "" if floor_n == 480 else ": 480 is reached when P07's ui.csv lands"])
	var py := _python()
	if py != "":
		var res: Dictionary = t.run_tool(py, PackedStringArray(["-I", _abs("res://tools/loc/csv_lint.py"), "--json", "--root", _abs("res://"), "--dir", _abs("res://localization")]))
		var data: Variant = JSON.parse_string(str(res["output"]))
		var independent := int((data as Dictionary).get("key_count", -1)) if data is Dictionary else -1
		t.check("loader_key_count_matches_independent_parser", independent == n, "GDScript loader %d keys, python csv module %d" % [n, independent])
	else:
		t.skip("loc.loader_key_count_matches_independent_parser (no python found)")
	# the loader replaced, not doubled, the translations when it ran twice
	var before: int = _lm.all_keys().size()
	_lm.reload()
	t.check("reload_does_not_double", _lm.all_keys().size() == before and TranslationServer.get_loaded_locales().size() <= 4, "locales %s" % str(TranslationServer.get_loaded_locales()))


func _check_core_copy() -> void:
	var t = _t
	var want := {
		"GAME_TITLE": ["Trætoppen", "Trætoppen"],
		"GAME_SUBTITLE": ["En gård i Fekongens skov", "A farm in the Fairy King's forest"],
		"UI_GOLD": ["guldagern", "gold acorns"],
		"UI_WEATHER_KLART": ["Solskin", "Sunny"],
		"CHAR_SELECT_TITLE": ["Hvem er du?", "Who are you?"],
		"CHAR_ANIMAL_NAME": ["Skovdyr", "Forest animal"],
		"UI_JOURNAL": ["Opgavebog", "Quest book"],
		"UI_INVENTORY": ["Rygsæk", "Backpack"],
		"NOTIF_QUEST_ACCEPTED_TITLE": ["Ny opgave!", "New quest!"],
		"NOTIF_QUEST_COMPLETED_TITLE": ["Opgave fuldført!", "Quest complete!"],
		"NPC_MAYOR_LYRA": ["Borgmester Hyldeblomst", "Mayor Hyldeblomst"],
		"NPC_BAKER_MAJA": ["Bagerfe Rosmarin", "Baker-fairy Rosmarin"],
		"NPC_MERCHANT_PIP": ["Butiksfe Kløvermynte", "Shop-fairy Kløvermynte"],
		"NPC_FAIRY_KING": ["Fekongen", "The Fairy King"],
		"NPC_CAT_MORFAR_MIS": ["Morfar Mis", "Grandpa Mis"],
		"ZONE_FARM": ["Min Trækronsgård", "My Treetop Farm"],
		"ZONE_TRAETOPPEN": ["Trætoppen", "Trætoppen"],
		"ZONE_CITY": ["Hyggebyen", "Hyggebyen"],
		"ZONE_DARK_FOREST": ["Mørkeskoven", "The Dark Wood"],
		"ZONE_FOREST_EDGE": ["Skovkanten", "The Forest Edge"],
		"ZONE_DYBE_BREGNER": ["Dybe Bregner", "Deep Ferns"],
		"ZONE_MUSHROOM_GROVE": ["Svampelunden", "Mushroom Grove"],
		"ZONE_CRYSTAL_CAVE": ["Krystalgrotten", "Crystal Cave"],
		"LANG_DA": ["dansk", "Danish"],
		"LANG_EN": ["engelsk", "English"],
	}
	var bad: Array[String] = []
	for key in want:
		for i in 2:
			var loc := "da" if i == 0 else "en"
			var got: String = _lm.text_in(key, loc)
			if got != want[key][i]:
				bad.append("%s/%s='%s'" % [key, loc, got])
	t.check("core_csv_copy_in_both_languages", bad.is_empty(), str(bad.slice(0, 4)))
	var owned: Array[String] = []
	for key in ["NPC_FAIRY_LILY", "NPC_SMITH_THORIN", "NPC_GUARD_OAK", "NPC_FARMER_ROSA", "NPC_FAIRY_WIZARD", "NPC_PIPPIN_BOEGEKNOP", "NPC_PENGUIN_POSTMAN"]:
		if _lm.file_of(key) != "core.csv" or _lm.text_in(key, "da") == "" or _lm.text_in(key, "en") == "":
			owned.append(key)
	t.check("core_csv_defines_the_roster_names", owned.is_empty(), str(owned))
	# V1-cast-data: the farm is its own branch (Min Trækronsgård), the treetop city is Trætoppen, Hyggebyen keeps its name (zone id `city` is kept on
	# purpose), and the seven new figures of the Figurer v2 cast + the eight citizens of the towns track have their names in core.csv (NPC_<ID>)
	var v1_pins := {
		"ZONE_FARM": ["Min Trækronsgård", "My Treetop Farm"], "ZONE_TRAETOPPEN": ["Trætoppen", "Trætoppen"], "ZONE_CITY": ["Hyggebyen", "Hyggebyen"],
		"NPC_GARDENER_HOPPE": ["Gartner Hoppe", "Gardener Hoppe"], "NPC_CARPENTER_BRUMME": ["Tømrer Brumme", "Carpenter Brumme"], "NPC_POSTMAN_PIP": ["Postbud Pip", "Postman Pip"],
		"NPC_BATHKEEPER_SOFUS": ["Sofus", "Sofus"], "NPC_APPRAISER_FRU_UGLE": ["Fru Ugle", "Mrs Owl"], "NPC_MAPSELLER_NATTEBLIK": ["Natteblik", "Natteblik"], "NPC_BEEKEEPER_BIRK": ["Birk", "Birk"],
		"NPC_RASMUS": ["Rasmus", "Rasmus"], "NPC_LAMPLIGHTER_KIKI": ["Kiki", "Kiki"], "NPC_BERTIL": ["Bertil Bøgeknop", "Bertil Bøgeknop"], "NPC_BODIL": ["Bodil Bøgeknop", "Bodil Bøgeknop"],
		"NPC_INNKEEPER_KVAK": ["Værten Kvak", "Innkeeper Kvak"], "NPC_CUB_BAMSE": ["Bamse", "Bamse"], "NPC_CLERK_FJERPEN": ["Skriver Fjerpen", "Clerk Fjerpen"], "NPC_FIDDLER_STRIMMEL": ["Spillemand Strimmel", "Fiddler Strimmel"],
	}
	var pin_bad: Array[String] = []
	for key in v1_pins:
		if _lm.file_of(key) != "core.csv":
			pin_bad.append("%s is defined in '%s', not core.csv" % [key, _lm.file_of(key)])
		for i in 2:
			var loc2 := "da" if i == 0 else "en"
			if _lm.text_in(key, loc2) != v1_pins[key][i]:
				pin_bad.append("%s/%s='%s'" % [key, loc2, _lm.text_in(key, loc2)])
	t.check("core_csv_pins", pin_bad.is_empty() and _lm.text_in("ZONE_FARM", "da") != _lm.text_in("ZONE_TRAETOPPEN", "da"), "ZONE_FARM 'Min Trækronsgård' / 'My Treetop Farm' (no longer 'Trætoppen'), ZONE_TRAETOPPEN, ZONE_CITY and the %d NPC names of the v2 cast and the towns citizens, all in core.csv %s" % [v1_pins.size() - 3, str(pin_bad.slice(0, 4))])
	# core.csv only holds the key families of the R.4 table
	var strays: Array[String] = []
	var rep := LM.parse_dir("res://localization", "res://", false)
	for d in rep["defs"]:
		if d["file"] == "core.csv" and not (str(d["key"]).begins_with("GAME_") or str(d["key"]).begins_with("NPC_") or str(d["key"]).begins_with("ZONE_") or str(d["key"]).begins_with("LANG_")):
			if not (str(d["key"]) in ["UI_GOLD", "UI_WEATHER_KLART", "UI_JOURNAL", "UI_INVENTORY", "NOTIF_QUEST_ACCEPTED_TITLE", "NOTIF_QUEST_COMPLETED_TITLE", "NOTIF_LANGUAGE_CHANGED_MSG", "CHAR_SELECT_TITLE", "CHAR_ANIMAL_NAME"]):
				strays.append(str(d["key"]))
	t.check("core_csv_only_r4_families", strays.is_empty(), str(strays))
	var old_town := "fes" + "by"    # the old name of the fairy town (never written out): core.csv must not carry it
	t.check("core_csv_names_the_town_hyggebyen", not FileAccess.get_file_as_string("res://localization/core.csv").to_lower().contains(old_town) and _lm.text_in("ZONE_CITY", "da") == "Hyggebyen")


# ---------------------------------------------------------------- runtime switch, toast, persistence

func _check_runtime_switch() -> void:
	var t = _t
	_lm.set_locale("da", false)
	var label := Label.new()
	label.text = "UI_INVENTORY"
	t.root.add_child(label)
	await t.frames(2)
	var da_len := label.get_total_character_count()
	t.check("switch_runtime_label_da", label.atr(label.text) == "Rygsæk" and da_len == "Rygsæk".length(), "atr='%s' chars=%d" % [label.atr(label.text), da_len])
	var seen: Array[String] = []
	var cb := func(loc: String) -> void: seen.append(loc)
	_lm.connect("locale_changed", cb)
	_lm.set_locale("en", false)
	await t.frames(2)
	var en_len := label.get_total_character_count()
	t.check("switch_runtime_label_en", label.atr(label.text) == "Backpack" and en_len == "Backpack".length(), "atr='%s' chars=%d" % [label.atr(label.text), en_len])
	t.check("switch_runtime_state_and_server", _lm.current_locale == "en" and TranslationServer.get_locale() == "en" and _lm.is_en() and not _lm.is_da())
	_lm.set_locale("en", false)
	t.check("locale_changed_emitted_once_per_real_change", seen == ["en"], "signals %s" % str(seen))
	_lm.set_locale("da", false)
	await t.frames(2)
	t.check("switch_runtime_back_to_da", label.atr(label.text) == "Rygsæk" and label.get_total_character_count() == "Rygsæk".length() and seen == ["en", "da"], "signals %s" % str(seen))
	var shown := label.atr(label.text)
	var raw_rx := RegEx.new()
	raw_rx.compile(RAW_KEY)
	t.check("no_raw_key_displayed_after_a_switch", raw_rx.search(shown) == null and shown != label.text, "label shows '%s'" % shown)
	_lm.disconnect("locale_changed", cb)
	t.allow("unsupported locale")
	_lm.set_locale("xx", false)
	t.expect_allowed("unsupported locale", 1, "set_locale('xx') warns")
	t.check("unsupported_locale_is_rejected", _lm.current_locale == "da" and seen == ["en", "da"])
	_lm.set_locale("EN_us", false)
	t.check("locale_codes_are_normalised", _lm.current_locale == "en")
	_lm.set_locale("da", false)
	label.queue_free()
	# fallback: a key that exists only in en is shown in en while the locale is da (project fallback "en")
	var probe := Translation.new()
	probe.locale = "en"
	probe.add_message("ZZ_LOC_PROBE_ONLY_EN", "english only")
	TranslationServer.add_translation(probe)
	t.check("fallback_locale_serves_en_text", String(TranslationServer.translate("ZZ_LOC_PROBE_ONLY_EN")) == "english only" and TranslationServer.get_locale() == "da")
	TranslationServer.remove_translation(probe)


func _check_toast_and_persistence() -> void:
	var t = _t
	var cfg_path := "user://settings.cfg"
	# an unrelated section the shared file must keep
	var cfg := ConfigFile.new()
	cfg.load(cfg_path)
	cfg.set_value("audio", "master_db", -3.5)
	cfg.set_value("zz_loc_probe", "keep_me", "yes")
	if cfg.has_section_key("game", "locale"):
		cfg.erase_section_key("game", "locale")
	cfg.save(cfg_path)
	_toasts.clear()
	var signals_at_boot := [0]
	var cb := func(_l: String) -> void: signals_at_boot[0] += 1
	_lm.connect("locale_changed", cb)
	_lm.boot()
	t.check("boot_posts_no_toast_and_no_signal", _toasts.is_empty() and signals_at_boot[0] == 0, "toasts %s" % str(_toasts))
	t.check("boot_default_locale_is_da", _lm.current_locale == "da" and TranslationServer.get_locale() == "da")
	_lm.set_locale("en", true)
	t.check("announce_posts_one_toast_with_language_name", _toasts.size() == 1 and str(_toasts[0][1]) == "Language is now English." and str(_toasts[0][0]) == "Language changed" and str(_toasts[0][2]) == "language", str(_toasts))
	var back := ConfigFile.new()
	back.load(cfg_path)
	t.check("locale_persisted_in_settings_cfg", str(back.get_value("game", "locale", "")) == "en", "[game] locale = %s" % str(back.get_value("game", "locale", "<none>")))
	t.check("settings_cfg_other_sections_kept", is_equal_approx(float(back.get_value("audio", "master_db", 0.0)), -3.5) and str(back.get_value("zz_loc_probe", "keep_me", "")) == "yes")
	_toasts.clear()
	_lm.set_locale("da", false)
	t.check("announce_false_posts_no_toast", _toasts.is_empty())
	_toasts.clear()
	_lm.set_locale("en", true)
	_lm.set_locale("da", true)
	t.check("da_toast_is_danish", _toasts.size() == 2 and str(_toasts[1][1]) == "Sproget er nu dansk." and str(_toasts[1][0]) == "Sprog ændret", str(_toasts))
	_toasts.clear()
	_lm.set_locale("da", true)
	t.check("same_locale_posts_no_toast", _toasts.is_empty())
	# boot() takes the saved locale; garbage and missing values fall back to da
	var saved := ConfigFile.new()
	saved.load(cfg_path)
	saved.set_value("game", "locale", "en")
	saved.save(cfg_path)
	_toasts.clear()
	signals_at_boot[0] = 0
	_lm.boot()
	t.check("boot_uses_saved_locale_silently", _lm.current_locale == "en" and TranslationServer.get_locale() == "en" and _toasts.is_empty() and signals_at_boot[0] == 0)
	saved.set_value("game", "locale", "klingon")
	saved.save(cfg_path)
	_lm.boot()
	t.check("boot_garbage_locale_falls_back_to_da", _lm.current_locale == "da")
	if saved.has_section_key("game", "locale"):
		saved.erase_section_key("game", "locale")
	saved.save(cfg_path)
	_lm.boot()
	t.check("boot_missing_locale_is_da", _lm.current_locale == "da")
	# a corrupt settings file is never overwritten (it may hold the player's other settings)
	var f := FileAccess.open(cfg_path, FileAccess.WRITE)
	f.store_string("[audio\nmaster_db = ??\n")
	f.close()
	t.allow("is unreadable")
	t.allow("ConfigFile parse error")
	_lm.set_locale("en", false)
	t.expect_allowed("is unreadable", 1, "a corrupt settings.cfg is reported")
	t.check("corrupt_settings_file_left_alone", FileAccess.get_file_as_string(cfg_path) == "[audio\nmaster_db = ??\n", "file content changed")
	var clean_cfg := ConfigFile.new()
	clean_cfg.set_value("audio", "master_db", -3.5)
	clean_cfg.save(cfg_path)
	_lm.set_locale("da", false)
	_lm.disconnect("locale_changed", cb)


# ---------------------------------------------------------------- t(), has_key, all_keys

func _check_t_and_lookups() -> void:
	var t = _t
	_lm.set_locale("da", false)
	t.check("t_formats_translated_key", _lm.t("NOTIF_LANGUAGE_CHANGED_MSG", ["dansk"]) == "Sproget er nu dansk.", _lm.t("NOTIF_LANGUAGE_CHANGED_MSG", ["dansk"]))
	t.check("t_without_args_returns_template", _lm.t("NOTIF_LANGUAGE_CHANGED_MSG") == "Sproget er nu %s.")
	var mark: int = t.log_mark()
	t.check("t_never_formats_an_untranslated_key", _lm.t("NO_SUCH_KEY_%d", [3]) == "NO_SUCH_KEY_%d" and _lm.t("NO_SUCH_KEY", [1, 2]) == "NO_SUCH_KEY")
	t.expect_clean_since(mark, "t() of an untranslated key logs nothing")
	t.allow("takes 1 argument(s)")
	var wrong: String = _lm.t("NOTIF_LANGUAGE_CHANGED_MSG", ["a", "b"])
	t.expect_allowed("takes 1 argument(s)", 1, "wrong argument count warns")
	t.check("t_wrong_argument_count_returns_the_template", wrong == "Sproget er nu %s.")
	t.check("has_key", _lm.has_key("GAME_TITLE") and _lm.has_key("MENU_NEW_GAME") and not _lm.has_key("NO_SUCH_KEY") and not _lm.has_key(""))
	var keys: PackedStringArray = _lm.all_keys()
	t.check("all_keys_lists_core_and_legacy", "GAME_TITLE" in keys and "NPC_FAIRY_KING" in keys and "MENU_NEW_GAME" in keys and not ("NO_SUCH_KEY" in keys))
	t.check("language_name_in_its_own_language", _lm.language_name("da") == "dansk" and _lm.language_name("en") == "English")
	t.check("file_of_reports_the_overriding_file", _lm.file_of("GAME_TITLE") == "core.csv" and _lm.file_of("MENU_NEW_GAME") in ["da.csv", "ui.csv", "menus.csv"] and _lm.file_of("NO_SUCH") == "")
	t.check("legacy_key_overridden_by_core_wins", _lm.text_in("GAME_TITLE", "da") == "Trætoppen" and _lm.text_in("UI_INVENTORY", "en") == "Backpack")
	# the old formatting crash of lua_runtime.gd:42 (tr() of an untranslated key used with %) is gone
	t.check("lua_runtime_reload_message_is_translated", TranslationServer.translate("NOTIF_LUA_RELOADED_MSG") != "NOTIF_LUA_RELOADED_MSG" and String(TranslationServer.translate("NOTIF_LUA_RELOADED_MSG")) % 3 != "")


# ---------------------------------------------------------------- pure helpers

func _check_static_helpers() -> void:
	var t = _t
	t.check("is_valid_key", LM.is_valid_key("A_B1") and not LM.is_valid_key("a_b") and not LM.is_valid_key("A:B") and not LM.is_valid_key("") and not LM.is_valid_key("A B"))
	t.check("format_signature", LM.format_signature("Dag %d") == "d" and LM.format_signature("%s har %d") == "ds" and LM.format_signature("100%% sikker") == "" and LM.format_signature("%.1f og %02d") == "df" and LM.format_arg_count("%s %s") == 2 and LM.format_arg_count("ingen") == 0)
	t.check("unescape_text", LM.unescape_text("a\\nb\\tc\\\\d\\\"e") == "a\nb\tc\\d\"e" and LM.unescape_text("rent") == "rent" and LM.unescape_text("slut\\") == "slut\\" and LM.unescape_text("\\q") == "\\q")
	t.check("normalize_locale", LM.normalize_locale("da_DK") == "da" and LM.normalize_locale(" EN-us ") == "en" and LM.normalize_locale("de") == "" and LM.normalize_locale("") == "")
	var files := LM.list_csv_files("res://localization")
	t.check("list_csv_files_order", files.size() >= 2 and files[0] == "da.csv")
	t.check("voice_key_for_has_no_double_prefix", _lm.voice_key_for("oak", "greet") == "voice/oak/greet" and _lm.voice_key_for("oak", "voice/oak/greet") == "voice/oak/greet")


func _check_lua_reader() -> void:
	var t = _t
	var src := """-- a comment
kind = "items"
version = 3
flag = true
ratio = 1.5
items = {
  -- inside a table
  alpha = { name_key = "ITEM_ALPHA", n = 5, f = 1.5, neg = -2, nested = { a = { "x", "y" }, empty = {} }, },
  ["beta"] = { list = { 1, 2, 3 }, s = 'single', t = "with, comma and } brace" },
  gamma = {
    f = function() return 1 end,
    after = "ok",
    -- trailing comment
  },
}
function foo(x)
  return { a = 1 }
end
config = { one = { two = 2 } }
config = { three = 3 }
"""
	var d := LM.lua_parse(src)
	var items: Dictionary = d.get("items", {})
	var alpha: Dictionary = items.get("alpha", {})
	t.check("lua_reader_top_level_scalars", d.get("kind") == "items" and d.get("version") == 3 and d.get("flag") == true and is_equal_approx(float(d.get("ratio", 0)), 1.5) and not d.has("foo"))
	t.check("lua_reader_items_ids", items.keys() == ["alpha", "beta", "gamma"], str(items.keys()))
	t.check("lua_reader_nested_values", alpha.get("n") == 5 and alpha.get("neg") == -2 and alpha.get("nested", {}).get("a") == ["x", "y"] and alpha.get("nested", {}).get("empty") == [], str(alpha))
	t.check("lua_reader_bracket_keys_and_strings", items["beta"].get("list") == [1, 2, 3] and items["beta"].get("s") == "single" and items["beta"].get("t") == "with, comma and } brace", str(items["beta"]))
	t.check("lua_reader_skips_function_values_without_losing_the_next_key", items["gamma"].get("after") == "ok", str(items["gamma"]))
	t.check("lua_reader_merges_repeated_top_level_tables", d.get("config", {}).get("one", {}).get("two") == 2 and d.get("config", {}).get("three") == 3, str(d.get("config")))
	# a hostile/unfinished table must terminate
	var broken := LM.lua_parse("items = { a = { b = \"x\", c = {")
	t.check("lua_reader_terminates_on_unfinished_input", broken.has("items"))
	var real := LM.lua_parse(FileAccess.get_file_as_string("res://lua/items/crops.lua"))
	t.check("lua_reader_reads_the_real_items_file", real.get("items", {}) is Dictionary and (real["items"] as Dictionary).has("turnip_seeds"), "ids %s" % str((real.get("items", {}) as Dictionary).keys().slice(0, 4)))


# ---------------------------------------------------------------- lint on the real tree

func _check_lint_real_tree() -> void:
	var t = _t
	var rep: Dictionary = _lm.lint()
	var errors: Array = rep["errors"]
	var legacy: Array = rep["legacy"]
	var msgs: Array[String] = []
	for e in errors:
		msgs.append(LM.format_issue(e))
	t.check("lint_clean_for_non_legacy_files", errors.is_empty(), str(msgs.slice(0, 3)))
	var dup_errors := 0
	for e in errors:
		if e["cat"] == "duplicate":
			dup_errors += 1
	t.check("lint_no_duplicate_errors_for_non_legacy_files", dup_errors == 0, "%d duplicate errors" % dup_errors)
	var stray: Array[String] = []
	var tolerated := ["duplicate", "malformed", "keep-import", "missing-text", "format", "header", "unreadable"]
	for e in legacy:
		if e["file"] != "da.csv" or not (str(e["cat"]) in tolerated):
			stray.append(LM.format_issue(e))
	t.check("lint_legacy_issues_only_in_da_csv", stray.is_empty(), str(stray.slice(0, 3)))
	var strict: Dictionary = _lm.lint(true)
	t.check("lint_strict_makes_legacy_issues_fatal", (strict["errors"] as Array).size() == errors.size() + legacy.size() and (strict["legacy"] as Array).is_empty())
	t.check("lint_reports_key_count_and_files", int(rep["key_count"]) == _lm.all_keys().size() and (rep["files"] as PackedStringArray) == _lm.loaded_files())
	# R.4: every CSV ships a keep-import
	var bad_imports: Array[String] = []
	for f in _lm.loaded_files():
		if f == "da.csv":
			continue
		var cfg := ConfigFile.new()
		if cfg.load("res://localization/%s.import" % f) != OK or str(cfg.get_value("remap", "importer", "")) != "keep":
			bad_imports.append(f)
	var legacy_import_ok := true
	var cfg_da := ConfigFile.new()
	var da_is_keep := cfg_da.load("res://localization/da.csv.import") == OK and str(cfg_da.get_value("remap", "importer", "")) == "keep"
	if not da_is_keep:
		# the legacy base is tolerated, but lint() must say so (fatal under --strict)
		legacy_import_ok = false
		for e in legacy:
			if e["cat"] == "keep-import" and e["file"] == "da.csv":
				legacy_import_ok = true
	t.check("csv_keep_imports", bad_imports.is_empty() and legacy_import_ok, "without keep-import: %s; da.csv.import keep=%s reported=%s" % [str(bad_imports), da_is_keep, legacy_import_ok])


# ---------------------------------------------------------------- lint rules on fixtures

func _cats(report: Dictionary, sev: String) -> Array[String]:
	var out: Array[String] = []
	for iss in (report["issues"] as Array):
		if iss["sev"] == sev:
			out.append("%s:%s" % [iss["cat"], iss["file"]])
	out.sort()
	return out


func _lint_fixture(name: String, files: Dictionary) -> Dictionary:
	var base := _fixture(name, files)
	return LM.parse_dir(base.path_join("localization"), base + "/", true)


func _check_lint_fixtures() -> void:
	var t = _t
	var da_csv := "keys,da,en\nA_ONE,\"ett\",\"one\"\nB_TWO,\"to\",\"two\"\n"
	var owners := JSON.stringify({"files": {"a.csv": {"owner": "T", "prefix": ["A_"], "exact": []}, "b.csv": {"owner": "T", "prefix": ["B_"], "exact": []}}})
	# clean tree: a legacy override, an own key, zz_final overriding a non-voiced key
	var clean := _lint_fixture("clean", {
		"localization/da.csv": da_csv, "localization/da.csv.import": KEEP,
		"localization/a.csv": "keys,da,en\nA_ONE,\"et\",\"one!\"\nA_NEW,\"ny\",\"new\"\n", "localization/a.csv.import": KEEP,
		"localization/b.csv": "keys,da,en\nB_TWO,\"to\",\"two\"\nB_FMT,\"Dag %d\",\"Day %d\"\n", "localization/b.csv.import": KEEP,
		"localization/zz_final.csv": "keys,da,en\nB_TWO,\"to!\",\"two!\"\n", "localization/zz_final.csv.import": KEEP,
		"tools/loc/key_owners.json": owners})
	t.check("fixture_clean_tree_has_no_issues", (clean["issues"] as Array).is_empty(), str(_cats(clean, "error") + _cats(clean, "legacy") + _cats(clean, "warning")))
	t.check("fixture_override_order_later_file_wins", (clean["rows"]["A_ONE"]["text"]["da"] == "et") and (clean["rows"]["B_TWO"]["text"]["en"] == "two!") and (clean["rows"]["A_ONE"]["file"] == "a.csv"))
	# duplicates
	var dups := _lint_fixture("dups", {
		"localization/a.csv": "keys,da,en\nA_SAME,\"x\",\"x\"\nA_SAME,\"y\",\"y\"\nSHARED,\"1\",\"1\"\n", "localization/a.csv.import": KEEP,
		"localization/b.csv": "keys,da,en\nSHARED,\"2\",\"2\"\n", "localization/b.csv.import": KEEP,
		"localization/da.csv": "keys,da,en\nSHARED,\"0\",\"0\"\nLEG,\"1\",\"1\"\nLEG,\"2\",\"2\"\n", "localization/da.csv.import": KEEP})
	t.check("fixture_duplicates_same_file_and_two_non_legacy_files", _cats(dups, "error") == ["duplicate:a.csv", "duplicate:b.csv"] and _cats(dups, "legacy") == ["duplicate:da.csv"], "%s | %s" % [str(_cats(dups, "error")), str(_cats(dups, "legacy"))])
	t.check("fixture_legacy_duplicate_last_row_wins", dups["rows"]["LEG"]["text"]["da"] == "2" and dups["rows"]["SHARED"]["file"] == "b.csv")
	# malformed rows, missing text, header
	var bad := _lint_fixture("badrows", {
		"localization/x.csv": "keys,da,en\nlower_key,\"x\",\"y\"\nONLY_DA,\"x\"\nNO_EN,\"x\",\"\"\nTOO_MANY,\"a\",\"b\",\"c\"\nTRAILING,\"a\",\"b\",\nMULTI,\"line\none\",\"two\nlines\"\nAFTER_MULTI,\"x\",\"y\"\nlate bad,\"x\",\"y\"\n", "localization/x.csv.import": KEEP,
		"localization/h.csv": "key,da\nH_ONE,\"x\"\n", "localization/h.csv.import": KEEP})
	var bad_lines: Array[int] = []
	for iss in bad["issues"]:
		if iss["file"] == "x.csv":
			bad_lines.append(int(iss["line"]))
	bad_lines.sort()
	t.check("fixture_malformed_rows_missing_text_and_header", _cats(bad, "error") == ["header:h.csv", "malformed:x.csv", "malformed:x.csv", "malformed:x.csv", "malformed:x.csv", "missing-text:x.csv"], str(_cats(bad, "error")))
	t.check("fixture_issue_line_numbers", bad_lines == [2, 3, 4, 5, 11], "lines %s" % str(bad_lines))
	t.check("fixture_good_rows_around_bad_ones_still_load", bad["rows"].has("TRAILING") and bad["rows"].has("AFTER_MULTI") and bad["rows"].has("NO_EN") and not bad["rows"].has("lower_key") and not bad["rows"].has("TOO_MANY") and bad["rows"]["MULTI"]["text"]["da"] == "line\none", "%s" % str(bad["rows"].keys()))
	# keep-imports
	var imps := _lint_fixture("imports", {
		"localization/c.csv": "keys,da,en\nC_ONE,\"x\",\"y\"\n",
		"localization/d.csv": "keys,da,en\nD_ONE,\"x\",\"y\"\n", "localization/d.csv.import": TRANSLATION_IMPORT,
		"localization/e.csv": "keys,da,en\nE_ONE,\"x\",\"y\"\n", "localization/e.csv.import": KEEP,
		"localization/da.csv": "keys,da,en\nL_ONE,\"x\",\"y\"\n", "localization/da.csv.import": TRANSLATION_IMPORT,
		"localization/junk.da.translation": "x"})
	t.check("fixture_keep_import_missing_or_wrong_importer", _cats(imps, "error") == ["keep-import:c.csv", "keep-import:d.csv"] and _cats(imps, "legacy") == ["keep-import:da.csv"] and _cats(imps, "warning").has("junk:junk.da.translation"), "%s | %s | %s" % [str(_cats(imps, "error")), str(_cats(imps, "legacy")), str(_cats(imps, "warning"))])
	# placeholders
	var fmt := _lint_fixture("format", {
		"localization/f.csv": "keys,da,en\nF_BAD,\"Dag %d\",\"Day %s\"\nF_GOOD,\"%s har %d\",\"%s has %d\"\nF_PCT,\"100%% sikker\",\"100%% sure\"\nF_FEWER,\"%d af %d\",\"%d\"\n", "localization/f.csv.import": KEEP})
	var fmt_keys: Array[String] = []
	for iss in fmt["issues"]:
		if iss["cat"] == "format":
			fmt_keys.append(str(iss["key"]))
	fmt_keys.sort()
	t.check("fixture_format_placeholders_must_match", fmt_keys == ["F_BAD", "F_FEWER"], str(fmt_keys))


# ---------------------------------------------------------------- ownership (task 7 / addendum 4.4 task 1)

func _check_ownership() -> void:
	var t = _t
	var owners := LM.load_owners("res://")
	var files: Dictionary = owners.get("files", {})
	t.check("key_owners_table_loads", not owners.is_empty() and files.has("core.csv") and files.has("finds.csv") and files.has("features_ui.csv") and files.has("home_ui.csv") and files.has("samlerbog.csv") and files.has("cast.csv") and files.has("ghost.csv"), "files %s" % str(files.keys()))
	var shape_ok := true
	for fname in files:
		var spec: Dictionary = files[fname]
		if not (spec.get("prefix") is Array) or not (spec.get("exact") is Array) or str(spec.get("owner", "")) == "":
			shape_ok = false
	t.check("key_owners_every_file_has_owner_prefix_and_exact", shape_ok)
	var cases := {
		"NPC_MAYOR_LYRA": "core.csv", "ZONE_FARM": "core.csv", "LANG_DA": "core.csv", "GAME_TITLE": "core.csv", "UI_GOLD": "core.csv",
		"UI_WEATHER_KLART": "core.csv", "NOTIF_QUEST_ACCEPTED_TITLE": "core.csv", "CHAR_SELECT_TITLE": "core.csv", "CHAR_ANIMAL_NAME": "core.csv",
		"UI_CURRENCY": "ui.csv", "UI_WEEKDAY_3": "ui.csv", "UI_MONTH_VINTER": "ui.csv", "CHAR_SELECT_SUBTITLE": "ui.csv", "MENU_CONTINUE": "ui.csv", "QJ_TITLE": "ui.csv",
		"SHOP_TAB_SEEDS": "ui.csv", "SHOP_TOTAL": "ui.csv", "UI_SLEEP": "world.csv", "WHISPER_TOO_EARLY": "world.csv", "NOTIF_PASSED_OUT": "world.csv",
		"FARM_NO_SEEDS": "farm.csv", "SIGN_FARM": "areas.csv", "ITEM_GEM_BAG": "economy.csv", "ITEM_GEM_BAG_DESC": "economy.csv", "RECIPE_SCARECROW": "economy.csv",
		"SHOP_SEED_SHOP": "economy.csv", "ITEM_BABY_CHICK": "animals.csv", "ITEM_CHICKEN": "animals.csv", "ITEM_OWL_DESC": "animals.csv", "BUILDING_COOP": "animals.csv",
		"QUEST_LOST_CAT_TITLE": "quests.csv", "OBJ_LOST_CAT_FIND_CAT": "quests.csv", "LUANOTIF_X": "quests.csv", "DLG_MAYOR_GREET": "dialogue.csv",
		"BOSS_SNURRESVAMPEN": "forest.csv", "WHISPER_FERNS": "forest.csv",
		# addendum 3.7 / RV-P8: the explicit exceptions and the longest prefix
		"NPC_FAIRY_BUILDER": "dialogue_builder.csv", "NPC_FAIRY_FURNISHER": "dialogue_builder.csv", "NPC_FAIRY_TAILOR": "dialogue_builder.csv",
		"DLG_CHOICE_HOME_UPGRADE": "dialogue_builder.csv", "DLG_BUILDER_T02_IDLE": "dialogue_builder.csv", "DLG_TAILOR_GREET": "dialogue_builder.csv",
		"QUEST_BOGTRAEET_TITLE": "features_quests.csv", "QUEST_MOONSTONE_CROWN_CHOICE": "features_quests.csv", "QUEST_SNURRESVAMPEN_REMIND": "features_quests.csv",
		"QUEST_SLOTSDROEMMEN_DONE_TEXT": "features_quests.csv", "OBJ_SLOTSDROEMMEN_FURNISH_TREASURES": "features_quests.csv", "OBJ_BOGTRAEET_RETURN_TO_ZEPHYR": "features_quests.csv",
		"PERK_SPEED": "finds.csv", "PERK_ENERGY": "finds.csv", "PERK_LUCK": "finds.csv", "PERK_DISCOUNT": "finds.csv", "RARITY_UNIQUE": "finds.csv", "SOURCE_BOSS": "finds.csv",
		"FIND_SPOT_SVAMPERING": "finds.csv", "FIND_UI_DUPLICATE_FMT": "features_ui.csv",
		"HYGGE_LABEL": "features_ui.csv", "HYGGE_SCORE_FMT": "features_ui.csv", "HYGGE_LUNT": "home.csv", "INDRET_ONLY_HOME": "features_ui.csv", "INDRET_TITLE": "home_ui.csv",
		"HOME_UI_BUILDING_CLOSED": "features_ui.csv", "WARDROBE_UI_CHANGE_AT_HOME": "features_ui.csv", "WARDROBE_SLOT_HAT": "wardrobe.csv", "SHOP_UI_CLOSED_TODAY": "features_ui.csv",
		"SHOP_FLEA_MARKET": "home.csv", "SHOP_BUILDER_YARD_GREETING": "home.csv", "SHOPTAB_FURN_SLEEP": "home.csv", "HOME_TIER_3_GATE": "home.csv", "HOME_WORLD_TITLE": "home_world.csv",
		"FURNI_REJECT_FULL": "home_ui.csv", "HUSBYG_TITLE": "home_ui.csv", "KISTE_TITLE": "home_ui.csv", "GARDEROBE_TITLE": "wardrobe_ui.csv", "SLOTCELL_HAT": "wardrobe_ui.csv",
		"PERKLINE_SPEED_FMT": "wardrobe_ui.csv", "COLLECT_TITLE": "samlerbog.csv", "FSET_BONDEGAARD": "furniture.csv", "FURN_CAT_BED": "furniture.csv", "OUTFIT_BAGEREN": "wardrobe.csv",
		"RECIPE_SAW_PLANK": "materials.csv", "RECIPE_FORGE_NAILS": "materials.csv",
		# V1-cast-data: cast.csv owns the hero cards, the card texts, Brumme's shop and Pip's quest (the longest prefix beats SHOP_ / QUEST_ / OBJ_ of the base files; the ghost heroes stay in ghost.csv)
		"HERO_KIKI_NAME": "cast.csv", "HERO_BIRK_BLURB": "cast.csv", "HERO_BODIL_KIND": "cast.csv", "HERO_BU_NAME": "ghost.csv", "HERO_HVISKE_BLURB": "ghost.csv",
		"CAST_GARDENER_HOPPE_DESC": "cast.csv", "SHOP_TIMBER_YARD": "cast.csv", "SHOP_TIMBER_YARD_GREETING": "cast.csv",
		"QUEST_PIPS_RUNDE_TITLE": "cast.csv", "QUEST_PIPS_RUNDE_ACCEPT_TEXT": "cast.csv", "OBJ_PIPS_RUNDE_GREET_HOPPE": "cast.csv", "NPC_POSTMAN_PIP": "core.csv", "ZONE_TRAETOPPEN": "core.csv",
		# unclaimed families are unconstrained
		"ABILITY_SLASH": "forest.csv", "UI_PAUSED": "", "SKIN_ANIMAL_FOX": "", "DEFAULT_PLAYER_NAME": "",
	}
	var wrong: Array[String] = []
	for key in cases:
		var got := LM.owner_of(key, owners)
		if got != cases[key]:
			wrong.append("%s -> '%s' (want '%s')" % [key, got, cases[key]])
	t.check("key_owners_resolution_exact_prefix_longest", wrong.is_empty(), str(wrong.slice(0, 4)))
	# ITEM_<id>[_DESC|_HINT] of the item ids of the named Lua files (fixture: a furniture.lua with two ids)
	var lua_items := "kind = \"items\"\nitems = {\n  chair_a = { name_key = \"ITEM_CHAIR_A\", art = { template = \"chair\" } },\n  -- a comment { with brace\n  table_b = { rarity = \"normal\", tabs = { 1, 2 } },\n}\n"
	var owners_json := JSON.stringify({"files": {
		"economy.csv": {"owner": "P12", "prefix": ["ITEM_"], "exact": []},
		"furniture.csv": {"owner": "F1", "prefix": ["FSET_"], "exact": [], "item_files": ["lua/items/furniture.lua"]},
		"a.csv": {"owner": "T", "prefix": ["A_"], "exact": []}}})
	var base := _fixture("owner_items", {"lua/items/furniture.lua": lua_items, "tools/loc/key_owners.json": owners_json})
	var fo := LM.load_owners(base + "/")
	t.check("key_owners_item_ids_come_from_the_lua_files", LM.owner_of("ITEM_CHAIR_A", fo) == "furniture.csv" and LM.owner_of("ITEM_CHAIR_A_DESC", fo) == "furniture.csv" and LM.owner_of("ITEM_TABLE_B_HINT", fo) == "furniture.csv" and LM.owner_of("ITEM_OTHER", fo) == "economy.csv" and LM.owner_of("FSET_X", fo) == "furniture.csv", str(fo.get("item_keys", {})))
	# negative controls: the lint finds a key in a file that does not own it, a missing owner entry, and a voiced key in zz_final
	var rep := _lint_fixture("owner_lint", {
		"localization/a.csv": "keys,da,en\nA_OK,\"x\",\"x\"\nITEM_CHAIR_A_DESC,\"x\",\"x\"\n", "localization/a.csv.import": KEEP,
		"localization/economy.csv": "keys,da,en\nITEM_OTHER,\"x\",\"x\"\nITEM_CHAIR_A,\"x\",\"x\"\n", "localization/economy.csv.import": KEEP,
		"localization/furniture.csv": "keys,da,en\nITEM_TABLE_B,\"x\",\"x\"\nFSET_ONE,\"x\",\"x\"\n", "localization/furniture.csv.import": KEEP,
		"localization/unlisted.csv": "keys,da,en\nU_ONE,\"x\",\"x\"\n", "localization/unlisted.csv.import": KEEP,
		"lua/items/furniture.lua": lua_items, "tools/loc/key_owners.json": owners_json})
	var own_errs: Array[String] = []
	for iss in rep["issues"]:
		if iss["cat"] == "ownership":
			own_errs.append("%s:%s:%s" % [iss["sev"], iss["file"], iss["key"]])
	own_errs.sort()
	t.check("ownership_lint_negative_control", own_errs == ["error:a.csv:ITEM_CHAIR_A_DESC", "error:economy.csv:ITEM_CHAIR_A", "warning:unlisted.csv:"], str(own_errs))
	# voiced keys (R.17)
	var dlg := "kind = \"dialogue\"\nid = \"n\"\nfunction get_dialogue(c)\n  return {\n    lines = {\n      { id = \"greet\", text_key = \"DLG_N_GREET\", voice_key = \"voice/n/greet\" },\n      { id = \"mute\", text_key = \"DLG_N_MUTE\" },\n    },\n  }\nend\n"
	var vrep := _lint_fixture("voiced", {
		"localization/dialogue.csv": "keys,da,en\nDLG_N_GREET,\"Hej\",\"Hi\"\nDLG_N_MUTE,\"Stille\",\"Quiet\"\n", "localization/dialogue.csv.import": KEEP,
		"localization/zz_final.csv": "keys,da,en\nDLG_N_GREET,\"Goddag\",\"Hello\"\nDLG_N_MUTE,\"Tavs\",\"Silent\"\n", "localization/zz_final.csv.import": KEEP,
		"lua/dialogue/n.lua": dlg, "tools/loc/key_owners.json": JSON.stringify({"files": {"dialogue.csv": {"owner": "P14", "prefix": ["DLG_"], "exact": []}}})})
	var voiced_hits: Array[String] = []
	for iss in vrep["issues"]:
		voiced_hits.append("%s:%s" % [iss["cat"], iss["key"]])
	t.check("voiced_key_cannot_be_overridden_by_zz_final", voiced_hits == ["voiced:DLG_N_GREET"], str(voiced_hits))
	# the real tree (the merged tree of everything that has landed so far)
	var real: Dictionary = _lm.lint()
	var own_real: Array[String] = []
	for iss in real["errors"]:
		if iss["cat"] == "ownership" or iss["cat"] == "duplicate" or iss["cat"] == "voiced":
			own_real.append(LM.format_issue(iss))
	t.check("ownership_lint", own_real.is_empty() and not owners.is_empty(), str(own_real.slice(0, 3)))


# ---------------------------------------------------------------- voice forwarder

func _check_voice_forwarder() -> void:
	var t = _t
	var real: Node = t.root.get_node_or_null("AudioManager")
	if real == null:
		t.skip("loc.voice_forwarder (no AudioManager autoload)")
		return
	var fake := FakeAudio.new()
	real.name = "AudioManager_real"
	fake.name = "AudioManager"
	t.root.add_child(fake)
	_lm.play_voice("voice/mayor_lyra/greet")
	_lm.play_voice("mayor_lyra", "greet")
	_lm.play_voice("oak", "voice/oak/greet")
	var exists_ok: bool = _lm.voice_exists("voice/x/y") and not _lm.voice_exists("voice/none")
	t.root.remove_child(fake)
	real.name = "AudioManager"
	var keys: Array[String] = []
	var vols_untouched := true
	for c in fake.calls:
		keys.append(str(c[0]))
		vols_untouched = vols_untouched and is_nan(float(c[1]))
	fake.free()
	t.check("voice_forwarder_key_unchanged_no_double_prefix", keys == ["voice/mayor_lyra/greet", "voice/mayor_lyra/greet", "voice/oak/greet"], str(keys))
	t.check("voice_forwarder_has_no_second_volume_state", vols_untouched and not ("voice_volume_db" in _lm) and not ("voice_enabled" in _lm), "LocalizationManager must not keep voice volume or enable state")
	t.check("voice_exists_forwards", exists_ok)
	t.check("voice_forwarder_restores_the_autoload", t.root.get_node_or_null("AudioManager") == real)


# ---------------------------------------------------------------- python tools

func _check_python_tools() -> void:
	var t = _t
	var py := _python()
	if py == "":
		t.skip("loc.python_tools (no python found)")
		return
	var lint_py := _abs("res://tools/loc/csv_lint.py")
	# parity on the real tree
	var real_gd := _issue_set(LM.parse_dir("res://localization", "res://", true)["issues"])
	var real_py := _py_issue_set(py, lint_py, _abs("res://"), _abs("res://localization"))
	t.check("python_lint_parity_real_tree", real_gd == real_py, "gd=%d python=%d diff %s" % [real_gd.size(), real_py.size(), str(_diff(real_gd, real_py))])
	var res: Dictionary = t.run_tool(py, PackedStringArray(["-I", lint_py, "--root", _abs("res://")]))
	var expect_ok: bool = (_lm.lint()["errors"] as Array).is_empty()
	t.check("csv_lint_py_exit_code_matches_lint", (int(res["code"]) == 0) == expect_ok and str(res["output"]).contains("csv_lint "), "exit %d" % int(res["code"]))
	var strict_res: Dictionary = t.run_tool(py, PackedStringArray(["-I", lint_py, "--root", _abs("res://"), "--strict", "--quiet"]))
	var strict_ok: bool = (_lm.lint(true)["errors"] as Array).is_empty()
	t.check("csv_lint_py_strict_matches_lint_strict", (int(strict_res["code"]) == 0) == strict_ok, "exit %d, strict errors %d" % [int(strict_res["code"]), (_lm.lint(true)["errors"] as Array).size()])
	# parity on every fixture family (including multi-line cells and line numbers)
	var fixtures := {
		"parity_a": {
			"localization/da.csv": "keys,da,en\n; --- section\nONE,\"a\",\"b\"\nbad key,\"x\",\"y\"\nONE,\"c\",\"d\"\nMULTI,\"l1\nl2\",\"m1\nm2\"\nAFTER,\"x\",\"\"\n", "localization/da.csv.import": TRANSLATION_IMPORT,
			"localization/a.csv": "keys,da,en\nA_ONE,\"x\",\"y\"\nA_ONE,\"x\",\"y\"\nSHARED,\"1\",\"1\"\nFMT,\"%d\",\"%s\"\n", "localization/a.csv.import": KEEP,
			"localization/b.csv": "keys,da,en\nSHARED,\"2\",\"2\"\nB_X,\"a\",\"b\",\n", "localization/b.csv.import": KEEP,
			"localization/c.csv": "keys,da,en\nC_X,\"a\"\n",
			"localization/zz_final.csv": "keys,da,en\nSHARED,\"3\",\"3\"\nDLG_V,\"hej\",\"hi\"\n", "localization/zz_final.csv.import": KEEP,
			"lua/dialogue/v.lua": "kind = \"dialogue\"\nlines = {\n { id = \"a\", text_key = \"DLG_V\", voice_key = \"voice/v/a\" },\n}\n",
			"tools/loc/key_owners.json": JSON.stringify({"files": {"a.csv": {"owner": "T", "prefix": ["A_"], "exact": []}, "b.csv": {"owner": "T", "prefix": ["B_", "SHARED"], "exact": []}}})},
		"parity_b": {
			"localization/x.csv": "key,da\nX_ONE,\"a\"\n", "localization/x.csv.import": KEEP,
			"localization/y.csv": "keys,da,en\nY_ONE,\"a\",\"b\"\n", "localization/y.csv.import": KEEP},
	}
	for name in fixtures:
		var base := _fixture(name, fixtures[name])
		var gd := _issue_set(LM.parse_dir(base.path_join("localization"), base + "/", true)["issues"])
		var pyset := _py_issue_set(py, lint_py, base, base.path_join("localization"))
		t.check("python_lint_parity_%s" % name, gd == pyset and gd.size() >= (8 if name == "parity_a" else 1), "gd=%d python=%d diff %s" % [gd.size(), pyset.size(), str(_diff(gd, pyset))])
	# new_csv.py: creates the CSV and its keep-import, refuses to overwrite, rejects bad names; the result lints clean
	var root := _fixture("newcsv", {"localization/da.csv": "keys,da,en\n", "localization/da.csv.import": KEEP})
	var new_py := _abs("res://tools/loc/new_csv.py")
	var made: Dictionary = t.run_tool(py, PackedStringArray(["-I", new_py, "hud", "--root", root, "--row", "HUD_ONE=Én|One", "--row", "HUD_COMMA=Sig, hej|Say, hi"]))
	var csv_text := FileAccess.get_file_as_string(root.path_join("localization/hud.csv"))
	_ck("new_csv_creates_csv_and_keep_import", int(made["code"]) == 0 and csv_text == "keys,da,en\nHUD_ONE,\"Én\",\"One\"\nHUD_COMMA,\"Sig, hej\",\"Say, hi\"\n" and FileAccess.get_file_as_string(root.path_join("localization/hud.csv.import")) == KEEP, str(made["output"]).left(200))
	var again: Dictionary = t.run_tool(py, PackedStringArray(["-I", new_py, "hud", "--root", root]))
	var badname: Dictionary = t.run_tool(py, PackedStringArray(["-I", new_py, "Bad-Name", "--root", root]))
	var quoting: Dictionary = t.run_tool(py, PackedStringArray(["-I", "-B", "-c", "import sys; sys.path.insert(0, sys.argv[1]); import new_csv; print(new_csv.quote(chr(97) + chr(34) + chr(98)))", _abs("res://tools/loc")]))
	t.check("new_csv_doubles_quotes_inside_texts", str(quoting["output"]).strip_edges() == "\"a\"\"b\"", str(quoting["output"]))
	t.check("new_csv_refuses_overwrite_and_bad_names", int(again["code"]) != 0 and int(badname["code"]) == 2)
	var made_rep := LM.parse_dir(root.path_join("localization"), root + "/", true)
	var made_loaded: bool = (made_rep["rows"] as Dictionary).has("HUD_COMMA") and made_rep["rows"]["HUD_COMMA"]["text"]["da"] == "Sig, hej" and made_rep["rows"]["HUD_ONE"]["text"]["da"] == "Én"
	t.check("new_csv_output_loads_and_lints_clean", made_loaded and _cats(made_rep, "error").is_empty(), str(made_rep["issues"]))
	_check_prune(py)


func _check_prune(py: String) -> void:
	var t = _t
	var prune := _abs("res://tools/loc/prune_legacy.py")
	var da := "keys,da,en\nGAME_TITLE,\"Gammel\",\"Old\"\n; --- Menus ---\nMENU_NEW,\"Nyt\",\"New\"\nMENU_OLD,\"Gammelt\",\"Old\"\n\n; --- Dead section ---\nDEAD_ONE,\"d\",\"d\"\nDEAD_TWO,\"d\",\"d\"\n\n; --- Items ---\nITEM_A,\"a\",\"a\"\nITEM_A,\"a2\",\"a2\"\nITEM_GONE,\"g\",\"g\"\nbroken:\"row\",\"x\"\nDYN_ONE,\"d\",\"d\"\nWEAK_ONE,\"w\",\"w\"\n"
	var root := _fixture("prune", {
		"localization/da.csv": da, "localization/da.csv.import": KEEP,
		"localization/core.csv": "keys,da,en\nGAME_TITLE,\"Ny\",\"New\"\n", "localization/core.csv.import": KEEP,
		"refs.json": JSON.stringify({
			"referenced": {"MENU_NEW": ["x.gd:1"], "ITEM_A": ["y.lua:2"]}, "groups": [], "weak": ["WEAK_ONE"],
			"dynamic_prefixes": [{"prefix": "DYN_", "src": "z.gd:3"}, {"prefix": "ITEM_", "src": "z.gd:4"}], "enumerated_prefixes": ["ITEM_"]})})
	var dry: Dictionary = t.run_tool(py, PackedStringArray(["-I", prune, "--root", root, "--refs", root.path_join("refs.json")]))
	var out := str(dry["output"])
	_ck("prune_dry_run_lists_every_reason_and_writes_nothing", int(dry["code"]) == 0 and out.contains("overridden: 1 row") and out.contains("malformed: 1 row") and out.contains("duplicate: 1 row") and out.contains("unreferenced: 4 row") and FileAccess.get_file_as_string(root.path_join("localization/da.csv")) == da, out)
	var applied: Dictionary = t.run_tool(py, PackedStringArray(["-I", prune, "--root", root, "--refs", root.path_join("refs.json"), "--apply"]))
	var after := FileAccess.get_file_as_string(root.path_join("localization/da.csv"))
	var want := "keys,da,en\n; --- Menus ---\nMENU_NEW,\"Nyt\",\"New\"\n\n; --- Items ---\nITEM_A,\"a2\",\"a2\"\nDYN_ONE,\"d\",\"d\"\nWEAK_ONE,\"w\",\"w\"\n"
	_ck("prune_apply_keeps_only_live_rows_and_drops_empty_sections", int(applied["code"]) == 0 and after == want, "got:\n" + after)
	var empty_refs: Dictionary = t.run_tool(py, PackedStringArray(["-I", prune, "--root", root, "--refs", root.path_join("refs.json").replace("refs.json", "none.json")]))
	t.check("prune_needs_a_valid_reference_index", int(empty_refs["code"]) != 0)


# ---------------------------------------------------------------- tests/loc_check.gd as a program

func _convention_rows() -> String:
	var rows := ""
	for d in range(1, 8):
		rows += "UI_WEEKDAY_%d,\"d\",\"d\"\n" % d
	for m in ["FORAAR", "SOMMER", "EFTERAAR", "VINTER"]:
		rows += "UI_MONTH_%s,\"m\",\"m\"\n" % m
	for w in ["KLART", "REGN", "TAAGE", "SNE", "TORDEN"]:
		rows += "UI_WEATHER_%s,\"w\",\"w\"\n" % w
	for z in ["FARM", "CITY", "DARK_FOREST", "FOREST_EDGE", "DYBE_BREGNER", "MUSHROOM_GROVE", "CRYSTAL_CAVE"]:
		rows += "ZONE_%s,\"z\",\"z\"\n" % z
	for b in ["COOP", "BARN", "HOUSE"]:
		rows += "BUILDING_%s,\"b\",\"b\"\n" % b
	return rows


func _check_loc_check_cli() -> void:
	var t = _t
	var tool := "res://tests/loc_check.gd"
	# the real tree: lenient exit code follows the lint errors, strict follows everything (state independent)
	var lenient: Dictionary = t.run_godot_script(tool)
	var lenient_line := _summary_line(str(lenient["output"]))
	_ck("loc_check_runs_on_the_real_tree", lenient_line != "" and lenient_line.contains("(lenient)"), str(lenient["output"]).right(300), lenient_line)
	var errs := _field(lenient_line, "lint_errors")
	t.check("loc_check_lenient_exit_follows_lint_errors", (int(lenient["code"]) == 0) == (errs == 0), "exit %d, %s" % [int(lenient["code"]), lenient_line])
	var strict: Dictionary = t.run_godot_script(tool, PackedStringArray(["--strict", "--quiet"]))
	var sline := _summary_line(str(strict["output"]))
	var all_clean := _field(sline, "missing") == 0 and _field(sline, "lint_errors") == 0 and _field(sline, "legacy_issues") == 0
	t.check("loc_check_strict_exit_follows_everything", (int(strict["code"]) == 0) == all_clean and sline.contains("(strict)"), "exit %d, %s" % [int(strict["code"]), sline])
	# a scan fixture: literal keys, dynamic families, comments ignored
	var da := "keys,da,en\n"
	var files := {
		"localization/da.csv": da, "localization/da.csv.import": KEEP,
		"localization/x.csv": "keys,da,en\nKEY_PRESENT,\"a\",\"a\"\nITEM_TABLE_A,\"a\",\"a\"\nITEM_TABLE_A_DESC,\"a\",\"a\"\nITEM_CHAIR,\"a\",\"a\"\nQUEST_Q1_TITLE,\"a\",\"a\"\nQUEST_Q1_DESC,\"a\",\"a\"\nQUEST_Q1_OFFER,\"a\",\"a\"\nOBJ_Q1_O1,\"a\",\"a\"\nNPC_NIX,\"a\",\"a\"\nHOME_TIER_1,\"a\",\"a\"\nHOME_TIER_1_DESC,\"a\",\"a\"\nHOME_TIER_2,\"a\",\"a\"\nHOME_TIER_2_DESC,\"a\",\"a\"\nHOME_TIER_2_GATE,\"a\",\"a\"\nDLG_BUILDER_T02_IDLE,\"a\",\"a\"\nSHOP_SHOP_A,\"a\",\"a\"\nRECIPE_RR,\"a\",\"a\"\nRARITY_NORMAL,\"a\",\"a\"\nFSET_ONE,\"a\",\"a\"\nFSET_ONE_DESC,\"a\",\"a\"\n" + _convention_rows(),
		"localization/x.csv.import": KEEP,
		"scripts/a.gd": "extends Node\nfunc f():\n\tvar a = tr(\"KEY_PRESENT\")\n\t# tr(\"KEY_IN_COMMENT\")\n\tvar b = tr(\"KEY_MISSING_GD\")\n\tlabel.text = \"KEY_TEXT_MISSING\"\n\tvar c = {\"name_key\": \"KEY_DICT_MISSING\"}\n\tvar d = \"ITEM_%s\" % id\n\tvar e = tr(\"DYN_PREFIX_\" + id)\n",
		"scenes/s.tscn": "[node name=\"L\" type=\"Label\"]\ntext = \"KEY_SCENE_MISSING\"\nitem_0/text = \"KEY_SCENE_ITEM_MISSING\"\ntext = \"OK\"\n",
		"lua/items/it.lua": "kind = \"items\"\nitems = {\n  chair = {\n    name_key = \"ITEM_CHAIR\",\n    hint_key = \"ITEM_CHAIR_HINT\",\n    category = \"x\",\n  },\n  table_a = { category = \"y\", hint_key = true },\n}\n",
		"lua/shops/s.lua": "kind = \"shops\"\nshops = {\n  shop_a = { keeper = \"nix\", stock = { ghost_item = { stock = 1 } } },\n}\n",
		"lua/recipes/r.lua": "kind = \"recipes\"\nrecipes = {\n  rr = { category = \"craft\" },\n  ss = { category = \"craft\", name_key = \"RECIPE_EXPLICIT\" },\n}\n",
		"lua/quests/q.lua": "kind = \"quest\"\nid = \"q1\"\nobjectives = {\n  { id = \"o1\", target = 1 },\n  { id = \"o2\", target = 1 },\n  { id = \"o3\", target = 1, description_key = \"OBJ_EXPLICIT_O3\" },\n}\nrewards = { items = { reward_item = 2 } }\nmeta = { giver = \"nix\" }\nfunction on_accept(c)\n  api.notification(\"NOTIF_FROM_LUA_TITLE\", \"NOTIF_FROM_LUA_TEXT\")\nend\n",
		"lua/config/c.lua": "kind = \"config\"\nconfig = {\n  npcs = { nix = { visual = \"v\" }, named = { name_key = \"NPC_CUSTOM\" } },\n  rarity_tiers = { order = { \"normal\" }, normal = { rank = 1 } },\n  furniture_sets = { one = { members = { \"a\" } } },\n  home = { tiers = {\n    { tier = 1, id = \"t1\" },\n    { tier = 2, id = \"t2\", dialogue = { idle = \"DLG_BUILDER_T02_IDLE\", offer = \"DLG_BUILDER_T02_OFFER\" } },\n  } },\n}\n",
		"data/maps/m.map": "@id m\n@title ZONE_FARM\n@zone farm\n@marker w warp to=farm label=WARP_LABEL_MISSING\n",
		"data/maps/_fixture.map": "@title KEY_FIXTURE_MAP_IGNORED\n",
		"tools/loc/key_owners.json": JSON.stringify({"files": {}}),
	}
	var root := _fixture("scan", files)
	var res: Dictionary = t.run_godot_script(tool, PackedStringArray(["--root=" + root]))
	var out := str(res["output"])
	var missing_wanted := ["KEY_MISSING_GD", "KEY_TEXT_MISSING", "KEY_DICT_MISSING", "KEY_SCENE_MISSING", "KEY_SCENE_ITEM_MISSING", "ITEM_CHAIR_DESC", "ITEM_GHOST_ITEM", "ITEM_REWARD_ITEM",
		"NOTIF_FROM_LUA_TITLE", "NOTIF_FROM_LUA_TEXT", "RECIPE_EXPLICIT", "OBJ_EXPLICIT_O3", "NPC_CUSTOM", "DLG_BUILDER_T02_OFFER", "WARP_LABEL_MISSING", "ITEM_TABLE_A_HINT", "ITEM_CHAIR_HINT"]
	var missing_unwanted := ["KEY_IN_COMMENT", "KEY_PRESENT", "KEY_FIXTURE_MAP_IGNORED", "ITEM_TABLE_A_DESC", "QUEST_Q1_TITLE", "NPC_NIX", "HOME_TIER_2_GATE", "RARITY_NORMAL", "ZONE_FARM", "UI_MONTH_VINTER", "RECIPE_RR", "RECIPE_SS", "ITEM_CHAIR", "DYN_PREFIX_", "ITEM_"]
	var seen_missing: Array[String] = []
	var wrongly_missing: Array[String] = []
	for k in missing_wanted:
		if not _has_miss(out, k):
			seen_missing.append(k)
	for k in missing_unwanted:
		if _has_miss(out, k):
			wrongly_missing.append(k)
	_ck("loc_check_finds_literal_and_dynamic_keys", seen_missing.is_empty(), "NOT reported missing: %s\n%s" % [str(seen_missing), out.left(1500)])
	t.check("loc_check_does_not_report_defined_or_ignored_keys", wrongly_missing.is_empty(), "wrongly reported: %s" % str(wrongly_missing))
	_ck("loc_check_any_of_group_objective", out.contains("OBJ_Q1_O2 | OBJ_O2") and not out.contains("OBJ_Q1_O1 | OBJ_O1"), out.left(400))
	t.check("loc_check_lenient_exit_0_with_misses", int(res["code"]) == 0 and _summary_line(out).contains("(lenient)") and _field(_summary_line(out), "missing") > 0, _summary_line(out))
	var res_strict: Dictionary = t.run_godot_script(tool, PackedStringArray(["--root=" + root, "--strict", "--quiet"]))
	t.check("loc_check_strict_exit_1_on_a_miss", int(res_strict["code"]) == 1 and _summary_line(str(res_strict["output"])).begins_with("loc_check FAIL"), _summary_line(str(res_strict["output"])))
	# positive control: a project root where every key exists passes --strict
	var ok_files := files.duplicate()
	var extra := "OBJ_Q1_O2,\"a\",\"a\"\n"
	for k in missing_wanted:
		extra += "%s,\"a\",\"a\"\n" % k
	ok_files["localization/y.csv"] = "keys,da,en\n" + extra
	ok_files["localization/y.csv.import"] = KEEP
	ok_files["scripts/a.gd"] = "extends Node\nfunc f():\n\tvar a = tr(\"KEY_PRESENT\")\n"
	ok_files["scenes/s.tscn"] = "[node name=\"L\" type=\"Label\"]\ntext = \"KEY_SCENE_MISSING\"\nitem_0/text = \"KEY_SCENE_ITEM_MISSING\"\n"
	var ok_root := _fixture("scan_ok", ok_files)
	var ok_res: Dictionary = t.run_godot_script(tool, PackedStringArray(["--root=" + ok_root, "--strict"]))
	var ok_line := _summary_line(str(ok_res["output"]))
	var still_missing: Array[String] = []
	for line in str(ok_res["output"]).split("\n"):
		if line.begins_with("MISS ") or line.begins_with("ERROR ") or line.begins_with("LEGACY "):
			still_missing.append(line.left(120))
	t.check("loc_check_strict_passes_when_everything_is_defined", int(ok_res["code"]) == 0 and ok_line.begins_with("loc_check PASS"), "%s %s" % [ok_line, str(still_missing.slice(0, 5))])
	# lint errors in the CSVs fail even the lenient mode
	var dup_root := _fixture("scan_dup", {
		"localization/a.csv": "keys,da,en\nSAME,\"x\",\"x\"\n", "localization/a.csv.import": KEEP,
		"localization/b.csv": "keys,da,en\nSAME,\"y\",\"y\"\n", "localization/b.csv.import": KEEP, "tools/loc/key_owners.json": JSON.stringify({"files": {}})})
	var dup_res: Dictionary = t.run_godot_script(tool, PackedStringArray(["--root=" + dup_root, "--quiet"]))
	t.check("loc_check_lenient_exit_1_on_a_duplicate_key", int(dup_res["code"]) == 1 and _field(_summary_line(str(dup_res["output"])), "lint_errors") >= 1, _summary_line(str(dup_res["output"])))
	# --dump: the reference index prune_legacy.py consumes
	var dump_path := _fixture("dump", {}).path_join("refs.json")
	t.run_godot_script(tool, PackedStringArray(["--root=" + root, "--quiet", "--dump=" + dump_path]))
	var dump: Variant = JSON.parse_string(FileAccess.get_file_as_string(dump_path))
	t.check("loc_check_dump_has_the_reference_index", dump is Dictionary and (dump as Dictionary).has("referenced") and (dump["referenced"] as Dictionary).has("KEY_MISSING_GD") and (dump["weak"] as Array).has("KEY_PRESENT") and (dump["enumerated_prefixes"] as Array).has("ITEM_") and str(dump["dynamic_prefixes"]).contains("DYN_PREFIX_") and not (dump["referenced"] as Dictionary).has("DYN_PREFIX_"))
	# bad arguments
	var bad_arg: Dictionary = t.run_godot_script(tool, PackedStringArray(["--bogus"]))
	t.check("loc_check_rejects_unknown_arguments", int(bad_arg["code"]) == 2)
	_check_voiced_manifest(tool)


func _check_voiced_manifest(tool: String) -> void:
	var t = _t
	var dlg := "kind = \"dialogue\"\nid = \"n\"\nfunction get_dialogue(c)\n  return { lines = {\n    { id = \"greet\", text_key = \"DLG_N_GREET\", voice_key = \"voice/n/greet\" },\n  } }\nend\n"
	var csvs := {"localization/dialogue.csv": "keys,da,en\nDLG_N_GREET,\"Hej\",\"Hi\"\n" + _convention_rows(), "localization/dialogue.csv.import": KEEP,
		"localization/da.csv": "keys,da,en\n", "localization/da.csv.import": KEEP, "lua/dialogue/n.lua": dlg, "tools/loc/key_owners.json": JSON.stringify({"files": {}})}
	var good := csvs.duplicate()
	good["assets/audio/voice/manifest.json"] = JSON.stringify({"lines": {"voice/n/greet": {"text_sha256": "Hej".sha256_text()}}})
	var bad := csvs.duplicate()
	bad["assets/audio/voice/manifest.json"] = JSON.stringify({"lines": {"voice/n/greet": {"text_sha256": "Noget andet".sha256_text()}}})
	var none := csvs.duplicate()
	none["assets/audio/voice/manifest.json"] = JSON.stringify({"lines": {"voice/n/greet": {"hash": "abc"}}})
	var r_good: Dictionary = t.run_godot_script(tool, PackedStringArray(["--root=" + _fixture("man_good", good), "--strict"]))
	var r_bad: Dictionary = t.run_godot_script(tool, PackedStringArray(["--root=" + _fixture("man_bad", bad)]))
	var r_none: Dictionary = t.run_godot_script(tool, PackedStringArray(["--root=" + _fixture("man_none", none), "--strict"]))
	t.check("voiced_manifest_hash_matches_passes_strict", int(r_good["code"]) == 0, _summary_line(str(r_good["output"])))
	t.check("voiced_manifest_hash_mismatch_fails_even_lenient", int(r_bad["code"]) == 1 and str(r_bad["output"]).contains("voiced-hash"), _summary_line(str(r_bad["output"])))
	t.check("voiced_manifest_without_text_hash_is_reported_not_guessed", int(r_none["code"]) == 0 and str(r_none["output"]).contains("hash check was skipped"), _summary_line(str(r_none["output"])))


# ---------------------------------------------------------------- helpers

## t.check() whose detail text is only printed when the check fails (the long outputs of child processes).
func _ck(check_name: String, cond: bool, fail_detail: String, ok_detail: String = "") -> bool:
	return _t.check(check_name, cond, ok_detail if cond else fail_detail)


func _abs(res_path: String) -> String:
	return ProjectSettings.globalize_path(res_path).trim_suffix("/")


func _python() -> String:
	for p in [_abs("res://tools/art/.venv/bin/python"), "/usr/bin/python3", "/opt/homebrew/bin/python3", "/usr/local/bin/python3"]:
		if FileAccess.file_exists(p):
			return p
	return ""


func _issue_set(issues: Array) -> Array[String]:
	var out: Array[String] = []
	for iss in issues:
		out.append("%s|%s|%s|%d" % [iss["cat"], iss["sev"], iss["file"], int(iss["line"])])
	out.sort()
	return out


func _py_issue_set(py: String, lint_py: String, root: String, folder: String) -> Array[String]:
	var res: Dictionary = _t.run_tool(py, PackedStringArray(["-I", lint_py, "--json", "--root", root, "--dir", folder]))
	var data: Variant = JSON.parse_string(str(res["output"]))
	if not (data is Dictionary):
		return ["<no json: %s>" % str(res["output"]).left(200)]
	return _issue_set(data["issues"])


func _diff(a: Array[String], b: Array[String]) -> Array:
	var only_a: Array[String] = []
	var only_b: Array[String] = []
	for x in a:
		if not (x in b):
			only_a.append(x)
	for x in b:
		if not (x in a):
			only_b.append(x)
	return [only_a.slice(0, 4), only_b.slice(0, 4)]


func _summary_line(output: String) -> String:
	for line in output.split("\n"):
		if line.begins_with("loc_check PASS") or line.begins_with("loc_check FAIL"):
			return line
	return ""


func _field(line: String, field_name: String) -> int:
	var rx := RegEx.new()
	rx.compile(field_name + "=(\\d+)")
	var m := rx.search(line)
	return int(m.get_string(1)) if m != null else -1


func _has_miss(output: String, key: String) -> bool:
	for line in output.split("\n"):
		if line.begins_with("MISS "):
			var parts := line.split(" ", false, 2)
			if parts.size() >= 3 and (parts[2].begins_with(key + " ") or parts[2].contains(" | " + key + " ")):
				return true
	return false


func _fixture(name: String, files: Dictionary) -> String:
	var base := OS.get_user_data_dir().path_join("loc_fx_" + name)
	_rm_rf(base)
	DirAccess.make_dir_recursive_absolute(base)
	for rel in files:
		var p := base.path_join(str(rel))
		DirAccess.make_dir_recursive_absolute(p.get_base_dir())
		var f := FileAccess.open(p, FileAccess.WRITE)
		f.store_string(str(files[rel]))
		f.close()
	if not (base in _fixtures):
		_fixtures.append(base)
	return base


func _rm_rf(path: String) -> void:
	var da := DirAccess.open(path)
	if da == null:
		return
	for f in da.get_files():
		da.remove(f)
	for d in da.get_directories():
		_rm_rf(path.path_join(d))
		da.remove(d)
	DirAccess.remove_absolute(path)


func _snapshot_settings() -> Dictionary:
	var p := "user://settings.cfg"
	if FileAccess.file_exists(p):
		return {"exists": true, "text": FileAccess.get_file_as_string(p)}
	return {"exists": false, "text": ""}


func _restore_settings(snap: Dictionary) -> void:
	var p := "user://settings.cfg"
	if bool(snap["exists"]):
		var f := FileAccess.open(p, FileAccess.WRITE)
		f.store_string(str(snap["text"]))
		f.close()
	elif FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
