extends RefCounted
## Section ghost_data (owner V1-cast-data, amendment AG1: `ownsAdd tests/sections/ghost_data.gd`).
## The data ROWS of the fourth race (Spoegelse, ids ghost_bu / ghost_hviske): lua/config/characters.lua (race, two skins, chains) and
## lua/config/race_perks.lua (the eight new perk keys on all four races, the ghost numbers). The four checks used to be part of
## tests/sections/ghost.gd (G-ghost-data); they need V1's rows, so they live in V1's gate (review defect 3). Lift: design4/proto/tests/ghost_data.gd.
##
## Named checks: ghost_data.race_key_and_visual_chain, ghost_data.data_rows_agree, ghost_data.perk_keys_defined_for_every_race, ghost_data.perk_numbers
const SECTION := "ghost_data"
const TIMEOUT_S := 60.0

const NEW_PERK_KEYS := ["run_cost_mult", "oil_use_mult", "dark_light_mult", "float_bob_px", "glow_energy", "glow_energy_dark", "glow_scale", "glow_color"]
const NEUTRAL := {"run_cost_mult": 1.0, "oil_use_mult": 1.0, "dark_light_mult": 1.0, "float_bob_px": 0.0, "glow_energy": 0.0, "glow_energy_dark": 0.0, "glow_scale": 0.0, "glow_color": ""}

var _lr: Node
var _gm: Node


func run(t) -> void:
	_lr = t.root.get_node_or_null("LuaRuntime")
	_gm = t.root.get_node_or_null("GameManager")
	if _lr == null or _gm == null:
		t.skip("ghost_data: LuaRuntime or GameManager is missing")
		return
	var script: Script = _gm.get_script()
	var e: Dictionary = script.get_script_constant_map().get("CharacterType", {})
	# the hero the run started with is restored afterwards (start_new_game is the one way to switch the race with its skin)
	var prev_type: int = int(_gm.character_type)
	var prev_skin: StringName = _gm.character_skin
	_gm.start_new_game("Hv", e["GHOST"], "F", &"ghost_hviske")
	t.check("race_key_and_visual_chain", GameData.race_key() == "ghost" and GameData.visual_for_skin(&"ghost_hviske") == "ghost_hviske_base" and CharacterCatalog.fallback_chain("ghost_bu_base") == ["ghost_bu_base", "ghost_bu", "rabbit"], "race %s, hviske head of chain %s, bu chain %s" % [GameData.race_key(), GameData.visual_for_skin(&"ghost_hviske"), str(CharacterCatalog.fallback_chain("ghost_bu_base"))])
	_gm.start_new_game("A", prev_type, "F", prev_skin if CharacterCatalog.skin_ids().has(str(prev_skin)) else &"")
	_data(t)
	_perks(t)


func _data(t) -> void:
	var chars: Dictionary = CharacterCatalog.data()
	var races: Dictionary = chars.get("races", {})
	var row: Dictionary = races.get("ghost", {})
	var skins: Array[String] = []
	for id in CharacterCatalog.skin_ids():
		if str(CharacterCatalog.skin(id).get("race", "")) == "ghost":
			skins.append(id)
	skins.sort()
	var mine: Array = (_lr.call("get_config", "race_perks.ghost.skins", []) as Array).map(func(s: Variant) -> String: return str(s))
	mine.sort()
	var bodies_ok := true
	for id in skins:
		bodies_ok = bodies_ok and CharacterCatalog.wardrobe_body(id, "ghost") == id and CharacterCatalog.fallback_chain(CharacterCatalog.visual_for_skin(id, "ghost")).back() == "rabbit"
	t.check("data_rows_agree", races.size() == 4 and str(row.get("default_skin", "")) == "ghost_bu" and str(row.get("name_key", "")) == "CHAR_GHOST_NAME" and str(row.get("perk_key", "")) == "CHAR_GHOST_PERK"
		and skins == ["ghost_bu", "ghost_hviske"] and mine == skins and str(_lr.call("get_config", "race_perks.ghost.default_skin", "")) == "ghost_bu" and bodies_ok,
		"races %d, skins %s, race_perks.ghost.skins %s, wardrobe body = skin id, chain ends at the pack rabbit" % [races.size(), str(skins), str(mine)])


func _perks(t) -> void:
	var all_ok := true
	var detail: Array = []
	for race in ["animal", "fairy", "hobbit", "ghost"]:
		var cfg: Dictionary = _lr.call("get_config", "race_perks.%s" % race, {})
		for k in NEW_PERK_KEYS:
			if not cfg.has(k):
				all_ok = false
				detail.append("%s.%s missing" % [race, k])
			elif race != "ghost" and str(cfg[k]) != str(NEUTRAL[k]) and not (cfg[k] is float and is_equal_approx(float(cfg[k]), float(NEUTRAL[k]))):
				all_ok = false
				detail.append("%s.%s is %s, neutral is %s" % [race, k, str(cfg[k]), str(NEUTRAL[k])])
	t.check("perk_keys_defined_for_every_race", all_ok, "the eight new keys (run_cost_mult oil_use_mult dark_light_mult float_bob_px glow_energy glow_energy_dark glow_scale glow_color) on all four races, neutral except the ghost %s" % str(detail))
	var g: Dictionary = _lr.call("get_config", "race_perks.ghost", {})
	var run_cost: float = float(_lr.call("get_config", "player.run_cost_per_second", 15.0))
	var oil: float = float(_lr.call("get_config", "combat.oil_seconds", 150.0))
	t.check("perk_numbers", is_equal_approx(float(g.get("run_cost_mult", 0.0)), 0.6) and is_equal_approx(float(g.get("oil_use_mult", 0.0)), 0.75) and is_equal_approx(float(g.get("dark_light_mult", 0.0)), 1.25) and is_equal_approx(float(g.get("float_bob_px", 0.0)), 2.5)
		and is_equal_approx(float(g.get("glow_energy", 0.0)), 0.35) and is_equal_approx(float(g.get("glow_energy_dark", 0.0)), 0.08) and is_equal_approx(float(g.get("glow_scale", 0.0)), 0.9) and str(g.get("glow_color", "")) == "bfe0ff"
		and g.get("shop_discount") == 0.0 and g.get("bake_bonus") == 0.0 and g.get("harvest_bonus_chance") == 0.0 and g.get("dig_speed") == 1.0 and g.get("tool_cost_mult") == 1.0 and g.get("can_fly") == false,
		"ghost: run %.1f energy/s (15 -> 9), one lantern fill %.0f s -> %.0f s, light radius x1.25, bob 2.5 px; no discount, no bake, no harvest, no dig, no flight" % [run_cost * float(g.get("run_cost_mult", 1.0)), oil, oil / maxf(float(g.get("oil_use_mult", 1.0)), 0.01)])
