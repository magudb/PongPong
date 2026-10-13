extends RefCounted
## Section rarity (package P10, addendum 4.4): the one rarity ladder (scripts/data/rarity.gd + lua/config/rarity.lua), the
## sort order, the UI colour rules of the guide (gold = focus only, no red, legendary the only dark tile), the contrast
## arithmetic of the legendary tile, and the perk formula (scripts/data/perks.gd) incl. the discount numbers 1360 / 1280 / 1440.
##
## Named checks: rarity.ladder_ids_and_order, rarity.sort_order, rarity.ui_colours_no_gold_no_red, rarity.perks_formula,
## rarity.no_ring_equals_focus_gold, rarity.label_not_damage_colour (all five labels CIEDE2000 >= 10 from Tornebaer b3436b),
## rarity.legendary_pairs_contrast, rarity.label_contrast, rarity.sell_ratio_unique_zero (+ a few supporting checks).
## The icon FILES are checked by A1 / A2 (art_home.icons_night_rim, art_wardrobe.icons_night_rim); this section is pure
## colour arithmetic and data.
const SECTION := "rarity"
const TIMEOUT_S := 60.0

const PARCHMENT := "f4e6c4"
const NIGHT_TRACK := "2f3654"

## fakes a manager autoload for the perk formula: every perk source answers fixed numbers
class FakeSource extends Node:
	var points: Dictionary = {}
	var energy_bonus: float = 0.0
	func gear_points(kind: String) -> float:
		return float(points.get(kind, 0.0))
	func perk_points(kind: String) -> float:
		return float(points.get(kind, 0.0))
	func max_energy_bonus() -> float:
		return energy_bonus

## fakes GameManager for the race lookup only
class FakeGame extends Node:
	var character_type: int = 0


func run(t) -> void:
	var lr: Node = t.autoload("LuaRuntime")
	_ladder(t, lr)
	_sorting(t, lr)
	_ui_colours(t)
	_contrast(t)
	_perks(t)


# ---------------------------------------------------------------------------------------------------- the ladder

func _ladder(t, lr: Node) -> void:
	var ids: Array[StringName] = Rarity.IDS
	var names: Array[String] = []
	for i in ids:
		names.append(str(i))
	t.check("ladder_ids_and_order", names == ["normal", "uncommon", "rare", "unique", "legendary"], str(names))
	t.expect(Rarity.ids() == Rarity.IDS, "the config `order` is the same five ids in the same order")
	for i in ids.size():
		t.expect(Rarity.rank(ids[i]) == i + 1, "rank(%s) == %d (content numbering 1..5)" % [ids[i], i + 1])
		t.expect(Rarity.pips(ids[i]) == i, "pips(%s) == rank - 1 == %d" % [ids[i], i])
	t.expect(Rarity.normalize("common") == &"normal" and Rarity.normalize("") == &"normal", "`common` is an alias of normal, no rarity means normal")
	t.expect(Rarity.is_valid("legendary") and Rarity.is_valid("common") and not Rarity.is_valid("epic") and not Rarity.is_valid("order"), "`epic` (and `order`) are not rarities")
	t.expect(Rarity.shape("normal") == "none" and Rarity.shape("uncommon") == "leaf" and Rarity.shape("rare") == "diamond" and Rarity.shape("unique") == "sparkle" and Rarity.shape("legendary") == "star", "one pip SHAPE per rarity: colour is never the only cue")
	t.expect(Rarity.label_key("rare") == "RARITY_RARE" and Rarity.label_key("common") == "RARITY_NORMAL", "label keys are RARITY_<ID> (finds.csv owns them)")
	# data: the Lua file and the built-in fallback are the same numbers
	var from_lua: Variant = lr.get_config("rarity_tiers", null)
	t.check("config_present", typeof(from_lua) == TYPE_DICTIONARY and (from_lua as Dictionary).has("legendary"), "rarity_tiers from lua/config/rarity.lua")
	var builtin := Rarity.builtin_tiers()
	var same := typeof(from_lua) == TYPE_DICTIONARY
	if same:
		for k in builtin:
			if builtin[k] != (from_lua as Dictionary).get(k):
				same = false
				t.fail("built-in fallback differs from rarity.lua at `%s`: %s vs %s" % [k, builtin[k], (from_lua as Dictionary).get(k)])
	t.check("fallback_equals_lua", same, "the built-in copy is byte-identical in content to config.rarity_tiers")
	# keepsakes
	t.expect(not Rarity.is_one_of_a_kind("rare") and Rarity.is_one_of_a_kind("unique") and Rarity.is_one_of_a_kind("legendary"), "only unique and legendary are one-of-a-kind")
	t.expect(not Rarity.sellable("unique") and not Rarity.buyable("legendary") and not Rarity.craftable("unique") and Rarity.sellable("rare") and Rarity.buyable("rare") and Rarity.craftable("normal"), "keepsakes cannot be sold, bought or crafted")
	# numbers: prices, weights and decor are strictly monotone along the ladder
	var prices_ok := true
	var weights_ok := true
	var decor_ok := true
	for i in range(1, ids.size()):
		prices_ok = prices_ok and Rarity.base_price(ids[i], "furniture") > Rarity.base_price(ids[i - 1], "furniture") and Rarity.base_price(ids[i], "clothing") > Rarity.base_price(ids[i - 1], "clothing")
		weights_ok = weights_ok and Rarity.find_weight(ids[i]) < Rarity.find_weight(ids[i - 1])
		decor_ok = decor_ok and Rarity.decor(ids[i]) > Rarity.decor(ids[i - 1])
	t.check("ladder_numbers_monotone", prices_ok and weights_ok and decor_ok, "price up, find weight down, decor up with every step")
	t.expect(Rarity.find_weight("normal") == 100.0 and Rarity.find_weight("rare") == 12.0 and Rarity.drop_weight("legendary") == 1.0, "find weights 100 / 40 / 12 / 3 / 1 (drop_weight is the prototype's name)")
	t.expect(Rarity.base_price("rare", "furniture") == 1600 and Rarity.base_price("rare", "clothing") == 800, "rare: 1600 furniture / 800 clothing (the 1360 / 1280 / 1440 contract is built on 1600)")
	# sell ratio: unique and legendary sell for nothing (keepsakes), the others for a share
	var sell_ok := Rarity.sell_ratio("unique") == 0.0 and Rarity.sell_ratio("legendary") == 0.0
	for r in ["normal", "uncommon", "rare"]:
		sell_ok = sell_ok and Rarity.sell_ratio(r) > 0.0 and Rarity.sell_ratio(r) <= 0.5
	t.check("sell_ratio_unique_zero", sell_ok, "unique and legendary 0.0, the three others 0 < ratio <= 0.5")


# ---------------------------------------------------------------------------------------------------- sorting

func _sorting(t, lr: Node) -> void:
	var rarity_of := {"bed_fyr": "normal", "bed_himmel": "uncommon", "bed_valnoed": "rare", "bed_svamp": "unique", "bed_maane": "legendary", "alpha_rare": "rare", "zeta_rare": "rare"}
	var rarity_fn := func(id: Variant) -> Variant: return rarity_of.get(str(id), "normal")
	var ids: Array = ["bed_fyr", "bed_maane", "bed_himmel", "bed_svamp", "bed_valnoed"]
	var desc := Rarity.sorted(ids, rarity_fn)
	t.check("sort_order", desc == ["bed_maane", "bed_svamp", "bed_valnoed", "bed_himmel", "bed_fyr"], "legendary, unique, rare, uncommon, normal: %s" % str(desc))
	t.expect(Rarity.sorted(ids, rarity_fn, Callable(), false) == ["bed_fyr", "bed_himmel", "bed_valnoed", "bed_svamp", "bed_maane"], "ascending is the reverse ladder")
	var tie := Rarity.sorted(["zeta_rare", "bed_valnoed", "alpha_rare"], rarity_fn)
	t.expect(tie == ["alpha_rare", "bed_valnoed", "zeta_rare"], "equal rarity: by name ascending (%s)" % str(tie))
	var by_title := Rarity.sorted(["zeta_rare", "alpha_rare"], rarity_fn, func(id: Variant) -> Variant: return {"zeta_rare": "Aa", "alpha_rare": "Zz"}[str(id)])
	t.expect(by_title == ["zeta_rare", "alpha_rare"], "the tie-break uses the name function (display names)")
	t.expect(Rarity.compare("legendary", "rare") == -1 and Rarity.compare("normal", "rare") == 1 and Rarity.compare("rare", "rare") == 0 and Rarity.compare("common", "normal") == 0, "compare: -1 means `a` comes first in a descending list")
	# real definitions: whatever items the game defines sort with non-increasing rank
	var all_ids: Array = lr.get_all_item_ids()
	var sorted_ids := Rarity.sorted_ids(all_ids)
	var monotone := sorted_ids.size() == all_ids.size()
	var last_rank := 99
	for id in sorted_ids:
		var r := Rarity.rank(ItemKinds.rarity_of(id))
		monotone = monotone and r <= last_rank
		last_rank = r
	t.expect(monotone, "Rarity.sorted_ids over %d defined items never goes up in rank" % all_ids.size())
	var ranks: Dictionary = {}
	for id in all_ids:
		ranks[Rarity.rank(ItemKinds.rarity_of(id))] = true
	t.expect(ranks.size() >= 2, "the legacy items already use more than one rarity (%s)" % str(ranks.keys()))


# ---------------------------------------------------------------------------------------------------- colours

func _ui_colours(t) -> void:
	var gold := Color.html("e3c372")
	var damage := Color.html(Rarity.DAMAGE_COLOUR)
	var rings: Array[String] = []
	var ring_clash := false
	var gold_clash := false
	var red_found: Array[String] = []
	var dark_ones: Array[String] = []
	for r in Rarity.IDS:
		var u := Rarity.ui(r)
		for key in ["fill", "ring", "label", "pip", "icon_rim"]:
			var c: Color = u[key]
			if c.a <= 0.0:
				continue
			if _same(c, gold):
				gold_clash = true
				t.fail("%s.%s is the focus gold" % [r, key])
			if _is_red(c):
				red_found.append("%s.%s %s" % [r, key, c.to_html(false)])
		var ring: Color = u["ring"]
		if bool(u["has_ring"]):
			rings.append(ring.to_html(false))
			if _same(ring, gold):
				ring_clash = true
		if bool(u["night"]):
			dark_ones.append(str(r))
		t.expect(Rarity.pips(r) == Rarity.rank(r) - 1, "%s: pip count follows the rank" % r)
	t.check("no_ring_equals_focus_gold", not ring_clash and not gold_clash, "no rarity ring is e3c372 (gold means focus only)")
	t.expect(rings.size() == 4 and _unique(rings), "four distinct ring colours (normal has the ink border only): %s" % str(rings))
	t.expect(not Rarity.ui("normal")["has_ring"] and Rarity.ui("normal")["ring_w"] == 0, "normal has no ring")
	t.check("ui_colours_no_gold_no_red", not gold_clash and red_found.is_empty() and dark_ones == ["legendary"], "no gold, no red %s, only legendary is dark %s" % [str(red_found), str(dark_ones)])
	t.expect(_same(Rarity.ui("legendary")["fill"], Color.html(NIGHT_TRACK)), "legendary tile = the night tile 2f3654")
	t.expect(_same(Rarity.ui("legendary")["ring"], Color.html("a9d3e0")) and _same(Rarity.ui("legendary")["pip"], Color.html("f2c14e")) and _same(Rarity.ui("legendary")["icon_rim"], Color.html("e4eff5")), "legendary ring Himmel a9d3e0, gold pips f2c14e, icon rim e4eff5 (CD1)")
	t.expect(_same(Rarity.ui("rare")["fill"], Color.html("e2d8f4")) and _same(Rarity.ui("rare")["ring"], Color.html("9b86d6")), "rare = the guide's own slot (fill e2d8f4, ring 9b86d6)")
	t.expect(Rarity.ui("uncommon")["label"] == Color.html("3f6b22") and Rarity.ui("unique")["label"] == Color.html("7d2e59"), "uncommon label 3f6b22 and unique label 7d2e59 (review fixes)")
	# the five labels keep their distance from the damage colour (the word "Unik" sits next to missing-ingredient rows)
	var worst := 999.0
	var worst_id := ""
	for r in Rarity.IDS:
		var d := delta_e2000(_lab(Rarity.ui(r)["label"]), _lab(damage))
		if d < worst:
			worst = d
			worst_id = str(r)
	t.check("label_not_damage_colour", worst >= 10.0, "closest label to Tornebaer: %s dE2000 %.1f (>= 10)" % [worst_id, worst])
	# the implementation reproduces the plan's evidence numbers and the published reference pairs
	var unique_d := delta_e2000(_lab(Color.html("7d2e59")), _lab(damage))
	var old_d := delta_e2000(_lab(Color.html("a8456a")), _lab(damage))
	t.expect(absf(unique_d - 13.0) < 0.25, "unique label vs Tornebaer = %.2f (plan: 13.0)" % unique_d)
	t.expect(absf(old_d - 2.2) < 0.25, "the old unique label a8456a vs Tornebaer = %.2f (plan: 2.2, the defect)" % old_d)
	var refs := [
		[Vector3(50.0, 2.6772, -79.7751), Vector3(50.0, 0.0, -82.7485), 2.0425],
		[Vector3(50.0, 0.0, 0.0), Vector3(50.0, -1.0, 2.0), 2.3669],
		[Vector3(50.0, 2.5, 0.0), Vector3(50.0, 0.0, -2.5), 4.3065],
		[Vector3(50.0, 2.49, -0.001), Vector3(50.0, -2.49, 0.0009), 7.1792],
	]
	var ref_ok := true
	for p in refs:
		var got := delta_e2000(p[0], p[1])
		if absf(got - float(p[2])) > 0.001:
			ref_ok = false
			t.fail("CIEDE2000 reference pair %s %s: got %.4f want %.4f" % [p[0], p[1], got, float(p[2])])
	t.expect(ref_ok, "CIEDE2000 matches the published Sharma/Wu/Dalal reference pairs")


# ---------------------------------------------------------------------------------------------------- contrast

func _contrast(t) -> void:
	var ink := Color.html(Rarity.INK)
	var u := Rarity.ui("legendary")
	var night: Color = u["fill"]
	var rim: Color = u["icon_rim"]
	var pip: Color = u["pip"]
	var c1 := contrast(ink, rim)
	var c2 := contrast(rim, night)
	var c3 := contrast(pip, night)
	t.check("legendary_pairs_contrast", c1 >= 7.0 and c2 >= 7.0 and c3 >= 7.0, "ink vs icon rim %.1f, icon rim vs night %.1f, gold pip vs night %.1f (all >= 7; plan: 12.4 / 10.1)" % [c1, c2, c3])
	t.expect(contrast(ink, night) < 2.0, "(control) ink on the night tile alone is %.2f: that is why the pale rim exists" % contrast(ink, night))
	var parchment := Color.html(PARCHMENT)
	var all_ok := true
	var worst := 99.0
	for r in Rarity.IDS:
		var label: Color = Rarity.ui(r)["label"]
		var c := contrast(label, parchment)
		worst = minf(worst, c)
		if c < 4.5:
			all_ok = false
			t.fail("label of %s on parchment: contrast %.2f < 4.5" % [r, c])
	t.check("label_contrast", all_ok, "all five labels on parchment >= 4.5 (worst %.2f)" % worst)
	var on_tile_ok := true
	for r in ["normal", "uncommon", "rare", "unique"]:
		var cc := contrast(Rarity.ui(r)["label"], Rarity.ui(r)["fill"])
		if cc < 4.5:
			on_tile_ok = false
			t.fail("label of %s on its own tile: contrast %.2f < 4.5" % [r, cc])
	t.expect(on_tile_ok, "labels on their own tile >= 4.5 (the rarity word inside the slot)")


# ---------------------------------------------------------------------------------------------------- perks

func _perks(t) -> void:
	Svc.clear_overrides()
	var failed_before: int = t.failed
	var gear := FakeSource.new()
	var furniture := FakeSource.new()
	var home := FakeSource.new()
	var game := FakeGame.new()
	var ok_all := true
	# --- no managers: speed, energy and luck are 0 (the managers arrive in waves 4-5); the discount is the race perk only
	if Svc.node("WardrobeManager") == null and Svc.node("FurnitureManager") == null and Svc.node("HomeManager") == null:
		t.expect(Perks.total("speed") == 0.0 and Perks.total("energy") == 0.0 and Perks.total("luck") == 0.0 and Perks.total("discount") <= 0.10 + 0.000001, "without wardrobe / furniture / home managers speed, energy and luck are 0 and the discount is the race share only")
	Svc.override("WardrobeManager", gear)
	Svc.override("FurnitureManager", furniture)
	Svc.override("HomeManager", home)
	Svc.override("GameManager", game)
	# --- the discount contract: 1600 gold -> 1360 fox (gear .10 + friend .05), 1280 hobbit, 1440 hobbit alone
	game.character_type = 0
	gear.points = {"discount": 0.10}
	furniture.points = {}
	var fox := Perks.discounted_price(1600, 0.05)
	game.character_type = 2
	var hobbit := Perks.discounted_price(1600, 0.05)
	gear.points = {}
	var hobbit_alone := Perks.discounted_price(1600, 0.0)
	t.expect(fox == 1360 and hobbit == 1280 and hobbit_alone == 1440, "1600-gold rare piece: fox with gear .10 + 10 hearts .05 pays %d (1360), the same hobbit %d (1280), hobbit alone %d (1440)" % [fox, hobbit, hobbit_alone])
	ok_all = ok_all and fox == 1360 and hobbit == 1280 and hobbit_alone == 1440
	t.expect(is_equal_approx(Perks.total("discount"), 0.10), "hobbit race discount alone: Perks.total(discount) == 0.10")
	var b := Perks.breakdown("discount")
	t.expect(is_equal_approx(float(b["race"]), 0.10) and float(b["gear"]) == 0.0, "breakdown names the race share (%s)" % str(b))
	game.character_type = 0
	t.expect(Perks.total("discount") == 0.0, "a fox has no race discount")
	# --- gear cap: the best gear in the world cannot exceed the caps
	gear.points = {"speed": 0.30, "energy": 35.0, "luck": 0.40, "discount": 0.25}
	furniture.points = {}
	t.expect(is_equal_approx(Perks.total("speed"), 0.15) and Perks.breakdown("speed")["at_cap"], "speed: gear .30 is capped at .15 and the UI says maks.")
	t.expect(is_equal_approx(Perks.total("energy"), 20.0), "energy: gear 35 is capped at 20")
	t.expect(is_equal_approx(Perks.total("luck"), 0.20), "luck: gear .40 is capped at .20")
	t.expect(is_equal_approx(Perks.total("discount"), 0.15), "discount: gear .25 is capped at .15 (fox)")
	# --- sources add up, then the global clamps
	gear.points = {"speed": 0.10, "energy": 12.0, "luck": 0.05, "discount": 0.05}
	furniture.points = {"speed": 0.50, "energy": 9.0, "luck": 0.05, "discount": 0.02}
	home.energy_bonus = 6.0
	t.expect(is_equal_approx(Perks.total("speed"), 0.10), "speed is the gear alone (furniture never adds speed)")
	t.expect(is_equal_approx(Perks.total("energy"), 27.0), "energy = gear 12 + furniture 9 + home 6 = 27")
	t.expect(is_equal_approx(Perks.total("luck"), 0.10), "luck = gear .05 + furniture .05")
	t.expect(is_equal_approx(Perks.total("discount"), 0.07), "discount = gear .05 + furniture .02 (+ race 0 for a fox)")
	gear.points = {"energy": 35.0}                      # capped to 20
	furniture.points = {"energy": 30.0}
	home.energy_bonus = 30.0
	var e := Perks.breakdown("energy")
	t.expect(is_equal_approx(Perks.total("energy"), 60.0) and e["at_cap"] and is_equal_approx(float(e["raw"]), 80.0) and is_equal_approx(float(e["gear_capped"]), 20.0), "energy_total clamps 20 + 30 + 30 = 80 to 60 (%s)" % str(e))
	gear.points = {"luck": 0.20}
	furniture.points = {"luck": 0.10}
	t.expect(is_equal_approx(Perks.total("luck"), 0.20), "luck clamps .20 + .10 to .20")
	game.character_type = 2
	gear.points = {"discount": 0.15}
	furniture.points = {"discount": 0.10}
	t.expect(is_equal_approx(Perks.total("discount"), 0.20), "discount_total clamps .15 gear + .10 furniture + .10 hobbit = .35 to .20")
	t.expect(Perks.discounted_price(1600, 0.10) == 1280, "the final price never goes below the 20% cap even with a friend discount on top")
	t.expect(Perks.label_key("discount") == "PERK_DISCOUNT" and Perks.KINDS == ["speed", "energy", "luck", "discount"], "the four perk kinds and their finds.csv label keys")
	t.expect(Perks.cap("speed") == 0.15 and Perks.cap("energy") == 20.0 and Perks.cap("luck") == 0.2 and Perks.cap("discount") == 0.15, "the caps are the perk_caps of rarity.lua")
	var caps := Perks.caps()
	t.expect(caps["energy_total"] == 60.0 and caps["discount_total"] == 0.2, "global clamps energy_total 60 and discount_total 0.2")
	var from_lua: Dictionary = LuaData.dict(Svc.lua_config("perk_caps", {}))
	var builtin := Perks.builtin_caps()
	var caps_same := not from_lua.is_empty()
	for k in builtin:
		caps_same = caps_same and is_equal_approx(float(from_lua.get(k, -1.0)), float(builtin[k]))
	t.expect(caps_same, "the built-in perk caps equal config.perk_caps of rarity.lua")
	# --- cleanup (overrides must never leak into other sections)
	Svc.clear_overrides()
	for n in [gear, furniture, home, game]:
		n.free()
	t.check("perks_formula", ok_all and t.failed == failed_before, "gear caps, furniture + home + race sources, global clamps, discount 1360 / 1280 / 1440")


# ---------------------------------------------------------------------------------------------------- colour maths

static func _same(a: Color, b: Color) -> bool:
	return a.to_html(false) == b.to_html(false)


static func _unique(items: Array[String]) -> bool:
	var seen := {}
	for s in items:
		if seen.has(s):
			return false
		seen[s] = true
	return true


## "red" for the guide: hue within 18 degrees of 0, clearly saturated and not dark. Tornebaer (hue 339) and the pinks are not red.
static func _is_red(c: Color) -> bool:
	var h := c.h * 360.0
	return (h <= 18.0 or h >= 348.0) and c.s >= 0.45 and c.v >= 0.35


static func _lin(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func _rel_luminance(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


## WCAG contrast ratio of two colours (1..21)
static func contrast(a: Color, b: Color) -> float:
	var la := _rel_luminance(a)
	var lb := _rel_luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _lab(c: Color) -> Vector3:
	var r := _lin(c.r)
	var g := _lin(c.g)
	var bl := _lin(c.b)
	var x := (0.4124564 * r + 0.3575761 * g + 0.1804375 * bl) / 0.95047
	var y := 0.2126729 * r + 0.7151522 * g + 0.0721750 * bl
	var z := (0.0193339 * r + 0.1191920 * g + 0.9503041 * bl) / 1.08883
	var fx := _lab_f(x)
	var fy := _lab_f(y)
	var fz := _lab_f(z)
	return Vector3(116.0 * fy - 16.0, 500.0 * (fx - fy), 200.0 * (fy - fz))


static func _lab_f(v: float) -> float:
	return pow(v, 1.0 / 3.0) if v > 216.0 / 24389.0 else (24389.0 / 27.0 * v + 16.0) / 116.0


## CIEDE2000 colour difference of two CIELAB colours (Sharma, Wu, Dalal 2005).
static func delta_e2000(c1: Vector3, c2: Vector3) -> float:
	var l1 := c1.x
	var a1 := c1.y
	var b1 := c1.z
	var l2 := c2.x
	var a2 := c2.y
	var b2 := c2.z
	var cab1 := sqrt(a1 * a1 + b1 * b1)
	var cab2 := sqrt(a2 * a2 + b2 * b2)
	var cbar7 := pow((cab1 + cab2) / 2.0, 7.0)
	var g := 0.5 * (1.0 - sqrt(cbar7 / (cbar7 + pow(25.0, 7.0))))
	var a1p := (1.0 + g) * a1
	var a2p := (1.0 + g) * a2
	var c1p := sqrt(a1p * a1p + b1 * b1)
	var c2p := sqrt(a2p * a2p + b2 * b2)
	var h1p := _hue_deg(b1, a1p)
	var h2p := _hue_deg(b2, a2p)
	var d_l := l2 - l1
	var d_c := c2p - c1p
	var d_h_angle := 0.0
	if c1p * c2p != 0.0:
		d_h_angle = h2p - h1p
		if d_h_angle > 180.0:
			d_h_angle -= 360.0
		elif d_h_angle < -180.0:
			d_h_angle += 360.0
	var d_h := 2.0 * sqrt(c1p * c2p) * sin(deg_to_rad(d_h_angle / 2.0))
	var lbar := (l1 + l2) / 2.0
	var cbarp := (c1p + c2p) / 2.0
	var hbarp := h1p + h2p
	if c1p * c2p != 0.0:
		if absf(h1p - h2p) <= 180.0:
			hbarp = (h1p + h2p) / 2.0
		elif h1p + h2p < 360.0:
			hbarp = (h1p + h2p + 360.0) / 2.0
		else:
			hbarp = (h1p + h2p - 360.0) / 2.0
	var t := 1.0 - 0.17 * cos(deg_to_rad(hbarp - 30.0)) + 0.24 * cos(deg_to_rad(2.0 * hbarp)) + 0.32 * cos(deg_to_rad(3.0 * hbarp + 6.0)) - 0.20 * cos(deg_to_rad(4.0 * hbarp - 63.0))
	var d_theta := 30.0 * exp(-pow((hbarp - 275.0) / 25.0, 2.0))
	var rc := 2.0 * sqrt(pow(cbarp, 7.0) / (pow(cbarp, 7.0) + pow(25.0, 7.0)))
	var sl := 1.0 + (0.015 * pow(lbar - 50.0, 2.0)) / sqrt(20.0 + pow(lbar - 50.0, 2.0))
	var sc := 1.0 + 0.045 * cbarp
	var sh := 1.0 + 0.015 * cbarp * t
	var rt := -sin(deg_to_rad(2.0 * d_theta)) * rc
	var term_l := d_l / sl
	var term_c := d_c / sc
	var term_h := d_h / sh
	return sqrt(term_l * term_l + term_c * term_c + term_h * term_h + rt * term_c * term_h)


static func _hue_deg(b: float, a: float) -> float:
	if a == 0.0 and b == 0.0:
		return 0.0
	var h := rad_to_deg(atan2(b, a))
	return h + 360.0 if h < 0.0 else h
