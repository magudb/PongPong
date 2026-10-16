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
## a layout can be compared 1:1 with the guide (tests/checkpoints/compare_guide.py), and then show ONLY what the mock shows (apply_guide_rules, P28,
## UI_NAVIGATION.md 4.8 / D12): the HintBar, any toast stack and (select page) the %BackButton are hidden, and the focus is released for RING controls
## (cards, slots, buttons, chips, tabs: the HTML mocks draw no ring on them) but kept on a MenuRow / ChoiceRow, whose focus look IS the gold fill the mock
## paints ("Fortsæt" on the title, the first choice of the dialogue).
##
## The components of P28 (confirm, toasts, prompt) bring their own state (`_default_setup`): a registered setup of the same name wins.

const GUIDE_JSON := "res://scripts/ui/dev/guide_fixture.json"
## screen name -> scene. The GameUI screens use GameUI.SCREEN_ORDER ids; the older spike names title/select/... are aliases.
const SCREENS := {
	"components": "res://scenes/ui/dev/components_gallery.tscn",
	# P28 components (not screens of GameUI: each is instanced by the screens that need it) and the registry names of screens that live inside another scene
	"confirm": "res://scenes/ui/components/ui_confirm.tscn",
	"toasts": "res://scenes/ui/components/toast_stack.tscn",
	"prompt": "res://scenes/ui/components/prompt_pill.tscn",
	"area_banner": "res://scenes/ui/components/area_banner.tscn",
	"animal_care": "res://scenes/ui/animal_care_ui.tscn",
	"build_menu": "res://scenes/ui/build_menu_ui.tscn",
	"intro": "res://scenes/ui/dialogue_ui.tscn",
	"minimap": "res://scenes/ui/forest_hud.tscn",
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
	"people": "res://scenes/ui/people.tscn",
	"gift": "res://scenes/ui/gift_ui.tscn",
	"calendar": "res://scenes/ui/social/calendar_tab.tscn",
	"social_hud": "res://scenes/ui/social_hud.tscn",
	"event_overlay": "res://scenes/ui/event_overlay.tscn",
	"post": "res://scenes/ui/post.tscn",
}
## stand-in for the world behind a HUD or a blurred modal: [colour a, colour b, band]
const BACKDROPS := {
	"hud": ["#a9c97a", "#9cbf6c", 22.0], "forest": ["#232a44", "#1c2138", 22.0],
	"shop": ["#d7cbe9", "#cbbde3", 18.0], "dialogue": ["#cde0a6", "#bfd694", 22.0],
	"journal": ["#3a3150", "#3a3150", 22.0], "inventory": ["#3a3150", "#3a3150", 22.0],
	"people": ["#3a3150", "#3a3150", 22.0], "gift": ["#3a3150", "#3a3150", 22.0],
	"calendar": ["#3a3150", "#3a3150", 22.0], "social_hud": ["#b9d7c4", "#aacbb6", 18.0],
	"pause": ["#a9c97a", "#9cbf6c", 22.0], "saveload": ["#a9c97a", "#9cbf6c", 22.0], "settings": ["#a9c97a", "#9cbf6c", 22.0],
	"husbyggeri": ["#3a3150", "#3a3150", 22.0], "indretning": ["#a9c97a", "#9cbf6c", 22.0], "home_chest": ["#3a3150", "#3a3150", 22.0],
	"garderobe": ["#3a3150", "#3a3150", 22.0], "samlerbog": ["#3a3150", "#3a3150", 22.0],
	"confirm": ["#a9c97a", "#9cbf6c", 22.0], "toasts": ["#a9c97a", "#9cbf6c", 22.0], "prompt": ["#a9c97a", "#9cbf6c", 22.0], "area_banner": ["#96ac6b", "#96ac6b", 22.0],
	"animal_care": ["#a9c97a", "#9cbf6c", 22.0], "build_menu": ["#a9c97a", "#9cbf6c", 22.0], "intro": ["#cde0a6", "#bfd694", 22.0], "minimap": ["#232a44", "#1c2138", 22.0],
}
## the variations whose focus look IS a gold fill: the guide mocks paint that fill, so a guide fixture keeps focus on them
const FILL_FOCUS_VARIATIONS: Array[StringName] = [&"MenuRow", &"ChoiceRow"]
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
	else:
		await _default_setup(name, node, host)
	if name.ends_with("_guide"):
		await tree.process_frame
		await tree.process_frame
		apply_guide_rules(name, node)
	return node


## The state of the P28 components when nobody registered one: a confirm that asks, a toast stack with toasts, a prompt that shows.
static func _default_setup(name: String, node: Node, host: Node) -> void:
	var tree := host.get_tree()
	match base_name(name):
		"confirm":
			if node is UiConfirm:
				(node as UiConfirm).setup("CONFIRM", "UI_CONFIRM_OVERWRITE", "NAV_OK", "NAV_CANCEL", &"cancel", [3])
				(node as UiConfirm).begin()
				await tree.process_frame
		"toasts":
			var bus := Svc.node("EventBus")
			if bus != null:
				bus.notification_posted.emit("NOTIF_QUEST_ACCEPTED_TITLE", "QUEST_LOST_CAT_TITLE", "quest")
				bus.notification_posted.emit("NOTIF_NO_GOLD_TITLE", "NOTIF_NO_GOLD_MSG", "gold")
				bus.item_gained.emit(&"moonstone", 2)                       # EconomyManager emits item_gained right before the "item" toast: the toast carries the item and its rarity tile
				bus.notification_posted.emit("NOTIF_ITEM_GAINED_TITLE", "ITEM_MOONSTONE x2", "item")
				await tree.process_frame
		"area_banner":
			node._area_changed(&"traetoppen")
			if node._arrival != null and node._arrival.is_valid():
				node._arrival.kill()
			node.get_node("%Title").modulate.a = 1.0
		"prompt":
			var bus2 := Svc.node("EventBus")
			if bus2 != null:
				bus2.interaction_prompt_changed.emit("UI_SLEEP")
				await tree.process_frame


## What a `<screen>_guide` fixture does after the screen opened and had two frames (see the header): hide what the mock does not have, release the focus of
## ring controls. Public so the section can prove it on a stand-in screen (ui_conformance.fixtures_guide_*).
static func apply_guide_rules(name: String, node: Node) -> void:
	for bar in node.find_children("*", "HintBar", true, false):
		(bar as HintBar).force_hidden = true
	for stack in node.find_children("*", "ToastStack", true, false):
		(stack as Control).visible = false
	if base_name(name) == "select":
		var back := node.find_child("BackButton", true, false)
		if back is CanvasItem:
			(back as CanvasItem).visible = false
	var vp := node.get_viewport()
	if vp == null:
		return
	var f := vp.gui_get_focus_owner()
	if f != null and not (StringName(f.theme_type_variation) in FILL_FOCUS_VARIATIONS):
		if node is TTScreen:
			(node as TTScreen).focus_guard = false      # the guard would put the focus straight back
		else:
			for screen in node.find_children("*", "TTScreen", true, false):
				(screen as TTScreen).focus_guard = false
		vp.gui_release_focus()


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
