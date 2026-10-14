extends RefCounted
## Section cast_data (package V1-cast-data, milestone 1a): the data of the Figurer v2 cast on top of the built contracts.
## Six heroes (two per race; the ghost's two are checked by ghost_data), the 22 NPCs of the v2 cast + the eight citizens of the towns track,
## the species layer of the perks, the zone names, Brumme's timber yard and Pip's first quest.
##
## Named checks (the order of V1-cast-data and its amendments RT20 / AG1):
##   cast_data.species_perk_precedence, species_perks_complete, species_perks_only_through_the_class, npc_homes_match_zone_graph,
##   pips_runde_loads_through_lua_runtime, pips_runde_objectives_bind, keys_da_en_complete, hero_blurbs_verbatim_from_the_sheet,
##   no_old_town_name_anywhere, no_foreign_csv_touched, timber_yard_stock_items_exist_and_keeper,
##   postman_pip_offers_forste_dage, new_roles_valid, family_and_age_present.
## What is NOT asserted here and why: the sprites of the new NPC ids (V2-cast-art: tests/sections/art_characters.gd), the dialogue files (V7), the
## shop natteblik_maps and the quest files skovlift_intro / bossernes_vej / ugles_noegle / rune_vandring (DR7), forste_dage (N04): the roster tests of
## data.gd SKIP them naming the package until they exist. The runtime binding of the objectives of pips_runde belongs to P13 (QuestManager).
const SECTION := "cast_data"
const TIMEOUT_S := 90.0

const LM := preload("res://scripts/autoload/localization_manager.gd")
const SPECIES_PERKS_PATH := "res://scripts/data/species_perks.gd"
## the user's own export of the Figurer v2 sheet: the card texts of cast.csv are copied from it VERBATIM
const SHEET_HTML := "res://docs/Trætoppen Style Guide Review/Trætoppen Figurer v2.dc.html"

## the keys a species_perks row may carry: the three race perks of the animal card plus the species-only keys (documented in lua/config/species_perks.lua)
const SPECIES_KEYS := ["dig_speed", "tool_cost_mult", "harvest_bonus_chance", "climb_speed_mult", "chest_sense_px", "crown_caches"]
## the skins of the six heroes of the Figurer v2 sheet (the ghost's two have no species rows: race_perks.ghost IS their layer)
const HERO_SKINS := ["animal_fox", "animal_monkey", "fairy_meadow", "fairy_birk", "hobbit_pip", "hobbit_bodil"]
const GHOST_SKINS := ["ghost_bu", "ghost_hviske"]
## the race perks every skin must answer through the fall-through (the ladder step 2)
const RACE_KEYS_EVERY_SKIN_ANSWERS := ["dig_speed", "tool_cost_mult", "harvest_bonus_chance", "can_fly", "shop_discount", "bake_bonus", "run_cost_mult", "glow_color"]

## the hero card blurbs of cast.csv, verbatim from the sheet (Danish)
const BLURBS := {
	"HERO_RASMUS_BLURB": "Standardfiguren, når man vælger skovdyr. Stærke poter, så han graver hurtigere og får mere ud af høsten.",
	"HERO_KIKI_BLURB": "Klatrer op ad stammer og lianer, hvor andre må tage stigen. Finder skjulte kister i trækronerne.",
	"HERO_KLOEVERMYNTE_BLURB": "Driver frøbutikken i Hyggebyen. Samme grundfigur bruges, når spilleren vælger at være fe: kort flyvning over marker.",
	"HERO_BIRK_BLURB": "Mandlig variant af feen og Kløvermyntes bror. Samme evne: kort flyvning over marker. Passer bierne i Hyggebyen.",
	"HERO_BERTIL_BLURB": "Standardfiguren for halvlinge. Bager bedre kager, går barfodet og får rabat i Hyggebyens butikker.",
	"HERO_BODIL_BLURB": "Kvindelig variant af halvlingen og Bertils søster. Samme evner: bedre kager, bare fødder og rabat i Hyggebyen.",
	"CAST_GARDENER_HOPPE_DESC": "Gartner på nabogrenen. Bytter sjældne frø for friske gulerødder og giver gode råd om vejret.",
	"CAST_CARPENTER_BRUMME_DESC": "Tømrer i Hyggebyen. Løfter bjælkerne, når feerne skal have nyt tag, og sælger byggematerialer til gården.",
	"CAST_CAT_MORFAR_MIS_DESC": "Pippins gamle kat. Forsvinder tit ind i Mørkeskoven efter sardiner og er hovedpersonen i opgaven \"Find Pippins kat\".",
	"CAST_MAPSELLER_NATTEBLIK_DESC": "Bor i Mørkeskoven. Sælger kort over hulerne, men kun efter mørkets frembrud.",
	"CAST_POSTMAN_PIP_DESC": "Postbud. Kommer forbi gården hver morgen med breve, pakker og nye opgaver fra Hyggebyens borgere.",
	"CAST_APPRAISER_FRU_UGLE_DESC": "Fekongens rådgiver og skovens klogeste. Vurderer de ædelsten og mineraler, du finder i Mørkeskoven.",
	"CAST_BATHKEEPER_SOFUS_DESC": "Driver badehuset i Trætoppen. Altid rolig, altid med en appelsin på hovedet, og ved hvem der har brug for en pause.",
}

## the home areas of the zone graph (DUNGEON_V2_ADDENDUM 2.1): `home` (the builder) is an area but nobody's home; moerkeskoven_f1..f12 are generated and never a home
const GRAPH_AREAS := ["farm", "home", "traetoppen", "hyggebyen", "moerkeskoven"]
const NPC_HOME_AREAS := ["farm", "hyggebyen", "moerkeskoven", "traetoppen"]

## the quest binding vocabulary of PLAN 3.12 (`on =` of an objective)
const BINDING_VOCABULARY := ["item_gained", "crop_planted", "crop_watered", "crop_harvested", "zone_entered", "dialogue_started", "animal_adopted", "animal_fed",
	"animal_product_collected", "building_built", "enemy_defeated", "recipe_crafted", "quest_completed", "manual", "game_event", "area_changed", "state"]

## the roles the v2 cast and the towns citizens brought (V1 + RT20): role -> the citizens that wear it
const NEW_ROLES := {
	"gardener": ["gardener_hoppe", "bertil"], "carpenter": ["carpenter_brumme"], "bathkeeper": ["bathkeeper_sofus"], "appraiser": ["appraiser_fru_ugle"],
	"mapseller": ["mapseller_natteblik"], "beekeeper": ["beekeeper_birk"], "apprentice": ["rasmus"], "lamplighter": ["lamplighter_kiki"],
	"baker_helper": ["bodil"], "innkeeper": ["innkeeper_kvak"], "clerk": ["clerk_fjerpen"], "musician": ["fiddler_strimmel"],
}

## age and family of the 30 citizens: the fields of D3/towns_scripts/proto/citizens.json that the social track reads (siblings Bertil / Bodil Boegeknop and
## Kloevermynte / Birk, the children Lily and Bamse). id -> [age, family or ""]
const AGE_FAMILY := {
	"mayor_lyra": ["adult", "hyldeblomst"], "baker_maja": ["adult", ""], "merchant_pip": ["adult", "kloevermynte"], "pippin_boegeknop": ["adult", ""], "fairy_king": ["elder", ""],
	"fairy_lily": ["child", "hyldeblomst"], "smith_thorin": ["adult", ""], "guard_oak": ["adult", "oak"], "farmer_rosa": ["adult", ""], "fairy_wizard": ["elder", ""],
	"cat_morfar_mis": ["elder", ""], "penguin_postman": ["adult", ""], "fairy_builder": ["adult", ""], "fairy_furnisher": ["adult", ""], "fairy_tailor": ["adult", ""],
	"gardener_hoppe": ["adult", ""], "carpenter_brumme": ["adult", ""], "postman_pip": ["adult", ""], "bathkeeper_sofus": ["adult", ""], "appraiser_fru_ugle": ["elder", ""],
	"mapseller_natteblik": ["adult", ""], "beekeeper_birk": ["adult", "kloevermynte"], "rasmus": ["adult", ""], "lamplighter_kiki": ["adult", ""], "bertil": ["adult", "boegeknop"],
	"bodil": ["adult", "boegeknop"], "innkeeper_kvak": ["adult", ""], "cub_bamse": ["child", "oak"], "clerk_fjerpen": ["adult", ""], "fiddler_strimmel": ["adult", ""],
}

## sha256 of the CSV files of OTHER packages, taken when V1 landed (the files V1 must not touch: ui.csv P07, finds.csv DL4 / F1, furniture.csv F1). A legitimate later
## edit by the file's owner makes no_foreign_csv_touched fail on purpose: update the hash in the same commit. Overrides of their keys go through P26's zz_final.csv.
const FOREIGN_CSV_PINS := {
	"res://localization/ui.csv": "fa6f57f0ac3d6e6e077a6479a2ac64d027d7ea923edb4ad51a20224031dae6b4",
	"res://localization/finds.csv": "5e836481a09a982b8be859f9efb9c556011a14bbfffbea5ac96008f440e725b7",
	"res://localization/furniture.csv": "ae3acc062997339785012e4de6cc1c80d763e0f9e206ddd15a7ba79f9930c75f",
}

const TIMBER_STOCK := {"wood": [60, 60], "stone": [60, 60], "plank_pine": [30, 30], "timber_beam": [20, 20], "nails": [40, 40], "rope": [20, 20], "straw_bundle": [20, 20]}

const SCAN_ROOTS := ["res://lua", "res://localization", "res://data", "res://scripts", "res://scenes", "res://tests", "res://docs", "res://tools"]
const SCAN_FILES := ["res://README.md", "res://project.godot"]
const SCAN_EXTENSIONS := ["gd", "lua", "csv", "tscn", "tres", "map", "json", "md", "py", "sh", "html", "txt", "cfg", "shader"]
const SCAN_SKIP_DIRS := [".git", ".godot", ".venv", "_stage", "node_modules", "__pycache__"]

var _t
var _lr: Node
var _gm: Node
var _lm: Node
var _saved_flags: Dictionary = {}
var _captured_notifs: Array = []


func run(t) -> void:
	_t = t
	_lr = t.autoload("LuaRuntime")
	_gm = t.autoload("GameManager")
	_lm = t.autoload("LocalizationManager")
	if _lr == null or _gm == null or _lm == null:
		t.skip("cast_data: LuaRuntime, GameManager or LocalizationManager is missing")
		return
	_saved_flags = (_gm.world_flags as Dictionary).duplicate(true)
	_species_perks()
	_species_perks_complete()
	_npc_homes()
	_new_roles()
	_family_and_age()
	_postman_pip()
	_pips_runde()
	_keys()
	_timber_yard()
	_old_town_name()
	_foreign_csv()
	_restore_flags()


# ---------------------------------------------------------------------------------------------------- species perks

## The ladder of SpeciesPerks.value: species layer -> race layer -> the caller's default; current() reads GameManager.character_skin.
func _species_perks() -> void:
	var t = _t
	var race_animal: Dictionary = _lr.get_config("race_perks.animal", {})
	var problems: Array[String] = []
	# 1. the species layer wins over the race (Kiki): dig 1.0 / cost 0.9 / harvest 0.0 against the race's 1.3 / 0.75 / 0.2, plus her own keys
	for pair in [["dig_speed", 1.0], ["tool_cost_mult", 0.9], ["harvest_bonus_chance", 0.0], ["climb_speed_mult", 2.2], ["chest_sense_px", 700]]:
		var got: Variant = SpeciesPerks.value(&"animal_monkey", pair[0], -1.0)
		if float(got) != float(pair[1]):
			problems.append("monkey %s = %s, want %s" % [pair[0], got, pair[1]])
	if SpeciesPerks.value("animal_monkey", "crown_caches", false) != true:
		problems.append("monkey crown_caches is not true")
	if not (float(race_animal["dig_speed"]) != 1.0 and float(race_animal["tool_cost_mult"]) != 0.9 and float(race_animal["harvest_bonus_chance"]) != 0.0):
		problems.append("the race row does not differ from the monkey row: nothing is overridden")
	# 2. a key the skin does not list falls through to race_perks.<race>.<key>: Rasmus is the race baseline (dig 1.3, cost 0.75, harvest +20 %)
	for k in ["dig_speed", "tool_cost_mult", "harvest_bonus_chance", "can_fly", "shop_discount"]:
		if not _same(SpeciesPerks.value(&"animal_fox", k, "<none>"), race_animal[k]):
			problems.append("animal_fox %s = %s, the race says %s" % [k, SpeciesPerks.value(&"animal_fox", k, "<none>"), race_animal[k]])
	var chars: Dictionary = _lr.get_config("characters", {})
	var heroes_via_race := {"fairy_meadow": ["can_fly", true], "fairy_birk": ["can_fly", true], "hobbit_pip": ["shop_discount", 0.1], "hobbit_bodil": ["bake_bonus", 0.25],
		"ghost_bu": ["run_cost_mult", 0.6], "ghost_hviske": ["glow_color", "bfe0ff"], "animal_squirrel": ["dig_speed", 1.3]}
	for skin in heroes_via_race:
		var k: String = heroes_via_race[skin][0]
		if not chars.get("skins", {}).has(skin) or not _same(SpeciesPerks.value(skin, k, "<none>"), heroes_via_race[skin][1]):
			problems.append("%s %s = %s, want %s through its race" % [skin, k, SpeciesPerks.value(skin, k, "<none>"), heroes_via_race[skin][1]])
	# the monkey's overrides do not leak into other skins of her race
	if float(SpeciesPerks.value(&"animal_fox", "climb_speed_mult", 1.0)) != 1.0 or SpeciesPerks.value(&"animal_fox", "crown_caches", false) != false or int(SpeciesPerks.value(&"animal_fox", "chest_sense_px", 0)) != 0:
		problems.append("the monkey's own keys leak into animal_fox")
	# 3. a key nobody lists, an unknown skin, an empty id, an NPC id: the caller's default (type kept)
	if SpeciesPerks.value(&"hobbit_pip", "climb_speed_mult", 1.0) != 1.0 or SpeciesPerks.value("no_such_skin", "dig_speed", 7.5) != 7.5 or SpeciesPerks.value("", "dig_speed", 7.5) != 7.5 or SpeciesPerks.value(&"guard_oak", "climb_speed_mult", 1.0) != 1.0 \
			or SpeciesPerks.value(&"animal_monkey", "no_such_key", "dflt") != "dflt" or SpeciesPerks.value(&"animal_fox", "no_such_key") != null:
		problems.append("the default of the caller is not returned for a key nobody lists / an unknown skin")
	# the contract V3's ClimbLane relies on: Svc.static_call(path, &"value", [skin, "climb_speed_mult", 1.0]) -> Kiki 2.2, everybody else 1.0
	var via_svc_monkey: Variant = Svc.static_call(SPECIES_PERKS_PATH, &"value", [&"animal_monkey", "climb_speed_mult", 1.0], -1.0)
	var via_svc_fox: Variant = Svc.static_call(SPECIES_PERKS_PATH, &"value", [&"animal_fox", "climb_speed_mult", 1.0], -1.0)
	if not (float(via_svc_monkey) == 2.2 and float(via_svc_fox) == 1.0):
		problems.append("Svc.static_call(value) gives %s / %s, want 2.2 / 1.0 (V3's ClimbLane)" % [via_svc_monkey, via_svc_fox])
	# current(): the skin the player plays right now; a skin the data does not know (a fresh node, an old save) answers for the race's DEFAULT skin
	var prev_skin: Variant = _gm.get("character_skin")
	var prev_type: Variant = _gm.get("character_type")
	var cases := [
		[0, &"animal_monkey", "climb_speed_mult", 2.2], [0, &"animal_monkey", "dig_speed", 1.0], [0, &"animal_fox", "dig_speed", 1.3], [0, &"animal_fox", "climb_speed_mult", "<none>"],
		[0, &"animal_bear", "dig_speed", 1.3], [0, &"default", "tool_cost_mult", 0.75], [1, &"fairy_birk", "can_fly", true], [2, &"hobbit_bodil", "shop_discount", 0.1],
		[3, &"default", "run_cost_mult", 0.6], [3, &"ghost_hviske", "float_bob_px", 2.5],
	]
	for c in cases:
		_gm.set("character_type", c[0])
		_gm.set("character_skin", c[1])
		var got2: Variant = SpeciesPerks.current(c[2], "<none>")
		if not _same(got2, c[3]):
			problems.append("current(%s) for type %s skin %s = %s, want %s" % [c[2], c[0], c[1], got2, c[3]])
	_gm.set("character_type", prev_type)
	_gm.set("character_skin", prev_skin)
	t.check("species_perk_precedence", problems.is_empty(), "species layer > race layer > the caller's default: Kiki 1.0 / 0.9 / 0.0 / climb 2.2 / chest 700 / crown caches, Rasmus the race baseline 1.3 / 0.75 / 0.2, every other skin through its race, unknown skins the default; SpeciesPerks.current follows GameManager.character_skin %s" % str(problems.slice(0, 4)))
	# the ladder 1.1 s / 2.2 = 0.5 s that V3 builds on
	t.expect(absf(1.1 / float(SpeciesPerks.value(&"animal_monkey", "climb_speed_mult", 1.0)) - 0.5) < 0.0001, "the monkey's climb_speed_mult 2.2 turns the 1.1 s ladder into 0.5 s")


## species_perks.lua is complete and well-formed: a row for each of the six heroes (empty = the race baseline), only live skins, only documented keys,
## no ghost rows (the ghost's layer is race_perks.ghost), and every skin of characters.lua answers every race perk through the fall-through.
func _species_perks_complete() -> void:
	var t = _t
	var rows: Dictionary = LuaData.dict(_lr.get_config("species_perks", {}))
	var chars: Dictionary = _lr.get_config("characters", {})
	var skins: Dictionary = LuaData.dict(chars.get("skins", {}))
	var problems: Array[String] = []
	for skin in HERO_SKINS:
		if not rows.has(skin):
			problems.append("no species_perks row for the hero skin %s (an empty row = the race baseline)" % skin)
	for skin in GHOST_SKINS:
		if rows.has(skin):
			problems.append("%s has a species row: the ghost's layer is race_perks.ghost (the fall-through)" % skin)
	for skin in rows:
		if not skins.has(skin):
			problems.append("species_perks.%s names no skin of characters.lua" % skin)
		elif bool(LuaData.dict(skins[skin]).get("retired", false)):
			problems.append("species_perks.%s is a retired skin" % skin)
		for k in LuaData.dict(rows[skin]):
			if not (str(k) in SPECIES_KEYS):
				problems.append("species_perks.%s.%s is not a documented key" % [skin, k])
	var monkey: Dictionary = LuaData.dict(rows.get("animal_monkey", {}))
	if not (monkey.size() == 6 and monkey["dig_speed"] == 1.0 and monkey["tool_cost_mult"] == 0.9 and monkey["harvest_bonus_chance"] == 0.0 and monkey["climb_speed_mult"] == 2.2 and monkey["chest_sense_px"] == 700 and monkey["crown_caches"] == true):
		problems.append("animal_monkey is not {dig_speed 1.0, tool_cost_mult 0.9, harvest_bonus_chance 0.0, climb_speed_mult 2.2, chest_sense_px 700, crown_caches true}: %s" % str(monkey))
	for skin in HERO_SKINS:
		if skin != "animal_monkey" and not LuaData.dict(rows.get(skin, {})).is_empty():
			problems.append("%s must list nothing: it is the race baseline" % skin)
	var unanswered: Array[String] = []
	for skin in skins:
		for k in RACE_KEYS_EVERY_SKIN_ANSWERS:
			if SpeciesPerks.value(skin, k, "<none>") is String and SpeciesPerks.value(skin, k, "<none>") == "<none>":
				unanswered.append("%s.%s" % [skin, k])
	_t.check("species_perks_complete", problems.is_empty() and unanswered.is_empty() and skins.size() == 15, "%d skins of characters.lua answer the %d race perks through the ladder, the six heroes have a row (only Kiki lists values), no ghost rows, only documented keys %s %s" % [skins.size(), RACE_KEYS_EVERY_SKIN_ANSWERS.size(), str(problems.slice(0, 3)), str(unanswered.slice(0, 3))])
	# nobody reads the species layer directly: every other script asks SpeciesPerks (the ONLY place it is resolved)
	var direct: Array[String] = []
	var scanned := {"files": 0}
	_scan_gd_for_direct_reads("res://scripts", direct, scanned)
	t.check("species_perks_only_through_the_class", direct.is_empty() and int(scanned["files"]) >= 50, "%d scripts scanned: none but scripts/data/species_perks.gd reads the config key species_perks %s" % [int(scanned["files"]), str(direct.slice(0, 3))])


## == that never raises: numbers compare as numbers, any other pair of values must be of the same type (String == float is an engine error)
func _same(a: Variant, b: Variant) -> bool:
	var a_num: bool = typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT
	var b_num: bool = typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT
	if a_num and b_num:
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b


func _scan_gd_for_direct_reads(dir: String, hits: Array[String], counter: Dictionary) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		_scan_gd_for_direct_reads(dir.path_join(sub), hits, counter)
	for f in d.get_files():
		if f.get_extension() != "gd" or f == "species_perks.gd":
			continue
		counter["files"] = int(counter["files"]) + 1
		var text := FileAccess.get_file_as_string(dir.path_join(f))
		for needle in ["config(\"species_perks", "config(\"species_perks.", "\"species_perks.", "\"species_perks\""]:
			if text.contains(needle):
				hits.append("%s (%s)" % [dir.path_join(f), needle])
				break


# ---------------------------------------------------------------------------------------------------- homes and the zone graph

## npc_homes_match_zone_graph: the homes of the roster are exactly the areas of the zone graph that can be a home, the markers of the hand-authored maps
## stand in their own home area, Oak lives at the Skovlift (traetoppen), Natteblik is placed by the dungeon generator, Morfar Mis lives in Hyggebyen.
func _npc_homes() -> void:
	var t = _t
	var npcs: Dictionary = _lr.get_npcs()
	var vocab_areas: Array = LuaData.strings(_lr.get_config("npc_vocab.areas", []))
	var problems: Array[String] = []
	var a := vocab_areas.duplicate()
	a.sort()
	if a != NPC_HOME_AREAS:
		problems.append("npc_vocab.areas %s is not the zone graph's home areas %s" % [str(a), str(NPC_HOME_AREAS)])
	for area in NPC_HOME_AREAS:
		if not (area in GRAPH_AREAS):
			problems.append("%s is not an area of the zone graph" % area)
	# the real areas on disk: the maps of data/maps (not the fixtures) and the levelled treetop city
	var map_areas := {}
	var markers_by_area := {}
	for f in DirAccess.get_files_at("res://data/maps"):
		if f.get_extension() != "map" or f.begins_with("_"):
			continue
		var info := _map_info("res://data/maps/%s" % f)
		map_areas[info["id"]] = true
		markers_by_area[info["id"]] = info["npcs"]
		if not (str(info["id"]) in GRAPH_AREAS):
			problems.append("data/maps/%s has the id %s which is no area of the zone graph" % [f, info["id"]])
	if not FileAccess.file_exists("res://data/traetoppen/traetoppen.json"):
		problems.append("data/traetoppen/traetoppen.json (the levelled city, V3) is missing")
	for area in ["farm", "hyggebyen", "moerkeskoven"]:
		if not map_areas.has(area):
			problems.append("data/maps has no %s.map" % area)
	for id in npcs:
		var home := str((npcs[id] as Dictionary).get("home_area", ""))
		if not (home in NPC_HOME_AREAS) or home.begins_with("moerkeskoven_f"):
			problems.append("%s: home_area %s is no home of the zone graph (a generated floor never is)" % [id, home])
	# a marker stands in the area its NPC lives in (the roster rows are informational, the map decides where he stands: they must agree)
	for area in markers_by_area:
		for nid in markers_by_area[area]:
			var home2 := str((npcs.get(nid, {}) as Dictionary).get("home_area", "<no row>"))
			if home2 != area:
				problems.append("%s stands in %s.map but lives in %s" % [nid, area, home2])
	if not (markers_by_area.get("moerkeskoven", []) as Array).is_empty() or not (markers_by_area.get("farm", []) as Array).is_empty():
		problems.append("the hub and the farm have npc markers (the hub has no slot, the farm's citizens are routines)")
	var oak: Dictionary = npcs.get("guard_oak", {})
	var natteblik: Dictionary = npcs.get("mapseller_natteblik", {})
	var mis: Dictionary = npcs.get("cat_morfar_mis", {})
	if str(oak.get("home_area", "")) != "traetoppen" or "guard_oak" in (markers_by_area.get("hyggebyen", []) as Array):
		problems.append("guard_oak must live in traetoppen (the Skovlift) with no marker in Hyggebyen")
	if str(natteblik.get("home_area", "")) != "moerkeskoven" or natteblik.has("shop_id") or _any_marker_of(markers_by_area, "mapseller_natteblik"):
		problems.append("mapseller_natteblik must live in moerkeskoven (placed by the dungeon generator), carry NO shop_id and stand in no hand-authored map")
	if str(mis.get("home_area", "")) != "hyggebyen":
		problems.append("cat_morfar_mis must live in Hyggebyen (the forest placement is a marker when=quest:lost_cat, not his home)")
	if str(npcs.get("beekeeper_birk", {}).get("home_area", "")) != "hyggebyen":
		problems.append("beekeeper_birk must live in Hyggebyen")
	# the shop of Natteblik is a contract id: if its file exists its keeper is him (DR7), if not the row simply has no shop_id
	var nm_shop: Dictionary = _lr.get_shop("natteblik_maps")
	if not nm_shop.is_empty() and str(nm_shop.get("keeper", "")) != "mapseller_natteblik":
		problems.append("natteblik_maps names %s as keeper" % nm_shop.get("keeper", ""))
	t.check("npc_homes_match_zone_graph", problems.is_empty(), "npc_vocab.areas = the %d home areas of the zone graph (farm hyggebyen traetoppen moerkeskoven; `home` is nobody's home, generated floors are never one); %d npc markers of %d maps stand in their NPC's home; Oak at the Skovlift, Natteblik without a shop_id, Mis in Hyggebyen %s" % [NPC_HOME_AREAS.size(), _marker_count(markers_by_area), markers_by_area.size(), str(problems.slice(0, 3))])


func _map_info(path: String) -> Dictionary:
	var out := {"id": "", "npcs": []}
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("@id "):
			out["id"] = line.substr(4).strip_edges()
		elif line.begins_with("@marker "):
			var parts := line.split(" ", false)
			if parts.size() >= 3 and parts[2] == "npc":
				for p in parts:
					if p.begins_with("id="):
						(out["npcs"] as Array).append(p.substr(3))
	return out


func _any_marker_of(markers_by_area: Dictionary, nid: String) -> bool:
	for area in markers_by_area:
		if nid in (markers_by_area[area] as Array):
			return true
	return false


func _marker_count(markers_by_area: Dictionary) -> int:
	var n := 0
	for area in markers_by_area:
		n += (markers_by_area[area] as Array).size()
	return n


# ---------------------------------------------------------------------------------------------------- roles, age, family, Pip's offers (RT20)

## new_roles_valid: every role the v2 cast and the towns citizens brought is in npc_vocab.roles and worn by exactly the citizens the design names.
func _new_roles() -> void:
	var t = _t
	var npcs: Dictionary = _lr.get_npcs()
	var roles: Array = LuaData.strings(_lr.get_config("npc_vocab.roles", []))
	var problems: Array[String] = []
	for role in NEW_ROLES:
		if not (role in roles):
			problems.append("npc_vocab.roles has no %s" % role)
		var wearers: Array[String] = []
		for id in npcs:
			if str((npcs[id] as Dictionary).get("role", "")) == role:
				wearers.append(str(id))
		wearers.sort()
		var want: Array = (NEW_ROLES[role] as Array).duplicate()
		want.sort()
		if wearers != want:
			problems.append("role %s is worn by %s, want %s" % [role, str(wearers), str(want)])
	t.check("new_roles_valid", problems.is_empty(), "%d new roles (gardener carpenter bathkeeper appraiser mapseller beekeeper apprentice lamplighter baker_helper innkeeper clerk musician) are in npc_vocab.roles and worn by the citizens of the design %s" % [NEW_ROLES.size(), str(problems.slice(0, 3))])


## family_and_age_present: age on all 30 rows, family on exactly the eight relatives (the data the social track's marriage exclusion reads);
## the social track's own file, lua/social/citizens.lua (S-data), must agree where it repeats a field.
func _family_and_age() -> void:
	var t = _t
	var npcs: Dictionary = _lr.get_npcs()
	var problems: Array[String] = []
	for id in AGE_FAMILY:
		if not npcs.has(id):
			problems.append("%s: no row" % id)
			continue
		var n: Dictionary = npcs[id]
		var want_age: String = AGE_FAMILY[id][0]
		var want_family: String = AGE_FAMILY[id][1]
		if str(n.get("age", "")) != want_age:
			problems.append("%s: age %s, want %s" % [id, n.get("age", ""), want_age])
		if str(n.get("family", "")) != want_family:
			problems.append("%s: family '%s', want '%s'" % [id, n.get("family", ""), want_family])
	# the relatives: sibling pairs share one family id, the children are children
	var sib_ok: bool = npcs["bertil"]["family"] == npcs["bodil"]["family"] and npcs["merchant_pip"]["family"] == npcs["beekeeper_birk"]["family"] \
		and npcs["bertil"]["family"] != npcs["merchant_pip"]["family"] and npcs["fairy_lily"]["age"] == "child" and npcs["cub_bamse"]["age"] == "child"
	if not sib_ok:
		problems.append("the sibling pairs / the children are wrong")
	var social: Variant = _lr.get_config("citizens", null)
	var social_note := ""
	if typeof(social) == TYPE_DICTIONARY and not (social as Dictionary).is_empty():
		for id in social:
			var row: Dictionary = LuaData.dict(social[id])
			for k in ["age", "family"]:
				if row.has(k) and npcs.has(id) and str(row[k]) != str((npcs[id] as Dictionary).get(k, "")):
					problems.append("lua/social/citizens.lua says %s.%s = %s, npcs.lua says %s" % [id, k, row[k], (npcs[id] as Dictionary).get(k, "")])
		social_note = "; lua/social/citizens.lua (S-data) agrees where it repeats a field"
	t.check("family_and_age_present", AGE_FAMILY.size() == 30 and problems.is_empty(), "age on all 30 citizens, family on the 8 relatives (Bertil / Bodil, Kloevermynte / Birk, Lily with the mayor, Bamse with Oak), the data of D3 citizens.json %s%s" % [str(problems.slice(0, 3)), social_note])
	if social_note == "":
		t.skip("family_and_age_present: lua/social/citizens.lua (S-data, the social track) is not in the tree yet; it will copy age and family from npcs.lua, which this check pins")


## postman_pip_offers_forste_dage: Pip offers his round AND the tutorial quest of the farm (N04); the ambient penguin postman offers nothing.
func _postman_pip() -> void:
	var t = _t
	var npcs: Dictionary = _lr.get_npcs()
	var pip: Dictionary = npcs.get("postman_pip", {})
	var offers: Array = pip.get("quests_offered", [])
	var ok: bool = offers == ["pips_runde", "forste_dage"] and not (npcs.get("penguin_postman", {}) as Dictionary).has("quests_offered") and str(pip.get("role", "")) == "postman"
	t.check("postman_pip_offers_forste_dage", ok, "postman_pip offers %s; penguin_postman (ambient) offers none" % str(offers))
	if _lr._quest_modules.has("forste_dage"):
		var sid: String = _lr._quest_modules["forste_dage"]
		t.expect(str(((_lr._scripts[sid] as Dictionary).get("meta", {}) as Dictionary).get("giver", "")) == "postman_pip", "forste_dage (N04) is given by postman_pip")
	else:
		t.skip("cast_data: lua/quests/forste_dage.lua belongs to N04-farm-first-morning (not in the tree yet); Pip's row offers it already")


# ---------------------------------------------------------------------------------------------------- Pip's first quest

func _on_notification(title: String, message: String, icon: String) -> void:
	if icon == "lua":
		_captured_notifs.append([title, message])


## pips_runde_loads_through_lua_runtime: the file lints clean, registers as the quest pips_runde with the meta / rewards / objectives of the design, and its
## functions run: the offer, the acceptance (flag + toast), the completion (flags + toast, the quest is then no longer available).
func _pips_runde() -> void:
	var t = _t
	var sid: String = str(_lr._quest_modules.get("pips_runde", ""))
	var problems: Array[String] = []
	if sid == "":
		t.fail("the quest pips_runde is not registered by LuaRuntime")
		return
	var script: Dictionary = _lr._scripts[sid]
	var meta: Dictionary = LuaData.dict(script.get("meta", {}))
	var rewards: Dictionary = LuaData.dict(script.get("rewards", {}))
	var objectives: Array = LuaData.arr(script.get("objectives", []))
	if not (str(meta.get("giver", "")) == "postman_pip" and str(meta.get("location", "")) == "ZONE_TRAETOPPEN" and str(meta.get("tag", "")) == "FIND" and str(meta.get("category", "")) == "help" and meta.get("repeatable") == false):
		problems.append("meta is %s" % str(meta))
	if not (int(rewards.get("gold", 0)) == 120 and LuaData.dict(rewards.get("items", {})) == {"friendship_token": 1} and LuaData.dict(rewards.get("friendship", {})) == {"postman_pip": 1}):
		problems.append("rewards are %s" % str(rewards))
	if objectives.size() != 4:
		problems.append("%d objectives, want 4" % objectives.size())
	var findings: Array = _lr.lint_source(FileAccess.get_file_as_string("res://lua/quests/pips_runde.lua"), "res://lua/quests/pips_runde.lua")
	if not findings.is_empty():
		problems.append("the file does not lint clean: %s" % str(findings.slice(0, 2)))
	# the functions, through the runtime (the notification keys are translated by api.notification)
	var offer: Variant = _lr._invoke_function(sid, "on_offer", [{}])
	if not (typeof(offer) == TYPE_DICTIONARY and offer.get("available") == true and str(offer.get("text_key", "")) == "QUEST_PIPS_RUNDE_OFFER"):
		problems.append("on_offer gives %s" % str(offer))
	(_gm.world_flags as Dictionary).erase(&"pips_runde_done")
	(_gm.world_flags as Dictionary).erase(&"pips_runde_active")
	var available_before: Variant = _lr._invoke_function(sid, "is_available", [{}])
	var bus: Node = t.autoload("EventBus")
	if bus != null:
		bus.notification_posted.connect(_on_notification)
	_captured_notifs.clear()
	var accepted: Variant = _lr._invoke_function(sid, "on_accept", [{}])
	var active_after_accept: Variant = _gm.get_flag(&"pips_runde_active")
	var toasts_after_accept: int = _captured_notifs.size()
	_lr.call_quest_event("pips_runde", "quest_completed", {})
	var done_flag: Variant = _gm.get_flag(&"pips_runde_done")
	var active_after_done: Variant = _gm.get_flag(&"pips_runde_active")
	var available_after: Variant = _lr._invoke_function(sid, "is_available", [{}])
	var toasts: Array = _captured_notifs.duplicate()
	if bus != null:
		bus.notification_posted.disconnect(_on_notification)
	if not (available_before == true and typeof(accepted) == TYPE_DICTIONARY and accepted.get("ok") == true and active_after_accept == true and toasts_after_accept == 1
			and done_flag == true and active_after_done == false and available_after == false and toasts.size() == 2):
		problems.append("the functions: available %s, accept %s, active %s, toasts %d, done %s, active %s, available after %s, toasts %d" % [available_before, accepted, active_after_accept, toasts_after_accept, done_flag, active_after_done, available_after, toasts.size()])
	for pair in toasts:
		if str(pair[0]) == "" or str(pair[1]) == "" or str(pair[0]).begins_with("QUEST_PIPS_RUNDE_") or str(pair[1]).begins_with("QUEST_PIPS_RUNDE_"):
			problems.append("a toast shows a raw key: %s" % str(pair))
	t.check("pips_runde_loads_through_lua_runtime", problems.is_empty(), "lua/quests/pips_runde.lua: giver postman_pip, ZONE_TRAETOPPEN, FIND, help, not repeatable; reward gold 120 + friendship_token + a heart with Pip; four objectives; on_offer / on_accept / handle_event / is_available run through LuaRuntime, both toasts are translated, no lint finding %s" % str(problems.slice(0, 3)))
	_objectives_bind(objectives, meta)


## pips_runde_objectives_bind: the three greetings and the return bind the dialogue_started event of ROSTER npcs, the return is after_others, every objective
## text is defined; QuestManager's own binding (P13) is not in the tree yet and is SKIPped by name.
func _objectives_bind(objectives: Array, meta: Dictionary) -> void:
	var t = _t
	var npcs: Dictionary = _lr.get_npcs()
	var want := [["greet_hoppe", "gardener_hoppe"], ["greet_brumme", "carpenter_brumme"], ["greet_sofus", "bathkeeper_sofus"], ["return_to_pip", "postman_pip"]]
	var problems: Array[String] = []
	if objectives.size() == want.size():
		for i in want.size():
			var o: Dictionary = LuaData.dict(objectives[i])
			var oid: String = want[i][0]
			if str(o.get("id", "")) != oid or str(o.get("on", "")) != "dialogue_started" or str(o.get("npc", "")) != want[i][1] or int(o.get("target", 0)) != 1:
				problems.append("objective %d is %s" % [i, str(o)])
			if not (str(o.get("on", "")) in BINDING_VOCABULARY):
				problems.append("%s binds the unknown event %s" % [oid, o.get("on", "")])
			if not npcs.has(str(o.get("npc", ""))):
				problems.append("%s names the unknown npc %s" % [oid, o.get("npc", "")])
			var key := str(o.get("description_key", ""))
			if key != "OBJ_PIPS_RUNDE_%s" % oid.to_upper() or _lm.text_in(key, "da") == "" or _lm.text_in(key, "en") == "":
				problems.append("%s: description_key %s is wrong or has no da / en text" % [oid, key])
			if (oid == "return_to_pip") != (o.get("after_others") == true):
				problems.append("%s: after_others must be true on the return only" % oid)
	else:
		problems.append("%d objectives" % objectives.size())
	# the giver is the npc who returns the player, and he offers the quest
	var giver: Dictionary = npcs.get(str(meta.get("giver", "")), {})
	if not ("pips_runde" in (giver.get("quests_offered", []) as Array)) or (objectives.size() == 4 and str(LuaData.dict(objectives[3]).get("npc", "")) != str(meta.get("giver", ""))):
		problems.append("the giver does not offer the quest or is not the return target")
	t.check("pips_runde_objectives_bind", problems.is_empty(), "greet_hoppe / greet_brumme / greet_sofus bind dialogue_started of gardener_hoppe / carpenter_brumme / bathkeeper_sofus, return_to_pip (after_others) binds postman_pip, all four are roster ids of the binding vocabulary, every OBJ_PIPS_RUNDE_* text in da + en %s" % str(problems.slice(0, 3)))
	var qm: Node = _t.autoload("QuestManager")
	if qm == null or not qm.has_method("get_objective_text"):
		t.skip("pips_runde_objectives_bind (runtime): QuestManager has no objective bindings yet - P13-quests-lua-runtime binds `on = dialogue_started` to EventBus.dialogue_started; the objectives above are checked against the PLAN 3.12 vocabulary")


# ---------------------------------------------------------------------------------------------------- the copy

## keys_da_en_complete: every key of cast.csv has da and en, only the five families of the key-owner table; every key the V1 data names (hero cards, NPC names,
## zone names, the shop, the quest) is defined with both languages; the hero blurbs also fit two lines of the select screen.
func _keys() -> void:
	var t = _t
	var rep := LM.parse_dir("res://localization", "res://", false)
	var by_key := {}
	var cast_keys: Array[String] = []
	for d in rep["defs"]:
		by_key[str(d["key"])] = d
		if str(d["file"]) == "cast.csv":
			cast_keys.append(str(d["key"]))
	var problems: Array[String] = []
	for k in cast_keys:
		var text: Dictionary = by_key[k]["text"]
		if str(text.get("da", "")) == "" or str(text.get("en", "")) == "":
			problems.append("%s has no da or no en text" % k)
		if not (k.begins_with("CAST_") or k.begins_with("HERO_") or k.begins_with("SHOP_TIMBER_") or k.begins_with("QUEST_PIPS_RUNDE_") or k.begins_with("OBJ_PIPS_RUNDE_")):
			problems.append("%s is outside the five families of cast.csv" % k)
		if k.begins_with("HERO_BU_") or k.begins_with("HERO_HVISKE_"):
			problems.append("%s belongs to ghost.csv" % k)
	# the keys the V1 data names
	var wanted: Array[String] = ["ZONE_TRAETOPPEN", "ZONE_FARM", "SHOP_TIMBER_YARD", "SHOP_TIMBER_YARD_GREETING"]
	for h in LuaData.arr(_lr.get_config("characters.heroes", [])):
		for field in ["name_key", "kind_key", "blurb_key"]:
			wanted.append(str(LuaData.dict(h).get(field, "")))
	for sk in ["animal_monkey", "fairy_birk", "hobbit_bodil", "ghost_bu", "ghost_hviske"]:
		wanted.append(str(LuaData.dict(_lr.get_config("characters.skins.%s" % sk, {})).get("name_key", "")))
	for row in LuaData.arr(_lr.get_config("characters.species", [])):
		wanted.append(str(LuaData.dict(row).get("name_key", "")))
	for id in _lr.get_npcs():
		wanted.append(str((_lr.get_npcs()[id] as Dictionary).get("name_key", "")))
	for k in ["TITLE", "DESC", "OFFER", "CHOICE", "REMIND", "ACCEPT_TITLE", "ACCEPT_TEXT", "DONE_TITLE", "DONE_TEXT"]:
		wanted.append("QUEST_PIPS_RUNDE_%s" % k)
	for k in ["GREET_HOPPE", "GREET_BRUMME", "GREET_SOFUS", "RETURN_TO_PIP"]:
		wanted.append("OBJ_PIPS_RUNDE_%s" % k)
	for k in BLURBS:
		wanted.append(k)
	var shop: Dictionary = _lr.get_shop("timber_yard")
	wanted.append(str(shop.get("name_key", "")))
	wanted.append(str(shop.get("greeting_key", "")))
	var missing: Array[String] = []
	for k in wanted:
		if k == "" or _lm.text_in(k, "da") == "" or _lm.text_in(k, "en") == "":
			missing.append(k)
	# the cards the player reads: the blurbs of the six heroes fit two lines of the select bottom bar (<= 118 characters, the bar of the ghost cards)
	var long_blurbs: Array[String] = []
	for k in BLURBS:
		if k.begins_with("HERO_") and _lm.text_in(k, "da").length() > 118:
			long_blurbs.append(k)
	t.check("keys_da_en_complete", problems.is_empty() and missing.is_empty() and long_blurbs.is_empty() and cast_keys.size() >= 40, "cast.csv: %d keys in the five families, every key the cast data names (%d lookups: 8 hero cards, 15 NPC names, 5 skin names, the shop, the quest and its objectives, the zone names) is defined in da + en, the six hero blurbs fit two lines %s %s %s" % [cast_keys.size(), wanted.size(), str(problems.slice(0, 3)), str(missing.slice(0, 4)), str(long_blurbs)])
	# the card texts are the sheet's own words
	var sheet: String = FileAccess.get_file_as_string(SHEET_HTML) if FileAccess.file_exists(SHEET_HTML) else ""
	sheet = sheet.replace("&amp;", "&").replace("&quot;", "\"").replace("&#39;", "'").replace("&nbsp;", " ")
	var off: Array[String] = []
	for k in BLURBS:
		if _lm.text_in(k, "da") != BLURBS[k]:
			off.append("%s differs from the pinned card text" % k)
		elif sheet != "" and not sheet.contains(str(BLURBS[k])):
			off.append("%s is not a text of the sheet" % k)
	if sheet == "":
		t.skip("hero_blurbs_verbatim_from_the_sheet: the sheet export (docs/Trætoppen Style Guide Review/Trætoppen Figurer v2.dc.html) is not readable here; the pinned texts were still compared")
	t.check("hero_blurbs_verbatim_from_the_sheet", off.is_empty(), "the %d card texts (6 hero blurbs, 7 CAST_*_DESC) of cast.csv are VERBATIM the paragraphs of the Figurer v2 export (Natteblik's drawing note is dropped) %s" % [BLURBS.size(), str(off.slice(0, 3))])


# ---------------------------------------------------------------------------------------------------- Brumme's timber yard

## timber_yard_stock_items_exist_and_keeper: keeper carpenter_brumme (his row names the shop), the seven farm-building materials at the item defs' own price
## (ONE price per item: no override), plain stock, every item exists and is no keepsake; Hasselnoed's builder_yard is untouched.
func _timber_yard() -> void:
	var t = _t
	var shop: Dictionary = _lr.get_shop("timber_yard")
	var problems: Array[String] = []
	if shop.is_empty():
		t.fail("the shop timber_yard is not registered")
		return
	if str(shop.get("keeper", "")) != "carpenter_brumme" or str((_lr.get_npc("carpenter_brumme")).get("shop_id", "")) != "timber_yard":
		problems.append("keeper %s / carpenter_brumme.shop_id %s" % [shop.get("keeper", ""), _lr.get_npc("carpenter_brumme").get("shop_id", "")])
	if not (float(shop.get("sell_multiplier", 0.0)) == 1.0 and float(shop.get("buy_multiplier", 0.0)) == 1.0 and LuaData.strings(shop.get("buys", [])) == ["building_material", "resource"]):
		problems.append("multipliers / buys: %s %s %s" % [shop.get("buy_multiplier"), shop.get("sell_multiplier"), shop.get("buys")])
	var stock: Dictionary = LuaData.dict(shop.get("stock", {}))
	var ids: Array = stock.keys()
	ids.sort()
	var want_ids: Array = TIMBER_STOCK.keys()
	want_ids.sort()
	if ids != want_ids:
		problems.append("stock ids %s, want %s" % [str(ids), str(want_ids)])
	for id in TIMBER_STOCK:
		var row: Dictionary = LuaData.dict(stock.get(id, {}))
		var def: Dictionary = _lr.get_item_def(id)
		if def.is_empty():
			problems.append("%s has no item def" % id)
			continue
		if row.has("price") or int(row.get("stock", -1)) != TIMBER_STOCK[id][0] or int(row.get("restock", -1)) != TIMBER_STOCK[id][1]:
			problems.append("%s: row %s, want stock %d / restock %d and no price override" % [id, str(row), TIMBER_STOCK[id][0], TIMBER_STOCK[id][1]])
		if not (str(def.get("category", "")) in ["building_material", "resource"]) or Rarity.is_one_of_a_kind(def.get("rarity", "normal")) or int(def.get("buy_price", 0)) <= 0:
			problems.append("%s: category %s, rarity %s, buy_price %s" % [id, def.get("category"), def.get("rarity"), def.get("buy_price")])
	# through the ShopSystem: seven lines at the defs' own price (before any discount of the player's race)
	var ss: Node = _t.autoload("ShopSystem")
	if ss != null and ss.has_method("get_shop_inventory"):
		var lines: Array = ss.get_shop_inventory("timber_yard")
		if lines.size() != TIMBER_STOCK.size():
			problems.append("ShopSystem lists %d lines" % lines.size())
		for row in lines:
			var def2: Dictionary = _lr.get_item_def(str(row["item_id"]))
			if int(row["base_price"]) != int(def2.get("buy_price", -1)) or int(row["max_stock"]) != TIMBER_STOCK.get(str(row["item_id"]), [-1])[0]:
				problems.append("ShopSystem line %s: base price %s (def %s), max stock %s" % [row["item_id"], row["base_price"], def2.get("buy_price"), row["max_stock"]])
	var yard: Dictionary = _lr.get_shop("builder_yard")
	if str(yard.get("keeper", "")) != "fairy_builder" or not yard.has("rotation") or yard.get("stock", {}).size() != 12:
		problems.append("Hasselnoeds builder_yard changed: keeper %s, %d fixed lines" % [yard.get("keeper", ""), yard.get("stock", {}).size()])
	t.check("timber_yard_stock_items_exist_and_keeper", problems.is_empty(), "timber_yard: keeper carpenter_brumme, %d lines (wood 60, stone 60, plank_pine 30, timber_beam 20, nails 40, rope 20, straw_bundle 20) at the item defs' own prices, buys building_material + resource, builder_yard (Hasselnoed) untouched %s" % [TIMBER_STOCK.size(), str(problems.slice(0, 3))])


# ---------------------------------------------------------------------------------------------------- the old town name, foreign CSV files

## no_old_town_name_anywhere: the fairy town is Hyggebyen. The old name appears in no text file of the project (the user's Style Guide export was renamed too).
func _old_town_name() -> void:
	var t = _t
	var needle := "fes" + "by"                      # the old name of the fairy town, never written out (this file must not carry it either)
	var hits: Array[String] = []
	var counter := {"files": 0}
	for root in SCAN_ROOTS:
		_scan_for(needle, root, hits, counter)
	for f in SCAN_FILES:
		if FileAccess.file_exists(f):
			counter["files"] = int(counter["files"]) + 1
			if FileAccess.get_file_as_string(f).to_lower().contains(needle):
				hits.append(f)
	var keys_clean := true
	for k in _lm.all_keys():
		for loc in ["da", "en"]:
			if _lm.text_in(k, loc).to_lower().contains(needle) or str(k).to_lower().contains(needle):
				keys_clean = false
	t.check("no_old_town_name_anywhere", hits.is_empty() and keys_clean and int(counter["files"]) > 500, "%d text files (lua, localization, data, scripts, scenes, tests, docs, tools) and every loaded key: the old town name is nowhere %s" % [int(counter["files"]), str(hits.slice(0, 3))])


func _scan_for(needle: String, dir: String, hits: Array[String], counter: Dictionary) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for sub in d.get_directories():
		if sub in SCAN_SKIP_DIRS or sub.begins_with("."):
			continue
		_scan_for(needle, dir.path_join(sub), hits, counter)
	for f in d.get_files():
		if f.get_extension().to_lower() in SCAN_EXTENSIONS:
			counter["files"] = int(counter["files"]) + 1
			var p := dir.path_join(f)
			if FileAccess.get_file_as_string(p).to_lower().contains(needle):
				hits.append(p)


## no_foreign_csv_touched: V1 edits core.csv (its own, carved out of P03) and adds cast.csv, nothing else: ui.csv (P07), finds.csv (DL4 / F1) and
## furniture.csv (F1) are byte-identical to the baseline, none of their keys is defined again in V1's files (an override goes through P26's
## zz_final.csv: CHAR_HOBBIT_NAME 'Halvling', FIND_AREA_FARM), and the texts the design overrides later are still the old ones.
func _foreign_csv() -> void:
	var t = _t
	var problems: Array[String] = []
	for path in FOREIGN_CSV_PINS:
		var h: String = FileAccess.get_sha256(path)
		if h != FOREIGN_CSV_PINS[path]:
			problems.append("%s changed (sha256 %s); a legitimate edit by its owner: update FOREIGN_CSV_PINS" % [path.get_file(), h.substr(0, 12)])
	var rep := LM.parse_dir("res://localization", "res://", false)
	var foreign_keys := {}
	var mine := {}
	for d in rep["defs"]:
		var file := str(d["file"])
		if file in ["ui.csv", "finds.csv", "furniture.csv"]:
			foreign_keys[str(d["key"])] = file
		elif file in ["core.csv", "cast.csv"]:
			mine[str(d["key"])] = file
	for k in mine:
		if foreign_keys.has(k):
			problems.append("%s (%s) redefines a key of %s" % [k, mine[k], foreign_keys[k]])
	if not (_lm.text_in("CHAR_HOBBIT_NAME", "da") == "Hobbit" and _lm.file_of("CHAR_HOBBIT_NAME") == "ui.csv" and _lm.text_in("FIND_AREA_FARM", "da") == "Trætoppen" and _lm.file_of("FIND_AREA_FARM") == "finds.csv" and _lm.text_in("SPECIES_FOX", "da") == "Ræv"):
		problems.append("CHAR_HOBBIT_NAME / FIND_AREA_FARM / SPECIES_FOX were changed (they are overridden through zz_final.csv by P26)")
	t.check("no_foreign_csv_touched", problems.is_empty(), "ui.csv, finds.csv and furniture.csv are byte-identical to the baseline (%d keys), cast.csv / core.csv redefine none of them; CHAR_HOBBIT_NAME 'Halvling' and FIND_AREA_FARM are P26's overrides, not V1's %s" % [foreign_keys.size(), str(problems.slice(0, 3))])


func _restore_flags() -> void:
	var flags: Dictionary = _gm.world_flags
	flags.clear()
	for k in _saved_flags:
		flags[k] = _saved_flags[k]
