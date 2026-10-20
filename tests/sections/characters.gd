extends RefCounted
## Section "characters" (package P05): the 12-character pack, IsoChibiSprite2D, lua/config/characters.lua, import stubs.
##
## Headless checks (tests/run_playtest.sh --only=characters --no-boot) and one windowed check (run_windowed: the cast line-up
## of tests/perf_world.gd is on screen and every figure has pixels). Named checks required by the plan / addendum:
##   characters.ids_resolve, pack_all_directions_all_clips_render, create_fox_and_fairy, flight_clips_only_fairy_bat,
##   warm_clips_finishes_cheap, memory_report, skins_resolve_with_and_without_bases, wardrobe_contract_members,
##   import_stub_audit_layers_lossless, shadow_floor_z, sprite_filter_is_4.
## v2 (package V1-cast-data): heroes_two_per_race (four races, eight heroes), catalog_heroes_api, species_chips (the two animal chips),
##   skins, skin_chains_match_the_addendum (all 15 skins), retired_skins_resolve.
## Needs the project imported (godot --headless --import, twice on a fresh clone): the sheets are S3TC textures.

const SECTION := "characters"
## Per-section watchdog: tests/playtest.gd reads this constant (consts["TIMEOUT_S"]); without it the default is 120 s.
## The section needs ~4-8 s headless (34 s once on a loaded machine) and ~12 s windowed.
const TIMEOUT_S := 300.0

const Catalog := preload("res://scripts/isometric/character_catalog.gd")
const Chibi := preload("res://scripts/isometric/iso_chibi_sprite_2d.gd")
const PerfWorld := preload("res://tests/perf_world.gd")

const DIR := "res://assets/isometric_characters/"
const PACK: Array[String] = ["bat", "cat", "bear", "rabbit", "fairy", "monkey", "capybara", "fox", "raccoon", "penguin", "hedgehog", "frog"]
const FLIERS: Array[String] = ["bat", "fairy"]
const STD_CLIPS := {"idle": 4, "walk": 6, "run": 6, "jump": 4, "fall": 3, "land": 3, "celebrate": 6, "interact": 4, "hit": 3, "sleep": 4, "talk": 4}
const FLIGHT_CLIPS := {"takeoff": 4, "hover": 5, "fly": 6, "flight_land": 4}
const PACK_SHEET_SIZE := 256

# The skin chains of the addendum (P05 amendment 1), spelled out once so the data is checked against the spec, not against itself.
const SKIN_CHAINS := {
	"animal_fox": ["fox_base", "fox"],
	"animal_rabbit": ["rabbit_base", "rabbit"],
	"animal_hedgehog": ["hedgehog_base", "hedgehog"],
	"animal_squirrel": ["squirrel_base", "squirrel", "monkey"],
	"fairy_meadow": ["fairy_base", "fairy"],
	"fairy_stardust": ["fairy_stardust_base", "fairy_stardust", "fairy"],
	"fairy_dusk": ["fairy_dusk_base", "fairy_dusk", "fairy"],
	"hobbit_pip": ["hobbit_pip_base", "hobbit_pip", "raccoon"],
	"hobbit_moss": ["hobbit_moss_base", "hobbit_moss", "raccoon"],
	"hobbit_bramble": ["hobbit_bramble_base", "hobbit_bramble", "raccoon"],
	# The v2 heroes use their own dressed character while wardrobe bases are pending.
	"animal_monkey": ["monkey_base", "monkey"],
	"fairy_birk": ["fairy_birk_base", "fairy_birk", "fairy"],
	"hobbit_bodil": ["hobbit_bodil_base", "hobbit_bodil", "hobbit_pip", "raccoon"],
	# the ghost (AG1): two skins, the pack rabbit at the end of the chain
	"ghost_bu": ["ghost_bu_base", "ghost_bu", "rabbit"],
	"ghost_hviske": ["ghost_hviske_base", "ghost_hviske", "rabbit"],
}
# The bodies.json hero id of every skin: a live hero has its own body, a RETIRED skin points at a live hero's body (the six v2 bodies
# fox monkey fairy fairy_birk hobbit_pip hobbit_bodil + the two ghost bodies), so A2's bodies.json can dress it.
const WARDROBE_BODIES := {
	"animal_fox": "fox", "animal_rabbit": "fox", "animal_hedgehog": "fox", "animal_squirrel": "monkey",
	"fairy_meadow": "fairy", "fairy_stardust": "fairy", "fairy_dusk": "fairy",
	"hobbit_pip": "hobbit_pip", "hobbit_moss": "hobbit_pip", "hobbit_bramble": "hobbit_pip",
	"animal_monkey": "monkey", "fairy_birk": "fairy_birk", "hobbit_bodil": "hobbit_bodil",
	"ghost_bu": "ghost_bu", "ghost_hviske": "ghost_hviske",
}
## The seven skins of the first guide: retired rows (never offered, kept for old saves and the pinned chains of art_characters).
const RETIRED_SKINS: Array[String] = ["animal_rabbit", "animal_hedgehog", "animal_squirrel", "fairy_stardust", "fairy_dusk", "hobbit_moss", "hobbit_bramble"]
## The heroes in card order: [id, race, skin] (Figurer v2: two per race; the ghost's two follow the other six).
const HEROES: Array = [
	["rasmus", "animal", "animal_fox"], ["kiki", "animal", "animal_monkey"],
	["kloevermynte", "fairy", "fairy_meadow"], ["birk", "fairy", "fairy_birk"],
	["bertil", "hobbit", "hobbit_pip"], ["bodil", "hobbit", "hobbit_bodil"],
	["bu", "ghost", "ghost_bu"], ["hviske", "ghost", "ghost_hviske"],
]
# Sheets the stock folders of P21 and the ghost art (G-ghost-art) will add (used to simulate "stock sheets exist, bases do not").
const NEW_STOCK_IDS: Array[String] = ["squirrel", "fairy_stardust", "fairy_dusk", "fairy_birk", "hobbit_pip", "hobbit_moss", "hobbit_bramble", "hobbit_bodil", "ghost_bu", "ghost_hviske"]

var _holder: Node2D


func run(t) -> void:
	t.allow("Unknown chibi character")
	_holder = Node2D.new()
	_holder.name = "CharactersSectionHolder"
	_holder.process_mode = Node.PROCESS_MODE_ALWAYS
	t.root.add_child(_holder)

	_data(t)
	_ids_resolve(t)
	_skins_resolve(t)
	_npc_fallbacks_match(t)
	_scene_and_script_shape(t)
	_meta_parse(t)
	_import_stubs(t)
	await _warm_clips(t)
	await _create_and_motion(t)
	await _wardrobe_contract(t)
	await _configure_before_add_child(t)
	await _fallbacks_and_open_ids(t)
	_pack_cells(t)
	_memory_report(t)

	t.expect_allowed("Unknown chibi character", 3, "the unknown-id warnings were provoked on purpose (no_such_character, ../fox, FOX)")
	_holder.queue_free()
	await t.frames(2)
	Catalog.clear_overrides()
	Chibi.clear_cache()


# ---------------------------------------------------------------- lua/config/characters.lua

func _data(t) -> void:
	var d: Dictionary = Catalog.data()
	t.check("data_loaded", d.has("races") and d.has("skins") and d.has("species") and d.has("animals") and d.has("enemies") and d.has("fallbacks"), "keys %s" % str(d.keys()))
	var races: Dictionary = d.get("races", {})
	var ok := races.size() == 4
	for race in ["animal", "fairy", "hobbit", "ghost"]:
		var row: Dictionary = Catalog.race(race)
		ok = ok and str(row.get("name_key", "")).begins_with("CHAR_") and str(row.get("perk_key", "")).ends_with("_PERK")
		ok = ok and str(Catalog.skin(Catalog.default_skin(race)).get("race", "")) == race
	t.check("races_perk_keys_and_default_skins", ok, "animal -> %s, fairy -> %s, hobbit -> %s, ghost -> %s" % [Catalog.default_skin("animal"), Catalog.default_skin("fairy"), Catalog.default_skin("hobbit"), Catalog.default_skin("ghost")])
	t.expect_eq([Catalog.default_skin("animal"), Catalog.default_skin("fairy"), Catalog.default_skin("hobbit"), Catalog.default_skin("ghost")], ["animal_fox", "fairy_meadow", "hobbit_pip", "ghost_bu"], "race -> default skin (plan 3.8)")
	# the species chips of the animal card: two since the Figurer v2 heroes (Rasmus the fox, Kiki the monkey); their key is the KIND line of the hero card
	var sp: Array = Catalog.species()
	var ids: Array = []
	var species_ok := sp.size() == 2
	for row in sp:
		ids.append(str((row as Dictionary).get("id", "")))
		species_ok = species_ok and str((row as Dictionary).get("name_key", "")).begins_with("HERO_") and str((row as Dictionary).get("name_key", "")).ends_with("_KIND") and not Catalog.skin((row as Dictionary).get("skin", "")).is_empty()
	t.check("species_chips", species_ok and ids == ["fox", "monkey"] and str((sp[0] as Dictionary).get("skin", "")) == "animal_fox" and str((sp[1] as Dictionary).get("skin", "")) == "animal_monkey", "chips %s (the two animal heroes; no SPECIES_ key)" % str(ids))
	_heroes(t, d)
	var animals: Dictionary = d.get("animals", {})
	var animal_ok := animals.size() == 10
	for species in ["chicken", "rabbit", "duck", "cat", "dog", "sheep", "cow", "deer", "fox", "owl"]:
		var look_baby: Dictionary = Catalog.animal_look(species, "baby")
		var look_adult: Dictionary = Catalog.animal_look(species, "adult")
		animal_ok = animal_ok and not look_baby.is_empty() and str(look_baby["visual"]) != "" and str(look_adult["visual"]) != ""
		animal_ok = animal_ok and float(look_baby["scale"]) > 0.0 and float(look_baby["scale"]) < float(look_adult["scale"])
	t.check("farm_animals_cover_every_species", animal_ok, "chicken: %s / %s" % [str(Catalog.animal_look("chicken", "baby")), str(Catalog.animal_look("chicken", "adult"))])
	t.check("enemy_visuals", Catalog.enemy_visual("bat") == "bat" and Catalog.enemy_visual("snurresvamp") == "snurresvamp" and Catalog.enemy_visual("lysesvamp") != "" and Catalog.enemy_visual("nope") == "", "bat stays the bat (never a scaled-up boss)")


## The `heroes` table (V1-cast-data, Figurer v2 + the ghost): four races, two heroes each, in card order; every hero wears a LIVE skin of
## its race, the first hero of a race is the race's default skin, and every text key of the cards is defined in da and en.
## Then the CharacterCatalog API on top of it (heroes(race), hero_of_skin(skin), is_retired(skin)), also with injected data.
func _heroes(t, d: Dictionary) -> void:
	var rows: Array = d.get("heroes", [])
	var problems: Array[String] = []
	if rows.size() != HEROES.size():
		problems.append("%d rows, want %d" % [rows.size(), HEROES.size()])
	for i in mini(rows.size(), HEROES.size()):
		var row: Dictionary = rows[i] if rows[i] is Dictionary else {}
		var want: Array = HEROES[i]
		var up := str(want[0]).to_upper()
		if str(row.get("id", "")) != want[0] or str(row.get("race", "")) != want[1] or str(row.get("skin", "")) != want[2]:
			problems.append("row %d is %s/%s/%s, want %s" % [i, row.get("id"), row.get("race"), row.get("skin"), str(want)])
		for pair in [["name_key", "HERO_%s_NAME" % up], ["kind_key", "HERO_%s_KIND" % up], ["blurb_key", "HERO_%s_BLURB" % up]]:
			if str(row.get(pair[0], "")) != pair[1]:
				problems.append("%s: %s is %s, want %s" % [want[0], pair[0], row.get(pair[0]), pair[1]])
		var skin_row: Dictionary = Catalog.skin(want[2])
		if skin_row.is_empty() or str(skin_row.get("race", "")) != want[1] or Catalog.is_retired(want[2]):
			problems.append("%s: skin %s is missing, of another race or retired" % [want[0], want[2]])
	var lm: Node = t.autoload("LocalizationManager")
	var untranslated: Array[String] = []
	for row in rows:
		for k in ["name_key", "kind_key", "blurb_key"]:
			for loc in ["da", "en"]:
				if lm != null and str(lm.call("text_in", str((row as Dictionary).get(k, "")), loc)) == "":
					untranslated.append("%s/%s" % [(row as Dictionary).get(k, ""), loc])
	var per_race := true
	var first_is_default := true
	for race in ["animal", "fairy", "hobbit", "ghost"]:
		var hs: Array[Dictionary] = Catalog.heroes(race)
		per_race = per_race and hs.size() == 2 and hs.all(func(h: Dictionary) -> bool: return str(h.get("race", "")) == race)
		first_is_default = first_is_default and not hs.is_empty() and str(hs[0].get("skin", "")) == Catalog.default_skin(race)
	t.check("heroes_two_per_race", problems.is_empty() and per_race and first_is_default and untranslated.is_empty() and Catalog.heroes("dragon").is_empty(),
		"four races, eight heroes in card order rasmus kiki | kloevermynte birk | bertil bodil | bu hviske; the first of a race is its default skin; every card text in da + en; problems %s %s" % [str(problems), str(untranslated.slice(0, 3))])
	# the API: rows in order, hero_of_skin both ways, retired / unknown skins are no heroes, is_retired
	var api_ok := true
	var detail: Array[String] = []
	var kiki: Array[Dictionary] = Catalog.heroes("animal")
	if not (kiki.size() == 2 and str(kiki[0].get("id", "")) == "rasmus" and str(kiki[1].get("id", "")) == "kiki"):
		api_ok = false
		detail.append("heroes(animal) %s" % str(kiki))
	for h in HEROES:
		var of_skin: Dictionary = Catalog.hero_of_skin(h[2])
		if str(of_skin.get("id", "")) != h[0] or str(of_skin.get("blurb_key", "")) != "HERO_%s_BLURB" % str(h[0]).to_upper():
			api_ok = false
			detail.append("hero_of_skin(%s) -> %s" % [h[2], str(of_skin)])
		if Catalog.is_retired(h[2]):
			api_ok = false
			detail.append("%s is retired" % h[2])
	for retired in RETIRED_SKINS:
		if not Catalog.hero_of_skin(retired).is_empty() or not Catalog.is_retired(retired):
			api_ok = false
			detail.append("%s: hero_of_skin %s is_retired %s" % [retired, str(Catalog.hero_of_skin(retired)), Catalog.is_retired(retired)])
	if not (Catalog.hero_of_skin("no_such_skin").is_empty() and Catalog.hero_of_skin(&"").is_empty() and not Catalog.is_retired("no_such_skin") and not Catalog.is_retired(&"animal_fox")):
		api_ok = false
		detail.append("unknown skin")
	# the same functions over injected data: rows of other races are skipped, a missing table is an empty answer, StringName ids work
	Catalog.set_data_override({"heroes": [{"id": "a", "race": "x", "skin": "s1"}, {"id": "b", "race": "y", "skin": "s2"}, {"id": "c", "race": "x", "skin": "s3"}], "skins": {"s1": {"retired": true}, "s2": {}}})
	var xs: Array[Dictionary] = Catalog.heroes("x")
	if not (xs.size() == 2 and str(xs[0]["id"]) == "a" and str(xs[1]["id"]) == "c" and Catalog.heroes("y").size() == 1 and Catalog.hero_of_skin(&"s2").get("id") == "b" and Catalog.is_retired(&"s1") and not Catalog.is_retired(&"s2")):
		api_ok = false
		detail.append("injected data")
	Catalog.set_data_override({})
	if not (Catalog.heroes("x").is_empty() and Catalog.hero_of_skin("s1").is_empty() and Catalog.species().is_empty()):
		api_ok = false
		detail.append("empty data")
	Catalog.clear_overrides()
	t.check("catalog_heroes_api", api_ok, "CharacterCatalog.heroes(race) in card order, hero_of_skin(skin) ({} for a retired or unknown skin), is_retired(skin); also over injected and empty data %s" % str(detail))


func _ids_resolve(t) -> void:
	for id in PACK:
		t.expect(Catalog.exists(id), "pack character folder exists: %s" % id)
	var ids: Array[String] = Catalog.all_ids()
	var unresolved: Array[String] = []
	var real: Array[String] = []
	var via_fallback: Array[String] = []
	var bad_end: Array[String] = []
	for id in ids:
		var r: String = Catalog.resolve(id)
		if r == "":
			unresolved.append(id)
		elif r == id:
			real.append(id)
		else:
			via_fallback.append("%s->%s" % [id, r])
		var chain: Array[String] = Catalog.fallback_chain(id)
		if not (chain.back() in PACK) or chain.size() >= Catalog.MAX_CHAIN or Catalog.fallback_of(chain.back()) != "":
			bad_end.append("%s:%s" % [id, str(chain)])
	t.check("ids_resolve", unresolved.is_empty() and ids.size() > 40, "%d ids in characters.lua, unresolved %s" % [ids.size(), str(unresolved)])
	t.check("chains_end_at_pack_characters", bad_end.is_empty(), str(bad_end.slice(0, 3)))
	t.info("characters.lua mentions %d ids: %d have their own art now, %d draw through a fallback chain (P21/A2 art not landed yet)" % [ids.size(), real.size(), via_fallback.size()])
	# a cycle in the data must stop, not hang
	Catalog.set_data_override({"fallbacks": {"a": "b", "b": "a"}})
	t.expect_eq(Catalog.fallback_chain("a"), ["a", "b"], "a fallback cycle ends at the first repeated id")
	Catalog.clear_overrides()


func _skins_resolve(t) -> void:
	var skins: Array[String] = Catalog.skin_ids()
	skins.sort()
	var want: Array = SKIN_CHAINS.keys()
	want.sort()
	t.check("skins", skins == want, "all %d skins are in characters.lua: the six v2 hero skins + the two ghost skins + the seven retired rows of the first guide (got %d)" % [want.size(), skins.size()])
	var chain_ok := true
	var fallback_ok := true
	var body_ok := true
	var detail: Array = []
	for skin in SKIN_CHAINS.keys():
		var chain: Array[String] = Catalog.skin_chain(skin)
		if chain != SKIN_CHAINS[skin]:
			chain_ok = false
			detail.append("%s: %s" % [skin, str(chain)])
		if str(Catalog.skin(skin).get("fallback", "")) != (SKIN_CHAINS[skin] as Array).back():
			fallback_ok = false
		if Catalog.wardrobe_body(skin) != WARDROBE_BODIES[skin]:
			body_ok = false
	t.check("skin_chains_match_the_addendum", chain_ok and SKIN_CHAINS.size() == 15, "%d skin chains, including Birk and Bodil's dedicated stock art before their legacy stand-ins %s" % [SKIN_CHAINS.size(), str(detail)])
	t.check("skin_fallback_is_the_end_of_the_chain", fallback_ok)
	t.check("wardrobe_body_is_the_bodies_json_hero_id", body_ok, "live hero bodies fox monkey fairy fairy_birk hobbit_pip hobbit_bodil ghost_bu ghost_hviske; retired skins point at a live body (fox fox monkey fairy fairy hobbit_pip hobbit_pip)")
	_retired_skins(t)
	# 1. the real disk: the first id of the chain with a folder wins
	var real_ok := true
	for skin in SKIN_CHAINS.keys():
		var expected := ""
		for id in SKIN_CHAINS[skin]:
			if FileAccess.file_exists(DIR + id + "/animations.json"):
				expected = id
				break
		if expected == "" or Catalog.resolved_visual_for_skin(skin) != expected:
			real_ok = false
	var stock_ok := true
	for skin in SKIN_CHAINS.keys():
		var chain: Array = SKIN_CHAINS[skin]
		var want_stock := ""
		for id in chain.slice(1):
			if FileAccess.file_exists(DIR + id + "/animations.json"):
				want_stock = id
				break
		stock_ok = stock_ok and Catalog.stock_visual_for_skin(skin) == want_stock and want_stock != ""
	t.check("stock_visual_is_never_the_undressed_base", stock_ok, "select screens show the stock sprite: %s" % Catalog.stock_visual_for_skin("animal_squirrel"))
	t.check("skins_resolve_on_the_real_disk", real_ok, "e.g. animal_squirrel -> %s, hobbit_pip -> %s, fairy_dusk -> %s" % [Catalog.resolved_visual_for_skin("animal_squirrel"), Catalog.resolved_visual_for_skin("hobbit_pip"), Catalog.resolved_visual_for_skin("fairy_dusk")])
	# 2. simulated art: bases present / stock sheets only / the pack only / nothing
	var scenarios := {
		"with_bases": Callable(self, "_art_with_bases"),
		"stock_only": Callable(self, "_art_stock_only"),
		"pack_only": Callable(self, "_art_pack_only"),
	}
	var all_ok := true
	var msgs: Array = []
	for scenario in scenarios.keys():
		Catalog.set_exists_override(scenarios[scenario])
		for skin in SKIN_CHAINS.keys():
			var chain: Array = SKIN_CHAINS[skin]
			var expected := ""
			match scenario:
				"with_bases":
					expected = chain[0]
				"stock_only":
					expected = chain[1]
				"pack_only":
					expected = chain[chain.size() - 1]
			var got: String = Catalog.resolved_visual_for_skin(skin)
			if got != expected:
				all_ok = false
				msgs.append("%s/%s: got %s want %s" % [scenario, skin, got, expected])
			# the stock sprite never is the undressed base: chain[1] while stock art exists, else the pack stand-in
			var stock_expected: String = chain[1] if scenario == "with_bases" else expected
			if Catalog.stock_visual_for_skin(skin) != stock_expected:
				all_ok = false
				msgs.append("%s/%s: stock %s want %s" % [scenario, skin, Catalog.stock_visual_for_skin(skin), stock_expected])
	Catalog.set_exists_override(func(_id: String) -> bool: return false)
	t.expect_eq(Catalog.resolved_visual_for_skin("animal_fox"), "", "no art at all: nothing resolves (and nothing crashes)")
	Catalog.clear_overrides()
	t.check("skins_resolve_with_and_without_bases", all_ok and real_ok and chain_ok, "bases -> chain[0], stock -> chain[1], pack only -> monkey/raccoon/fairy/fox/...; %s" % str(msgs.slice(0, 3)))
	# unknown skins (the dropped animal_bear / animal_owl of old saves) use the race default
	t.expect_eq(Catalog.visual_for_skin("animal_bear", "animal"), "fox_base", "old saves: unknown animal skin -> fox")
	t.expect_eq(Catalog.visual_for_skin("zzz", "hobbit"), "hobbit_pip_base", "unknown hobbit skin -> hobbit_pip")
	t.expect_eq(Catalog.wardrobe_body("animal_owl", "fairy"), "fairy", "unknown skin -> default skin of the race for the wardrobe body")


## The seven retired skins (V1-cast-data) are rows of the data and no hero: they keep resolving through their pinned chains on the REAL disk
## (old saves and art_characters.gd name them), their wardrobe body is the body of a LIVE hero, and nothing offers them (no hero row, no chip).
func _retired_skins(t) -> void:
	var live_bodies := {}
	for skin in Catalog.skin_ids():
		if not Catalog.is_retired(skin):
			live_bodies[Catalog.wardrobe_body(skin)] = true
	var chips := {}
	for row in Catalog.species():
		chips[str((row as Dictionary).get("skin", ""))] = true
	var problems: Array[String] = []
	for skin in RETIRED_SKINS:
		var chain: Array = SKIN_CHAINS[skin]
		var first_with_art := ""
		for id in chain:
			if FileAccess.file_exists(DIR + id + "/animations.json"):
				first_with_art = id
				break
		if not Catalog.is_retired(skin):
			problems.append("%s is not retired" % skin)
		if Catalog.skin_chain(skin) != chain or first_with_art == "" or Catalog.resolved_visual_for_skin(skin) != first_with_art:
			problems.append("%s: chain %s resolves to '%s', want %s" % [skin, str(Catalog.skin_chain(skin)), Catalog.resolved_visual_for_skin(skin), first_with_art])
		if not live_bodies.has(Catalog.wardrobe_body(skin)):
			problems.append("%s: wardrobe body %s is no live hero body" % [skin, Catalog.wardrobe_body(skin)])
		if not Catalog.hero_of_skin(skin).is_empty() or chips.has(skin):
			problems.append("%s is offered (hero row or chip)" % skin)
	var live := 0
	for skin in Catalog.skin_ids():
		if not Catalog.is_retired(skin):
			live += 1
	t.check("retired_skins_resolve", problems.is_empty() and live == HEROES.size() and Catalog.skin_ids().size() - live == RETIRED_SKINS.size(),
		"%d retired skins (%s) still resolve on the real disk through their chains, dress with a live hero body (%s) and are offered nowhere; %d live skins = the %d heroes %s" % [RETIRED_SKINS.size(), ", ".join(RETIRED_SKINS), ", ".join(PackedStringArray(live_bodies.keys())), live, HEROES.size(), str(problems.slice(0, 3))])


# D19: stand-ins are data in ONE place. lua/config/npcs.lua (P10) documents a per-NPC `fallback`; it is never read at runtime
# (CharacterCatalog follows characters.lua), so the two must not drift apart. Mutant check: characters.lua mouse_pippin =
# "hedgehog" while npcs.lua says "rabbit" fails this check and names the NPC.
func _npc_fallbacks_match(t) -> void:
	var lua: Node = t.root.get_node_or_null("LuaRuntime")
	var npcs: Dictionary = lua.call("get_npcs") if lua != null and lua.has_method("get_npcs") else {}
	if npcs.is_empty():
		t.skip("npc_fallbacks_match_characters_lua: lua/config/npcs.lua is not loaded (no LuaRuntime or no npcs table)")
		return
	var diffs: Array[String] = []
	var unresolved: Array[String] = []
	var compared := 0
	for npc_id in npcs.keys():
		var row: Dictionary = npcs[npc_id] if npcs[npc_id] is Dictionary else {}
		var visual := str(row.get("visual", ""))
		if visual == "":
			unresolved.append("%s has no visual" % npc_id)
			continue
		if Catalog.resolve(visual) == "":
			unresolved.append("%s: %s resolves to nothing" % [npc_id, visual])
		if row.has("fallback"):
			compared += 1
			var chain_head := Catalog.fallback_of(visual)
			# a visual that is itself a pack character has no chain: its `fallback` then names itself or nothing to compare
			if chain_head != str(row["fallback"]) and not (chain_head == "" and Catalog.exists(visual)):
				diffs.append("%s: npcs.lua fallback=%s but characters.lua %s -> %s" % [npc_id, str(row["fallback"]), visual, chain_head if chain_head != "" else "(no entry)"])
	t.check("npc_fallbacks_match_characters_lua", diffs.is_empty() and unresolved.is_empty() and compared >= 14, "%d NPCs compared (visual -> fallback in npcs.lua equals the chain head in characters.lua, visual resolves); differences %s %s" % [compared, str(diffs), str(unresolved)])


# art predicates of the "with and without bases" scenarios (Callables for CharacterCatalog.set_exists_override)
func _art_with_bases(id: String) -> bool:
	return id.ends_with("_base") or id in PACK or id in NEW_STOCK_IDS


func _art_stock_only(id: String) -> bool:
	return not id.ends_with("_base") and (id in PACK or id in NEW_STOCK_IDS)


func _art_pack_only(id: String) -> bool:
	return id in PACK


# ---------------------------------------------------------------- scene, script shape, filters

func _scene_and_script_shape(t) -> void:
	t.check("generic_scene_exists", ResourceLoader.exists("res://scenes/isometric/chibi.tscn"))
	t.check("per_character_scenes_are_gone", not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://scenes/isometric/characters")) and not ResourceLoader.exists("res://scenes/isometric/characters/fox.tscn"), "ONE chibi.tscn replaces the 12 scenes")
	t.check("standalone_demo_project_is_gone", not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://docs/PongPong_Isometric2D")) and DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://docs/art/isometric_pack/isometric_previews")))
	var consts: Dictionary = (Chibi as GDScript).get_script_constant_map()
	t.check("character_ids_enum_is_gone", not consts.has("CHARACTER_IDS"), "ids are open: any folder with an animations.json")
	var node = Chibi.create("fox")
	var enum_hint := false
	for p in node.get_property_list():
		if p["name"] == "character_id":
			enum_hint = int(p["hint"]) == PROPERTY_HINT_ENUM
			t.expect_eq(int(p["type"]), TYPE_STRING, "character_id is a plain String")
	t.check("character_id_has_no_enum_hint", not enum_hint)
	var packed := load("res://scenes/isometric/chibi.tscn") as PackedScene
	var inst = packed.instantiate()
	var names: Array = []
	for c in inst.get_children():
		names.append(str(c.name))
	t.expect_eq(names, ["Shadow", "Sprite"], "chibi.tscn = Node2D + Shadow + Sprite")
	inst.free()
	node.free()


# ---------------------------------------------------------------- animations.json (display_scale, glow, role)

func _meta_parse(t) -> void:
	var text := '{"character":"x","role":"boss","family":"mushroom","flyer":false,"portrait":"portrait.webp","display_scale":1.5,"glow":{"color":"#6FD6C4","radius_px":14,"strength":0.85},"animations":{"idle":{"frames":4,"fps":5,"loop":true,"sheet":"idle.webp"},"spin":{"frames":8,"fps":14,"loop":true,"sheet":"spin.webp"}}}'
	var m: Dictionary = Chibi.parse_meta("x", text)
	var g: Dictionary = m["glow"]
	t.check("meta_display_scale_and_glow_from_animations_json", is_equal_approx(float(m["display_scale"]), 1.5) and not g.is_empty() and (g["color"] as Color).is_equal_approx(Color("6FD6C4")) and is_equal_approx(float(g["radius_px"]), 14.0) and is_equal_approx(float(g["strength"]), 0.85), str(g))
	t.check("meta_role_family_and_open_clip_names", m["role"] == "boss" and m["family"] == "mushroom" and (m["animations"] as Dictionary).has("spin") and int(m["animations"]["spin"]["frames"]) == 8 and not (m["animations"] as Dictionary).has("walk"), "clip sets come from animations.json (attack, spin, hover ...)")
	var broken: Dictionary = Chibi.parse_meta("fairy", "this is not json")
	t.check("meta_defaults_without_json", is_equal_approx(float(broken["display_scale"]), 1.0) and broken["glow"].is_empty() and (broken["animations"] as Dictionary).has("takeoff") and (broken["animations"] as Dictionary).size() == 15, "a folder without a usable animations.json still gets the pack's clip set")
	var neg: Dictionary = Chibi.parse_meta("x", '{"display_scale": -2}')
	t.check("meta_rejects_non_positive_scale", is_equal_approx(float(neg["display_scale"]), 1.0))
	var fox: Dictionary = Chibi.meta_for("fox")
	t.check("pack_meta_is_the_full_player_set", fox["role"] == "player" and is_equal_approx(float(fox["display_scale"]), 1.0) and fox["glow"].is_empty() and not bool(fox["flyer"]) and (fox["animations"] as Dictionary).size() == 11, "pack characters carry no role field: full clip set = player")


# ---------------------------------------------------------------- import stubs

func _write_text(abs_path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(abs_path.get_base_dir())
	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()


func _rm_rf(abs_dir: String) -> void:
	var d := DirAccess.open(abs_dir)
	if d == null:
		return
	d.include_hidden = true
	for sub in d.get_directories():
		_rm_rf(abs_dir.path_join(sub))
	for f in d.get_files():
		DirAccess.remove_absolute(abs_dir.path_join(f))
	DirAccess.remove_absolute(abs_dir)


func _import_stubs(t) -> void:
	var tool := ProjectSettings.globalize_path("res://tools/import/write_import_stubs.py")
	var py: String = t.python()
	t.check("stub_tool_exists", FileAccess.file_exists(tool), tool)
	# the real project: every sheet carries the S3TC preset (the harness runs this tool on every assets/ change as well)
	var res: Dictionary = t.run_tool(py, PackedStringArray([tool, "--check"]))
	t.check("import_stub_audit_repo_clean", int(res["code"]) == 0, str(res["output"]).strip_edges().get_slice("\n", 0))
	# the tool's own regression suite (27 checks on throwaway trees)
	res = t.run_tool(py, PackedStringArray([ProjectSettings.globalize_path("res://tools/import/selftest.py")]))
	var ids: Dictionary = t.parse_tool_ids(res)
	t.check("import_stub_tool_selftest", int(res["code"]) == 0 and (ids["fail"] as Array).is_empty() and (ids["pass"] as Array).size() >= 20, "%d passed, failed: %s" % [(ids["pass"] as Array).size(), str(ids["fail"])])
	# addendum: tint-ready wardrobe layers must stay lossless; the audit fails on any VRAM compressed preset
	var fixture := ProjectSettings.globalize_path("user://p05_stub_fixture")
	_rm_rf(fixture)
	var imp := "[remap]\n\nimporter=\"texture\"\ntype=\"CompressedTexture2D\"\n\n[params]\n\ncompress/mode=%d\nmipmaps/generate=true\n"
	var layer := fixture.path_join("assets/wardrobe/layers/fox/shirt_linen.loco.webp.import")
	_write_text(layer, imp % 0)
	res = t.run_tool(py, PackedStringArray([tool, "--check", "--root", fixture]))
	var lossless_ok: bool = int(res["code"]) == 0
	_write_text(layer, imp % 2)
	res = t.run_tool(py, PackedStringArray([tool, "--check", "--root", fixture]))
	var vram_fails: bool = int(res["code"]) == 1 and str(res["output"]).contains("wardrobe/layers/fox/shirt_linen.loco.webp.import") and str(res["output"]).contains("compress/mode=2")
	_write_text(layer, imp % 4)
	res = t.run_tool(py, PackedStringArray([tool, "--check", "--root", fixture]))
	var basis_fails: bool = int(res["code"]) == 1
	_write_text(layer, imp % 0)
	res = t.run_tool(py, PackedStringArray([tool, "--check", "--root", fixture]))
	var back_ok: bool = int(res["code"]) == 0
	_rm_rf(fixture)
	t.check("import_stub_audit_layers_lossless", lossless_ok and vram_fails and basis_fails and back_ok, "lossless passes %s, S3TC fails %s, Basis fails %s, fixed passes again %s" % [lossless_ok, vram_fails, basis_fails, back_ok])
	# the committed stubs became S3TC-only imports: no lossless cache next to them
	var sheets := 0
	var imported := 0
	var bad: Array[String] = []
	for id in PACK:
		var meta: Dictionary = Chibi.meta_for(id)
		for clip in (meta["animations"] as Dictionary).keys():
			var sheet_path: String = DIR + id + "/" + str(meta["animations"][clip]["sheet"])
			sheets += 1
			var f := FileAccess.open(sheet_path + ".import", FileAccess.READ)
			if f == null:
				bad.append("%s/%s: no .import" % [id, clip])
				continue
			var body := f.get_as_text()
			f.close()
			if not body.contains("compress/mode=2") or not body.contains("compress/high_quality=false") or not body.contains("mipmaps/generate=true"):
				bad.append("%s/%s: preset missing" % [id, clip])
			if body.contains("path.s3tc="):
				imported += 1
				if body.contains("\npath=") or body.count(".ctex") != 2 or not body.contains(".s3tc.ctex"):
					bad.append("%s/%s: a non-S3TC texture was produced" % [id, clip])
				var dest := body.get_slice("dest_files=[\"", 1).get_slice("\"", 0)
				if not FileAccess.file_exists(dest):
					bad.append("%s/%s: cache file %s is missing" % [id, clip, dest])
	t.check("sheets_import_as_s3tc_from_the_stubs", bad.is_empty() and sheets == 140, "%d pack sheets, %d already imported, problems %s" % [sheets, imported, str(bad.slice(0, 3))])
	if imported == 0:
		t.skip("sheets_import_as_s3tc_from_the_stubs: the project has not been imported yet (run godot --headless --import); only the stub content was checked")


# ---------------------------------------------------------------- warm_clips

## Largest growth between two consecutive samples of a counter ([base, after frame 0, after frame 1, ...]).
func _max_step(samples: Array[int]) -> int:
	var worst := 0
	for i in range(1, samples.size()):
		worst = maxi(worst, samples[i] - samples[i - 1])
	return worst


func _warm_clips(t) -> void:
	var clips := ["walk", "run", "interact", "talk", "hit"]
	# Already loaded textures have completed their upload. Adopting staging refs
	# must not add an idle frame per clip; genuinely cold sheets are paced below.
	var held: Array = []
	for c in clips:
		held.append(load(DIR + "frog/" + str(c) + ".webp"))
	var det = Chibi.create("frog")
	_holder.add_child(det)
	await t.frames(2)
	var det_counts: Array[int] = [det.resident_clip_count()]
	var det_state := {"done": false}
	var det_runner := func() -> void:
		await det.warm_clips(clips)
		det_state["done"] = true
	det_runner.call()                       # runs synchronously up to its first await: the first finalise is counted here
	det_counts.append(det.resident_clip_count())
	var guard := 0
	while not det_state["done"] and guard < 60:
		await t.tree.process_frame
		det_counts.append(det.resident_clip_count())
		guard += 1
	var det_step := _max_step(det_counts)
	var det_frames := det_counts.size() - 1
	t.check("warm_clips_adopts_resident_sheets_without_idle_frames",bool(det_state["done"]) and det_step==clips.size() and det_frames==1 and det_counts.back()==det_counts[0]+clips.size(),"already uploaded clips adopted immediately: %s" % [det_counts])
	held.clear()
	det.queue_free()
	await t.frames(1)

	# 2. the real threaded path (cold sheets): finishes, stays cheap per frame, never takes two sheets in one frame, caches.
	var probe = Chibi.create("capybara")
	_holder.add_child(probe)
	await t.frames(2)
	var state := {"done": false}
	var runner := func() -> void:
		await probe.warm_clips(clips)
		state["done"] = true
	var counts: Array[int] = [probe.resident_clip_count()]
	runner.call()
	counts.append(probe.resident_clip_count())
	var frame_ms: Array[float] = []
	var last := Time.get_ticks_usec()
	var t0 := Time.get_ticks_msec()
	while not state["done"] and Time.get_ticks_msec() - t0 < 20000:
		await t.tree.process_frame
		var now := Time.get_ticks_usec()
		frame_ms.append(float(now - last) / 1000.0)
		last = now
		counts.append(probe.resident_clip_count())
	var worst := 0.0
	var sum := 0.0
	for ms in frame_ms:
		worst = maxf(worst, ms)
		sum += ms
	var mean := sum / maxf(frame_ms.size(), 1)
	var cached := true
	for c in clips:
		cached = cached and ResourceLoader.has_cached(DIR + "capybara/" + str(c) + ".webp")
	t.check("warm_clips_one_sheet_per_frame", bool(state["done"]) and _max_step(counts)<=1 and frame_ms.size()>=clips.size() and counts.back()==counts[0]+clips.size(),"genuinely cold clips per frame: %s" % [counts])
	t.check("warm_clips_worst_frame", t.perf_ok("warm_clips_worst_frame", worst, 40.0), "worst frame %.1f ms while 5 cold clips load (native reference 40)" % worst)
	t.check("warm_clips_finishes_cheap", t.perf_ok("warm_clips_finishes_cheap", mean, 8.0), "5 cold clips finished over %d frames, mean frame %.2f ms, worst %.1f ms, at most %d sheet(s) per frame (SCRIPT cost only: headless = dummy renderer where a GPU upload is free; the real-renderer budget is checked windowed by characters.warm_clips_worst_frame_real_renderer and tests/perf_world.tscn)" % [frame_ms.size(), mean, worst, _max_step(counts)])
	t.check("warm_clips_leaves_sheets_cached", cached)
	probe.play_loop(&"walk")
	t.check("warmed_clip_is_used_immediately", str(probe.sprite.texture.resource_path).ends_with("capybara/walk.webp"))
	t.expect_eq(probe.clip_duration(&"hit"), 3.0 / 11.0, "clip_duration = frames / fps")
	probe.queue_free()
	await t.frames(1)


# ---------------------------------------------------------------- create, motion, actions

func _create_and_motion(t) -> void:
	var fox = Chibi.create("fox")
	var fairy = Chibi.create("fairy")
	_holder.add_child(fox)
	_holder.add_child(fairy)
	fairy.position = Vector2(300, 0)
	await t.frames(3)
	t.check("create_fox_and_fairy", fox != null and fairy != null and fox.is_inside_tree() and fox.character_id == "fox" and fox.resolved_id == "fox" and fairy.character_id == "fairy" and fairy.resolved_id == "fairy" and fox.sprite.texture != null and fairy.sprite.texture != null and fox.sprite.region_enabled, "texture %s" % str(fox.sprite.texture.resource_path if fox.sprite.texture != null else "null"))
	t.expect_eq(fox.get_clip_names().size(), 11, "fox: the 11 player clips")
	t.expect_eq(fairy.get_clip_names().size(), 15, "fairy: 11 + takeoff hover fly flight_land")
	t.expect(fairy.flyer and not fox.flyer and fox.role == "player", "flyer flag and role come from the data")
	t.expect_eq(fox.sprite.region_rect, Rect2(0, 0, 256, 256), "first frame, south row")
	# facing comes from the INPUT, not from the squashed velocity (gameplay patch)
	fox.update_motion(Vector2(0, 100), false, false, false, Vector2(1, 0))
	t.check("update_motion_facing_override", fox.direction_index == 6 and fox.current_clip == &"walk", "velocity points south, input points east -> sheet row E (6), clip walk")
	fox.update_motion(Vector2(0, 100), true)
	t.expect(fox.current_clip == &"run", "running -> run clip")
	fox.update_motion(Vector2.ZERO, false, true)
	t.expect(fox.current_clip == &"fall", "airborne -> fall")
	fox.update_motion(Vector2.ZERO)
	t.expect(fox.current_clip == &"idle", "standing -> idle")
	fairy.update_motion(Vector2(0, 150), false, false, true)
	t.expect(fairy.current_clip == &"fly", "flying and moving -> fly")
	fairy.update_motion(Vector2.ZERO, false, false, true)
	t.expect(fairy.current_clip == &"hover", "flying and still -> hover")
	fairy.update_motion(Vector2.ZERO)
	# action clips: duration, rate, lock, finished signal
	t.expect_near(fairy.clip_duration(&"takeoff"), 0.4, 0.0001, "takeoff = 4 frames at 10 fps")
	t.expect_near(fairy.clip_duration(&"takeoff", 2.0), 0.2, 0.0001, "rate 2 halves it")
	t.expect_eq(fox.clip_duration(&"takeoff"), 0.0, "a clip the character does not have lasts 0 s")
	t.expect(not fox.has_clip(&"takeoff") and fairy.has_clip(&"takeoff"), "has_clip")
	fox.play_action(&"takeoff")
	t.expect(not fox.is_action_playing() and fox.current_clip == &"idle", "an unknown action is ignored")
	fairy.play_action(&"takeoff", 2.0)
	t.expect(fairy.is_action_playing() and fairy.current_clip == &"takeoff", "play_action locks the clip")
	fairy.update_motion(Vector2(0, 200), true)
	t.expect(fairy.current_clip == &"takeoff", "locomotion cannot interrupt an action")
	var got: Variant = await t.wait_signal(fairy.action_finished, 3.0)
	t.check("action_finished_signal", got != null and (got as Array)[0] == &"takeoff" and not fairy.is_action_playing() and fairy.current_clip == &"idle", "takeoff at rate 2 ended after ~0.2 s and went back to idle")
	fox.play_action(&"celebrate")
	fox.cancel_action()
	t.expect(not fox.is_action_playing(), "cancel_action unlocks")
	fox.queue_free()
	fairy.queue_free()
	await t.frames(1)

	# flight clips exist only for fairy and bat (animations.json, sheets on disk and the sprite agree)
	var bad: Array[String] = []
	for id in PACK:
		var probe = Chibi.create(id)
		for clip in FLIGHT_CLIPS.keys():
			var has: bool = probe.has_clip(StringName(clip))
			var file := FileAccess.file_exists(DIR + id + "/" + clip + ".webp")
			if has != (id in FLIERS) or file != (id in FLIERS):
				bad.append("%s/%s has=%s file=%s" % [id, clip, has, file])
		for clip in STD_CLIPS.keys():
			if not probe.has_clip(StringName(clip)):
				bad.append("%s lacks %s" % [id, clip])
		probe.free()
	t.check("flight_clips_only_fairy_bat", bad.is_empty(), str(bad.slice(0, 4)))


# ---------------------------------------------------------------- the contract WardrobeLayers (F5) relies on

func _wardrobe_contract(t) -> void:
	var fox = Chibi.create("fox")
	_holder.add_child(fox)
	await t.frames(2)
	var sprite_child: Node = fox.get_node_or_null("Sprite")
	var shadow_child: Node = fox.get_node_or_null("Shadow")
	var ok: bool = sprite_child is Sprite2D and fox.sprite == sprite_child and shadow_child is Sprite2D and fox.shadow == shadow_child
	ok = ok and fox.current_clip == &"idle" and fox.direction_index == 0
	# base_sprite_offset: read-only, the UNROTATED offset (feet on the node origin: 128 - 200 = -72)
	ok = ok and fox.base_sprite_offset == Vector2(0.0, -72.0) and fox.sprite.offset == fox.base_sprite_offset
	var source := (Chibi as GDScript).source_code
	var from := source.find("var base_sprite_offset")
	var block := source.substr(from, 140).get_slice("\n\n", 0) if from >= 0 else ""
	var has_getter := false
	var has_setter := false
	for line in block.split("\n"):
		var s := line.strip_edges()
		has_getter = has_getter or s.begins_with("get:") or s.begins_with("get(")
		has_setter = has_setter or s.begins_with("set:") or s.begins_with("set(")
	var read_only := has_getter and not has_setter
	t.check("wardrobe_contract_members", ok and read_only, "child Sprite = sprite, current_clip, direction_index, base_sprite_offset read-only %s" % read_only)
	# set_spin rotates about the body centre: the sprite offset leaves base_sprite_offset, the base stays
	fox.set_spin(0.8)
	var spin_ok: bool = is_equal_approx(fox.sprite.rotation, 0.8) and fox.sprite.offset == fox.base_sprite_offset + Vector2(0, 44) and is_equal_approx(fox.sprite.position.y, -44.0) and fox.base_sprite_offset == Vector2(0, -72)
	fox.set_spin(0.0)
	spin_ok = spin_ok and fox.sprite.rotation == 0.0 and fox.sprite.offset == fox.base_sprite_offset and fox.sprite.position.y == 0.0
	t.check("spin_shifts_offset_and_resets", spin_ok, "offset-shift = sprite.offset - base_sprite_offset = (0, 44) while spinning")
	# set_altitude lifts the sprite, keeps the shadow on the ground, fades and widens it
	var shadow_alpha: float = fox.shadow.modulate.a
	var shadow_scale: Vector2 = fox.shadow.scale
	fox.set_altitude(40.0)
	var alt_ok: bool = is_equal_approx(fox.sprite.position.y, -40.0) and fox.shadow.position.y == 4.0 and fox.shadow.modulate.a < shadow_alpha and fox.shadow.scale.x > shadow_scale.x
	fox.set_spin(0.5)
	alt_ok = alt_ok and is_equal_approx(fox.sprite.position.y, -84.0)
	fox.set_spin(0.0)
	fox.set_altitude(0.0)
	alt_ok = alt_ok and is_equal_approx(fox.sprite.position.y, 0.0) and fox.shadow.scale.is_equal_approx(shadow_scale)
	t.check("altitude_lifts_sprite_not_shadow", alt_ok)
	# flash tints ONLY the Sprite child (WardrobeLayers mirrors it) and fades back
	var pink := Color("e58fa6")
	fox.flash(pink, 0.2)
	var flash_now: bool = fox.sprite.modulate.is_equal_approx(pink) and fox.modulate == Color.WHITE
	await t.seconds(0.4)
	t.check("flash_tints_the_sprite_child_and_fades", flash_now and fox.sprite.modulate.is_equal_approx(Color.WHITE), "damage pink on Sprite, back to white")
	# halos of sibling nodes are inserted BEFORE the Sprite (drawn behind it)
	var halo := Sprite2D.new()
	halo.name = "Halo"
	fox.add_child(halo)
	fox.move_child(halo, fox.sprite.get_index())
	var order: Array = []
	for c in fox.get_children():
		order.append(str(c.name))
	t.check("halo_inserted_before_sprite", halo.get_index() < fox.sprite.get_index() and order == ["Shadow", "Halo", "Sprite"], str(order))
	halo.free()
	# display_scale scales sprite and shadow, the roll pivot and the offset shift follow
	var shadow_base: Vector2 = fox.shadow.scale
	fox.display_scale = 1.5
	fox.refresh_visual_scale()
	fox.set_spin(0.5)
	var scale_ok: bool = fox.sprite.scale.is_equal_approx(Vector2(1.5, 1.5)) and fox.shadow.scale.is_equal_approx(shadow_base * 1.5) and is_equal_approx(fox.sprite.position.y, -66.0) and fox.sprite.offset == fox.base_sprite_offset + Vector2(0, 44) and fox.base_sprite_offset == Vector2(0, -72)
	fox.set_spin(0.0)
	fox.display_scale = 1.0
	fox.refresh_visual_scale()
	scale_ok = scale_ok and fox.sprite.scale == Vector2.ONE and fox.shadow.scale.is_equal_approx(shadow_base)
	t.check("display_scale_applies_to_sprite_and_shadow", scale_ok, "scale 1.5: spin pivot 44 px -> 66 px, base_sprite_offset unchanged")
	# the shadow is on the FLOOR layer whatever the character does (fairy shadow over trees, plan 8.5)
	fox.z_index = 20
	var floor_ok: bool = fox.shadow.z_as_relative == false and fox.shadow.z_index == -5 and fox.sprite.z_as_relative == true
	fox.z_index = 0
	t.check("shadow_floor_z", floor_ok, "shadow z_as_relative=false z_index=-5 (above ground -10, below every y-sorted object) even for a flier at z 20")
	t.check("sprite_filter_is_4", fox.sprite.texture_filter == 4 and fox.shadow.texture_filter == 4 and Chibi.SPRITE_FILTER == 4 and ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter") == 2, "CanvasItem LINEAR_WITH_MIPMAPS (4) on Sprite and Shadow, project default 2")
	t.expect(fox.get_portrait() != null, "get_portrait loads portrait.webp of the art folder")
	fox.queue_free()
	await t.frames(1)


# ---------------------------------------------------------------- create() -> configure -> add_child

## What a caller does with create(): configure first, add to the tree afterwards. Nothing of it may be lost in _ready().
func _configure_before_add_child(t) -> void:
	var fox = Chibi.create("fox")
	fox.set_direction_index(3)
	fox.set_facing_direction(Vector2(1, 0))      # the later explicit call wins: E = row 6
	fox.set_altitude(60.0)
	fox.set_spin(0.0)
	_holder.add_child(fox)
	await t.frames(2)
	var alpha_want := lerpf(0.50, 0.20, 60.0 / 135.0)
	var scale_want := 1.0 + minf(60.0 / 400.0, 0.28)
	var set_ok: bool = fox.direction_index == 6 and fox.sprite.region_rect.position.y == 6.0 * 256.0
	var alt_ok: bool = is_equal_approx(fox.sprite.position.y, -60.0) and absf(fox.shadow.modulate.a - alpha_want) < 0.001 and absf(fox.shadow.scale.x - scale_want) < 0.001 and fox.shadow.position.y == 4.0
	t.check("configure_before_add_child", set_ok and alt_ok, "direction_index %d (want 6), sprite row %.0f (want %d), sprite y %.1f (want -60), shadow alpha %.3f (want %.3f), shadow scale %.3f (want %.3f)" % [fox.direction_index, fox.sprite.region_rect.position.y, 6 * 256, fox.sprite.position.y, fox.shadow.modulate.a, alpha_want, fox.shadow.scale.x, scale_want])
	# a sprite whose altitude was never set keeps the scene's own shadow (set_altitude is the only thing that changes the alpha)
	var plain = Chibi.create("fox")
	_holder.add_child(plain)
	await t.frames(2)
	t.expect(plain.shadow.modulate.a == 1.0 and plain.shadow.scale.is_equal_approx(Vector2.ONE) and plain.sprite.position.y == 0.0, "no set_altitude: the shadow keeps the scene's alpha 1.0 and scale 1 (the shadow art carries its own transparency)")
	# `starting_direction` is the initial facing; an explicit direction (even row 0) is never overwritten by it
	var starter = Chibi.create("fox")
	starter.starting_direction = 5
	_holder.add_child(starter)
	var south = Chibi.create("fox")
	south.starting_direction = 5
	south.set_direction_index(0)
	_holder.add_child(south)
	var direct = Chibi.create("fox")
	direct.starting_direction = 5
	direct.direction_index = 2
	_holder.add_child(direct)
	await t.frames(2)
	t.check("starting_direction_is_only_the_default", starter.direction_index == 5 and south.direction_index == 0 and direct.direction_index == 2, "starting_direction 5 -> %d, explicit set_direction_index(0) -> %d, direct direction_index = 2 -> %d" % [starter.direction_index, south.direction_index, direct.direction_index])
	# the editor path (a placed scene, not create()): starting_direction applies and the default character loads
	var placed := (load("res://scenes/isometric/chibi.tscn") as PackedScene).instantiate()
	placed.starting_direction = 3
	_holder.add_child(placed)
	await t.frames(2)
	t.expect(placed.direction_index == 3 and placed.resolved_id == "fox" and placed.sprite.texture != null, "scene instantiated directly: starting_direction 3 and the default character")
	for n in [fox, plain, starter, south, direct, placed]:
		n.queue_free()
	await t.frames(1)


# ---------------------------------------------------------------- fallbacks and open ids

func _fallbacks_and_open_ids(t) -> void:
	# P21 delivered the real art: every roster id now resolves to its own folder (or the head of its _base chain)
	var cases := {
		"hobbit_pip": "hobbit_pip", "hobbit_moss": "hobbit_moss", "hobbit_pip_base": "hobbit_pip", "squirrel": "squirrel", "squirrel_base": "squirrel",
		"fairy_stardust": "fairy_stardust", "fairy_dusk_base": "fairy_dusk", "fairy_king": "fairy_king", "fairy_builder": "fairy_builder", "fox_base": "fox",
		"snurresvamp": "snurresvamp", "mouse_pippin": "mouse_pippin", "hen": "hen",
	}
	var bad: Array[String] = []
	for id in cases.keys():
		var vis = Chibi.create(id)
		_holder.add_child(vis)
		if vis.character_id != id or vis.resolved_id != cases[id]:
			bad.append("%s -> %s (want %s)" % [id, vis.resolved_id, cases[id]])
		vis.queue_free()
	await t.frames(3)
	t.check("create_falls_back_along_characters_lua", bad.is_empty(), "%d ids resolve along characters.lua to their real art folders; %s" % [cases.size(), str(bad)])
	var pip = Chibi.create("hobbit_pip_base")
	_holder.add_child(pip)
	await t.frames(2)
	t.expect(str(pip.sprite.texture.resource_path).contains("/hobbit_pip/idle.webp"), "the base id draws the real hobbit sheets (head of its chain)")
	pip.queue_free()
	# an id nothing resolves for warns (declared as expected) and shows the default character
	var warns_before: int = t.allowed_count("Unknown chibi character")
	var unknown = Chibi.create("no_such_character")
	_holder.add_child(unknown)
	var tricky = Chibi.create("../fox")
	_holder.add_child(tricky)
	# ids are lowercase: on a case-insensitive file system "FOX" would open fox/ (engine 'Case mismatch' warning, character_id
	# "FOX") and on Linux it would not exist; it is refused the same way everywhere (the harness fails on the engine warning)
	var shout = Chibi.create("FOX")
	_holder.add_child(shout)
	await t.frames(2)
	var safe_ok: bool = Catalog.is_safe_id("fox") and Catalog.is_safe_id("hobbit_pip_base") and Catalog.is_safe_id("fairy_stardust")
	for bad_id in ["", "FOX", "Fox", "fOx", "../fox", "fox/idle", "fox idle", "fox.json"]:
		safe_ok = safe_ok and not Catalog.is_safe_id(bad_id) and not Catalog.exists(bad_id)
	t.check("unknown_id_shows_the_default", unknown.resolved_id == "fox" and unknown.character_id == "fox" and tricky.resolved_id == "fox" and t.allowed_count("Unknown chibi character") == warns_before + 3, "warning + fox; a path-like id is refused, never opened")
	t.check("uppercase_ids_are_refused", shout.character_id == "fox" and shout.resolved_id == "fox" and safe_ok and Catalog.resolve("FOX") == "", "FOX -> character_id %s, resolved %s; is_safe_id/exists reject '', FOX, Fox, fOx, ../fox, fox/idle, 'fox idle', fox.json" % [shout.character_id, shout.resolved_id])
	unknown.queue_free()
	tricky.queue_free()
	shout.queue_free()
	# a skin of the data draws through create(), the way Player2D will use it
	for skin in SKIN_CHAINS.keys():
		var vis = Chibi.create(Catalog.visual_for_skin(skin))
		_holder.add_child(vis)
		var want: String = Catalog.resolved_visual_for_skin(skin)
		t.expect(vis.resolved_id == want and vis.sprite != null, "skin %s: create(%s) draws %s" % [skin, Catalog.visual_for_skin(skin), want])
		vis.queue_free()
	await t.frames(2)


# ---------------------------------------------------------------- every direction of every clip

func _pack_cells(t) -> void:
	var t0 := Time.get_ticks_msec()
	var cells := 0
	var empty_cells: Array[String] = []
	var bad_size: Array[String] = []
	var same_rows: Array[String] = []
	var sheets := 0
	for id in PACK:
		var meta: Dictionary = Chibi.meta_for(id)
		var expected: Dictionary = STD_CLIPS.duplicate()
		if id in FLIERS:
			expected.merge(FLIGHT_CLIPS)
		var anims: Dictionary = meta["animations"]
		if anims.size() != expected.size():
			bad_size.append("%s has %d clips, want %d" % [id, anims.size(), expected.size()])
		for clip in expected.keys():
			if not anims.has(clip) or int(anims[clip]["frames"]) != int(expected[clip]):
				bad_size.append("%s/%s frames" % [id, clip])
				continue
			var frames: int = int(expected[clip])
			var path: String = DIR + id + "/" + str(anims[clip]["sheet"])
			sheets += 1
			# the texture the game really loads (S3TC from the committed stub), decoded back to RGBA
			var tex := load(path) as Texture2D
			if tex == null or tex.get_width() != frames * PACK_SHEET_SIZE or tex.get_height() != 8 * PACK_SHEET_SIZE:
				bad_size.append("%s/%s: texture %s" % [id, clip, "missing" if tex == null else "%dx%d" % [tex.get_width(), tex.get_height()]])
				continue
			var gpu: Image = tex.get_image()
			if gpu == null:
				bad_size.append("%s/%s: no image data" % [id, clip])
				continue
			if gpu.is_compressed():
				gpu.decompress()
			var row_hashes := {}
			for dir in 8:
				for f in frames:
					cells += 1
					var cell := gpu.get_region(Rect2i(f * PACK_SHEET_SIZE, dir * PACK_SHEET_SIZE, PACK_SHEET_SIZE, PACK_SHEET_SIZE))
					if cell.is_invisible():
						empty_cells.append("%s/%s dir %d frame %d" % [id, clip, dir, f])
					elif f == 0:
						row_hashes[hash(cell.get_data())] = true
			if row_hashes.size() != 8 and empty_cells.is_empty():
				same_rows.append("%s/%s: %d distinct rows" % [id, clip, row_hashes.size()])
	t.check("pack_eight_distinct_directions", same_rows.is_empty(), "the first frame of all 8 rows differs in every clip of every character %s" % str(same_rows.slice(0, 3)))
	t.check("pack_all_directions_all_clips_render", empty_cells.is_empty() and bad_size.is_empty() and cells == 4816 and sheets == 140, "%d cells (12 characters x 8 directions x every frame) in %d S3TC sheets all non-empty; %d ms; empty %s, problems %s" % [cells, sheets, Time.get_ticks_msec() - t0, str(empty_cells.slice(0, 3)), str(bad_size.slice(0, 3))])
	# a sprite really shows every direction row of every clip (region inside the sheet)
	var vis = Chibi.create("fairy")
	_holder.add_child(vis)
	var region_ok := true
	for clip in vis.get_clip_names():
		vis.play_loop(StringName(clip))
		for dir in 8:
			vis.set_direction_index(dir)
			var rect: Rect2 = vis.sprite.region_rect
			var tex: Texture2D = vis.sprite.texture
			if tex == null or rect.position.y != dir * 256.0 or rect.end.x > tex.get_width() or rect.end.y > tex.get_height() or vis.current_clip != StringName(clip):
				region_ok = false
	t.check("sprite_regions_cover_every_clip_and_direction", region_ok, "fairy: 15 clips x 8 rows")
	vis.free()


func _memory_report(t) -> void:
	var rgba := 0.0
	var s3tc := 0.0
	var per_char: Array[String] = []
	for id in PACK:
		var meta: Dictionary = Chibi.meta_for(id)
		var c_rgba := 0.0
		for clip in (meta["animations"] as Dictionary).keys():
			var frames := int(meta["animations"][clip]["frames"])
			var px := float(frames * PACK_SHEET_SIZE) * float(8 * PACK_SHEET_SIZE)
			c_rgba += px * 4.0
		var c_s3tc := c_rgba / 4.0 * (4.0 / 3.0)         # DXT5: 1 byte per pixel, +1/3 for the mip chain
		rgba += c_rgba
		s3tc += c_s3tc
		per_char.append("%s %.0f/%.0f" % [id, c_rgba / 1048576.0, c_s3tc / 1048576.0])
	t.info("MEMORY all clips of one character resident (RGBA8 MB / S3TC+mips MB): %s" % ", ".join(per_char))
	t.info("MEMORY the 12 pack characters with every clip resident: %.0f MB RGBA8 -> %.0f MB S3TC with mipmaps (the residency rule keeps only the clips in use: plan 6.2)" % [rgba / 1048576.0, s3tc / 1048576.0])
	t.info("MEMORY engine counters: static %.1f MB, texture memory in the render server %.1f MB (0 in headless: dummy renderer), objects %d" % [Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, int(Performance.get_monitor(Performance.OBJECT_COUNT))])
	t.check("memory_report", rgba > 400.0 * 1048576.0 and s3tc < rgba * 0.4, "%.0f MB RGBA8 vs %.0f MB S3TC: the S3TC import is what makes 12 resident characters affordable" % [rgba / 1048576.0, s3tc / 1048576.0])


# ---------------------------------------------------------------- windowed: the line-up has pixels

func run_windowed(t) -> void:
	var world: Dictionary = PerfWorld.make_world(t.root, PerfWorld.GAME_ZOOM)
	var objects: Node2D = world["objects"]
	var step := Vector2(PerfWorld.TILE_W * 2.0, 0.0)
	var first := Vector2(-step.x * (PACK.size() - 1) * 0.5, 0.0)
	var row: Array = PerfWorld.place_cast(objects, PACK, first, step, PACK.size(), PerfWorld.SE, &"idle")
	(world["camera"] as Camera2D).position = Vector2(0, -30)
	await t.frames(20)
	var img: Image = await t.capture("cast_game_zoom")
	if img == null:
		return
	# canvas coordinates (1280x720 base, camera included) -> image pixels (the window may be hiDPI)
	var k := float(img.get_width()) / float(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var ground: Dictionary = t.region_stats(img, Rect2i(int(20 * k), int(20 * k), int(200 * k), int(80 * k)))
	t.expect(int(ground["distinct"]) >= 1, "the ground is drawn above the clear colour")
	var all_ok := true
	var report: Array[String] = []
	for n in row.size():
		var vis: Node2D = row[n]
		var screen: Vector2 = vis.get_global_transform_with_canvas().origin * k
		var rect := Rect2i(int(screen.x - 36.0 * k), int(screen.y - 84.0 * k), int(72.0 * k), int(84.0 * k))
		var s: Dictionary = t.region_stats(img, rect, 2)
		# a figure over grass: many more colours and more contrast than the plain ground sample
		var good: bool = int(s["distinct"]) > int(ground["distinct"]) + 6 and float(s["luma_std"]) > 0.03
		all_ok = all_ok and good
		report.append("%s:%d/%.2f" % [PACK[n], int(s["distinct"]), float(s["luma_std"])])
	t.check("cast_pixels", all_ok, "every one of the 12 pack figures has pixels at game zoom (colours/luma-std per figure: %s; ground %d colours)" % [", ".join(report), int(ground["distinct"])])
	await _windowed_budgets(t, objects)
	(world["root"] as Node).queue_free()
	await t.frames(2)


## The plan 8.6 budgets in the REAL renderer (the headless dummy renderer cannot see a GPU upload), measured with the same
## helpers as tests/perf_world.gd, whose budget constants are asserted here (vsync is switched off for the measurement).
## NOISE RULE (perf_world.gd): every budget is the best of 3 repetitions, because load on a shared machine only adds time while
## a real regression is in every repetition (this section ran at load averages of 22-30 while it was written).
func _windowed_budgets(t, objects: Node2D) -> void:
	var old_cap: Dictionary = PerfWorld.uncap()
	var load_before: Dictionary = PerfWorld.machine_load()
	await t.frames(30)
	var suite: Dictionary = await PerfWorld.measure_warm_suite(t.tree, objects, ["cat", "capybara", "frog"], PerfWorld.WARM_LIST, PerfWorld.WARM_PLAY_LIST)
	var cold: Dictionary = await PerfWorld.measure_cold_first_play(t.tree, objects, ["monkey", "bear", "raccoon"], ["walk", "run", "interact", "celebrate", "talk"], ["interact", "celebrate"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var crowd: Array = []
	PerfWorld.fill_crowd(objects, crowd, 100, rng)
	await t.seconds(1.0)
	var m: Dictionary = await PerfWorld.measure_frames_best(t.tree, 2.0)
	for v in crowd:
		v.queue_free()
	await t.frames(2)
	PerfWorld.restore_cap(old_cap)
	var load_after: Dictionary = PerfWorld.machine_load()
	var busy: bool = bool(load_before["busy"]) or bool(load_after["busy"])
	var load_text := "%s before, %s after" % [load_before["text"], load_after["text"]]
	# warm_clips on characters whose sheets are cold: the worst frame stays inside the 8 ms budget (the pacing guard itself is the headless
	# characters.warm_clips_one_sheet_per_frame; this is the real-renderer cost of the sheets)
	_judge(t, "warm_clips_worst_frame_real_renderer", bool(suite["done"]) and int(suite["frames"]) >= PerfWorld.WARM_LIST.size() and float(suite["worst_ms"]) < PerfWorld.BUDGET_WARM_FRAME_MS, busy, "5 cold S3TC sheets finalised over %d frames in %.0f ms, worst frame %.1f ms = best of 3 characters %s (limit %.0f ms; a synchronous load of the five sheets in one frame measured 12.6-23.5 ms); %s" % [int(suite["frames"]), float(suite["wall_ms"]), float(suite["worst_ms"]), str(suite["all_worst_ms"]), PerfWorld.BUDGET_WARM_FRAME_MS, load_text])
	# after warm_clips the first play of a clip is cheap
	_judge(t, "warmed_first_play_under_budget", float(suite["warmed_worst_ms"]) < PerfWorld.BUDGET_WARMED_MS, busy, "first play of 4 warmed clips, slowest at its best of 3: %.1f ms (limit %.0f ms) %s; %s" % [float(suite["warmed_worst_ms"]), PerfWorld.BUDGET_WARMED_MS, str(suite["warmed_best"]), load_text])
	# the first play of a clip nobody loaded yet (no warm_clips): synchronous load + upload inside one frame (plan 8.6: < 40 ms)
	_judge(t, "unwarmed_first_play_under_budget", float(cold["worst_ms"]) < PerfWorld.BUDGET_UNWARMED_MS, busy, "first play of 5 unloaded clips on 3 fresh characters, slowest clip at its best: %.1f ms (limit %.0f ms); all samples %s; %s" % [float(cold["worst_ms"]), PerfWorld.BUDGET_UNWARMED_MS, str(cold["all"]), load_text])
	# 100 animated characters at game zoom: the frame stays inside the 8 ms budget
	_judge(t, "hundred_characters_frame_budget", float(m["ms"]) < PerfWorld.BUDGET_100_MS, busy, "100 animated characters: mean frame %.2f ms = best of 3 windows %s (%.0f fps, worst frame %.1f ms), limit %.0f ms; %s" % [float(m["ms"]), str(m["all_ms"]), float(m["fps"]), float(m["worst_ms"]), PerfWorld.BUDGET_100_MS, load_text])


## A pass is a pass (load only adds time). A miss is a failure on a quiet machine and a visible SKIP, not a verdict, on a busy
## one: a budget cannot be judged while other jobs eat the cores (the same rule as tests/perf_world.gd, exit code 3 there).
func _judge(t, check_name: String, within: bool, busy: bool, detail: String) -> void:
	if within or not busy:
		t.check(check_name, within, detail)
	else:
		t.skip("characters.%s NOT JUDGED: over budget while the machine is busy, rerun when quiet. %s" % [check_name, detail])
