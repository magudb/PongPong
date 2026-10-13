extends RefCounted
## scenes/ui/dev/components_gallery.tscn : every building block of guide section 03 on one page (page "guide", identical layout
## to the spike's FINAL2/components.png) plus a second page "rarity" with the rarity row of the feature addendum (RaritySlot x5
## states, selected, unknown, themed item slots, pips, words, the ladder rows). Every text in the scene is a translation KEY
## (GALLERY_* in localization/ui.csv): the raw-key sweep of the smoke test is real, and the page follows the language.

const SLOT := "res://scenes/ui/components/item_slot.tscn"
const STEPPER := "res://scenes/ui/components/quantity_stepper.tscn"
const RSLOT := "res://scripts/ui/components/rarity_slot.gd"
const RPIPS := "res://scripts/ui/components/rarity_pips.gd"
const LADDER := "res://scripts/ui/components/ladder_row.gd"

## the five rarities with a real icon each (assets/icons/home): normal .. legendary
const SAMPLES := [
	["normal", "chair_pine"], ["uncommon", "bed_birch_single"], ["rare", "chair_lavender"], ["unique", "bed_toadstool"], ["legendary", "bed_moon"],
]


func build(K) -> void:
	var r = K.begin("Control", "ComponentsGallery", "res://scripts/ui/dev/components_gallery.gd")
	K.full(r)
	var bg = K.add(r, "ColorRect", "Page", {"color": Color("#f0ece4"), "ignore": true})
	K.full(bg)
	_guide_page(K, r)
	_rarity_page(K, r)
	K.save("res://scenes/ui/dev/components_gallery.tscn")


func _guide_page(K, r) -> void:
	var m = K.margin(r, "Margin", 36, 20, 36, 20, {}, true)
	K.full(m)
	var cols = K.hbox(m, "Columns", 40)

	# ---------------- left column
	var L = K.vbox(cols, "Left", 14, {"min": Vector2(520, 0)})
	K.lbl(L, "H_Buttons", "GALLERY_H_BUTTONS", "EyebrowL")
	var flow = K.add(L, "HFlowContainer", "ButtonRow", {"hsep": 16, "vsep": 16})
	K.btn(flow, "BuyButton", "UI_BUY", "ButtonPrimary", {}, true)
	K.btn(flow, "AcceptButton", "UI_ACCEPT", "ButtonSecondary")
	K.btn(flow, "BackButton", "MENU_BACK", "ButtonTertiary")
	K.btn(flow, "SoldOutButton", "GALLERY_SOLD_OUT", "ButtonTertiary", {"disabled": true})
	K.lbl(L, "H_Slots", "GALLERY_H_SLOTS", "EyebrowL")
	var srow = K.hbox(L, "SlotRow", 14)
	for nm in ["Tom", "Fyldt", "Valgt", "Sjælden"]:
		var col = K.vbox(srow, "Col" + nm, 6, {"shrink_begin_h": true})
		K.inst(col, SLOT, "Slot" + nm, {"min": Vector2(72, 72)}, true)
		var cap: String = {"Tom": "GALLERY_SLOT_EMPTY", "Fyldt": "GALLERY_SLOT_FILLED", "Valgt": "GALLERY_SLOT_SELECTED", "Sjælden": "GALLERY_SLOT_RARE"}[nm]
		K.lbl(col, "Caption", cap, "Heavy14", {"horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER})
	K.lbl(L, "H_Meters", "GALLERY_H_METERS", "EyebrowL")
	var mt = K.vbox(L, "Meters", 12, {"min": Vector2(420, 0), "shrink_begin_h": true})
	var specs = [["Energi", "HUD_ENERGY", "MeterGreen", 72.0], ["Hjerter", "GALLERY_METER_HEARTS", "MeterRose", 60.0], ["Lygteolie", "FOREST_OIL", "MeterHoney", 45.0]]
	for sp in specs:
		var row = K.hbox(mt, "Row" + sp[0], 12)
		K.lbl(row, "Name", sp[1], "Heavy17", {"min": Vector2(110, 0)})
		K.add(row, "ProgressBar", "Meter" + sp[0], {"variation": sp[2], "min": Vector2(0, 20), "expand_h": true,
			"show_percentage": false, "value": sp[3], "shrink_center_v": true})

	K.lbl(L, "H_States", "GALLERY_H_STATES", "EyebrowL")
	K.hbox(L, "StatesRow", 18, {"min": Vector2(0, 76)}, true)

	# ---------------- right column
	var R = K.vbox(cols, "Right", 14, {"expand_h": true})
	K.lbl(R, "H_Tabs", "GALLERY_H_TABS", "EyebrowL")
	var tr_ = K.hbox(R, "TabRow", 6)
	var names = ["SHOP_TAB_SEEDS", "SHOP_TAB_TOOLS", "UI_SELL"]
	for i in names.size():
		K.btn(tr_, "Tab" + str(i), names[i], "PillTab", {"toggle_mode": true, "button_pressed": i == 0})
	K.lbl(R, "H_Chips", "GALLERY_H_CHIPS", "EyebrowL")
	var cr = K.hbox(R, "ChipRow", 10)
	K.lbl(cr, "Prefix", "CHAR_SPECIES_PREFIX", "Heavy18", {"shrink_center_v": true})
	var cn = ["SPECIES_FOX", "SPECIES_RABBIT", "SPECIES_HEDGEHOG", "SPECIES_SQUIRREL"]
	for i in cn.size():
		K.btn(cr, "Chip" + str(i), cn[i], "Chip", {"toggle_mode": true, "button_pressed": i == 0})
	K.lbl(R, "H_Stepper", "GALLERY_H_STEPPER", "EyebrowL")
	var sr = K.hbox(R, "StepperRow", 14)
	K.inst(sr, STEPPER, "Stepper", {"shrink_center_v": true}, true)
	K.lbl(sr, "TotalLabel", "SHOP_TOTAL", "Bold17Muted", {"shrink_center_v": true}, true)
	K.btn(sr, "BuyButton2", "UI_BUY", "ButtonPrimary", {"shrink_center_v": true})
	K.lbl(R, "H_Hearts", "GALLERY_H_HEARTS", "EyebrowL")
	var hr = K.hbox(R, "HeartRow", 24)
	var hp = K.panel(hr, "HeartsPanel", "PanelHearts", {"shrink_begin_h": true, "shrink_begin_v": true})
	K.add(hp, "Control", "Hearts", {"script": "res://scripts/ui/components/tt_hearts.gd", "max_hearts": 5, "half_hearts": 7}, true)
	var tp = K.panel(hr, "Tooltip", "PanelTooltip", {"shrink_begin_h": true, "shrink_begin_v": true})
	var tv = K.vbox(tp, "V", 2)
	K.lbl(tv, "Title", "GALLERY_TIP_TITLE", "Heavy19")
	K.lbl(tv, "Desc", "GALLERY_TIP_TEXT", "Muted15")
	K.lbl(R, "H_Focus", "GALLERY_H_FOCUS", "EyebrowL")
	var fr = K.hbox(R, "FocusRow", 18)
	K.btn(fr, "FocusedButton", "GALLERY_FOCUSED", "ButtonPrimary", {}, true)
	K.btn(fr, "OtherButton", "GALLERY_OTHER", "ButtonSecondary")
	K.lbl(R, "H_Rules", "GALLERY_H_RULES", "EyebrowL")
	var g = K.add(R, "GridContainer", "Rules", {"columns": 2, "hsep": 14, "vsep": 10})
	for ru in ["INK", "GOLD", "NUM", "RED"]:
		var c = K.vbox(g, "Rule", 4, {"expand_h": true})
		K.add(c, "ColorRect", "Line", {"color": Color("#2b2340"), "min": Vector2(0, 2)})
		var mm = K.margin(c, "Pad", 16, 8, 16, 0)
		var cc = K.vbox(mm, "Col", 4)
		K.lbl(cc, "T", "GALLERY_RULE_%s_T" % ru, "Heavy17")
		K.lbl(cc, "D", "GALLERY_RULE_%s_D" % ru, "Muted14", {"autowrap_mode": TextServer.AUTOWRAP_WORD_SMART, "custom_minimum_size": Vector2(260, 0)})


## page "rarity": one ROW per rarity (tile filled / selected / unknown, themed item slot normal + selected, the word and the
## pips), then the two legendary icon cases and the ladder.
func _rarity_page(K, r) -> void:
	var m = K.margin(r, "RarityMargin", 36, 20, 36, 20, {"visible": false}, true)
	K.full(m)
	var cols = K.hbox(m, "RarityColumns", 48)
	var L = K.vbox(cols, "RarityLeft", 10, {"min": Vector2(640, 0)})
	K.lbl(L, "H_Rarity", "GALLERY_H_RARITY", "EyebrowL")
	K.lbl(L, "RarityNote", "GALLERY_RARITY_NOTE", "Muted15")
	var head = K.hbox(L, "RarityHead", 14)
	# column widths = the controls below (RaritySlot 66 + 2 x 8 = 82, themed item slot 62), same 14 px gap, so the captions line up
	for pair in [["GALLERY_COL_FILLED", 82], ["GALLERY_COL_SELECTED", 82], ["GALLERY_COL_UNKNOWN", 82], ["GALLERY_SLOT_FILLED", 62], ["GALLERY_SLOT_SELECTED", 62]]:
		K.lbl(head, "Col_" + pair[0], pair[0], "Muted13", {"min": Vector2(pair[1], 0), "horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER})
	var rows = K.vbox(L, "RarityRows", 2)
	for s in SAMPLES:
		var row = K.hbox(rows, "Row_" + s[0], 14, {"shrink_begin_h": true})
		K.add(row, "Control", "Filled_" + s[0], {"script": RSLOT, "rarity": StringName(s[0]), "item_id": StringName(s[1]), "count": 3 if s[0] == "normal" else 1})
		K.add(row, "Control", "Selected_" + s[0], {"script": RSLOT, "rarity": StringName(s[0]), "item_id": StringName(s[1]), "selected": true, "count": 3 if s[0] == "normal" else 1})
		K.add(row, "Control", "Unknown_" + s[0], {"script": RSLOT, "rarity": StringName(s[0]), "item_id": StringName(s[1]), "unknown": true})
		var tile = K.inst(row, SLOT, "ThemedSlot_" + s[0], {"min": Vector2(62, 62), "shrink_center_v": true})
		tile.set_meta("sample", s)
		var tile2 = K.inst(row, SLOT, "ThemedSelected_" + s[0], {"min": Vector2(62, 62), "shrink_center_v": true})
		tile2.set_meta("sample", s)
		tile2.set("button_pressed", true)
		var word = K.vbox(row, "Word_" + s[0], 2, {"shrink_center_v": true})
		K.lbl(word, "WordLabel", "RARITY_" + s[0].to_upper(), "RarityWord" + s[0].capitalize())
		K.add(word, "Control", "Pips", {"script": RPIPS, "rarity": StringName(s[0]), "pip_size": 12.0})
	var R = K.vbox(cols, "RarityRight", 10, {"expand_h": true})
	K.lbl(R, "H_Night", "GALLERY_RARITY_LEGEND_NIGHT", "Heavy17")
	var nrow = K.hbox(R, "NightRow", 14)
	K.add(nrow, "Control", "NightFile", {"script": RSLOT, "rarity": &"legendary", "item_id": &"clock_moon"})
	K.add(nrow, "Control", "NightFileSelected", {"script": RSLOT, "rarity": &"legendary", "item_id": &"clock_moon", "selected": true})
	K.lbl(R, "H_Disc", "GALLERY_RARITY_LEGEND_DISC", "Heavy17")
	var drow = K.hbox(R, "DiscRow", 14)
	K.add(drow, "Control", "DiscNoFile", {"script": RSLOT, "rarity": &"legendary", "item_id": &"chair_pine"})
	K.add(drow, "Control", "DiscNoFileSelected", {"script": RSLOT, "rarity": &"legendary", "item_id": &"chair_pine", "selected": true})
	K.lbl(R, "H_NoIcon", "GALLERY_RARITY_NO_ICON", "Heavy17")
	var irow = K.hbox(R, "NoIconRow", 14)
	K.add(irow, "Control", "NoIconRare", {"script": RSLOT, "rarity": &"rare", "item_id": &"gizmo_unmade"})
	K.add(irow, "Control", "NoIconLegendary", {"script": RSLOT, "rarity": &"legendary", "item_id": &"lamp_unmade"})
	K.lbl(R, "H_Ladder", "GALLERY_H_LADDER", "EyebrowL")
	var lad = K.vbox(R, "Ladder", 4, {"min": Vector2(360, 0)})
	var steps := [["Done", 1, "done", "GALLERY_LADDER_1", "GALLERY_CHIP_BUILT", false], ["Current", 2, "current", "GALLERY_LADDER_2", "GALLERY_CHIP_HERE", false],
		["Next", 3, "next", "GALLERY_LADDER_3", "GALLERY_CHIP_NEXT", true], ["Locked", 4, "locked", "GALLERY_LADDER_4", "GALLERY_CHIP_LOCKED", false]]
	for st in steps:
		var lr = K.add(lad, "Control", "Ladder" + st[0], {"script": LADDER, "number": st[1], "state": StringName(st[2]), "selected": st[5], "custom_minimum_size": Vector2(360, 50)})
		lr.set_meta("title_key", st[3])
		lr.set_meta("chip_key", st[4])
