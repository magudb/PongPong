class_name Perks
extends RefCounted
## ONE place that adds up every perk source and applies the caps (addendum 2.4, DF14, DF23).
## Kinds: speed (fraction), energy (points), luck (fraction), discount (fraction). Caps live in lua/config/rarity.lua
## (`perk_caps`: speed 0.15, energy 20, luck 0.20, discount 0.15 for GEAR; energy_total 60, discount_total 0.20 overall).
##
## Formula:
##   gear(kind)      = sum of worn item perks + the best 2 wardrobe-set bonuses            WardrobeManager.gear_points(kind)
##   gear_capped     = min(gear, perk_caps[kind])
##   furniture(kind) = all placed furniture-set bonuses + the hygge level                  FurnitureManager.perk_points(kind)
##   home(energy)    = tier max_energy_bonus                                               HomeManager.max_energy_bonus()
##   race(discount)  = race_perks.<race>.shop_discount (hobbit 0.10)                        lua/config/race_perks.lua
##   speed    = gear_capped
##   energy   = min(gear_capped + furniture + home, energy_total)
##   luck     = min(gear_capped + furniture, perk_caps.luck)
##   discount = min(gear_capped + furniture + race, discount_total)      (NO friend term: PriceCurve adds the friend discount
##              and applies the final min(total + friend, discount_total); a second hobbit factor must never exist)
## Every source is queried LATE-BOUND (Svc.node) and counts 0 until its manager exists (waves 4-5 add them). The managers
## return natural units (fractions for speed/luck/discount, points for energy); they never apply caps themselves.

const KINDS: Array[String] = ["speed", "energy", "luck", "discount"]
const RACE_KEYS := ["animal", "fairy", "hobbit", "ghost"]       # GameManager.CharacterType 0 1 2 3
const _DEFAULT_CAPS := {"speed": 0.15, "energy": 20.0, "luck": 0.2, "discount": 0.15, "energy_total": 60.0, "discount_total": 0.2}


## the built-in caps (tests compare them with `perk_caps` of lua/config/rarity.lua)
static func builtin_caps() -> Dictionary:
	return _DEFAULT_CAPS.duplicate()


## perk_caps from the Lua config (built-in numbers when missing)
static func caps() -> Dictionary:
	var out: Dictionary = _DEFAULT_CAPS.duplicate()
	var c := LuaData.dict(Svc.lua_config("perk_caps", {}))
	for k in out:
		if c.has(k):
			out[k] = LuaData.num(c[k], out[k])
	return out


## gear cap of a kind
static func cap(kind: Variant) -> float:
	return float(caps().get(str(kind), 0.0))


## {kind, gear, gear_cap, gear_capped, furniture, home, race, raw, total, total_cap, gear_at_cap, at_cap}
## raw = the sum before the final clamp, total = what the game uses, at_cap = the UI shows "maks." (gear or total at its cap).
static func breakdown(kind: Variant) -> Dictionary:
	var k := str(kind)
	var cs := caps()
	var gear := maxf(_gear(k), 0.0)
	var gear_cap := float(cs.get(k, 0.0))
	var gear_capped := minf(gear, gear_cap)
	var furniture := maxf(_furniture(k), 0.0) if k != "speed" else 0.0
	var home := maxf(_home(k), 0.0)
	var race := maxf(_race(k), 0.0)
	var raw := gear_capped
	var total_cap := gear_cap
	match k:
		"speed":
			raw = gear_capped
			total_cap = gear_cap
		"energy":
			raw = gear_capped + furniture + home
			total_cap = float(cs.get("energy_total", 60.0))
		"luck":
			raw = gear_capped + furniture
			total_cap = float(cs.get("luck", 0.2))
		"discount":
			raw = gear_capped + furniture + race
			total_cap = float(cs.get("discount_total", 0.2))
		_:
			raw = 0.0
	var total := minf(raw, total_cap) if total_cap > 0.0 else 0.0
	var gear_at_cap := gear_cap > 0.0 and gear >= gear_cap - 0.000001
	return {
		"kind": k, "gear": gear, "gear_cap": gear_cap, "gear_capped": gear_capped,
		"furniture": furniture, "home": home, "race": race,
		"raw": raw, "total": total, "total_cap": total_cap,
		"gear_at_cap": gear_at_cap, "at_cap": gear_at_cap or (total_cap > 0.0 and raw >= total_cap - 0.000001),
	}


## translation key of the perk word (Fart / Energi / Held / Rabat): exact keys of finds.csv
static func label_key(kind: Variant) -> String:
	return "PERK_%s" % str(kind).to_upper()


## The perk the game applies (see the formula in the header).
static func total(kind: Variant) -> float:
	return float(breakdown(kind)["total"])


## The shop price after Perks.total("discount") and the friend discount, capped at discount_total (the contract that
## PriceCurve implements; kept here as the executable definition: 1600 gold -> 1360 fox, 1280 hobbit, 1440 hobbit alone).
static func discounted_price(base_price: int, friend_discount: float = 0.0) -> int:
	var cap_total := float(caps().get("discount_total", 0.2))
	return roundi(float(base_price) * (1.0 - minf(total("discount") + maxf(friend_discount, 0.0), cap_total)))


# ------------------------------------------------------------------------------------------------ sources (late-bound)

static func _gear(kind: String) -> float:
	var w := Svc.node("WardrobeManager")
	return LuaData.num(w.call("gear_points", kind)) if w != null and w.has_method("gear_points") else 0.0


static func _furniture(kind: String) -> float:
	var f := Svc.node("FurnitureManager")
	return LuaData.num(f.call("perk_points", kind)) if f != null and f.has_method("perk_points") else 0.0


static func _home(kind: String) -> float:
	if kind != "energy":
		return 0.0
	var h := Svc.node("HomeManager")
	return LuaData.num(h.call("max_energy_bonus")) if h != null and h.has_method("max_energy_bonus") else 0.0


## race perks of lua/config/race_perks.lua: only the shop discount feeds the perk kinds (hobbit 0.10)
static func _race(kind: String) -> float:
	if kind != "discount":
		return 0.0
	var rp := LuaData.dict(Svc.lua_config("race_perks", {}))
	var gm := Svc.node("GameManager")
	if rp.is_empty() or gm == null:
		return 0.0
	var race_index := clampi(LuaData.int_of(gm.get("character_type")), 0, RACE_KEYS.size() - 1)
	return LuaData.num(LuaData.dict(rp.get(RACE_KEYS[race_index], {})).get("shop_discount", 0.0))
