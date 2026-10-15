extends RefCounted
## Section ghost (package G-ghost-data, wave 3b: the FIRST gate after the fix round RG1-RG7). DRAFT, proven in a clone of main.
## The fourth playable race (Spoegelse, ids ghost_bu / ghost_hviske): the save-stable enum, the perk table that cannot leak the hobbit's perks, the saves, the copy, the harness helpers.
## Only what the fix round (the edits of BUILT packages) + localization/ghost.csv make true: nothing here reads the data rows of V1 (characters.lua, race_perks.lua), the ghost art or P16.
## The four checks that need V1's rows live in tests/sections/ghost_data.gd (V1, wave 4).
##
## Named checks: ghost.enum_order_is_save_stable, ghost.new_game_default_and_explicit_skin, ghost.save_roundtrip_and_old_saves,
## ghost.every_enum_value_has_a_perk_row, ghost.no_hobbit_perks_leak, ghost.keys_translate, ghost.harness_helpers_know_the_ghost
const SECTION := "ghost"
const TIMEOUT_S := 60.0

var _t
var _lr: Node
var _gm: Node


func run(t) -> void:
	_t = t
	_lr = t.root.get_node_or_null("LuaRuntime")
	_gm = t.root.get_node_or_null("GameManager")
	if _lr == null or _gm == null:
		t.skip("ghost: LuaRuntime or GameManager is missing")
		return
	_enum_and_new_game(t)
	_perks(t)
	_save(t)
	_loc(t)
	_harness(t)


func _enum_dict() -> Dictionary:
	var script: Script = _gm.get_script()
	var d: Variant = script.get_script_constant_map().get("CharacterType", {})
	return d if d is Dictionary else {}


func _enum_and_new_game(t) -> void:
	var e := _enum_dict()
	var ordered := {}
	for k in e:
		ordered[int(e[k])] = str(k)
	t.check("enum_order_is_save_stable", ordered == {0: "ANIMAL", 1: "FAIRY", 2: "HOBBIT", 3: "GHOST"}, "saves store the int: ANIMAL 0, FAIRY 1, HOBBIT 2 must never move, GHOST is appended as 3 (%s)" % str(ordered))
	_gm.start_new_game("Bu", e["GHOST"], "F")
	var def_skin: StringName = _gm.character_skin
	_gm.start_new_game("Hv", e["GHOST"], "F", &"ghost_hviske")
	var explicit: StringName = _gm.character_skin
	t.check("new_game_default_and_explicit_skin", def_skin == &"ghost_bu" and explicit == &"ghost_hviske", "default %s explicit %s" % [def_skin, explicit])
	_gm.start_new_game("A", e["ANIMAL"], "F")


func _perks(t) -> void:
	var e := _enum_dict()
	t.check("every_enum_value_has_a_perk_row", Perks.RACE_KEYS.size() == e.size() and Perks.RACE_KEYS.find("ghost") == 3 and GameData.RACE_KEYS.size() == e.size(), "Perks.RACE_KEYS %s, GameData.RACE_KEYS %d, enum %d (a missing entry would CLAMP a new race onto the hobbit's discount)" % [str(Perks.RACE_KEYS), GameData.RACE_KEYS.size(), e.size()])
	# the silent leak: with the enum extended but Perks.RACE_KEYS not, index 3 clamps to 2 and the ghost would get the hobbit's 10 percent and the bake bonus
	_gm.start_new_game("Bu", e["GHOST"], "F")
	var discount: float = Perks.total("discount")
	var bake: float = CraftingSystem.bake_bonus_chance()
	t.check("no_hobbit_perks_leak", discount == 0.0 and bake == 0.0, "ghost: Perks.total(discount) %s, CraftingSystem.bake_bonus_chance %s (both 0.0; a hobbit has 0.10 and 0.25)" % [str(discount), str(bake)])
	_gm.start_new_game("A", e["ANIMAL"], "F")


func _save(t) -> void:
	var e := _enum_dict()
	_gm.start_new_game("Hv", e["GHOST"], "Gaard", &"ghost_hviske")
	var d: Dictionary = _gm.to_dict()
	_gm.start_new_game("Other", e["ANIMAL"], "X")
	_gm.from_dict(d)
	var round_ok: bool = int(_gm.character_type) == 3 and _gm.character_skin == &"ghost_hviske" and int(d["character_type"]) == 3
	var old_ok := true
	for kind in 3:
		_gm.from_dict({"character_type": kind})
		old_ok = old_ok and int(_gm.character_type) == kind
	_gm.from_dict({"character_type": 99})
	var clamp_ok: bool = int(_gm.character_type) == 3
	var summary_ok := true
	var sm: Node = t.root.get_node_or_null("SaveManager")
	if sm != null and sm.has_method("gather_payload"):
		_gm.start_new_game("Bu", e["GHOST"], "F")
		var payload: Dictionary = sm.call("gather_payload")
		var meta: Dictionary = payload.get("meta", {})
		var summary: Dictionary = meta.get("summary", {})
		summary_ok = str(summary.get("character", "")) == "ghost"
	t.check("save_roundtrip_and_old_saves", round_ok and old_ok and clamp_ok and summary_ok, "character_type 3 survives to_dict/from_dict with its skin, saves of 0 1 2 load as before, a type beyond the enum clamps to the last race, meta.summary.character is 'ghost' (%s %s %s %s)" % [str(round_ok), str(old_ok), str(clamp_ok), str(summary_ok)])
	_gm.start_new_game("A", e["ANIMAL"], "F")


func _loc(t) -> void:
	var keys := ["CHAR_GHOST_NAME", "CHAR_GHOST_PERK", "SKIN_GHOST_BU", "SKIN_GHOST_HVISKE", "HERO_BU_NAME", "HERO_BU_KIND", "HERO_BU_BLURB", "HERO_HVISKE_NAME", "HERO_HVISKE_KIND", "HERO_HVISKE_BLURB", "GHOST_WARDROBE_NOTE", "GHOST_HIDDEN_TAG", "GHOST_EQUIP_HIDDEN_FMT", "GHOST_WHISPER_WATER", "GHOST_WHISPER_DARK"]
	var raw: Array[String] = []
	for k in keys:
		if TranslationServer.translate(k) == k:
			raw.append(k)
	var blurb_ok := true
	for k in ["HERO_BU_BLURB", "HERO_HVISKE_BLURB"]:
		blurb_ok = blurb_ok and TranslationServer.translate(k).length() <= 118
	t.check("keys_translate", raw.is_empty() and blurb_ok and TranslationServer.translate("CHAR_GHOST_NAME") != "", "raw keys %s; the two hero blurbs are at most 118 characters (a proxy for two lines of the select bottom bar: the longest blurb of the sheet, Kloevermynte, has 116 and fits; the real measurement is menus.hero_blurb_fits_two_lines)" % str(raw))


func _harness(t) -> void:
	# the helpers that map --character= to the enum: an unknown name used to give 0 (the animal) silently, so a ghost run would have tested a fox
	var flow: Script = load("res://tests/lib/flow.gd")
	var consts: Dictionary = flow.get_script_constant_map()
	var fresh: Script = load("res://tests/lib/features/fresh.gd")
	var fresh_type: int = int(fresh.call("_character_type", "ghost"))
	var ct: Dictionary = consts.get("CHARACTER_TYPES", {})
	var race_btn: Dictionary = consts.get("UI_RACE", {})
	t.check("harness_helpers_know_the_ghost", fresh_type == 3 and int(ct.get("ghost", -1)) == 3 and str(race_btn.get("ghost", "")) == "%GhostButton" and t.character_type("ghost") == 3,
		"tests/lib/flow.gd CHARACTER_TYPES + UI_RACE, tests/lib/features/fresh.gd _character_type: ghost -> 3 / %%GhostButton (fresh says %d)" % fresh_type)
