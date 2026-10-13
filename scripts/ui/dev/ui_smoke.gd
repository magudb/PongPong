extends Control
## FOUNDATION smoke (plan R.3 / D23). Headless, as a scene so the autoloads exist:
##   godot --headless --path . res://scenes/ui/dev/ui_smoke.tscn
## Runs: theme + fonts (Æ Ø Å æ ø å), the components gallery (both pages) and every component, the tt_* helpers, GameUI's dynamic
## loader (with the screens that exist - none are required - and with fake screens), five window shapes, and a raw-key sweep of the
## gallery in both languages. Fails on any engine error OR warning. Exit code 0 = all good; the last line is
## "UI SMOKE PASS|FAIL: N checks, F failures, E engine errors".
## The per-screen checks (title, select, hud, shop, dialogue, journal, inventory, forest, pause, saveload) are NOT here: their owners
## (P16, P17, P18, P14, P19) lift them into their own tests/sections and use scripts/ui/dev/ui_fixtures.gd.

class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _e: bool, error_type: int, _s: Array[ScriptBacktrace]) -> void:
		var kind := "warning" if error_type == Logger.ERROR_TYPE_WARNING else "error"
		errors.append("%s %s:%d in %s(): %s %s" % [kind, file, line, function, code, rationale])

const Fixtures = preload("res://scripts/ui/dev/ui_fixtures.gd")
const Fmt = preload("res://scripts/ui/theme/tt_format.gd")
const Portraits = preload("res://scripts/ui/theme/tt_portraits.gd")
const QuestText = preload("res://scripts/ui/theme/tt_quest_text.gd")
const C = preload("res://scripts/ui/theme/tt_colors.gd")
const FAKE_DIR := "user://p07_game_ui_smoke/"

var _catcher := ErrorCatcher.new()
var _fails: Array[String] = []
var _checks := 0


func _ready() -> void:
	OS.add_logger(_catcher)
	_run.call_deferred()


func _run() -> void:
	await _theme_and_fonts()
	await _components()
	await _rarity_page()
	await _tt_helpers()
	await _game_ui()
	await _raw_keys()
	await _stretch()
	for e in _catcher.errors:
		print("  ENGINE MESSAGE: ", e)
	var bad := _fails.size() + _catcher.errors.size()
	print("UI SMOKE %s: %d checks, %d failures, %d engine errors" % ["PASS" if bad == 0 else "FAIL", _checks, _fails.size(), _catcher.errors.size()])
	get_tree().quit(0 if bad == 0 else 1)


func _ok(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("  ok    ", label)
	else:
		_fails.append(label)
		print("  FAIL  ", label)


func _frames(n: int = 3) -> void:
	for i in n:
		await get_tree().process_frame


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if a[i] != b[i]:
			return false
	return true


func _clear() -> void:
	for c in get_children():
		c.queue_free()
	await _frames(1)


func _focus() -> String:
	var f := get_viewport().gui_get_focus_owner()
	return str(f.name) if f else "<none>"


func _act(action: String) -> void:
	for pressed in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = pressed
		Input.parse_input_event(ev)
	await _frames(2)


# ---------------------------------------------------------------------------------------------------- theme and fonts

func _theme_and_fonts() -> void:
	print("-- theme and fonts")
	var theme := ThemeDB.get_project_theme()
	_ok(theme != null, "the project theme (assets/ui/theme.tres) is loaded")
	if theme == null:
		return
	var types := theme.get_type_list()
	_ok(types.size() >= 145, "theme has %d types (>= the spike's 145)" % types.size())
	for need in ["ButtonPrimary", "ButtonSecondary", "ButtonTertiary", "PanelParchment", "PanelBook", "PillTab", "Chip", "RowButton", "CardButton", "SlotEmpty", "SlotFilled", "SlotUncommon", "SlotRare", "SlotUnique", "SlotLegendary", "MeterGreen", "MeterBoss", "HeroTitle", "Display20", "RarityWordNormal", "RarityWordLegendary", "Display15Night"]:
		_ok(types.has(need), "theme type %s" % need)
	var box := theme.get_stylebox("normal", "ButtonPrimary")
	_ok(box != null and box.get_script() != null and str((box.get_script() as Script).resource_path).ends_with("tt_box_style.gd"), "buttons use the scripted TTBoxStyle (vector, sharp at every stretch)")
	# the slot tiles carry the Rarity.ui() colours (single source: tools/ui/build_theme.gd reads Rarity)
	for id in Rarity.IDS:
		var vn := "Slot" + ("Filled" if id == &"normal" else String(id).capitalize())
		var ui: Dictionary = Rarity.ui(id)
		var sb := theme.get_stylebox("normal", vn)
		_ok(sb != null and sb.get("fill") == ui["fill"], "%s fill = Rarity.ui(%s).fill %s" % [vn, id, (ui["fill"] as Color).to_html(false)])
		var rc: PackedColorArray = sb.get("ring_colors")
		_ok((rc.size() == 1 and rc[0] == ui["ring"]) if bool(ui["has_ring"]) else rc.is_empty(), "%s ring = %s" % [vn, "the rarity ring" if bool(ui["has_ring"]) else "none (ink border only)"])
		var pr: PackedColorArray = theme.get_stylebox("pressed", vn).get("ring_colors")
		_ok(pr.size() == 2 and pr[0].is_equal_approx(C.GOLD), "%s pressed = the gold selection ring REPLACES the rarity ring" % vn)
	# umlauts: Caprasimo and Alegreya both carry Æ Ø Å æ ø å
	var caprasimo: Font = load("res://assets/fonts/Caprasimo-Regular.ttf")
	var alegreya: Font = load("res://assets/fonts/AlegreyaSans-Medium.ttf")
	var missing_cap: Array[String] = []
	var missing_ale: Array[String] = []
	for ch in "ÆØÅæøå":
		if not caprasimo.has_char(ch.unicode_at(0)):
			missing_cap.append(ch)
		if not alegreya.has_char(ch.unicode_at(0)):
			missing_ale.append(ch)
	_ok(missing_cap.is_empty(), "Caprasimo has Æ Ø Å æ ø å (missing %s)" % str(missing_cap))
	_ok(missing_ale.is_empty(), "Alegreya Sans has Æ Ø Å æ ø å (missing %s)" % str(missing_ale))
	var sym: Font = load("res://assets/fonts/TTSymbols-Regular.ttf")
	var missing_sym: Array[String] = []
	for ch in "▸◂♥★✓✗":
		if not sym.has_char(ch.unicode_at(0)):
			missing_sym.append(ch)
	_ok(missing_sym.is_empty(), "TTSymbols has ▸ ◂ ♥ ★ ✓ ✗ (missing %s)" % str(missing_sym))
	# the fallback must not stretch a line (spike pitfall: Noto Symbols 2 has 1.7 em metrics)
	var disp: Font = theme.get_font("font", "ButtonPrimary")
	var ratio := disp.get_height(22) / caprasimo.get_height(22)
	_ok(ratio < 1.3, "Caprasimo + fallbacks line height is %.2f x Caprasimo's own (symbol fallback metrics are corrected)" % ratio)
	# every character the UI texts use is covered by the font chains (da + en of ui.csv)
	var uncovered := _uncovered_chars(theme)
	_ok(uncovered.is_empty(), "every character of ui.csv is drawable in the theme fonts (uncovered: %s)" % str(uncovered))


func _uncovered_chars(theme: Theme) -> Array[String]:
	var f := FileAccess.open("res://localization/ui.csv", FileAccess.READ)
	var bad: Array[String] = []
	if f == null:
		return ["<ui.csv unreadable>"]
	var body: Font = theme.default_font
	var disp: Font = theme.get_font("font", "ButtonPrimary")
	f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 3 or row[0].begins_with(";"):
			continue
		for col in [1, 2]:
			for i in row[col].length():
				var c := row[col].unicode_at(i)
				var ch := row[col][i]
				if c < 32 or bad.has(ch):
					continue
				if not (body.has_char(c) or disp.has_char(c)):
					bad.append(ch)
	return bad


# ---------------------------------------------------------------------------------------------------- components

func _components() -> void:
	print("-- components gallery (guide page) and components")
	await _clear()
	var g: Control = (load("res://scenes/ui/dev/components_gallery.tscn") as PackedScene).instantiate()
	add_child(g)
	await _frames(3)
	_ok(g.page == &"guide" and g.get_node("%Margin").visible and not g.get_node("%RarityMargin").visible, "the gallery opens on the guide page")
	_ok(g.slot_empty.theme_type_variation == &"SlotEmpty" and g.slot_filled.theme_type_variation == &"SlotFilled" and g.slot_rare.theme_type_variation == &"SlotRare", "slot states: empty / filled / rare theme variations")
	_ok(g.slot_selected.button_pressed and g.slot_selected.count_label.text == "12", "selected slot is pressed (gold ring) and shows its count")
	_ok(g.get_node("%StatesRow").get_child_count() == 3, "button state sheet: normal / hover / pressed")
	var tabs := g.find_children("Tab*", "Button", true, false)
	_ok(tabs.size() == 3 and (tabs[0] as Button).button_pressed, "three pill tabs, the first is active")
	_ok(_focus() == "FocusedButton", "initial focus = FocusedButton (got %s)" % _focus())
	var ring: PackedColorArray = g.focused_button.get_theme_stylebox("focus").ring_colors
	_ok(ring.size() == 2 and ring[0].is_equal_approx(C.GOLD), "keyboard focus style = gold ring (%d rings)" % ring.size())
	var hearts = g.get_node("%Hearts")
	_ok(hearts.half_hearts == 7 and hearts.max_hearts == 5, "hearts: 7 half hearts of 5 (three full + one half)")
	# stepper
	var step = g.get_node("%Stepper")
	var seen: Array[int] = []
	step.value_changed.connect(func(v): seen.append(v))
	step.set_range(1, 5)
	step.value = 9
	_ok(step.value == 5 and step.plus_button.disabled and not step.minus_button.disabled, "stepper clamps to its range (9 -> 5), plus disabled at the top")
	step.value = 0
	_ok(step.value == 1 and step.minus_button.disabled, "stepper clamps at the bottom (0 -> 1)")
	_ok(str(seen) == "[5, 1]", "value_changed fires once per real change (%s)" % str(seen))
	_ok(g.total_label.text.ends_with("300"), "total label is formatted from SHOP_TOTAL (%s)" % g.total_label.text)
	# item slot: rarity -> variation, pips, count colour
	var slot_scene: PackedScene = load("res://scenes/ui/components/item_slot.tscn")
	var expect_variation := {&"normal": &"SlotFilled", &"uncommon": &"SlotUncommon", &"rare": &"SlotRare", &"unique": &"SlotUnique", &"legendary": &"SlotLegendary"}
	for id in Rarity.IDS:
		var s: Button = slot_scene.instantiate()
		add_child(s)
		await _frames(1)
		s.setup(&"chair_pine", 3, "", false, "", id)
		_ok(s.current_variation() == expect_variation[id] and s.pips.pip_count() == Rarity.pips(id), "item_slot rarity %s -> %s, %d pip(s)" % [id, s.current_variation(), s.pips.pip_count()])
		_ok(s.count_label.theme_type_variation == (&"Display15Night" if id == &"legendary" else &"Display15"), "item_slot %s count label %s" % [id, s.count_label.theme_type_variation])
		s.queue_free()
	var es: Button = slot_scene.instantiate()
	add_child(es)
	await _frames(1)
	es.setup(&"", 0)
	_ok(es.current_variation() == &"SlotEmpty", "an empty slot is SlotEmpty whatever the rarity")
	es.setup(&"moonstone", 1, "", true)
	_ok(es.rarity == &"rare" and es.current_variation() == &"SlotRare", "the old `rare` flag still means rarity rare")
	es.queue_free()
	# toast with the item picture (legendary night icon)
	var toast: PanelContainer = (load("res://scenes/ui/components/notification_toast.tscn") as PackedScene).instantiate()
	add_child(toast)
	await _frames(1)
	toast.setup("T", "M", 0.05, &"bed_moon", &"legendary")
	await _frames(2)
	_ok(toast.icon_frame.visible and toast.item_icon.item_id == &"bed_moon", "toast shows the item picture of a find")
	_ok(not toast.item_icon.uses_night_disc() and TTItemIcon.resolve("bed_moon", &"legendary")["night"], "legendary toast icon = the bed_moon_night.webp rim variant (file exists, no disc)")
	toast.setup("T", "", 0.05)
	_ok(not toast.icon_frame.visible and not toast.message_label.visible, "a text-only toast hides picture and empty message")
	toast.queue_free()
	# ability slot
	var ab: VBoxContainer = (load("res://scenes/ui/components/ability_slot.tscn") as PackedScene).instantiate()
	add_child(ab)
	await _frames(1)
	ab.setup(&"slash", &"attack", 78.0)
	_ok(ab.key_label.text == tr("KEY_MOUSE_LEFT"), "ability key cap reads the InputMap: %s" % ab.key_label.text)
	ab.set_cooldown(0.5, "2")
	_ok(is_equal_approx(ab.veil.offset_top, -(78.0 - 4.0) * 0.5) and ab.cd_label.text == "2", "cooldown veil rises by the fraction")
	ab.queue_free()
	# sprite face + dashed line + stripes
	var face := Control.new()
	face.set_script(preload("res://scripts/ui/components/tt_sprite_face.gd"))
	add_child(face)
	await _frames(2)
	_ok(face.character_id == "fox" and face.sprite_scale == 1.0, "tt_sprite_face defaults (fox, scale 1)")
	face.queue_free()
	await _clear()


# ---------------------------------------------------------------------------------------------------- the rarity page

func _rarity_page() -> void:
	print("-- rarity row of the components gallery")
	await _clear()
	var g: Control = (load("res://scenes/ui/dev/components_gallery.tscn") as PackedScene).instantiate()
	add_child(g)
	await _frames(2)
	g.show_page(&"rarity")
	await _frames(2)
	_ok(g.get_node("%RarityMargin").visible and not g.get_node("%Margin").visible, "page rarity visible, guide page hidden")
	var slots := g.find_children("*", "RaritySlot", true, false)
	_ok(slots.size() == 21, "21 RaritySlots on the page (5 filled + 5 selected + 5 unknown + 4 legendary icon cases + 2 without an icon): %d" % slots.size())
	for id in Rarity.IDS:
		var f: RaritySlot = g.find_child("Filled_%s" % id, true, false)
		var s: RaritySlot = g.find_child("Selected_%s" % id, true, false)
		var u: RaritySlot = g.find_child("Unknown_%s" % id, true, false)
		_ok(f != null and s != null and u != null, "row %s has filled / selected / unknown tiles" % id)
		if f == null or s == null or u == null:
			continue
		var pf := f.current_plan()
		_ok(int((pf["pips"] as Dictionary)["count"]) == Rarity.pips(id) and str(pf["state"]) == "filled", "%s: %d pip(s)" % [id, Rarity.pips(id)])
		_ok(bool(s.current_plan()["gold_ring"]) and not bool(s.current_plan()["rarity_ring_shown"]), "%s selected: gold ring, rarity ring replaced" % id)
		_ok(str(u.current_plan()["state"]) == "unknown", "%s unknown tile is the dashed silhouette" % id)
	var pips: Array[Node] = []
	for w in g.find_children("Word_*", "VBoxContainer", true, false):
		pips.append_array(w.find_children("Pips", "RarityPips", false, false))
	_ok(pips.size() == 5, "five pip rows next to the rarity words (one per rarity)")
	var counts: Array[int] = []
	for pp in pips:
		counts.append(pp.pip_count())
	_ok(str(counts) == "[0, 1, 2, 3, 4]", "pip counts along the ladder %s (rank - 1)" % str(counts))
	var ladder := g.find_children("Ladder*", "LadderRow", true, false)
	_ok(ladder.size() == 4, "ladder: four rows (done, current, next, locked)")
	var states: Array[StringName] = []
	for lr in ladder:
		states.append(lr.state)
		_ok(lr.title != "" and lr.title != lr.get_meta("title_key"), "ladder row %s shows its translated title '%s'" % [lr.name, lr.title])
	_ok(_same(states, [&"done", &"current", &"next", &"locked"]), "ladder states %s" % str(states))
	var themed := g.find_children("ThemedSlot_*", "Button", true, false)
	_ok(themed.size() == 5, "five themed item slots")
	var vars: Array[StringName] = []
	for t in themed:
		vars.append(t.current_variation())
	_ok(_same(vars, [&"SlotFilled", &"SlotUncommon", &"SlotRare", &"SlotUnique", &"SlotLegendary"]), "themed slots follow the rarity ladder: %s" % str(vars))
	var night: RaritySlot = g.find_child("NightFile", true, false)
	var disc: RaritySlot = g.find_child("DiscNoFile", true, false)
	_ok(night != null and not bool(night.current_plan()["disc"]), "legendary clock_moon: the _night.webp variant, no disc")
	_ok(disc != null and bool(disc.current_plan()["disc"]), "legendary chair_pine has no _night.webp: pale disc behind the icon")
	var no_rare: RaritySlot = g.find_child("NoIconRare", true, false)
	var no_leg: RaritySlot = g.find_child("NoIconLegendary", true, false)
	_ok(no_rare != null and no_leg != null and bool(no_rare.current_plan()["badge"]) and bool(no_leg.current_plan()["badge"]) and not bool(no_leg.current_plan()["disc"]),
		"an item without an icon file: the initial badge of TTItemIcon, never an empty tile and never a disc")
	_ok(night != null and disc != null and not bool(night.current_plan()["badge"]) and not bool(disc.current_plan()["badge"]), "tiles with a picture draw no badge")
	await _clear()


# ---------------------------------------------------------------------------------------------------- tt_* helpers

func _tt_helpers() -> void:
	print("-- tt_* helpers")
	TranslationServer.set_locale("da")
	_ok(Fmt.thousands(1250) == "1.250" and Fmt.thousands(-45000) == "-45.000" and Fmt.thousands(7) == "7", "thousands(da): 1250 -> %s" % Fmt.thousands(1250))
	TranslationServer.set_locale("en")
	_ok(Fmt.thousands(1250) == "1,250", "thousands(en): 1250 -> %s" % Fmt.thousands(1250))
	TranslationServer.set_locale("da")
	_ok(Fmt.clock(7, 5) == "07:05" and Fmt.clock(10, 40) == "10:40", "clock(10, 40) = 10:40")
	# ONE calendar: TTFormat.date_text is TimeManager.date_text
	var tm := Svc.node("TimeManager")
	_ok(tm != null, "TimeManager autoload present")
	var da_text := Fmt.date_text(16, &"foraar")
	_ok(da_text == "Tirsdag 16. Blomstermåned", "date_text(16, foraar) in da = '%s'" % da_text)
	_ok(da_text == tm.date_text(16, &"foraar"), "TTFormat.date_text == TimeManager.date_text (one implementation)")
	TranslationServer.set_locale("en")
	_ok(Fmt.date_text(16, &"foraar") == "Tuesday 16. Month of Blooms", "date_text in en = '%s'" % Fmt.date_text(16, &"foraar"))
	_ok(Fmt.date_text(28, &"vinter") == "Sunday 28. Month of Frost", "date_text(28, vinter) = '%s'" % Fmt.date_text(28, &"vinter"))
	TranslationServer.set_locale("da")
	for w in ["KLART", "REGN", "TAAGE", "SNE", "TORDEN"]:
		_ok(tr("UI_WEATHER_" + w) != "UI_WEATHER_" + w, "weather label UI_WEATHER_%s = %s" % [w, tr("UI_WEATHER_" + w)])
	# portraits: npcs.lua -> characters.lua chain -> portraits/ then isometric_characters/<id>/portrait.webp
	var p := Portraits.resolve_path(&"mayor_lyra")
	_ok(p != "" and ResourceLoader.exists(p), "mayor_lyra portrait resolves (%s)" % p)
	_ok(Portraits.portrait(&"mayor_lyra") != null, "mayor_lyra portrait loads as a texture")
	_ok(Portraits.resolve_path(&"nobody_here") != "", "an unknown npc id still resolves (default visual)")
	var fake := {"res://assets/portraits/fairy_mayor.webp": true}
	var picked := Portraits.resolve_path(&"mayor_lyra", func(path: String) -> bool: return fake.has(path) or ResourceLoader.exists(path))
	_ok(picked == "res://assets/portraits/fairy_mayor.webp", "when the bust of fairy_mayor lands it wins over the chain stand-in (%s)" % picked)
	var both := {"res://assets/portraits/fox.webp": true, "res://assets/isometric_characters/fox/portrait.webp": true}
	_ok(Portraits.resolve_visual_path(["fox"], func(path: String) -> bool: return both.has(path)) == "res://assets/portraits/fox.webp", "assets/portraits/<id>.webp is tried before isometric_characters/<id>/portrait.webp")
	var cands := Portraits.visual_candidates(&"mayor_lyra")
	_ok(cands.size() >= 2 and cands[0] == "fairy_mayor" and "fairy" in cands, "candidate chain of mayor_lyra: %s" % str(cands))
	# quest text through injected definitions (QuestManager is P13's)
	var defs := {
		&"lost_cat": {"id": &"lost_cat", "title_key": "QUEST_LOST_CAT_TITLE", "meta": {"giver": "pippin_boegeknop", "tag": "FIND", "location": "Hyggebyen"},
			"objectives": [{"id": "ask", "target": 3, "description": "plain text"}, {"id": "find", "target": 1}],
			"rewards": {"gold": 150, "items": {"catnip_seeds": 3}, "friendship": {"pippin_boegeknop": 2}}, "source_path": "res://lua/quests/lost_cat.lua"},
		&"hoest": {"meta": {"tag": "HØST"}}, &"laer": {"meta": {"tag": "LÆR"}}, &"old": {"meta": {"category": "adventure"}}, &"none": {},
	}
	QuestText.set_providers(func(id): return defs.get(id, {}),
		func(id): return {"objectives": {&"ask": {"current": 2, "done": false}}} if id == &"lost_cat" else {},
		func(_id): return false)
	_ok(QuestText.giver_name(&"lost_cat") == tr("NPC_PIPPIN_BOEGEKNOP") and QuestText.giver_name(&"lost_cat") != "NPC_PIPPIN_BOEGEKNOP", "giver name from NPC_<ID>: %s" % QuestText.giver_name(&"lost_cat"))
	_ok(QuestText.from_line(&"lost_cat").begins_with("Fra Pippin") and QuestText.from_line(&"lost_cat").ends_with("Hyggebyen"), "from line '%s'" % QuestText.from_line(&"lost_cat"))
	_ok(QuestText.tag_text(&"lost_cat") == "FIND" and QuestText.tag_color(&"lost_cat") == Color("#e2d8f4"), "meta.tag FIND: chip FIND, lavender")
	_ok(QuestText.tag_text(&"hoest") == "HØST" and QuestText.tag_color(&"hoest") == Color("#cde0a6"), "meta.tag HØST (ASCII id HOEST): chip HØST, light moss")
	_ok(QuestText.tag_text(&"laer") == "LÆR", "meta.tag LÆR -> chip LÆR")
	_ok(QuestText.tag_color(&"old") == Color("#b9c3e3") and QuestText.tag_text(&"old") == "SKOV", "the older meta.category 'adventure' still maps to SKOV blue-grey")
	_ok(QuestText.tag_text(&"none") == "HJÆLP", "no tag -> the default chip (HJÆLP)")
	var steps := QuestText.steps(&"lost_cat")
	_ok(steps.size() == 2 and steps[0]["current"] == 2 and steps[0]["target"] == 3 and not steps[0]["done"], "steps carry live progress 2/3")
	_ok(steps[0]["text"] == "plain text" and steps[1]["text"] == "Find", "step text falls back description -> capitalised id")
	var chips := QuestText.rewards(&"lost_cat")
	_ok(chips.size() == 3 and chips[0]["text"] == "150 guldagern" and chips[1]["text"].ends_with("× 3") and chips[2]["text"].begins_with("♥ "), "reward chips gold / item / heart: %s" % str(chips.map(func(c): return c["text"])))
	_ok(QuestText.source_path(&"lost_cat") == "quests/lost_cat.lua" and QuestText.source_path(&"none") == "quests/none.lua", "source path caption")
	QuestText.clear_providers()
	# the one palette
	_ok(C.INK == Color("#2b2340") and C.PARCHMENT == Color("#f4e6c4") and C.GOLD == Color("#e3c372") and C.THORNBERRY == Color("#b3436b") and C.NIGHT_TRACK == Color("#2f3654"), "tt_colors carry the guide's numbers")


# ---------------------------------------------------------------------------------------------------- GameUI

func _write_fake_scene(id: String, root: Node) -> void:
	var ps := PackedScene.new()
	ps.pack(root)
	ResourceSaver.save(ps, "%s%s.tscn" % [FAKE_DIR, id])
	root.free()


func _fake_screen(nm: String, with_button: bool) -> Control:
	var c := Control.new()
	c.name = nm
	if with_button:
		var b := Button.new()
		b.name = "SlotButton"
		b.focus_mode = Control.FOCUS_ALL
		c.add_child(b)
		b.owner = c
	return c


func _game_ui() -> void:
	print("-- GameUI (dynamic loader)")
	await _clear()
	var order := GameUI.SCREEN_ORDER
	_ok(order.size() == 16 and order[0] == &"hud" and order[1] == &"forest_hud" and order[-1] == &"settings_ui" and order[-3] == &"pause_menu", "the ordered list: 16 screens, hud first, settings_ui last (%s)" % str(order))
	for added in ["husbyggeri", "indretning", "home_chest", "garderobe", "samlerbog"]:
		_ok(order.has(StringName(added)) and order.find(StringName(added)) < order.find(&"pause_menu"), "the home screen %s is in the list, below the pause menu" % added)
	var existing: Array[StringName] = []
	for id in order:
		if ResourceLoader.exists(GameUI.scene_path(id)):
			existing.append(id)
	var ui: GameUI = (load("res://scenes/ui/game_ui.tscn") as PackedScene).instantiate()
	add_child(ui)
	await _frames(2)
	_ok(ui is CanvasLayer and ui.layer == 10, "GameUI is a CanvasLayer on layer 10")
	_ok(ui.process_mode == Node.PROCESS_MODE_ALWAYS, "GameUI process_mode is ALWAYS")
	_ok(ui.is_in_group(&"game_ui"), "GameUI is in group game_ui")
	_ok(_same(ui.loaded_screens(), existing), "GameUI instanced exactly the screens whose scene exists (%d: %s), none are required" % [existing.size(), str(existing)])
	if existing.is_empty():
		_ok(ui.get_child_count() == 0 and ui.get_screen(&"hud") == null, "with zero screens: no children, get_screen(&\"hud\") = null")
	ui.set_mode(&"action")
	_ok(ui.mode == &"action", "set_mode(action) works with no HUD present")
	ui.set_mode(&"farm")
	_ok(ui.mode == &"farm", "set_mode(farm)")
	ui.queue_free()
	await _frames(1)
	# fake screens: order, naming, process mode, HUD focus, set_mode, late arrival
	DirAccess.make_dir_recursive_absolute(FAKE_DIR)
	_write_fake_scene("pause_menu", _fake_screen("X", false))
	_write_fake_scene("hud", _fake_screen("X", true))
	_write_fake_scene("inventory_ui", _fake_screen("X", false))
	_write_fake_scene("forest_hud", _fake_screen("X", true))
	var gu: GameUI = (load("res://scenes/ui/game_ui.tscn") as PackedScene).instantiate()
	gu.load_screens(FAKE_DIR, [&"hud", &"forest_hud", &"dialogue_ui", &"inventory_ui", &"pause_menu", &"settings_ui"])   # before _ready: the loader is directory-injectable
	add_child(gu)
	await _frames(2)
	_ok(_same(gu.loaded_screens(), [&"hud", &"forest_hud", &"inventory_ui", &"pause_menu"]), "fake dir: only the existing scenes load, in list order %s" % str(gu.loaded_screens()))
	var names: Array[String] = []
	for c in gu.get_children():
		names.append(c.name)
	_ok(_same(names, ["Hud", "ForestHud", "InventoryUi", "PauseMenu"]), "draw order = list order, nodes named in PascalCase %s" % str(names))
	_ok(gu.get_screen(&"inventory_ui") == gu.get_child(2) and gu.get_screen(&"InventoryUi") == gu.get_child(2) and gu.get_screen(&"settings_ui") == null, "get_screen by id or node name; null for a missing screen")
	var all_always := true
	for c in gu.get_children():
		all_always = all_always and c.process_mode == Node.PROCESS_MODE_ALWAYS
	_ok(all_always, "every screen is PROCESS_MODE_ALWAYS")
	var hud_btn: Button = gu.get_screen(&"hud").get_node("SlotButton")
	var inv_ok := gu.get_screen(&"inventory_ui")
	_ok(hud_btn.focus_mode == Control.FOCUS_NONE and (gu.get_screen(&"hud") as Control).focus_mode == Control.FOCUS_NONE, "HUD controls use focus_mode NONE (rule for P17)")
	var late := Button.new()
	late.focus_mode = Control.FOCUS_ALL
	gu.get_screen(&"forest_hud").add_child(late)
	_ok(late.focus_mode == Control.FOCUS_NONE, "a control the HUD adds later is forced to focus NONE as well")
	var other := Button.new()
	other.focus_mode = Control.FOCUS_ALL
	inv_ok.add_child(other)
	_ok(other.focus_mode == Control.FOCUS_ALL, "modal screens keep their focus (only the HUD screens are forced)")
	var got_modes: Array[StringName] = []
	gu.mode_changed.connect(func(m): got_modes.append(m))
	gu.set_mode(&"action")
	_ok(not (gu.get_screen(&"hud") as Control).visible and (gu.get_screen(&"forest_hud") as Control).visible, "set_mode(action): forest HUD shown, farm HUD hidden")
	gu.set_mode(&"farm")
	_ok((gu.get_screen(&"hud") as Control).visible and not (gu.get_screen(&"forest_hud") as Control).visible, "set_mode(farm): farm HUD shown, forest HUD hidden")
	_ok(_same(got_modes, [&"action", &"farm"]), "mode_changed fires per real change %s" % str(got_modes))
	# a screen that lands later joins at its place
	_write_fake_scene("dialogue_ui", _fake_screen("X", false))
	var late_ids := gu.load_screens()
	_ok(_same(late_ids, [&"dialogue_ui"]) and _same(gu.loaded_screens(), [&"hud", &"forest_hud", &"dialogue_ui", &"inventory_ui", &"pause_menu"]), "a scene that appears later is picked up and inserted in order %s" % str(gu.loaded_screens()))
	_ok(gu.get_child(2).name == "DialogueUi", "its node sits at index 2 (between forest_hud and inventory_ui)")
	# no key handling at all
	var methods: Array[String] = []
	for m in (gu.get_script() as Script).get_script_method_list():
		methods.append(str(m["name"]))
	var key_handlers := ["_input", "_unhandled_input", "_unhandled_key_input", "_shortcut_input", "_gui_input"].filter(func(n): return methods.has(n))
	_ok(key_handlers.is_empty(), "GameUI has no key handling (every modal owns its key): %s" % str(key_handlers))
	gu.queue_free()
	await _frames(1)
	var d := DirAccess.open(FAKE_DIR)
	if d != null:
		for f in d.get_files():
			d.remove(f)
	DirAccess.remove_absolute(FAKE_DIR)
	var wrong_mode_errors := _catcher.errors.size()
	_ok(wrong_mode_errors == 0, "no engine message while loading screens")


# ---------------------------------------------------------------------------------------------------- raw keys

## No label/button anywhere may DISPLAY a raw translation key (ALL_CAPS_WITH_UNDERSCORES) in either language.
func _raw_keys() -> void:
	print("-- raw translation keys")
	var re := RegEx.new()
	re.compile("^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$")
	for lang in ["da", "en"]:
		TranslationServer.set_locale(lang)
		for page in [&"guide", &"rarity"]:
			await _clear()
			var g: Control = (load("res://scenes/ui/dev/components_gallery.tscn") as PackedScene).instantiate()
			add_child(g)
			await _frames(2)
			g.show_page(page)
			await _frames(2)
			var bad: Array[String] = []
			var seen := [0]
			_scan(g, re, bad, seen)
			_ok(seen[0] > 20 and bad.is_empty(), "no raw keys in gallery/%s/%s (%d texts looked at) %s" % [page, lang, seen[0], str(bad)])
			if page == &"rarity":
				var n_rows := g.find_children("Ladder*", "LadderRow", true, false)
				_ok(not n_rows.is_empty() and not (n_rows[0] as LadderRow).title.contains("GALLERY_"), "ladder strings are translated in %s ('%s')" % [lang, (n_rows[0] as LadderRow).title])
	TranslationServer.set_locale("da")
	await _clear()


func _scan(n: Node, re: RegEx, bad: Array[String], seen: Array) -> void:
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	var text := ""
	if n is Label:
		text = (n as Label).text
	elif n is Button:
		text = (n as Button).text
	elif n is RichTextLabel:
		text = (n as RichTextLabel).text
	if text != "":
		var shown: String = n.atr(text).strip_edges()          # what the node DISPLAYS
		seen[0] += 1
		if re.search(shown):
			bad.append("%s='%s'" % [n.name, shown])
	for c in n.get_children():
		_scan(c, re, bad, seen)


# ---------------------------------------------------------------------------------------------------- stretch

## Window shapes: base 1280x720, stretch canvas_items + expand => scale = min(w/1280, h/720), the visible rect grows on the long
## axis, and corner-anchored pieces must stay at their inset from the (new) corners (a stand-in for the HUD: top-right card 40 px
## from the edge, bottom-centre tray 30 px above the bottom). The real HUD repeats this check in P17's section.
func _stretch() -> void:
	print("-- stretch / aspect (canvas_items + expand, base 1280x720)")
	await _clear()
	var win := get_window()
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var card := PanelContainer.new()
	card.theme_type_variation = &"PanelCard"
	card.custom_minimum_size = Vector2(300, 168)
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.offset_left = -340.0
	card.offset_right = -40.0
	card.offset_top = 40.0
	card.offset_bottom = 208.0
	holder.add_child(card)
	var tray := PanelContainer.new()
	tray.theme_type_variation = &"PanelHotbar"
	tray.custom_minimum_size = Vector2(660, 80)
	tray.anchor_left = 0.5
	tray.anchor_right = 0.5
	tray.anchor_top = 1.0
	tray.anchor_bottom = 1.0
	tray.offset_left = -330.0
	tray.offset_right = 330.0
	tray.offset_top = -110.0
	tray.offset_bottom = -30.0
	holder.add_child(tray)
	for size in [Vector2i(1920, 1080), Vector2i(2560, 1080), Vector2i(1600, 1200), Vector2i(1280, 720), Vector2i(3440, 1440)]:
		win.size = size
		await _frames(4)
		var vis := get_viewport().get_visible_rect().size
		var sc := minf(size.x / 1280.0, size.y / 720.0)
		var want := Vector2(size) / sc
		var ok_size := vis.is_equal_approx(want) or (absf(vis.x - want.x) < 1.0 and absf(vis.y - want.y) < 1.0)
		var right_gap := vis.x - card.get_global_rect().end.x
		var tray_center := tray.get_global_rect().get_center().x
		var bottom_gap := vis.y - tray.get_global_rect().end.y
		_ok(ok_size, "%dx%d: visible rect %s (expected %s)" % [size.x, size.y, vis, want])
		_ok(absf(right_gap - 40.0) < 1.5, "%dx%d: top-right card is 40 px from the right edge (gap %.1f)" % [size.x, size.y, right_gap])
		_ok(absf(tray_center - vis.x * 0.5) < 1.5, "%dx%d: bottom tray stays centred (%.1f vs %.1f)" % [size.x, size.y, tray_center, vis.x * 0.5])
		_ok(absf(bottom_gap - 30.0) < 2.0, "%dx%d: tray 30 px above the bottom (gap %.1f)" % [size.x, size.y, bottom_gap])
	win.size = Vector2i(1280, 720)
	await _clear()
