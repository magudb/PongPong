extends RefCounted
## Section ui_foundation (package P07, plan R.3 / addendum 4.4): the FOUNDATION of the UI - theme + fonts, the component library
## (item_slot, quantity_stepper, ability_slot, notification_toast, tt_* controls, RarityPips / RaritySlot / LadderRow), GameUI's
## dynamic loader, ui.csv, the tt_* helpers, tt_item_icon's three-directory lookup and tests/checkpoints/compare_guide.py.
## The per-screen checks (title, select, hud, shop, dialogue, journal, inventory, forest, pause, saveload) belong to the screens'
## owners (P16, P17, P18, P14, P19) and use scripts/ui/dev/ui_fixtures.gd.
##
## Named checks: ui_foundation.components, ui_foundation.smoke, ui_foundation.no_duplicate_keys, ui_foundation.rarity_components,
## ui_foundation.rarity_contrast, ui_foundation.item_icon_three_dirs_and_night, ui_foundation.compare_guide_modes (+ supporting ones).
## Fix-round regressions: ui_foundation.rarity_order_independent (item_id before rarity), ui_foundation.setup_before_ready
## (item_slot / toast), ui_foundation.rarity_slot_badge (an item without an icon file), ui_foundation.quest_text_location
## (meta.location is a zone KEY), ui_foundation.quest_text_hostile_definitions (empty Lua tables), ui_foundation.guide_ref_pinned,
## and the bad-input cases of compare_guide_modes (exit 2, never 1).
## Fix round 2: ui_foundation.ability_slot_before_ready, ui_foundation.ability_slot_danish_label, ui_foundation.toast_second_setup,
## ui_foundation.empty_cell_no_count, ui_foundation.icon_dir_constant_gone, ui_foundation.quest_text_title (+ the --frame-px cases of
## compare_guide_modes).
## Windowed (tests/run_playtest.sh --windowed): run_windowed samples the pixels of the rarity row of the gallery and of two ability slots.
const SECTION := "ui_foundation"
const TIMEOUT_S := 240.0

const Fmt = preload("res://scripts/ui/theme/tt_format.gd")
const Portraits = preload("res://scripts/ui/theme/tt_portraits.gd")
const QuestText = preload("res://scripts/ui/theme/tt_quest_text.gd")
const PARCHMENT := Color("#f4e6c4")
const FAKE_DIRS: Array[String] = ["res://fake/icons/items/", "res://fake/icons/home/", "res://fake/icons/wardrobe/"]
const GUIDE_SCREENS: Array[String] = ["title", "select", "hud", "shop", "quest", "inventory", "forest"]

var _py := ""


func run(t) -> void:
	_theme_and_fonts(t)
	_theme_matches_builder(t)
	await _components(t)
	await _rarity_components(t)
	await _rarity_order_and_setup(t)
	await _ability_slot(t)
	await _toast_second_setup(t)
	await _empty_cell_and_icon_dir(t)
	await _fixtures(t)
	_rarity_contrast(t)
	_item_icon_dirs(t)
	await _game_ui(t)
	_tt_helpers(t)
	_quest_text(t)
	_quest_text_title(t)
	_no_duplicate_keys(t)
	_compare_guide_modes(t)
	_guide_ref_pinned(t)
	_smoke(t)


# ---------------------------------------------------------------------------------------------------- theme and fonts

func _theme_and_fonts(t) -> void:
	var theme := ThemeDB.get_project_theme()
	t.check("theme_loaded", theme != null, "gui/theme/custom = assets/ui/theme.tres")
	if theme == null:
		return
	var types := theme.get_type_list()
	t.check("theme_type_count", types.size() >= 145, "%d theme types (the spike had 145; the rarity tiers and words add more)" % types.size())
	var caprasimo: Font = load("res://assets/fonts/Caprasimo-Regular.ttf")
	var alegreya: Font = load("res://assets/fonts/AlegreyaSans-Medium.ttf")
	var ok := true
	for ch in "ÆØÅæøå":
		ok = ok and caprasimo.has_char(ch.unicode_at(0)) and alegreya.has_char(ch.unicode_at(0))
	t.check("fonts_have_aeoeaa", ok, "Æ Ø Å æ ø å in Caprasimo and Alegreya Sans")
	var licences := ["OFL-AlegreyaSans.txt", "OFL-Caprasimo.txt", "OFL-IBMPlexMono.txt", "OFL-TTSymbols.txt", "OFL-NotoSansSymbols2.txt"]
	var missing: Array[String] = []
	for l in licences:
		if not FileAccess.file_exists("res://assets/fonts/" + l):
			missing.append(l)
	t.check("font_licences_present", missing.is_empty(), "OFL texts: missing %s" % str(missing))
	t.check("noto_binary_not_shipped", not FileAccess.file_exists("res://assets/fonts/NotoSansSymbols2-Regular.ttf"), "TTSymbols covers every glyph; the 1.2 MB Noto binary stays out")
	var ratio := theme.get_font("font", "ButtonPrimary").get_height(22) / caprasimo.get_height(22)
	t.check("symbol_fallback_keeps_line_height", ratio < 1.3, "display font with fallbacks is %.2f x Caprasimo's own line height" % ratio)


## "Never edit theme.tres by hand": regenerate it with tools/ui/build_theme.gd into user:// (a child Godot) and compare it, value for
## value, with the committed assets/ui/theme.tres. (The ext_resource / sub_resource ids of a .tres differ per save, so the files are
## compared by content, not by bytes.)
func _font_sig(f: Font) -> String:
	if f == null:
		return "null"
	var sig := f.resource_path
	if f is FontVariation:
		var fv := f as FontVariation
		sig = "variation|base=%s|fb=%s|ot=%s" % [fv.base_font.resource_path if fv.base_font else "", str((fv.fallbacks as Array).map(func(x): return (x as Font).resource_path)), str(fv.opentype_features)]
	return sig


func _theme_diff(a: Theme, b: Theme) -> Array[String]:
	var diffs: Array[String] = []
	var ta := a.get_type_list()
	var tb := b.get_type_list()
	ta.sort()
	tb.sort()
	if ta != tb:
		diffs.append("type lists differ (%d vs %d)" % [ta.size(), tb.size()])
		return diffs
	if a.default_font_size != b.default_font_size or _font_sig(a.default_font) != _font_sig(b.default_font):
		diffs.append("default font")
	for ty in ta:
		if a.get_type_variation_base(ty) != b.get_type_variation_base(ty):
			diffs.append("%s: variation base" % ty)
		for n in a.get_color_list(ty):
			if not b.has_color(n, ty) or a.get_color(n, ty) != b.get_color(n, ty):
				diffs.append("%s: color %s" % [ty, n])
		for n in a.get_constant_list(ty):
			if not b.has_constant(n, ty) or a.get_constant(n, ty) != b.get_constant(n, ty):
				diffs.append("%s: constant %s" % [ty, n])
		for n in a.get_font_size_list(ty):
			if not b.has_font_size(n, ty) or a.get_font_size(n, ty) != b.get_font_size(n, ty):
				diffs.append("%s: font size %s" % [ty, n])
		for n in a.get_font_list(ty):
			if not b.has_font(n, ty) or _font_sig(a.get_font(n, ty)) != _font_sig(b.get_font(n, ty)):
				diffs.append("%s: font %s" % [ty, n])
		for n in a.get_stylebox_list(ty):
			if not b.has_stylebox(n, ty):
				diffs.append("%s: stylebox %s missing" % [ty, n])
				continue
			var sa := a.get_stylebox(n, ty)
			var sb := b.get_stylebox(n, ty)
			var same := sa.get_class() == sb.get_class()
			for pr in sa.get_property_list():
				if same and (int(pr["usage"]) & PROPERTY_USAGE_STORAGE) != 0 and str(pr["name"]) not in ["resource_name", "resource_path", "script"]:
					same = str(sa.get(pr["name"])) == str(sb.get(pr["name"]))
			if not same:
				diffs.append("%s: stylebox %s" % [ty, n])
		for n in a.get_icon_list(ty):
			if not b.has_icon(n, ty) or (a.get_icon(n, ty) as Texture2D).resource_path != (b.get_icon(n, ty) as Texture2D).resource_path:
				diffs.append("%s: icon %s" % [ty, n])
	return diffs


func _theme_matches_builder(t) -> void:
	var out := "user://p07_theme_regen.tres"
	var r: Dictionary = t.run_godot_script("res://tools/ui/build_theme.gd", PackedStringArray(["--out=" + out]))
	var ok_run: bool = r["code"] == 0 and str(r["output"]).contains("err=0")
	t.expect(ok_run, "tools/ui/build_theme.gd regenerates the theme in a child run (exit %s)" % r["code"])
	if not ok_run:
		return
	var fresh := ResourceLoader.load(out, "Theme", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	var committed := ResourceLoader.load("res://assets/ui/theme.tres", "Theme", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	var diffs: Array[String] = []
	if fresh == null or committed == null:
		diffs.append("a theme did not load")
	else:
		diffs = _theme_diff(fresh, committed)
	DirAccess.remove_absolute(out)
	t.check("theme_matches_builder", diffs.is_empty(), "assets/ui/theme.tres equals what tools/ui/build_theme.gd generates (%d types) %s" % [committed.get_type_list().size() if committed else 0, str(diffs.slice(0, 5))])


# ---------------------------------------------------------------------------------------------------- fixtures

func _fixtures(t) -> void:
	var fx := preload("res://scripts/ui/dev/ui_fixtures.gd")
	var host := Control.new()
	t.root.add_child(host)
	t.expect(fx.available("components") and fx.available("components_rarity"), "fixtures: the components gallery is always available (both pages)")
	t.expect(not fx.available("no_such_screen") and await fx.make("no_such_screen", host) == null, "fixtures: an unknown screen is SKIP (null), never an error")
	var shop_exists := ResourceLoader.exists("res://scenes/ui/shop_ui.tscn")
	t.expect(fx.available("shop") == shop_exists and (shop_exists or await fx.make("shop", host) == null), "fixtures: shop_ui.tscn %s -> %s" % ["exists" if shop_exists else "does not exist yet", "loaded" if shop_exists else "SKIP"])
	for legacy in fx.LEGACY_SHARED:
		var path: String = fx.scene_path(legacy)
		var themed := ResourceLoader.exists(path) and FileAccess.get_file_as_string(path).contains("theme_type_variation")
		t.expect(fx.available(legacy) == themed, "fixtures: %s (%s) counts only once it is built on the guide theme (legacy 3D scene does not count)" % [legacy, path])
	t.expect(fx.base_name("hud_guide") == "hud" and fx.base_name("select2") == "select" and fx.base_name("title_en") == "title" and fx.base_name("home_chest") == "home_chest" and fx.base_name("components_rarity") == "components", "fixtures: variant names resolve to their screen")
	var ran := [false]
	fx.register_setup("components", func(node, _h): ran[0] = true)
	var node: Node = await fx.make("components", host)
	t.expect(node != null and ran[0], "fixtures: a registered setup runs after the screen is built")
	fx.clear_setups()
	var gd: Dictionary = fx.guide_data()
	t.expect(gd.has("texts") and gd.has("quests") and (gd["quests"] as Array).size() == 4 and int(gd["gold"]) == 1250, "fixtures: the guide's mock copy (4 quests, 1.250 guldagern) loads")
	host.queue_free()
	await t.frames(1)


# ---------------------------------------------------------------------------------------------------- components

func _components(t) -> void:
	var host := Control.new()
	t.root.add_child(host)
	var g: Control = (load("res://scenes/ui/dev/components_gallery.tscn") as PackedScene).instantiate()
	host.add_child(g)
	await t.frames(3)
	var ok_guide: bool = g.slot_empty.theme_type_variation == &"SlotEmpty" and g.slot_filled.theme_type_variation == &"SlotFilled" and g.slot_rare.theme_type_variation == &"SlotRare"
	ok_guide = ok_guide and g.slot_selected.button_pressed and g.get_node("%StatesRow").get_child_count() == 3 and g.get_node("%Hearts").half_hearts == 7
	t.expect(ok_guide, "guide page: slot states, button states, hearts")
	var step = g.get_node("%Stepper")
	step.set_range(1, 5)
	step.value = 9
	var clamp_hi: bool = step.value == 5
	step.value = -3
	t.expect(clamp_hi and step.value == 1, "quantity_stepper clamps to its range")
	g.show_page(&"rarity")
	await t.frames(2)
	var slots := g.find_children("*", "RaritySlot", true, false)
	var ladder := g.find_children("Ladder*", "LadderRow", true, false)
	var themed := g.find_children("ThemedSlot_*", "Button", true, false)
	t.check("components", ok_guide and slots.size() == 21 and ladder.size() == 4 and themed.size() == 5 and clamp_hi,
		"gallery guide page + rarity page: %d RaritySlots, %d ladder rows, %d themed slots" % [slots.size(), ladder.size(), themed.size()])
	t.check("gallery_rarity_row", slots.size() >= 15 and g.find_child("Word_legendary", true, false) != null, "the gallery carries the rarity row (5 states x filled/selected/unknown, word + pips, night icon and disc cases)")
	# every other component scene instantiates and answers its API
	var toast: PanelContainer = (load("res://scenes/ui/components/notification_toast.tscn") as PackedScene).instantiate()
	host.add_child(toast)
	await t.frames(1)
	toast.setup("T", "M", 0.05, &"bed_moon", &"legendary")
	t.expect(toast.icon_frame.visible and toast.item_icon.item_id == &"bed_moon", "toast with an item picture")
	toast.queue_free()
	var ab: VBoxContainer = (load("res://scenes/ui/components/ability_slot.tscn") as PackedScene).instantiate()
	host.add_child(ab)
	await t.frames(1)
	ab.setup(&"slash", &"attack", 78.0)
	ab.set_cooldown(0.5, "2")
	t.expect(ab.cd_label.text == "2" and ab.frame.custom_minimum_size.x == 78.0, "ability_slot setup + cooldown")
	ab.queue_free()
	host.queue_free()
	await t.frames(1)


# ---------------------------------------------------------------------------------------------------- rarity components

func _rarity_components(t) -> void:
	# RarityPips: count = rank - 1, one SHAPE per rarity (colour is never the only cue)
	var counts: Array[int] = []
	var shapes: Array[String] = []
	for id in Rarity.IDS:
		var p := RarityPips.new()
		p.rarity = id
		counts.append(p.pip_count())
		shapes.append(Rarity.shape(id))
		p.free()
	t.expect(str(counts) == "[0, 1, 2, 3, 4]", "pips along the ladder %s" % str(counts))
	var verts := {"leaf": RarityPips.polygon("leaf", Vector2.ZERO, 5.0).size(), "diamond": RarityPips.polygon("diamond", Vector2.ZERO, 5.0).size(), "sparkle": RarityPips.polygon("sparkle", Vector2.ZERO, 5.0).size(), "star": RarityPips.polygon("star", Vector2.ZERO, 5.0).size()}
	t.expect(verts["leaf"] == 18 and verts["diamond"] == 4 and verts["sparkle"] == 8 and verts["star"] == 10 and RarityPips.polygon("none", Vector2.ZERO, 5.0).is_empty(), "four distinct pip outlines %s" % str(verts))
	t.expect(str(shapes) == '["none", "leaf", "diamond", "sparkle", "star"]', "shapes %s" % str(shapes))
	# RaritySlot.plan: what is drawn, for every state
	var gold := RaritySlot.GOLD
	var all_ok := true
	for id in Rarity.IDS:
		var ui: Dictionary = Rarity.ui(id)
		var plain := RaritySlot.plan(id, false, false, false, true, true)
		var sel := RaritySlot.plan(id, true, false, false, true, true)
		all_ok = all_ok and plain["fill"] == ui["fill"] and int((plain["pips"] as Dictionary)["count"]) == Rarity.pips(id)
		if bool(ui["has_ring"]):
			var rings: Array = plain["rings"]
			all_ok = all_ok and bool(plain["rarity_ring_shown"]) and rings.size() == 1 and rings[0]["color"] == ui["ring"] and int(rings[0]["width"]) == 3
			all_ok = all_ok and rings[0]["color"] != gold                      # a rarity ring is never the focus gold
		else:
			all_ok = all_ok and (plain["rings"] as Array).is_empty() and not bool(plain["rarity_ring_shown"])
		# selected: the gold double ring REPLACES the rarity ring; fill and pips stay
		var srings: Array = sel["rings"]
		all_ok = all_ok and bool(sel["gold_ring"]) and not bool(sel["rarity_ring_shown"]) and srings.size() == 2 and srings[0]["color"] == gold and int(srings[0]["width"]) == 3 and srings[1]["color"] == RaritySlot.INK and int(srings[1]["width"]) == 2
		all_ok = all_ok and sel["fill"] == plain["fill"] and sel["pips"] == plain["pips"]
		all_ok = all_ok and plain["word_color"] == ui["label"]
		if not all_ok:
			t.fail("rarity_slot plan wrong for %s: %s / %s" % [id, str(plain), str(sel)])
			break
	t.check("rarity_slot_plan_five_states_and_selected", all_ok, "fill + ring + pips per rarity; selected = gold ring replaces the rarity ring")
	var empty := RaritySlot.plan(&"rare", false, true, false)
	var unknown := RaritySlot.plan(&"rare", false, false, true)
	t.expect(str(empty["state"]) == "empty" and empty["fill"] == RaritySlot.EMPTY and int((empty["pips"] as Dictionary)["count"]) == 0, "empty tile: the guide's empty slot, no pips")
	t.expect(str(unknown["state"]) == "unknown" and unknown["fill"] == RaritySlot.EMPTY and (unknown["border"] as Color).a < 1.0, "unknown tile: dashed silhouette state")
	# the legendary night tile: dark, rim variant or pale disc
	var leg_file := RaritySlot.plan(&"legendary", false, false, false, true, true)
	var leg_disc := RaritySlot.plan(&"legendary", false, false, false, true, false)
	var leg_none := RaritySlot.plan(&"legendary", false, false, false, false, false)
	var rare_disc := RaritySlot.plan(&"rare", false, false, false, true, false)
	t.expect(bool(leg_file["night"]) and not bool(leg_file["disc"]), "legendary with the _night.webp file: no disc")
	t.expect(bool(leg_disc["disc"]), "legendary WITHOUT the _night.webp file: the pale disc is drawn behind the icon")
	t.expect(not bool(leg_none["disc"]) and not bool(rare_disc["disc"]), "no picture -> no disc; a rare tile never gets a disc")
	t.expect((leg_file["count_color"] as Color).is_equal_approx(Color("#e4eff5")) and (leg_file["pips"] as Dictionary)["color"] == Color("#f2c14e"), "legendary count text pale (e4eff5), pips gold (f2c14e)")
	# real RaritySlot nodes: the plan follows the properties and the icon lookup
	var s := RaritySlot.new()
	s.rarity = &"legendary"
	s.item_id = &"bed_moon"
	t.root.add_child(s)
	await t.frames(1)
	var p1 := s.current_plan()
	s.item_id = &"chair_pine"
	var p2 := s.current_plan()
	s.selected = true
	var p3 := s.current_plan()
	t.expect(not bool(p1["disc"]) and bool(p2["disc"]) and bool(p3["gold_ring"]) and bool(p3["disc"]), "RaritySlot node: bed_moon uses its _night file, chair_pine gets the disc, selecting keeps the disc and adds gold")
	s.show_word = true
	t.expect(s.custom_minimum_size.y > s.slot_size + 2.0 * RaritySlot.PAD, "show_word makes room under the tile")
	s.queue_free()
	# LadderRow
	var lr := {}
	for st in LadderRow.STATES:
		lr[st] = LadderRow.plan(st, false)
	t.expect(bool(lr[&"locked"]["dashed"]) and not bool(lr[&"done"]["dashed"]) and (lr[&"next"]["chip_fill"] as Color).is_equal_approx(RaritySlot.GOLD) and (lr[&"current"]["chip_fill"] as Color).is_equal_approx(Color("#6b9a3e")), "ladder: locked is dashed, next has the gold chip, current the moss chip")
	t.expect(bool(LadderRow.plan(&"done", true)["gold_ring"]) and not bool(LadderRow.plan(&"done", false)["gold_ring"]), "ladder: the selected row (and only it) has the gold ring")
	# item_slot: theme variation, pips, night count label
	var slot_scene: PackedScene = load("res://scenes/ui/components/item_slot.tscn")
	var variations := []
	for id in Rarity.IDS:
		var b: Button = slot_scene.instantiate()
		t.root.add_child(b)
		await t.frames(1)
		b.setup(&"chair_pine", 2, "", false, "", id)
		variations.append("%s:%d" % [b.current_variation(), b.pips.pip_count()])
		b.queue_free()
	t.check("rarity_components", str(variations) == '["SlotFilled:0", "SlotUncommon:1", "SlotRare:2", "SlotUnique:3", "SlotLegendary:4"]' and all_ok,
		"item_slot rarity property -> theme variation + pip count %s; RarityPips / RaritySlot / LadderRow plans" % str(variations))


# ---------------------------------------------------------------------------------------------------- order of assignment, setup before ready, badge

const NIGHT_BED := "res://assets/icons/home/bed_moon_night.webp"
const PLAIN_BED := "res://assets/icons/home/bed_moon.webp"


func _rarity_order_and_setup(t) -> void:
	TTItemIcon.clear_cache()
	# --- RaritySlot: `item_id` and `rarity` may be assigned in either order (a scene lists them in file order, code in any)
	var failed_before: int = t.failed
	var first_rarity := RaritySlot.new()
	first_rarity.rarity = &"legendary"
	first_rarity.item_id = &"bed_moon"
	var first_item := RaritySlot.new()
	first_item.item_id = &"bed_moon"
	first_item.rarity = &"legendary"
	t.expect(first_rarity.icon_path() == NIGHT_BED and first_item.icon_path() == NIGHT_BED, "RaritySlot bed_moon legendary: the _night.webp file in either assignment order (%s / %s)" % [first_rarity.icon_path(), first_item.icon_path()])
	t.expect(not bool(first_item.current_plan()["disc"]) and not bool(first_item.current_plan()["badge"]), "item_id before rarity: no pale disc although the night file exists (the reported defect)")
	first_item.rarity = &"normal"
	t.expect(first_item.icon_path() == PLAIN_BED and not bool(first_item.current_plan()["disc"]), "legendary -> normal after the icon was loaded: the plain icon, no disc")
	first_item.rarity = &"legendary"
	t.expect(first_item.icon_path() == NIGHT_BED, "normal -> legendary after the icon was loaded: back to the _night file")
	var no_night := RaritySlot.new()
	no_night.item_id = &"chair_pine"
	no_night.rarity = &"legendary"
	t.expect(bool(no_night.current_plan()["disc"]) and no_night.icon_path() == "res://assets/icons/home/chair_pine.webp", "item_id before rarity, no _night file: the pale disc on the plain icon")
	for n in [first_rarity, first_item, no_night]:
		n.free()
	# --- item_slot: assigning `rarity` re-themes the tile AND hands the rarity to its icon
	var slot_scene: PackedScene = load("res://scenes/ui/components/item_slot.tscn")
	var slot: Button = slot_scene.instantiate()
	t.root.add_child(slot)
	await t.frames(1)
	slot.setup(&"bed_moon", 1, "", false, "", &"legendary")
	var legendary_ok: bool = slot.item_icon.rarity == &"legendary" and slot.item_icon.icon_path() == NIGHT_BED and not slot.item_icon.uses_night_disc() and slot.current_variation() == &"SlotLegendary"
	slot.rarity = &"normal"
	var normal_ok: bool = slot.item_icon.rarity == &"normal" and slot.item_icon.icon_path() == PLAIN_BED and slot.current_variation() == &"SlotFilled" and slot.count_label.theme_type_variation == &"Display15"
	slot.rarity = &"legendary"
	var back_ok: bool = slot.item_icon.rarity == &"legendary" and slot.item_icon.icon_path() == NIGHT_BED and slot.count_label.theme_type_variation == &"Display15Night"
	slot.setup(&"chair_pine", 1, "", false, "", &"normal")
	slot.rarity = &"legendary"
	var disc_ok: bool = slot.item_icon.uses_night_disc()
	t.expect(legendary_ok and normal_ok and back_ok and disc_ok, "item_slot.rarity = X updates the icon too (legendary %s, normal %s, legendary again %s, chair_pine disc %s)" % [legendary_ok, normal_ok, back_ok, disc_ok])
	slot.queue_free()
	t.check("rarity_order_independent", t.failed == failed_before, "RaritySlot and item_slot resolve the legendary _night icon whatever the order of item_id / rarity assignments")

	# --- setup() before the node is in the tree: item_slot and toast keep the arguments and apply them in _ready
	failed_before = t.failed
	var pre: Button = slot_scene.instantiate()
	pre.setup(&"bed_moon", 4, "3", false, "Bed", &"legendary")
	t.expect(pre.item_id == &"bed_moon" and pre.amount == 4 and pre.rarity == &"legendary", "item_slot.setup before add_child keeps the data")
	t.root.add_child(pre)
	await t.frames(1)
	var applied: bool = pre.key_label.text == "3" and pre.key_label.visible and pre.count_label.text == "4" and pre.item_icon.item_id == &"bed_moon" and pre.item_icon.display_name == "Bed"
	applied = applied and pre.current_variation() == &"SlotLegendary" and pre.pips.pip_count() == 4 and pre.count_label.theme_type_variation == &"Display15Night" and pre.item_icon.icon_path() == NIGHT_BED
	t.expect(applied, "item_slot built before add_child: key, count, name, icon (night variant), tile and pips are applied when it is ready")
	pre.queue_free()
	var pre_empty: Button = slot_scene.instantiate()
	pre_empty.setup(&"hoe", 1, "1")
	t.root.add_child(pre_empty)
	await t.frames(1)
	t.expect(pre_empty.current_variation() == &"SlotFilled" and pre_empty.item_icon.item_id == &"hoe" and pre_empty.key_label.text == "1", "item_slot (the 24-cell backpack pattern): instantiate, setup, add_child gives a filled cell")
	pre_empty.queue_free()
	var toast_scene: PackedScene = load("res://scenes/ui/components/notification_toast.tscn")
	var toast: PanelContainer = toast_scene.instantiate()
	toast.setup("Title", "Message", 0.05, &"bed_moon", &"legendary")
	t.root.add_child(toast)
	await t.frames(1)
	t.expect(toast.title_label.text == "Title" and toast.message_label.text == "Message" and toast.message_label.visible and toast.icon_frame.visible and toast.item_icon.item_id == &"bed_moon" and toast.item_icon.icon_path() == NIGHT_BED,
		"toast.setup before add_child: text, picture (night variant) applied when it is ready")
	toast.queue_free()
	var plain: PanelContainer = toast_scene.instantiate()
	plain.setup("Only text", "", 0.05)
	t.root.add_child(plain)
	await t.frames(1)
	t.expect(plain.title_label.text == "Only text" and not plain.message_label.visible and not plain.icon_frame.visible, "toast.setup before add_child, text only: picture and empty message stay hidden")
	plain.queue_free()
	await t.frames(1)
	t.check("setup_before_ready", t.failed == failed_before, "item_slot.setup / notification_toast.setup are safe before add_child (no script error, arguments applied in _ready)")

	# --- a tile whose icon file does not exist shows the initial badge of TTItemIcon, never an empty tile
	failed_before = t.failed
	var plan_item := RaritySlot.plan(&"rare", false, false, false, false, false, {}, true)
	var plan_pic := RaritySlot.plan(&"rare", false, false, false, true, false, {}, true)
	var plan_none := RaritySlot.plan(&"rare", false, false, false, false, false, {}, false)
	t.expect(bool(plan_item["badge"]) and not bool(plan_item["has_picture"]) and not bool(plan_pic["badge"]) and bool(plan_pic["has_picture"]) and not bool(plan_none["badge"]), "plan(): an item without a picture -> badge; with a picture or without an item -> none")
	t.expect(not bool(RaritySlot.plan(&"rare", false, false, true, false, false, {}, true)["badge"]) and not bool(RaritySlot.plan(&"rare", false, true, false, false, false, {}, true)["badge"]), "an unknown (silhouette) or empty tile never shows the badge: it must not give the item away")
	var missing := RaritySlot.new()
	missing.item_id = &"gizmo_unmade"
	var p_missing := missing.current_plan()
	t.expect(bool(p_missing["badge"]) and not bool(p_missing["has_picture"]) and missing.icon_path() == "" and not bool(p_missing["disc"]), "RaritySlot with an unresolvable item id: badge, no disc")
	missing.rarity = &"legendary"
	t.expect(bool(missing.current_plan()["badge"]) and not bool(missing.current_plan()["disc"]), "legendary without any icon file: the badge, not a disc")
	missing.unknown = true
	t.expect(not bool(missing.current_plan()["badge"]), "...and as an unknown silhouette no badge")
	missing.unknown = false
	missing.icon = PlaceholderTexture2D.new()
	t.expect(not bool(missing.current_plan()["badge"]), "an explicit `icon` picture replaces the badge")
	missing.icon = null
	missing.item_id = &"bed_moon"
	t.expect(not bool(missing.current_plan()["badge"]) and missing.icon_path() == NIGHT_BED, "an item with art: no badge")
	missing.item_id = &""
	t.expect(not bool(missing.current_plan()["badge"]), "no item: no badge")
	missing.free()
	t.check("rarity_slot_badge", t.failed == failed_before, "RaritySlot draws TTItemIcon's initial badge for an item whose icon file is missing (plan()['badge'])")


# ---------------------------------------------------------------------------------------------------- fix round 2: ability slot, toast, empty cell, icon constant

const AbilitySlotScript = preload("res://scripts/ui/components/ability_slot.gd")
const ABILITY_IDS: Array[StringName] = [&"slash", &"dodge", &"light", &"drink"]
const ABILITY_ACTIONS: Array[StringName] = [&"attack", &"dodge", &"light", &"drink"]


## Registers throw-away translations ({key: [da, en]}); hand the result to _drop_translations(). The real ABILITY_* keys belong to
## forest.csv (P19, a later wave), so the tests bring their own keys instead of depending on that file.
func _add_fake_translations(entries: Dictionary) -> Array[Translation]:
	var out: Array[Translation] = []
	for loc in ["da", "en"]:
		var fake := Translation.new()
		fake.locale = loc
		for key in entries:
			fake.add_message(StringName(key), StringName(entries[key][0 if loc == "da" else 1]))
		TranslationServer.add_translation(fake)
		out.append(fake)
	return out


func _drop_translations(list: Array[Translation]) -> void:
	for fake in list:
		TranslationServer.remove_translation(fake)


func _ability_slot(t) -> void:
	var failed_before: int = t.failed
	var mark: int = t.log_mark()
	TranslationServer.set_locale("da")
	var fakes := _add_fake_translations({"ABILITY_TESTSTRIKE": ["slag", "strike"]})
	var scene: PackedScene = load("res://scenes/ui/components/ability_slot.tscn")
	# --- the forest HUD pattern: instantiate -> setup (+ cooldown) -> add_child, four slots, before any of them is ready
	var row := HBoxContainer.new()
	var slots: Array = []
	for i in 4:
		var slot: VBoxContainer = scene.instantiate()
		slot.setup(ABILITY_IDS[i], ABILITY_ACTIONS[i], 78.0 if i == 0 else 64.0)
		slot.set_cooldown(0.25 * i, str(i))
		slots.append(slot)
		row.add_child(slot)
	t.expect(slots[0].icon_id == &"slash" and slots[0].action == &"attack", "ability_slot.setup before add_child keeps the data")
	t.root.add_child(row)
	await t.frames(2)
	var applied := true
	for i in 4:
		var slot: VBoxContainer = slots[i]
		var side := 78.0 if i == 0 else 64.0
		applied = applied and slot.action == ABILITY_ACTIONS[i] and slot.icon.item_id == ABILITY_IDS[i] and slot.frame.custom_minimum_size == Vector2(side, side) \
			and slot.key_label.text != "" and slot.cd_label.text == str(i) and is_equal_approx(slot.veil.offset_top, -(side - 4.0) * 0.25 * i)
	t.expect(applied, "four ability slots built before add_child: size, icon id, key cap, cooldown veil and number are applied when each is ready")
	t.expect(slots[0].key_label.text == TranslationServer.translate("KEY_MOUSE_LEFT"), "the primary attack's key cap reads the InputMap: %s" % slots[0].key_label.text)
	var cd_only: VBoxContainer = scene.instantiate()
	cd_only.set_cooldown(1.0, "9")
	t.root.add_child(cd_only)
	await t.frames(1)
	t.expect(cd_only.cd_label.text == "9" and is_equal_approx(cd_only.veil.offset_top, -60.0), "set_cooldown before the slot is ready (no setup yet) is applied in _ready too")
	cd_only.queue_free()
	var twice: VBoxContainer = scene.instantiate()
	twice.setup(&"slash", &"attack", 64.0)
	twice.setup(&"dodge", &"dodge", 78.0)
	t.root.add_child(twice)
	await t.frames(1)
	t.expect(twice.icon.item_id == &"dodge" and twice.frame.custom_minimum_size.x == 78.0 and twice.action == &"dodge", "two setup() calls before ready: the last one wins")
	twice.queue_free()
	t.expect_clean_since(mark, "ability_slot setup / set_cooldown before add_child raise no script error")
	t.check("ability_slot_before_ready", t.failed == failed_before, "ability_slot.setup / set_cooldown are safe before add_child (the forest HUD builds its four slots that way)")

	# --- the word on the slot: ABILITY_<ID> in the current language, never the English id
	failed_before = t.failed
	t.expect(AbilitySlotScript.label_for(&"teststrike") == "slag" and AbilitySlotScript.label_for(&"no_such_ability_zz") == "" and AbilitySlotScript.label_for(&"") == "",
		"label_for: ABILITY_<ID> translated; a key without a translation (or no id) gives \"\", never the id")
	var with_word: VBoxContainer = scene.instantiate()
	with_word.setup(&"teststrike", &"attack")
	var no_word: VBoxContainer = scene.instantiate()
	no_word.setup(&"no_such_ability_zz", &"attack")
	t.root.add_child(with_word)
	t.root.add_child(no_word)
	await t.frames(2)
	t.expect(with_word.shown_label() == "slag" and with_word.icon.display_name == "slag", "ABILITY_TESTSTRIKE exists: the slot shows its Danish word '%s'" % with_word.shown_label())
	t.expect(no_word.shown_label() == "" and no_word.icon.display_name == "" and no_word.icon.fallback_label() == "" and not no_word.icon.id_fallback,
		"no ABILITY_ key yet: the icon only - the English id '%s' is not shown ('%s')" % [no_word.icon.item_id, no_word.icon.fallback_label()])
	TranslationServer.set_locale("en")
	await t.frames(1)
	t.expect(with_word.shown_label() == "strike" and with_word.key_label.text == "Left click", "a language switch re-translates the word and the key cap (%s / %s)" % [with_word.shown_label(), with_word.key_label.text])
	TranslationServer.set_locale("da")
	await t.frames(1)
	t.expect(with_word.shown_label() == "slag" and with_word.key_label.text == "Venstre klik", "...and back to Danish (%s / %s)" % [with_word.shown_label(), with_word.key_label.text])
	# TTItemIcon: the default still falls back to the id (every other tile), only id_fallback = false suppresses it
	var plain_icon := TTItemIcon.new()
	plain_icon.item_id = &"no_such_item_zz"
	var quiet_icon := TTItemIcon.new()
	quiet_icon.item_id = &"no_such_item_zz"
	quiet_icon.id_fallback = false
	t.expect(plain_icon.fallback_label() == "no such item zz" and quiet_icon.fallback_label() == "", "TTItemIcon.fallback_label: the id by default, nothing with id_fallback = false")
	quiet_icon.display_name = "Navn"
	t.expect(quiet_icon.fallback_label() == "Navn", "...and an explicit display_name is always shown")
	plain_icon.free()
	quiet_icon.free()
	var real_keys := true
	for id in ABILITY_IDS:
		var key := "ABILITY_%s" % String(id).to_upper()
		real_keys = real_keys and TranslationServer.translate(key) != key
	if real_keys:
		var words: Array[String] = []
		for id in ABILITY_IDS:
			words.append(AbilitySlotScript.label_for(id))
		t.expect(words.all(func(w): return w != "") and not words.has("slash") and not words.has("drink"), "the real ABILITY_SLASH/DODGE/LIGHT/DRINK words (forest.csv): %s" % str(words))
	else:
		t.skip("ability_slot_danish_label: ABILITY_SLASH/DODGE/LIGHT/DRINK are defined by forest.csv (P19, a later wave); until then the four slots show the icon only")
	row.queue_free()
	with_word.queue_free()
	no_word.queue_free()
	_drop_translations(fakes)
	await t.frames(1)
	t.expect_clean_since(mark, "the ability slot tests logged no engine message")
	t.check("ability_slot_danish_label", t.failed == failed_before, "ability_slot labels itself with ABILITY_<ID> (Danish / English) and never with the English icon id")


func _toast_second_setup(t) -> void:
	var failed_before: int = t.failed
	var mark: int = t.log_mark()
	var scene: PackedScene = load("res://scenes/ui/components/notification_toast.tscn")
	var toast: PanelContainer = scene.instantiate()
	t.root.add_child(toast)
	await t.frames(1)
	toast.setup("First", "one", 0.2)                  # first schedule: in 0.15 s, held 0.2 s, out 0.4 s -> queue_free at 0.75 s
	await t.seconds(0.1)
	var alpha_before: float = toast.modulate.a
	toast.setup("Second", "two", 3.0)                 # a REPLACEMENT: the first schedule must not run on
	var alpha_after: float = toast.modulate.a
	t.expect(toast.title_label.text == "Second" and toast.message_label.text == "two", "the second setup() shows the second text")
	t.expect(alpha_before > 0.2 and is_equal_approx(alpha_after, alpha_before), "...and carries on from the current opacity instead of dropping to 0 (%.2f -> %.2f)" % [alpha_before, alpha_after])
	await t.seconds(0.9)                              # 1.0 s after the first call: the first schedule would have freed the toast at 0.75 s
	t.expect(is_instance_valid(toast) and not toast.is_queued_for_deletion(), "a second setup() on a toast in the tree: the first fade's queue_free no longer removes it early")
	t.expect(is_instance_valid(toast) and toast.modulate.a > 0.95, "...it holds full opacity for its own 3 s (%.2f)" % (toast.modulate.a if is_instance_valid(toast) else -1.0))
	if is_instance_valid(toast):
		toast.queue_free()
	# a toast that is set up again before it is ready keeps only the last call (no tween exists yet)
	var pre: PanelContainer = scene.instantiate()
	pre.setup("A", "a", 0.1)
	pre.setup("B", "b", 0.1)
	t.root.add_child(pre)
	await t.frames(1)
	t.expect(pre.title_label.text == "B", "two setup() calls before add_child: the last one is shown")
	await t.seconds(0.9)
	t.expect(not is_instance_valid(pre) or pre.is_queued_for_deletion(), "...and the toast still frees itself when its own schedule ends")
	t.expect_clean_since(mark, "the toast tests logged no engine message")
	t.check("toast_second_setup", t.failed == failed_before, "notification_toast: a second setup() replaces the running fade (one tween, no early queue_free)")


func _scan_gd(dir: String, out: Array[String]) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_scan_gd(dir.path_join(d), out)


func _empty_cell_and_icon_dir(t) -> void:
	var failed_before: int = t.failed
	var mark: int = t.log_mark()
	var scene: PackedScene = load("res://scenes/ui/components/item_slot.tscn")
	# --- an empty cell shows no count, however the caller filled the arguments (the backpack passes the cell's number)
	var pre: Button = scene.instantiate()
	pre.setup(&"", 5, "2")
	t.root.add_child(pre)
	await t.frames(1)
	t.expect(pre.count_label.text == "" and pre.amount == 0 and pre.current_variation() == &"SlotEmpty" and pre.key_label.text == "2" and pre.key_label.visible,
		"item_slot.setup(&\"\", 5) before ready: no count '%s', amount %d, tile SlotEmpty, the hotbar key cap stays" % [pre.count_label.text, pre.amount])
	pre.setup(&"hoe", 5)
	t.expect(pre.count_label.text == "5" and pre.amount == 5 and pre.current_variation() == &"SlotFilled", "...filled with an item the count shows")
	pre.setup(&"", 7)
	t.expect(pre.count_label.text == "" and pre.amount == 0 and pre.current_variation() == &"SlotEmpty", "...and emptied again (setup(&\"\", 7) after ready): count gone")
	pre.setup(&"hoe", 0)
	t.expect(pre.count_label.text == "", "a non-stackable tool (amount 0) shows no count either")
	pre.queue_free()
	t.expect_clean_since(mark, "item_slot empty-cell setup raised no engine message")
	t.check("empty_cell_no_count", t.failed == failed_before, "an empty item_slot never shows a count")

	# --- the unused ICON_DIR constant (a second hard-coded copy of the first icon directory) is gone: ONE list, TTItemIcon.DIRS
	failed_before = t.failed
	var consts: Dictionary = (load("res://scripts/ui/components/tt_item_icon.gd") as GDScript).get_script_constant_map()
	t.expect(not consts.has("ICON_DIR") and consts.has("DIRS"), "TTItemIcon has no ICON_DIR constant, only DIRS (%s)" % str(consts.keys().filter(func(k): return str(k).contains("DIR"))))
	var files: Array[String] = []
	_scan_gd("res://scripts/ui", files)
	var literal := "\"res://assets/icons/"
	var hits: Array[String] = []
	for f in files:
		var n := FileAccess.get_file_as_string(f).count(literal)
		if n > 0:
			hits.append("%s x%d" % [f.get_file(), n])
	t.expect(hits.size() == 1 and hits[0] == "tt_item_icon.gd x%d" % TTItemIcon.DIRS.size(), "the icon directories are spelled out once (TTItemIcon.DIRS: items, home, wardrobe), nowhere else in scripts/ui %s" % str(hits))
	t.check("icon_dir_constant_gone", t.failed == failed_before, "no second copy of the icon directory in scripts/ui")


# ---------------------------------------------------------------------------------------------------- contrast

static func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.03928 else pow((c + 0.055) / 1.055, 2.4)


static func _lum(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


static func _contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _rarity_contrast(t) -> void:
	var worst_label := 99.0
	var worst_id := ""
	for id in Rarity.IDS:
		var c := _contrast(Rarity.ui(id)["label"], PARCHMENT)
		if c < worst_label:
			worst_label = c
			worst_id = String(id)
	t.expect(worst_label >= 4.5, "rarity WORD labels on parchment >= 4.5:1 (worst %s %.2f)" % [worst_id, worst_label])
	var leg: Dictionary = Rarity.ui(&"legendary")
	var pips_on_night := _contrast(leg["pip"], leg["fill"])
	t.expect(pips_on_night >= 7.0, "gold pips on the night tile >= 7.0:1 (%.2f)" % pips_on_night)
	var rim_on_night := _contrast(leg["icon_rim"], leg["fill"])
	var ink_on_rim := _contrast(Color("#2b2340"), leg["icon_rim"])
	var ink_on_night := _contrast(Color("#2b2340"), leg["fill"])
	t.expect(rim_on_night >= 7.0 and ink_on_rim >= 7.0, "icon rim: rim vs night %.1f:1, ink vs rim %.1f:1 (both >= 7)" % [rim_on_night, ink_on_rim])
	t.expect(ink_on_night < 1.5, "ink on the night tile alone is %.2f:1: the reason legendary icons need the rim (RV-A2)" % ink_on_night)
	var count_ok := true
	for id in Rarity.IDS:
		var ui: Dictionary = Rarity.ui(id)
		var text_col: Color = ui["icon_rim"] if bool(ui["night"]) else Color("#2b2340")
		count_ok = count_ok and _contrast(text_col, ui["fill"]) >= 7.0
	t.expect(count_ok, "slot count text (ink, or the pale rim on night) reads >= 7:1 on every tile fill")
	# the theme's word variations carry exactly these colours
	var theme := ThemeDB.get_project_theme()
	var words_ok := theme != null
	if theme != null:
		for id in Rarity.IDS:
			words_ok = words_ok and theme.get_color("font_color", "RarityWord" + String(id).capitalize()).is_equal_approx(Rarity.ui(id)["label"])
	t.expect(words_ok, "theme RarityWord<Id> label variations carry the Rarity.ui() label colours")
	t.check("rarity_contrast", worst_label >= 4.5 and pips_on_night >= 7.0 and rim_on_night >= 7.0 and ink_on_rim >= 7.0 and count_ok and words_ok,
		"labels >= 4.5 (worst %.2f), gold pips on night %.2f >= 7.0, rim pairs %.1f / %.1f" % [worst_label, pips_on_night, rim_on_night, ink_on_rim])


# ---------------------------------------------------------------------------------------------------- tt_item_icon lookup

func _item_icon_dirs(t) -> void:
	var failed_before: int = t.failed
	var present := {}
	var seen: Array[String] = []
	var exists := func(path: String) -> bool:
		seen.append(path)
		return present.has(path)
	var d0 := FAKE_DIRS[0]
	var d1 := FAKE_DIRS[1]
	var d2 := FAKE_DIRS[2]
	t.expect(str(TTItemIcon.DIRS) == str(["res://assets/icons/items/", "res://assets/icons/home/", "res://assets/icons/wardrobe/"]), "default lookup order = ArtCatalog.icon: items, home, wardrobe")
	present.merge({d0 + "hoe.webp": true, d1 + "bed_pine.webp": true, d2 + "shirt_linen.webp": true, d0 + "dup.webp": true, d1 + "dup.webp": true, d2 + "dup.webp": true,
		d1 + "clock_moon.webp": true, d1 + "clock_moon_night.webp": true, d1 + "chair_pine.webp": true, d1 + "chair_pine_night.webp": true,
		d2 + "hat_wizard_night.webp": true, d2 + "hat_wizard.webp": true, d0 + "hat_wizard.webp": true, d0 + "crate.png": true, d0 + "crate.webp": true, d0 + "gem.svg": true, d0 + "gem.png": true})
	t.expect(TTItemIcon.resolve_path(&"hoe", &"normal", FAKE_DIRS, exists) == d0 + "hoe.webp", "an item icon lives in assets/icons/items")
	t.expect(TTItemIcon.resolve_path(&"bed_pine", &"normal", FAKE_DIRS, exists) == d1 + "bed_pine.webp", "a furniture / material icon is found in assets/icons/home")
	t.expect(TTItemIcon.resolve_path(&"shirt_linen", &"normal", FAKE_DIRS, exists) == d2 + "shirt_linen.webp", "a garment icon is found in assets/icons/wardrobe")
	t.expect(TTItemIcon.resolve_path(&"dup", &"normal", FAKE_DIRS, exists) == d0 + "dup.webp", "the same id in all three: the FIRST directory wins (ordered lookup)")
	t.expect(TTItemIcon.resolve_path(&"crate", &"normal", FAKE_DIRS, exists) == d0 + "crate.webp" and TTItemIcon.resolve_path(&"gem", &"normal", FAKE_DIRS, exists) == d0 + "gem.png", "extension order inside a directory: webp, png, svg")
	t.expect(TTItemIcon.resolve_path(&"nothing_here", &"normal", FAKE_DIRS, exists) == "", "no directory has it: empty path (the caller draws the badge)")
	t.expect(TTItemIcon.resolve_path(&"", &"normal", FAKE_DIRS, exists) == "" and TTItemIcon.resolve_path(&"../hoe", &"normal", FAKE_DIRS, exists) == "" and TTItemIcon.resolve_path(&"Hoe Two", &"normal", FAKE_DIRS, exists) == "", "empty, path-like and spaced ids are refused")
	# legendary: the _night sibling of the file that was found
	var night := TTItemIcon.resolve(&"clock_moon", &"legendary", FAKE_DIRS, exists)
	t.expect(night["path"] == d1 + "clock_moon_night.webp" and bool(night["night"]) and night["base_path"] == d1 + "clock_moon.webp", "legendary: the <id>_night.webp rim variant is used when it exists")
	var no_night := TTItemIcon.resolve(&"bed_pine", &"legendary", FAKE_DIRS, exists)
	t.expect(no_night["path"] == d1 + "bed_pine.webp" and not bool(no_night["night"]), "legendary WITHOUT the night file: the plain icon, night=false (the pale disc is drawn)")
	t.expect(TTItemIcon.resolve_path(&"chair_pine", &"rare", FAKE_DIRS, exists) == d1 + "chair_pine.webp" and TTItemIcon.resolve_path(&"chair_pine", &"unique", FAKE_DIRS, exists) == d1 + "chair_pine.webp", "only the dark (legendary) tile uses the night variant")
	var sib := TTItemIcon.resolve(&"hat_wizard", &"legendary", FAKE_DIRS, exists)
	t.expect(sib["path"] == d0 + "hat_wizard.webp" and not bool(sib["night"]), "the night variant must sit beside the file that was found (items/ has the hat, wardrobe/ has the night file: not used)")
	t.expect(TTItemIcon.resolve_path(&"clock_moon", &"common", FAKE_DIRS, exists) == d1 + "clock_moon.webp", "`common` is normal: no night variant")
	# the disc: radius 0.60 x the icon edge, clipped to the rounded tile
	var tile := Rect2(2, 2, 62, 62)
	var icon_rect := Rect2(8, 8, 50, 50)
	var disc := TTItemIcon.night_disc(icon_rect, tile, 8.0)
	t.expect(is_equal_approx(float(disc["radius"]), 30.0) and (disc["center"] as Vector2).is_equal_approx(icon_rect.get_center()), "disc radius = 0.60 x the 50 px icon edge = 30 px, centred on the icon")
	var inside := true
	for poly in disc["polygons"]:
		for pt in poly:
			inside = inside and tile.grow(0.01).has_point(pt)
	t.expect(inside and not (disc["polygons"] as Array).is_empty(), "the disc stays inside the tile")
	var big := TTItemIcon.night_disc(Rect2(2, 2, 58, 58), Rect2(2, 2, 58, 58), 8.0)       # a 58 px icon fills the tile: radius 34.8 > 29 -> clipped
	var clipped := true
	for poly in big["polygons"]:
		for pt in poly:
			clipped = clipped and Rect2(2, 2, 58, 58).grow(0.01).has_point(pt)
	t.expect(float(big["radius"]) > 29.0 and clipped, "an icon that fills the tile: the disc (r %.1f) is clipped to the tile rect" % float(big["radius"]))
	t.expect(is_equal_approx(TTItemIcon.NIGHT_DISC_RADIUS, 0.60) and TTItemIcon.NIGHT_DISC_COLOR == Color("#e4eff5") and is_equal_approx(TTItemIcon.NIGHT_DISC_ALPHA, 0.92), "disc constants: 0.60, e4eff5, alpha .92")
	# the real files this wave: A1's icons are in assets/icons/home with night siblings
	TTItemIcon.clear_cache()
	var real := TTItemIcon.resolve(&"bed_moon", &"legendary")
	t.expect(str(real["path"]) == "res://assets/icons/home/bed_moon_night.webp" and bool(real["night"]) and ResourceLoader.exists(str(real["path"])), "real files: bed_moon (A1) resolves to its _night.webp in assets/icons/home")
	t.check("item_icon_three_dirs_and_night", t.failed == failed_before, "ordered items > home > wardrobe lookup, extension order, legendary _night sibling, disc fallback (%d predicate calls)" % seen.size())


# ---------------------------------------------------------------------------------------------------- GameUI

func _write_fake_scene(dir: String, id: String, root: Node) -> void:
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, "%s%s.tscn" % [dir, id])
	root.free()


func _game_ui(t) -> void:
	var order := GameUI.SCREEN_ORDER
	t.expect(order.size() == 16 and order[0] == &"hud" and order[1] == &"forest_hud" and order[-1] == &"settings_ui", "GameUI list: hud, forest_hud ... settings_ui (16)")
	var wanted := [&"hud", &"forest_hud", &"dialogue_ui", &"inventory_ui", &"quest_journal", &"shop_ui", &"animal_care_ui", &"build_menu_ui", &"pause_menu", &"save_load_ui", &"settings_ui", &"husbyggeri", &"indretning", &"home_chest", &"garderobe", &"samlerbog"]
	var all_there := true
	for id in wanted:
		all_there = all_there and order.has(id)
	t.expect(all_there, "the 11 base screens and the 5 addendum screens are all in the list")
	var ui: GameUI = (load("res://scenes/ui/game_ui.tscn") as PackedScene).instantiate()
	t.root.add_child(ui)
	await t.frames(2)
	var existing: Array[StringName] = []
	for id in order:
		if ResourceLoader.exists(GameUI.scene_path(id)):
			existing.append(id)
	t.check("game_ui_instantiates_what_exists", ui.layer == 10 and ui.process_mode == Node.PROCESS_MODE_ALWAYS and ui.is_in_group(&"game_ui") and str(ui.loaded_screens()) == str(existing),
		"layer 10, ALWAYS, group game_ui; loaded %s (none are required)" % str(ui.loaded_screens()))
	ui.queue_free()
	await t.frames(1)
	# fake screens in user:// (the loader takes a directory and an order)
	var dir := "user://p07_game_ui_section/"
	DirAccess.make_dir_recursive_absolute(dir)
	for id in ["hud", "inventory_ui", "pause_menu", "garderobe"]:
		var c := Control.new()
		c.name = "X"
		if id == "hud":
			var b := Button.new()
			b.name = "Slot"
			b.focus_mode = Control.FOCUS_ALL
			c.add_child(b)
			b.owner = c
		_write_fake_scene(dir, id, c)
	var gu: GameUI = (load("res://scenes/ui/game_ui.tscn") as PackedScene).instantiate()
	gu.load_screens(dir, order)
	t.root.add_child(gu)
	await t.frames(2)
	t.expect(str(gu.loaded_screens()) == str([&"hud", &"inventory_ui", &"garderobe", &"pause_menu"]), "only existing scenes load, in list order (garderobe below pause_menu): %s" % str(gu.loaded_screens()))
	t.expect(gu.get_screen(&"hud") != null and gu.get_screen(&"samlerbog") == null and gu.get_screen(&"Garderobe") != null, "get_screen by id or node name, null when missing")
	t.expect((gu.get_screen(&"hud").get_node("Slot") as Control).focus_mode == Control.FOCUS_NONE, "HUD controls use focus_mode NONE")
	gu.set_mode(&"action")
	t.expect(gu.mode == &"action" and not (gu.get_screen(&"hud") as Control).visible, "set_mode(action) hides the farm HUD")
	gu.set_mode(&"farm")
	t.expect((gu.get_screen(&"hud") as Control).visible, "set_mode(farm) shows it again")
	var key_handlers := ["_input", "_unhandled_input", "_unhandled_key_input", "_shortcut_input"].filter(func(n): return (gu.get_script() as Script).get_script_method_list().any(func(m): return str(m["name"]) == n))
	t.check("game_ui_no_key_handling", key_handlers.is_empty(), "no key handler in game_ui.gd: %s" % str(key_handlers))
	gu.queue_free()
	await t.frames(1)
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			d.remove(f)
	DirAccess.remove_absolute(dir)


# ---------------------------------------------------------------------------------------------------- tt_* helpers

func _tt_helpers(t) -> void:
	var failed_before: int = t.failed
	var fmt := Fmt
	var portraits := Portraits
	var tm: Node = t.autoload("TimeManager")
	TranslationServer.set_locale("da")
	var da_text: String = fmt.date_text(16, &"foraar")
	t.expect(da_text == "Tirsdag 16. Blomstermåned" and da_text == tm.date_text(16, &"foraar"), "date_text = TimeManager.date_text (one calendar): %s" % da_text)
	TranslationServer.set_locale("en")
	t.expect(fmt.date_text(16, &"foraar") == "Tuesday 16. Month of Blooms" and fmt.thousands(1250) == "1,250", "en: %s / %s" % [fmt.date_text(16, &"foraar"), fmt.thousands(1250)])
	TranslationServer.set_locale("da")
	t.expect(fmt.thousands(1250) == "1.250" and fmt.clock(7, 5) == "07:05", "da: thousands and clock")
	var p: String = portraits.resolve_path(&"mayor_lyra")
	t.expect(p != "" and ResourceLoader.exists(p), "mayor_lyra portrait resolves through npcs.lua + characters.lua (%s)" % p)
	var fake := {"res://assets/portraits/fairy_mayor.webp": true}
	t.expect(portraits.resolve_path(&"mayor_lyra", func(path: String) -> bool: return fake.has(path)) == "res://assets/portraits/fairy_mayor.webp", "the bust of the NPC's own visual wins as soon as it exists")
	var both := {"res://assets/portraits/fox.webp": true, "res://assets/isometric_characters/fox/portrait.webp": true}
	t.expect(portraits.resolve_visual_path(["fox"], func(path: String) -> bool: return both.has(path)) == "res://assets/portraits/fox.webp", "assets/portraits/<id>.webp before isometric_characters/<id>/portrait.webp")
	var only_pack := {"res://assets/isometric_characters/fairy/portrait.webp": true}
	t.expect(portraits.resolve_path(&"mayor_lyra", func(path: String) -> bool: return only_pack.has(path)) == "res://assets/isometric_characters/fairy/portrait.webp", "fallback chain fairy_mayor -> fairy, pack folder portrait")
	var quest_text := QuestText
	t.expect(quest_text.tag_id("HØST") == "HOEST" and quest_text.tag_id("LÆR") == "LAER" and quest_text.tag_id("find") == "FIND", "quest tag ids are ASCII (HØST -> HOEST)")
	t.check("tt_helpers", t.failed == failed_before, "tt_format / tt_portraits / tt_quest_text answer through TimeManager, npcs.lua and characters.lua")


# ---------------------------------------------------------------------------------------------------- tt_quest_text: location + hostile tables

## the harness's own raw-key pattern, applied to every word of a line
func _raw_key_words(t, line: String) -> Array[String]:
	var rx := RegEx.new()
	rx.compile(t.RAW_KEY_PATTERN)
	var bad: Array[String] = []
	for word in line.replace(" · ", " ").split(" ", false):
		if rx.search(word) != null:
			bad.append(word)
	return bad


func _real_quest_ids(t) -> Array[StringName]:
	var qm: Node = t.autoload("QuestManager")
	var ids: Array[StringName] = []
	for k in qm.quest_flags:
		if str(k).begins_with("def_"):
			ids.append(StringName(str(k).substr(4)))
	return ids


## title(): the Lua title, else a translated title_key, else QUEST_<ID>_TITLE, else the id made readable - never a raw key.
func _quest_text_title(t) -> void:
	var failed_before: int = t.failed
	TranslationServer.set_locale("da")
	var fakes := _add_fake_translations({
		"QUEST_T_KEYED_TITLE": ["Nøgletitel", "Key title"],
		"QUEST_T_DERIVED_TITLE": ["Afledt titel", "Derived title"],
		"QUEST_T_BAD_KEY_DERIVED_TITLE": ["Titel efter fejlnøgle", "Title after a bad key"],
	})
	var defs := {
		&"t_plain": {"title": "Ren titel"},
		&"t_keyed": {"title_key": "QUEST_T_KEYED_TITLE"},
		&"t_derived": {},
		&"t_bad_key_derived": {"title_key": "QUEST_NOT_ANYWHERE_TITLE"},
		&"t_bad_key": {"title_key": "QUEST_STILL_NOT_ANYWHERE_TITLE"},
		&"t_missing": {},
		&"t_wrong_type": {"title": [], "title_key": {}},
	}
	QuestText.set_providers(func(id): return defs.get(id, {}))
	t.expect(QuestText.title(&"t_plain") == "Ren titel" and QuestText.title(&"t_keyed") == "Nøgletitel" and QuestText.title(&"t_derived") == "Afledt titel", "title: the Lua title, a translated title_key, QUEST_<ID>_TITLE")
	t.expect(QuestText.title(&"t_bad_key_derived") == "Titel efter fejlnøgle", "a title_key without a translation falls back to QUEST_<ID>_TITLE ('%s')" % QuestText.title(&"t_bad_key_derived"))
	var lines: Array[String] = []
	for id in [&"t_bad_key", &"t_missing", &"t_wrong_type"]:
		lines.append(QuestText.title(id))
	t.expect(lines[0] == "T Bad Key" and lines[1] == "T Missing" and lines[2] == "T Wrong Type", "no title, no key, no translation: the id made readable, never a raw key %s" % str(lines))
	var raw: Array[String] = []
	for id in defs:
		raw.append_array(_raw_key_words(t, QuestText.title(id)))
	t.expect(raw.is_empty() and QuestText.title(&"t_bad_key") != "QUEST_STILL_NOT_ANYWHERE_TITLE" and QuestText.title(&"t_missing") != "QUEST_T_MISSING_TITLE", "none of the seven titles contains a raw translation key %s" % str(raw))
	TranslationServer.set_locale("en")
	t.expect(QuestText.title(&"t_keyed") == "Key title" and QuestText.title(&"t_derived") == "Derived title" and QuestText.title(&"t_bad_key") == "T Bad Key", "en: the same fallbacks")
	TranslationServer.set_locale("da")
	QuestText.clear_providers()
	_drop_translations(fakes)
	var bad: Array[String] = []
	var ids := _real_quest_ids(t)
	for id in ids:
		var title := QuestText.title(id)
		if title == "" or not _raw_key_words(t, title).is_empty():
			bad.append("%s: '%s'" % [id, title])
	t.expect(ids.size() > 0 and bad.is_empty(), "%d real quest definitions: every title is real text %s" % [ids.size(), str(bad)])
	t.check("quest_text_title", t.failed == failed_before, "tt_quest_text.title() guards title_key and QUEST_<ID>_TITLE with _has_key like description() and step_text()")


func _quest_text(t) -> void:
	var failed_before: int = t.failed
	TranslationServer.set_locale("da")
	var giver_defs := {
		&"q_zone": {"meta": {"giver": "pippin_boegeknop", "location": "ZONE_CITY"}},
		&"q_farm": {"meta": {"giver": "pippin_boegeknop", "location": "ZONE_FARM"}},
		&"q_deep": {"meta": {"giver": "pippin_boegeknop", "location": "ZONE_DYBE_BREGNER"}},
		&"q_missing": {"meta": {"giver": "pippin_boegeknop", "location": "ZONE_NOT_IN_ANY_CSV"}},
		&"q_plain": {"meta": {"giver": "pippin_boegeknop", "location": "Skovbrynet"}},
		&"q_none": {"meta": {"giver": "pippin_boegeknop"}},
		&"q_nogiver": {"meta": {"location": "ZONE_CITY"}},
	}
	QuestText.set_providers(func(id): return giver_defs.get(id, {}))
	var prefix: String = TranslationServer.translate("QJ_FROM") % QuestText.giver_name(&"q_zone")
	t.expect(TranslationServer.translate("ZONE_CITY") == "Hyggebyen" and TranslationServer.translate("ZONE_FARM") != "ZONE_FARM", "the zone keys of the real quests translate (ZONE_CITY = %s)" % TranslationServer.translate("ZONE_CITY"))
	t.expect(QuestText.from_line(&"q_zone") == prefix + " · Hyggebyen", "meta.location = \"ZONE_CITY\" is shown translated: '%s'" % QuestText.from_line(&"q_zone"))
	t.expect(QuestText.from_line(&"q_farm") == prefix + " · " + TranslationServer.translate("ZONE_FARM") and QuestText.from_line(&"q_deep") == prefix + " · " + TranslationServer.translate("ZONE_DYBE_BREGNER"), "ZONE_FARM and ZONE_DYBE_BREGNER too: '%s' / '%s'" % [QuestText.from_line(&"q_farm"), QuestText.from_line(&"q_deep")])
	t.expect(QuestText.from_line(&"q_missing") == prefix and QuestText.location_text(&"q_missing") == "", "a key-shaped location WITHOUT a translation is dropped, never printed raw: '%s'" % QuestText.from_line(&"q_missing"))
	t.expect(QuestText.from_line(&"q_plain") == prefix + " · Skovbrynet", "plain text (not a key) is kept as it is: '%s'" % QuestText.from_line(&"q_plain"))
	t.expect(QuestText.from_line(&"q_none") == prefix and QuestText.from_line(&"q_nogiver") == "", "no location: no separator; no giver: no line")
	TranslationServer.set_locale("en")
	t.expect(QuestText.from_line(&"q_zone").ends_with(" · Hyggebyen") and QuestText.from_line(&"q_deep").ends_with(TranslationServer.translate("ZONE_DYBE_BREGNER")) and TranslationServer.translate("ZONE_DYBE_BREGNER") != "ZONE_DYBE_BREGNER", "en: the same lines in English ('%s')" % QuestText.from_line(&"q_deep"))
	TranslationServer.set_locale("da")
	QuestText.clear_providers()
	# the real quest definitions of the repo (24 files when this was written): not one 'Fra <giver> · <place>' line shows a raw key
	var qm: Node = t.autoload("QuestManager")
	var ids := _real_quest_ids(t)
	var raw_lines: Array[String] = []
	var keyed := 0
	var keyed_ok := true
	for id in ids:
		var line: String = QuestText.from_line(id)
		for w in _raw_key_words(t, line):
			raw_lines.append("%s: %s" % [id, line])
		var loc := str(LuaData.dict(LuaData.dict(qm.get_quest_def(id)).get("meta", {})).get("location", ""))
		if loc.begins_with("ZONE_") and TranslationServer.translate(loc) != loc:
			keyed += 1
			keyed_ok = keyed_ok and line.ends_with(" · " + TranslationServer.translate(loc))
		QuestText.title(id)
		QuestText.steps(id)
		QuestText.rewards(id)
	t.expect(ids.size() > 0 and raw_lines.is_empty(), "%d real quest definitions: no from-line carries a raw translation key %s" % [ids.size(), str(raw_lines)])
	t.expect(keyed > 0 and keyed_ok, "%d real quests carry a ZONE_ key as location: each from-line ends with the translated place" % keyed)
	t.check("quest_text_location", t.failed == failed_before, "meta.location is a zone KEY (plan 3.12): translated in the quest book's 'Fra <giver> · <place>' line, never printed raw")

	# --- hostile definitions: the Lua reader hands an EMPTY table over as an Array (or an empty Dictionary)
	failed_before = t.failed
	var hostile := {
		&"h_empty_tables": {"meta": [], "rewards": [], "objectives": []},
		&"h_empty_dicts": {"meta": {}, "rewards": {}, "objectives": {}},
		&"h_empty_subs": {"meta": {"giver": "pippin_boegeknop", "location": []}, "rewards": {"gold": 5, "items": [], "friendship": []},
			"objectives": [[], {"id": "a", "target": []}, {"id": "b", "target": 2, "description": []}]},
		&"h_wrong_types": {"meta": "text", "rewards": 7, "objectives": "none", "title": [], "description": {}, "source_path": 3},
		&"h_array_def": [],
	}
	var progress := func(_id): return []
	QuestText.set_providers(func(id): return hostile.get(id, {}), progress, func(_id): return false)
	var tag_default: String = TranslationServer.translate("QJ_TAG_HELP")
	var all_ok := true
	for id in hostile:
		if id != &"h_empty_subs":
			all_ok = all_ok and QuestText.giver_id(id) == ""
		var lines := [QuestText.title(id), QuestText.description(id), QuestText.giver_name(id), QuestText.from_line(id), QuestText.location_text(id), QuestText.tag_text(id), QuestText.source_path(id)]
		var chips: Array = QuestText.rewards(id)
		var steps: Array = QuestText.steps(id)
		all_ok = all_ok and lines[5] == tag_default and QuestText.tag_color(id) == Color(QuestText.TAGS["HELP"][1])
		if id != &"h_empty_subs":
			all_ok = all_ok and chips.is_empty() and steps.is_empty() and lines[3] == ""
		if not all_ok:
			t.fail("hostile definition %s answered %s / %d chips / %d steps" % [id, str(lines), chips.size(), steps.size()])
			break
	t.expect(all_ok, "meta / rewards / objectives that are empty tables (Array or Dictionary) or the wrong type: every reader answers with 'nothing' instead of a script error")
	var chips: Array = QuestText.rewards(&"h_empty_subs")
	var steps: Array = QuestText.steps(&"h_empty_subs")
	t.expect(chips.size() == 1 and chips[0]["kind"] == "gold" and str(chips[0]["text"]).begins_with("5 "), "rewards = { gold = 5, items = {}, friendship = {} }: the gold chip only (%s)" % str(chips))
	t.expect(QuestText.giver_id(&"h_empty_subs") == "pippin_boegeknop" and QuestText.from_line(&"h_empty_subs") == prefix and QuestText.location_text(&"h_empty_subs") == "", "meta.location = {} is no place: '%s'" % QuestText.from_line(&"h_empty_subs"))
	t.expect(steps.size() == 3 and int(steps[1]["target"]) == 1 and int(steps[2]["target"]) == 2 and str(steps[2]["text"]) == "B", "objectives = { {}, {id = a, target = {}}, ... }: three rows with default targets (%s)" % str(steps.map(func(x): return x["target"])))
	QuestText.clear_providers()
	t.check("quest_text_hostile_definitions", t.failed == failed_before, "tt_quest_text reads every sub-table through LuaData: empty tables never raise script errors")


# ---------------------------------------------------------------------------------------------------- ui.csv

func _no_duplicate_keys(t) -> void:
	var lm: Node = t.autoload("LocalizationManager")
	var csv: Dictionary = lm.read_csv("res://localization/ui.csv")
	t.check("ui_csv_readable", not csv.is_empty() and csv["header"] == PackedStringArray(["keys", "da", "en"]), "localization/ui.csv has the header keys,da,en")
	var keys: Array[String] = []
	var dup: Array[String] = []
	var bad_cells: Array[String] = []
	var banned: Array[String] = []
	for row in csv.get("rows", []):
		var cells: PackedStringArray = row["cells"]
		var k := cells[0].strip_edges()
		if k.begins_with(";") or k.begins_with("#"):
			continue
		if keys.has(k):
			dup.append(k)
		keys.append(k)
		if cells.size() < 3 or cells[1].strip_edges() == "" or cells[2].strip_edges() == "":
			bad_cells.append(k)
		var shop_greeting := k.begins_with("SHOP_") and k.ends_with("_GREETING") and k != "SHOP_GREETING_DEFAULT"
		if k.begins_with("RECIPE_") or k.begins_with("ITEM_") and not k.begins_with("GALLERY_") or shop_greeting or k.begins_with("INV_RARITY_") or k.contains("_EPIC"):
			banned.append(k)
	t.expect(dup.is_empty(), "no key twice inside ui.csv %s" % str(dup))
	t.expect(bad_cells.is_empty(), "every ui.csv key has da AND en text %s" % str(bad_cells))
	t.expect(banned.is_empty(), "no RECIPE_*, ITEM_*, per-shop SHOP_<id>_GREETING or INV_RARITY_* (EPIC) rows %s" % str(banned))
	# required content (handoffs of P02, P03, P05 + plan 3.4)
	var need: Array[String] = ["UI_CURRENCY", "HUD_ACTIVE_QUESTS", "HUD_ENERGY", "UI_MONTH_FORAAR", "UI_MONTH_SOMMER", "UI_MONTH_EFTERAAR", "UI_MONTH_VINTER", "UI_WEATHER_REGN", "UI_WEATHER_TAAGE", "UI_WEATHER_SNE", "UI_WEATHER_TORDEN",
		"SPECIES_FOX", "SPECIES_RABBIT", "SPECIES_HEDGEHOG", "SPECIES_SQUIRREL", "MENU_CONTINUE", "MENU_SETTINGS", "MENU_QUIT", "CHAR_FAIRY_NAME", "CHAR_HOBBIT_NAME", "SHOP_TAB_SEEDS", "SHOP_TOTAL", "SHOP_GREETING_DEFAULT", "DIALOGUE_VOICE_DA", "DIALOGUE_CONTINUE_HINT"]
	for i in range(1, 8):
		need.append("UI_WEEKDAY_%d" % i)
	var missing: Array[String] = []
	for k in need:
		if not keys.has(k):
			missing.append(k)
	t.expect(missing.is_empty(), "the keys other packages asked for exist in ui.csv: missing %s" % str(missing))
	t.expect(not keys.has("UI_WEATHER_KLART"), "UI_WEATHER_KLART stays in core.csv (defined there already)")
	# the values of the canonical copy (plan 3.4), both languages
	var checks := {"UI_CURRENCY": ["guldagern", "gold acorns"], "UI_WEEKDAY_2": ["Tirsdag", "Tuesday"], "UI_MONTH_FORAAR": ["Blomstermåned", "Month of Blooms"], "UI_WEATHER_TORDEN": ["Torden", "Thunder"],
		"SPECIES_RABBIT": ["Kanin", "Rabbit"], "MENU_QUIT": ["Afslut", "Quit"], "HUD_ENERGY": ["Energi", "Energy"], "HUD_ACTIVE_QUESTS": ["AKTIVE OPGAVER", "ACTIVE QUESTS"]}
	var values_ok := true
	for k in checks:
		values_ok = values_ok and lm.text_in(k, "da") == checks[k][0] and lm.text_in(k, "en") == checks[k][1]
	t.expect(values_ok, "canonical copy da/en of the shared keys")
	# ownership and cross-file: no key of ui.csv defined by another non-legacy CSV; the lint finds no error in ui.csv
	var report: Dictionary = lm.parse_dir("res://localization", "res://", true)
	var other: Array[String] = []
	for def in report["defs"]:
		if def["file"] != "ui.csv" and def["file"] != "da.csv" and def["file"] != "zz_final.csv" and keys.has(str(def["key"])):
			other.append("%s in %s" % [def["key"], def["file"]])
	t.expect(other.is_empty(), "no ui.csv key is defined in another non-legacy CSV %s" % str(other))
	var mine: Array[String] = []
	for iss in report["issues"]:
		if iss["file"] == "ui.csv" and iss["sev"] == "error":
			mine.append(lm.format_issue(iss))
	t.expect(mine.is_empty(), "the localization lint reports no error for ui.csv %s" % str(mine))
	var owners: Dictionary = lm.load_owners("res://")
	var foreign: Array[String] = []
	for k in keys:
		var o: String = lm.owner_of(k, owners)
		if o != "" and o != "ui.csv" and not k.begins_with("GALLERY_"):
			foreign.append("%s -> %s" % [k, o])
	t.expect(foreign.is_empty(), "every ui.csv key is owned by ui.csv in tools/loc/key_owners.json %s" % str(foreign))
	t.expect(FileAccess.get_file_as_string("res://localization/ui.csv.import").contains('importer="keep"'), "ui.csv.import is a keep stub (R.4)")
	t.check("no_duplicate_keys", dup.is_empty() and banned.is_empty() and missing.is_empty() and other.is_empty() and mine.is_empty() and foreign.is_empty() and values_ok, "%d keys, 0 duplicates, no RECIPE_/ITEM_/shop-greeting/INV_RARITY_ rows, no cross-file duplicate" % keys.size())


# ---------------------------------------------------------------------------------------------------- compare_guide.py

func _python() -> String:
	if _py != "":
		return _py
	for p in ["res://tools/art/.venv/bin/python", "res://tools/art/.venv/bin/python3"]:
		var g := ProjectSettings.globalize_path(p)
		if FileAccess.file_exists(g):
			_py = g
			return _py
	return ""


func _cg(t, args: Array) -> Dictionary:
	var script := ProjectSettings.globalize_path("res://tests/checkpoints/compare_guide.py")
	var argv := PackedStringArray(["-I", script])
	for a in args:
		argv.append(str(a))
	return t.run_tool(_python(), argv)


func _solid(path: String, w: int, h: int, col: Color, frame: int = 0, frame_col: Color = Color("#2b2340"), patch: Rect2i = Rect2i(), patch_col: Color = Color.BLACK) -> void:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGB8)
	img.fill(frame_col if frame > 0 else col)
	if frame > 0:
		img.fill_rect(Rect2i(frame, frame, w - 2 * frame, h - 2 * frame), col)
	if patch.size != Vector2i.ZERO:
		img.fill_rect(patch, patch_col)
	img.save_png(path)


func _compare_guide_modes(t) -> void:
	var py := _python()
	if py == "":
		t.skip("compare_guide_modes: the project venv (tools/art/.venv, python + numpy + Pillow) is missing: run tools/art/setup_env.sh")
		return
	var dir := OS.get_user_data_dir() + "/p07_compare_guide/"
	DirAccess.make_dir_recursive_absolute(dir)
	var A := Color8(120, 160, 90)
	# 1. the seven bundled references: present, 1280x720, a reference compared with itself is exactly 0 (and the screens differ)
	var sizes_ok := true
	var self_ok := true
	for s in GUIDE_SCREENS:
		var ref := ProjectSettings.globalize_path("res://tests/checkpoints/guide_ref/pw1x_%s.png" % s)
		var img := Image.load_from_file(ref)
		sizes_ok = sizes_ok and img != null and img.get_size() == Vector2i(1280, 720)
		var r := _cg(t, ["--ref", ref, "--no-frame-crop", "--json", ref])
		var j: Variant = JSON.parse_string(str(r["output"]))
		self_ok = self_ok and r["code"] == 0 and j is Dictionary and absf(float((j as Dictionary)["screens"].values()[0]["mean"])) < 1e-9
	t.expect(sizes_ok, "tests/checkpoints/guide_ref holds the seven pw1x_<screen>.png renders at 1280x720")
	t.expect(FileAccess.file_exists("res://tests/checkpoints/guide_ref/.gdignore"), "guide_ref has a .gdignore: Godot never imports the reference PNGs (python reads them)")
	t.expect(self_ok, "a bundled reference compared with itself (--ref, --no-frame-crop) is 0.00 for all seven")
	var hud := ProjectSettings.globalize_path("res://tests/checkpoints/guide_ref/pw1x_hud.png")
	var ttl := ProjectSettings.globalize_path("res://tests/checkpoints/guide_ref/pw1x_title.png")
	var neg := _cg(t, ["--json", "hud=" + ttl])
	var neg_mean := float(((JSON.parse_string(str(neg["output"])) as Dictionary)["screens"] as Dictionary)["hud"]["mean"]) if neg["code"] == 0 else -1.0
	t.expect(neg_mean > 20.0, "negative control: the TITLE render scored against the HUD guide screen is far off (%.1f)" % neg_mean)
	# 2. frame crop: a 2 px frame reference against a frameless shot
	var ref_f := dir + "ref_frame.png"
	var shot := dir + "shot_flat.png"
	_solid(ref_f, 1280, 720, A, 2)
	_solid(shot, 1280, 720, A)
	var crop := _cg(t, ["--ref", ref_f, "--json", shot])
	var nocrop := _cg(t, ["--ref", ref_f, "--no-frame-crop", "--json", shot])
	var m_crop := float(((JSON.parse_string(str(crop["output"])) as Dictionary)["screens"] as Dictionary).values()[0]["mean"])
	var m_nocrop := float(((JSON.parse_string(str(nocrop["output"])) as Dictionary)["screens"] as Dictionary).values()[0]["mean"])
	t.expect(m_crop < 0.01 and m_nocrop > 0.5, "frame crop is the default (2 px HTML frame ignored: %.3f); --no-frame-crop keeps it (%.3f)" % [m_crop, m_nocrop])
	# 3. region: a patch that differs by exactly 20 in every channel
	var ref_p := dir + "ref_plain.png"
	var shot_p := dir + "shot_patch.png"
	_solid(ref_p, 1280, 720, A)
	_solid(shot_p, 1280, 720, A, 0, A, Rect2i(100, 100, 200, 100), Color8(140, 180, 110))
	var inside := _cg(t, ["--ref", ref_p, "--no-frame-crop", "--region", "100,100,200,100", "--json", shot_p])
	var outside := _cg(t, ["--ref", ref_p, "--no-frame-crop", "--region", "400,300,200,100", "--json", shot_p])
	var whole := _cg(t, ["--ref", ref_p, "--no-frame-crop", "--json", shot_p])
	var mi := float(((JSON.parse_string(str(inside["output"])) as Dictionary)["screens"] as Dictionary).values()[0]["mean"])
	var mo := float(((JSON.parse_string(str(outside["output"])) as Dictionary)["screens"] as Dictionary).values()[0]["mean"])
	var mw := float(((JSON.parse_string(str(whole["output"])) as Dictionary)["screens"] as Dictionary).values()[0]["mean"])
	var expect_whole := 20.0 * (200.0 * 100.0) / (1280.0 * 720.0)
	t.expect(absf(mi - 20.0) < 1e-6 and mo < 1e-9 and absf(mw - expect_whole) < 1e-3, "--region x,y,w,h: inside the patch %.4f (=20), outside %.4f, whole picture %.4f (=%.4f)" % [mi, mo, mw, expect_whole])
	# 4. --ref accepts any name; --max / --target; usage errors
	var other := dir + "anything_at_all.png"
	_solid(other, 1280, 720, A)
	var any_ref := _cg(t, ["--ref", ref_p, "--no-frame-crop", other])
	t.expect(any_ref["code"] == 0 and str(any_ref["output"]).contains("mean abs diff"), "--ref works with any shot name: %s" % str(any_ref["output"]).strip_edges())
	var over := _cg(t, ["--ref", ref_p, "--no-frame-crop", "--max", "0.3", shot_p])
	var under := _cg(t, ["--ref", ref_p, "--no-frame-crop", "--max", "5", shot_p])
	var tgt := _cg(t, ["--no-frame-crop", "--target", "hud=0.1", "hud=" + shot_p])
	t.expect(over["code"] == 1 and under["code"] == 0, "--max N on the whole picture: mean 0.43 > 0.3 exits 1, <= 5 exits 0 (codes %s / %s)" % [over["code"], under["code"]])
	var bad_screen := _cg(t, ["nonsense.png"])
	var bad_region := _cg(t, ["--ref", ref_p, "--no-frame-crop", "--region", "1200,700,200,100", shot_p])
	var two := _cg(t, ["--ref", ref_p, shot_p, shot_p])
	var missing := _cg(t, ["--ref", ref_p, dir + "does_not_exist.png"])
	t.expect(bad_screen["code"] == 2 and bad_region["code"] == 2 and two["code"] == 2 and missing["code"] == 2, "usage errors exit 2 (unknown screen %s, region outside %s, --ref with two shots %s, missing file %s)" % [bad_screen["code"], bad_region["code"], two["code"], missing["code"]])
	t.expect(tgt["code"] == 1 and str(tgt["output"]).contains("EXCEEDS"), "--target hud=0.1 on a flat shot against the HUD guide screen exits 1 (%s)" % str(tgt["output"]).strip_edges())
	# a limit that is exceeded exits 1 with a flag in the JSON (shot_p vs ref_p is 20 in the patch: use the patch region 100% -> mean 20)
	var lim := _cg(t, ["--ref", ref_p, "--no-frame-crop", "--region", "100,100,200,100", "--max", "10", shot_p])
	var lim_ok := _cg(t, ["--ref", ref_p, "--no-frame-crop", "--region", "100,100,200,100", "--max", "25", shot_p])
	t.expect(lim["code"] == 1 and lim_ok["code"] == 0 and str(lim["output"]).contains("EXCEEDS"), "--max N: mean 20 > 10 exits 1 ('EXCEEDS'), <= 25 exits 0")
	# 5. bad inputs are a usage / file error (2), never "a limit was exceeded" (1): F7 / F8 / P27 tell the two apart by the code
	var junk := dir + "hud_junk.png"
	var fj := FileAccess.open(junk, FileAccess.WRITE)
	fj.store_string("this is not a picture")
	fj.close()
	var trunc := dir + "hud_truncated.png"
	var fw := FileAccess.open(trunc, FileAccess.WRITE)
	fw.store_buffer(FileAccess.get_file_as_bytes(hud).slice(0, 3000))
	fw.close()
	var bad_target := _cg(t, ["--target", "hud=abc", "hud=" + shot_p])
	var nan_target := _cg(t, ["--target", "hud=nan", "hud=" + shot_p])
	var neg_target := _cg(t, ["--target", "hud=-1", "hud=" + shot_p])
	var nan_max := _cg(t, ["--max", "nan", "hud=" + shot_p])
	var junk_shot := _cg(t, ["hud=" + junk])
	var junk_ref := _cg(t, ["--ref", junk, "--no-frame-crop", shot_p])
	var trunc_shot := _cg(t, ["hud=" + trunc])
	var trunc_ref := _cg(t, ["--ref", trunc, "--no-frame-crop", shot_p])
	var out_dir := _cg(t, ["--ref", ref_p, "--no-frame-crop", "--out", dir + "no_such_dir/x", shot_p])
	var bad_codes := [bad_target["code"], nan_target["code"], neg_target["code"], nan_max["code"], junk_shot["code"], junk_ref["code"], trunc_shot["code"], trunc_ref["code"], out_dir["code"]]
	var bad_ok: bool = bad_codes.all(func(c): return c == 2)
	var said_so: bool = [bad_target, junk_shot, trunc_shot, out_dir].all(func(r): return str(r["output"]).contains("compare_guide:") and not str(r["output"]).contains("Traceback"))
	t.expect(bad_ok and said_so, "malformed --target / --max, a text file, a truncated PNG (shot or reference) and an unwritable --out all exit 2 with a 'compare_guide:' message and no traceback (codes %s)" % str(bad_codes))
	# 6. --frame-px is validated: a negative value used to PAD the picture (exit 0, a 1290x730 comparison, a wrong number) and a value
	#    larger than the picture failed inside PIL; both are usage errors (2) that name the limit
	var fp_neg := _cg(t, ["--frame-px=-3", "--json", "hud=" + shot_p])
	var fp_neg_nocrop := _cg(t, ["--frame-px=-1", "--no-frame-crop", "hud=" + shot_p])
	var fp_huge := _cg(t, ["--frame-px", "5000", "hud=" + shot_p])
	var fp_edge := _cg(t, ["--frame-px", "360", "hud=" + shot_p])              # 2 x 360 = 720: nothing of a 1280x720 reference is left
	var fp_text := _cg(t, ["--frame-px", "wide", "hud=" + shot_p])
	var fp_zero := _cg(t, ["--frame-px", "0", "--json", "hud=" + shot_p])
	var fp_last := _cg(t, ["--frame-px", "359", "--json", "hud=" + shot_p])     # the largest value that still leaves a picture
	var fp_codes := [fp_neg["code"], fp_neg_nocrop["code"], fp_huge["code"], fp_edge["code"], fp_text["code"]]
	var fp_said: bool = str(fp_neg["output"]).contains("compare_guide: --frame-px wants a whole number >= 0") and str(fp_huge["output"]).contains("use 0 to 359") and str(fp_edge["output"]).contains("use 0 to 359")
	for r in [fp_neg, fp_huge, fp_edge]:
		fp_said = fp_said and not str(r["output"]).contains("Traceback") and not str(r["output"]).contains("less than left")
	var fp_ok: bool = fp_codes.all(func(c): return c == 2) and fp_said
	t.expect(fp_ok, "--frame-px: a negative number (with or without --no-frame-crop), 360+ on a 720 px picture, 5000 and text all exit 2 with the limit named, no PIL error (codes %s)" % str(fp_codes))
	var fp_size_of := func(r: Dictionary) -> Array:
		var j: Variant = JSON.parse_string(str(r["output"]))
		if r["code"] != 0 or not (j is Dictionary):
			return []
		return ((j as Dictionary)["screens"] as Dictionary)["hud"]["size"]
	var zero_size: Array = fp_size_of.call(fp_zero)
	var last_size: Array = fp_size_of.call(fp_last)
	var sizes_match: bool = zero_size.size() == 2 and last_size.size() == 2 and int(zero_size[0]) == 1280 and int(zero_size[1]) == 720 and int(last_size[0]) == 562 and int(last_size[1]) == 2
	t.expect(sizes_match, "--frame-px 0 keeps the whole 1280x720 reference, 359 is accepted (%s / %s)" % [str(zero_size), str(last_size)])
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			d.remove(f)
	DirAccess.remove_absolute(dir)
	t.check("compare_guide_modes", sizes_ok and self_ok and neg_mean > 20.0 and m_crop < 0.01 and m_nocrop > 0.5 and absf(mi - 20.0) < 1e-6 and lim["code"] == 1 and bad_ok and said_so and fp_ok and sizes_match,
		"--ref / --no-frame-crop / --region / --max / --frame-px exercised on synthetic images and the seven bundled references; bad inputs exit 2")


## The seven references were REGENERATED (the spike's originals were lost), so they are the baseline every later diff target
## (F7 / F8 / P27) is measured against. A changed reference silently shifts all of them: tests/checkpoints/guide_ref/SHA256SUMS pins them.
## Replacing a reference on purpose = regenerate SHA256SUMS (see guide_ref/README.md) in the same change.
func _guide_ref_pinned(t) -> void:
	var sums_path := ProjectSettings.globalize_path("res://tests/checkpoints/guide_ref/SHA256SUMS")
	t.expect(FileAccess.file_exists(sums_path), "guide_ref/SHA256SUMS exists")
	var pinned := {}
	for line in FileAccess.get_file_as_string(sums_path).split("\n", false):
		var parts := line.strip_edges().split("  ", false)
		if parts.size() == 2:
			pinned[parts[1]] = parts[0]
	var drift: Array[String] = []
	for s in GUIDE_SCREENS:
		var name := "pw1x_%s.png" % s
		var actual := FileAccess.get_sha256(ProjectSettings.globalize_path("res://tests/checkpoints/guide_ref/" + name))
		if not pinned.has(name):
			drift.append("%s is not pinned" % name)
		elif str(pinned[name]) != actual:
			drift.append("%s changed (%s...)" % [name, actual.substr(0, 12)])
	for name in pinned:
		if not FileAccess.file_exists(ProjectSettings.globalize_path("res://tests/checkpoints/guide_ref/" + str(name))):
			drift.append("%s is pinned but missing" % name)
	t.check("guide_ref_pinned", drift.is_empty() and pinned.size() == GUIDE_SCREENS.size(), "the seven regenerated guide references still hash to SHA256SUMS %s" % str(drift))


# ---------------------------------------------------------------------------------------------------- the smoke

func _smoke(t) -> void:
	var r: Dictionary = t.run_tool(OS.get_executable_path(), PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "res://scenes/ui/dev/ui_smoke.tscn"]))
	var line := ""
	for l in r["lines"]:
		if str(l).begins_with("UI SMOKE"):
			line = str(l)
	var n := 0
	if line != "":
		n = int(line.get_slice(": ", 1).get_slice(" ", 0))
	t.check("smoke", r["code"] == 0 and line.begins_with("UI SMOKE PASS") and n >= 150, "ui_smoke.tscn child run: exit %s, '%s'" % [r["code"], line])
	if r["code"] != 0:
		for l in r["lines"]:
			if str(l).contains("FAIL") or str(l).contains("ENGINE MESSAGE"):
				t.info(str(l))


# ---------------------------------------------------------------------------------------------------- windowed pixels

func run_windowed(t) -> void:
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.root.add_child(host)
	var g: Control = (load("res://scenes/ui/dev/components_gallery.tscn") as PackedScene).instantiate()
	host.add_child(g)
	await t.frames(4)
	var guide: Image = await t.capture("gallery_guide")
	g.show_page(&"rarity")
	await t.frames(4)
	var img: Image = await t.capture("gallery_rarity")
	if img == null or guide == null:
		return
	t.expect_not_blank(guide, Rect2i(0, 0, 1280, 720), "the guide page renders")
	# fill of every filled RaritySlot = Rarity.ui(id).fill; ring of uncommon = its moss ring; selected = gold
	for id in Rarity.IDS:
		var f: RaritySlot = g.find_child("Filled_%s" % id, true, false)
		var s: RaritySlot = g.find_child("Selected_%s" % id, true, false)
		var cell: Vector2 = f.get_global_rect().position + Vector2(RaritySlot.PAD, RaritySlot.PAD)
		var fill_px := img.get_pixel(int(cell.x) + 5, int(cell.y) + 5)
		var want: Color = Rarity.ui(id)["fill"]
		t.expect(t.color_delta(fill_px, want) <= 6.0, "%s tile fill pixel %s = Rarity.ui fill %s" % [id, fill_px.to_html(false), want.to_html(false)])
		if bool(Rarity.ui(id)["has_ring"]):
			var ring_px := img.get_pixel(int(cell.x) - 2, int(cell.y + RaritySlot.PAD + 20))
			t.expect(t.color_delta(ring_px, Rarity.ui(id)["ring"]) <= 8.0, "%s ring pixel %s" % [id, ring_px.to_html(false)])
		var scell: Vector2 = s.get_global_rect().position + Vector2(RaritySlot.PAD, RaritySlot.PAD)
		var gold_px := img.get_pixel(int(scell.x) - 2, int(scell.y + RaritySlot.PAD + 20))
		t.expect(t.color_delta(gold_px, RaritySlot.GOLD) <= 8.0, "%s selected: the ring pixel is the focus gold (%s), not the rarity ring" % [id, gold_px.to_html(false)])
	# the disc case: pale pixels inside radius 30 of the icon centre where the chair icon is transparent
	var disc: RaritySlot = g.find_child("DiscNoFile", true, false)
	var dcell: Vector2 = disc.get_global_rect().position + Vector2(RaritySlot.PAD, RaritySlot.PAD)
	var centre := dcell + Vector2(33, 33)
	var pale := 0
	for off in [Vector2(-24, -14), Vector2(24, -14), Vector2(-24, 14), Vector2(24, 14)]:
		var px := img.get_pixel(int(centre.x + off.x), int(centre.y + off.y))
		if t.color_delta(px, Color(0.89, 0.93, 0.95)) <= 20.0:
			pale += 1
	t.expect(pale >= 3, "the legendary tile without a night icon shows the pale disc (%d of 4 probe pixels pale)" % pale)
	var night: RaritySlot = g.find_child("NightFile", true, false)
	var ncell: Vector2 = night.get_global_rect().position + Vector2(RaritySlot.PAD, RaritySlot.PAD)
	var corner := img.get_pixel(int(ncell.x) + 6, int(ncell.y) + 6)
	t.expect(t.color_delta(corner, Color("#2f3654")) <= 6.0, "the night-file tile is the dark night tile (%s)" % corner.to_html(false))
	# an item without an icon file: the initial badge (its id colour) sits inside the tile instead of an empty tile
	for nm in ["NoIconRare", "NoIconLegendary"]:
		var ni: RaritySlot = g.find_child(nm, true, false)
		var icon_rect := Rect2(ni.get_global_rect().position + Vector2(RaritySlot.PAD, RaritySlot.PAD), Vector2.ONE * ni.slot_size).grow(-8.0)
		var rad := minf(icon_rect.size.x, icon_rect.size.y) * 0.34
		var probe := icon_rect.get_center() + Vector2(rad * 0.8, 0.0)
		var want_badge: Color = TTItemIcon.BADGES[absi(String(ni.item_id).hash()) % TTItemIcon.BADGES.size()]
		var got := img.get_pixel(int(probe.x), int(probe.y))
		t.expect(t.color_delta(got, want_badge) <= 8.0, "%s (%s) has no icon file: its badge colour %s at the probe pixel, got %s" % [nm, ni.item_id, want_badge.to_html(false), got.to_html(false)])
	host.queue_free()
	await t.frames(1)
	await _windowed_ability_slots(t)


## Two ability slots on screen: one with an ABILITY_ word (its tiny mono word is drawn inside the frame), one without (the English
## id is not drawn: the frame stays an empty, flat panel).
func _windowed_ability_slots(t) -> void:
	TranslationServer.set_locale("da")
	var fakes := _add_fake_translations({"ABILITY_TESTSTRIKE": ["slag", "strike"]})
	var host := Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.root.add_child(host)
	var row := HBoxContainer.new()
	row.position = Vector2(60, 200)
	row.add_theme_constant_override("separation", 40)
	host.add_child(row)
	var scene: PackedScene = load("res://scenes/ui/components/ability_slot.tscn")
	var named: VBoxContainer = scene.instantiate()
	named.setup(&"teststrike", &"attack", 78.0)
	var silent: VBoxContainer = scene.instantiate()
	silent.setup(&"no_such_ability_zz", &"attack", 78.0)
	row.add_child(named)
	row.add_child(silent)
	await t.frames(4)
	var img: Image = await t.capture("ability_slots")
	if img != null:
		var stats := {}
		for pair in [["named", named], ["silent", silent]]:
			var frame: Control = pair[1].frame
			var inner := Rect2i(Vector2i(frame.get_global_rect().position) + Vector2i(10, 10), Vector2i(58, 58))
			stats[pair[0]] = t.region_stats(img, inner, 1)
		t.expect(float(stats["named"]["luma_min"]) < float(stats["silent"]["luma_min"]) - 0.25 and int(stats["named"]["distinct"]) > int(stats["silent"]["distinct"]),
			"the ability slot with an ABILITY_ word draws it (darkest pixel %.2f, %d colours); without one the frame stays empty (%.2f, %d colours): the English id is not drawn" % [stats["named"]["luma_min"], stats["named"]["distinct"], stats["silent"]["luma_min"], stats["silent"]["distinct"]])
	host.queue_free()
	_drop_translations(fakes)
	await t.frames(1)
