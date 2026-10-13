extends RefCounted
## scenes/ui/character_select.tscn  (guide section 05 "Vælg figur", 2 pages: 1 = race + animal, 2 = names)
## Script: scripts/ui/character_select.gd

const RACES := [
	{"id": "Animal", "name": "Skovdyr", "perk": "Stærke poter. Graver hurtigere og får mere ud af høsten.", "a": "#e8cfa6", "b": "#dfc293", "sprite": "fox"},
	{"id": "Fairy", "name": "Fe", "perk": "Kan flyve kort over marker og taler med blomster.", "a": "#e2d8f4", "b": "#d3c6ee", "sprite": "fairy"},
	{"id": "Hobbit", "name": "Hobbit", "perk": "Bager bedre kager og får rabat i Hyggebyens butikker.", "a": "#d4e4b4", "b": "#c7dba2", "sprite": "capybara"},
]
const SPECIES := ["Ræv", "Kanin", "Pindsvin", "Egern"]

func build(K) -> void:
	var r = K.begin("Control", "CharacterSelect", "res://scripts/ui/character_select.gd")
	K.full(r)
	var bg = K.add(r, "ColorRect", "Background", {"color": Color("#e7d8b6"), "ignore": true})
	K.full(bg)
	var m = K.margin(r, "Margin", 64, 48, 64, 48)
	K.full(m)
	var col = K.vbox(m, "Column", 28)

	# header
	var head = K.hbox(col, "Header", 0)
	var hl = K.vbox(head, "HeaderText", 4, {"expand_h": true})
	K.lbl(hl, "TitleLabel", "Hvem er du?", "Display48", {}, true)
	K.lbl(hl, "SubtitleLabel", "Fekongen vil gerne vide, hvem der har vundet hans gård.", "Subtitle", {}, true)
	K.lbl(head, "PageLabel", "1 / 2", "EyebrowL", {"shrink_end_v": true}, true)

	# ---------------- page 1: race cards + animal chips
	var p1 = K.vbox(col, "PageRace", 28, {"expand_v": true}, true)
	var cards = K.hbox(p1, "Cards", 32, {"expand_v": true})
	var group = ButtonGroup.new()
	for race in RACES:
		var slot = K.add(cards, "Control", race["id"] + "Slot", {"expand_h": true, "expand_v": true, "min": Vector2(0, 220)})
		var card = K.btn(slot, race["id"] + "Button", "", "CardButton", {"toggle_mode": true, "button_group": group, "focus_mode": Control.FOCUS_ALL}, true)
		K.full(card)
		var cm = K.margin(card, "Pad", 16, 16, 16, 16, {"ignore": true})
		K.full(cm)
		var cv = K.vbox(cm, "Body", 14, {"ignore": true})
		var art = K.add(cv, "Control", "Art", {"expand_v": true, "min": Vector2(0, 120), "ignore": true})
		var st = K.stripes(art, "Stripes", Color(race["a"]), Color(race["b"]), 14, {"radii": Vector4(12, 12, 12, 12), "border": 2.0})
		K.full(st)
		var face = K.add(art, "Control", race["id"] + "Face", {"script": "res://scripts/ui/components/tt_sprite_face.gd", "character_id": race["sprite"], "direction": 7, "sprite_scale": 1.25, "feet_y": 0.93}, true)
		K.full(face)
		var tx = K.vbox(cv, "Text", 4, {"ignore": true})
		K.lbl(tx, race["id"] + "Name", race["name"], "Display32", {"ignore": true}, true)
		K.lbl(tx, race["id"] + "Perk", race["perk"], "Muted17", {"autowrap_mode": TextServer.AUTOWRAP_WORD_SMART, "ignore": true, "min": Vector2(0, 50)}, true)

	var foot = K.hbox(p1, "Footer", 10)
	K.lbl(foot, "SpeciesPrefix", "Dyr:", "Heavy18", {"shrink_center_v": true}, true)
	var sgroup = ButtonGroup.new()
	var chips = K.hbox(foot, "Species", 10, {"shrink_center_v": true}, true)
	for i in SPECIES.size():
		K.btn(chips, "Species%d" % i, SPECIES[i], "Chip", {"toggle_mode": true, "button_group": sgroup, "button_pressed": i == 0, "focus_mode": Control.FOCUS_ALL}, true)
	K.spacer(foot, "Spacer", 0, 0, true)
	K.btn(foot, "BackButton", "Tilbage", "ButtonTertiary", {}, true)
	K.btn(foot, "NextButton", "Videre ▸", "ButtonPrimaryL", {}, true)

	# ---------------- page 2: names
	var p2 = K.vbox(col, "PageNames", 18, {"expand_v": true, "visible": false}, true)
	var form = K.panel(p2, "FormPanel", "PanelParchment", {"shrink_begin_h": true, "min": Vector2(640, 0)})
	var fv = K.vbox(form, "FormBody", 10)
	K.lbl(fv, "NameCaption", "Dit navn", "Heavy18", {}, true)
	K.add(fv, "LineEdit", "NameInput", {"placeholder_text": "Eventyrrejsende", "max_length": 20, "min": Vector2(0, 44)}, true)
	K.lbl(fv, "FarmCaption", "Gårdens navn", "Heavy18", {}, true)
	K.add(fv, "LineEdit", "FarmNameInput", {"placeholder_text": "Min Trækronsgård", "max_length": 28, "min": Vector2(0, 44)}, true)
	var fb = K.hbox(p2, "FormButtons", 12)
	K.btn(fb, "BackToRaceButton", "Tilbage", "ButtonTertiary", {}, true)
	K.btn(fb, "ConfirmButton", "Start ▸", "ButtonPrimaryL", {}, true)
	K.save("res://scenes/ui/character_select.tscn")
