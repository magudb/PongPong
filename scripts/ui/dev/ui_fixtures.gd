extends RefCounted
## Fixture states for screenshots and screen tests: puts a screen scene under a host node, with a stand-in backdrop, and returns it.
##
##   Fixtures.available("shop")            -> true only when the screen's scene exists (and, for the two paths the legacy 3D flow
##                                            shares, is a guide-themed scene: the legacy main_menu / character_select do NOT count)
##   Fixtures.make("shop", host)           -> the screen node, or null = SKIP (never an error: screens land in any order)
##   Fixtures.register_setup("shop", fn)   -> the OWNER of a screen registers its state setup (Callable(node, host)); make() runs it.
##                                            The per-screen smoke functions (title, select, hud, shop, dialogue, journal, inventory,
##                                            forest, pause, saveload) live in the owners' tests/sections (P16, P17, P18, P14, P19).
## Names ending in `_guide` also install the style guide's mock copy (scripts/ui/dev/guide_fixture.json) as a runtime Translation so
## a layout can be compared 1:1 with the guide (tests/checkpoints/compare_guide.py).

const GUIDE_JSON := "res://scripts/ui/dev/guide_fixture.json"
## screen name -> scene. The GameUI screens use GameUI.SCREEN_ORDER ids; the older spike names title/select/... are aliases.
const SCREENS := {
	"components": "res://scenes/ui/dev/components_gallery.tscn",
	"title": "res://scenes/main/main_menu.tscn",
	"select": "res://scenes/ui/character_select.tscn",
	"hud": "res://scenes/ui/hud.tscn",
	"shop": "res://scenes/ui/shop_ui.tscn",
	"dialogue": "res://scenes/ui/dialogue_ui.tscn",
	"journal": "res://scenes/ui/quest_journal.tscn",
	"inventory": "res://scenes/ui/inventory_ui.tscn",
	"forest": "res://scenes/ui/forest_hud.tscn",
	"pause": "res://scenes/ui/pause_menu.tscn",
	"settings": "res://scenes/ui/settings_ui.tscn",
	"saveload": "res://scenes/ui/save_load_ui.tscn",
	"husbyggeri": "res://scenes/ui/husbyggeri.tscn",
	"indretning": "res://scenes/ui/indretning.tscn",
	"home_chest": "res://scenes/ui/home_chest.tscn",
	"garderobe": "res://scenes/ui/garderobe.tscn",
	"samlerbog": "res://scenes/ui/samlerbog.tscn",
}
## stand-in for the world behind a HUD or a blurred modal: [colour a, colour b, band]
const BACKDROPS := {
	"hud": ["#a9c97a", "#9cbf6c", 22.0], "forest": ["#232a44", "#1c2138", 22.0],
	"shop": ["#d7cbe9", "#cbbde3", 18.0], "dialogue": ["#cde0a6", "#bfd694", 22.0],
	"journal": ["#3a3150", "#3a3150", 22.0], "inventory": ["#3a3150", "#3a3150", 22.0],
	"pause": ["#a9c97a", "#9cbf6c", 22.0], "saveload": ["#a9c97a", "#9cbf6c", 22.0], "settings": ["#a9c97a", "#9cbf6c", 22.0],
	"husbyggeri": ["#3a3150", "#3a3150", 22.0], "indretning": ["#a9c97a", "#9cbf6c", 22.0], "home_chest": ["#3a3150", "#3a3150", 22.0],
	"garderobe": ["#3a3150", "#3a3150", 22.0], "samlerbog": ["#3a3150", "#3a3150", 22.0],
}
## screens whose scene path is shared with the legacy 3D flow: they only count once the scene is built on the guide theme
const LEGACY_SHARED: Array[String] = ["title", "select"]

static var _setups: Dictionary = {}


## Variant names: "hud_guide", "select2", "title_en", "components_rarity" -> the base screen name ("hud", "select", ...).
static func base_name(name: String) -> String:
	var n := name
	while n != "" and not SCREENS.has(n):
		if n.is_valid_int() or n[n.length() - 1].is_valid_int():
			n = n.rstrip("0123456789")
		elif n.contains("_"):
			n = n.substr(0, n.rfind("_"))
		else:
			break
	return n if SCREENS.has(n) else name


static func scene_path(name: String) -> String:
	return str(SCREENS.get(base_name(name), "res://scenes/ui/%s.tscn" % name))


## True when the scene exists; the legacy main_menu / character_select scenes do not count (they have no theme variations).
static func available(name: String) -> bool:
	var path := scene_path(name)
	if not ResourceLoader.exists(path):
		return false
	if base_name(name) in LEGACY_SHARED:
		return FileAccess.get_file_as_string(path).contains("theme_type_variation")
	return true


static func register_setup(name: String, setup: Callable) -> void:
	_setups[name] = setup


static func clear_setups() -> void:
	_setups.clear()


## The style guide's mock copy: {texts, hotbar, gold, day, hour, minute, season, weather, quests}.
static func guide_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GUIDE_JSON))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## Installs the guide copy as a runtime Translation (da) on top of the loaded CSVs; returns it so the caller can remove it again.
static func install_guide_translation() -> Translation:
	var t := Translation.new()
	t.locale = "da"
	var texts: Dictionary = guide_data().get("texts", {})
	for k in texts:
		t.add_message(k, texts[k])
	TranslationServer.add_translation(t)
	return t


## Calendar, gold and weather of the guide mock ("Tirsdag 16. Blomstermåned", 10:40, 1.250, Solskin) through the live autoloads.
static func apply_guide_state() -> void:
	var g := guide_data()
	var gm := Svc.node("GameManager")
	if gm != null:
		gm.day = int(g.get("day", 16))
		gm.hour = int(g.get("hour", 10))
		gm.minute = int(g.get("minute", 40))
		gm.season = StringName(str(g.get("season", "foraar")))
	var eco := Svc.node("EconomyManager")
	if eco != null:
		eco.gold = int(g.get("gold", 1250))
	var tm := Svc.node("TimeManager")
	if tm != null and tm.has_method("set_weather"):
		tm.set_weather(StringName(str(g.get("weather", "klart"))))


static func reset_state(host: Node) -> void:
	host.get_tree().paused = false
	TranslationServer.set_locale("da")


## Puts the screen under `host`. null = SKIP (the scene does not exist yet / is still the legacy one).
static func make(name: String, host: Node) -> Node:
	var tree := host.get_tree()
	reset_state(host)
	if not available(name):
		return null
	if name.ends_with("_guide"):
		install_guide_translation()
		apply_guide_state()
	_backdrop(host, base_name(name))
	var node: Node = (load(scene_path(name)) as PackedScene).instantiate()
	host.add_child(node)
	await tree.process_frame
	if name == "components_rarity" and node.has_method("show_page"):
		node.show_page(&"rarity")
	var setup: Variant = _setups.get(name, _setups.get(base_name(name)))
	if setup is Callable and (setup as Callable).is_valid():
		await (setup as Callable).call(node, host)
	return node


## Stand-in for the world behind a HUD (the real game draws the iso map here).
static func _backdrop(host: Node, base: String) -> void:
	if not BACKDROPS.has(base):
		return
	var c: Array = BACKDROPS[base]
	var st := ColorRect.new()
	st.set_script(preload("res://scripts/ui/components/tt_stripes.gd"))
	st.set("color_a", Color(c[0]))
	st.set("color_b", Color(c[1]))
	st.set("band", c[2])
	st.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	st.name = "Backdrop"
	host.add_child(st)
