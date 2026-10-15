class_name GiftRules
extends RefCounted
## What a gift is worth (package S-gifts): taste resolution over the selector lists of lua/social/gift_tastes.lua, the giftable guard
## and the point formula. Pure statics (item defs are passed in), so tools, tests and the validator share one implementation.
##
## Resolution: the NPC's own row, then its archetype row, then `universal`; the FIRST row that matches the item decides (his own opinions beat
## the archetype's); inside a row the most specific selector wins: item id (4) > ftype / slot / set (3) > category (2) > rarity (1);
## nothing matches -> neutral. Disliked and hated gifts are worth 0, never negative.

const CLASSES: Array[StringName] = [&"love", &"like", &"neutral", &"dislike", &"hate"]
const _ORDER := [&"hate", &"dislike", &"love", &"like"]          # tie-break inside one specificity (the validator forbids the tie)
const KEEPSAKE_RARITIES := ["unique", "legendary"]
const NEVER_GIVEN_CATEGORIES := ["quest", "special", "animal", "building", "blueprint"]


static func selectors_of(item_id: String, def: Dictionary) -> Dictionary:
	## selector string -> specificity (all selectors this item answers to)
	var out := {item_id: 4}
	var ft := str(def.get("furniture_type", ""))
	if ft != "":
		out["ftype:" + ft] = 3
	var slot := str(def.get("slot", ""))
	if slot != "":
		out["slot:" + slot] = 3
	var set_id := str(def.get("set", ""))
	if set_id != "":
		out["set:" + set_id] = 3
	var cat := str(def.get("category", ""))
	if cat != "":
		out["category:" + cat] = 2
	out["rarity:" + str(def.get("rarity", "normal"))] = 1
	return out


## Best match inside ONE taste row {love: [...], like: [...], dislike: [...], hate: [...]}: {class, selector, spec} or {}.
static func match_row(row: Dictionary, sels: Dictionary) -> Dictionary:
	var best := {}
	var best_spec := 0
	var best_rank := 99
	for cls in _ORDER:
		for entry in LuaData.arr(row.get(String(cls), [])):
			var sel := str(entry)
			if not sels.has(sel):
				continue
			var spec := int(sels[sel])
			var rank := _ORDER.find(cls)
			if spec > best_spec or (spec == best_spec and rank < best_rank):
				best = {"class": cls, "selector": sel, "spec": spec}
				best_spec = spec
				best_rank = rank
	return best


## {class, level: npc|archetype|universal|default, selector}
static func taste_of(tastes: Dictionary, npc: String, archetype: String, item_id: String, def: Dictionary) -> Dictionary:
	var sels := selectors_of(item_id, def)
	var levels := [
		["npc", LuaData.dict(LuaData.dict(tastes.get("npcs", {})).get(npc, {}))],
		["archetype", LuaData.dict(LuaData.dict(tastes.get("archetypes", {})).get(archetype, {}))],
		["universal", LuaData.dict(tastes.get("universal", {}))],
	]
	for lv in levels:
		var m := match_row(lv[1], sels)
		if not m.is_empty():
			return {"class": m["class"], "level": lv[0], "selector": m["selector"]}
	return {"class": &"neutral", "level": "default", "selector": ""}


## {ok, reason}: reason is a short id (UI maps it to a GIFT_REFUSE_* key).
static func giftable(item_id: String, def: Dictionary, sell_value: int = 1) -> Dictionary:
	if def.is_empty():
		return {"ok": false, "reason": "unknown"}
	var rarity := str(def.get("rarity", "normal"))
	if rarity in KEEPSAKE_RARITIES:
		return {"ok": false, "reason": "keepsake"}
	if bool(def.get("protected", false)):
		return {"ok": false, "reason": "protected"}
	if str(def.get("category", "")) in NEVER_GIVEN_CATEGORIES:
		return {"ok": false, "reason": "category"}
	if def.has("giftable"):
		return {"ok": bool(def["giftable"]), "reason": "" if bool(def["giftable"]) else "not_giftable"}
	if sell_value <= 0:
		return {"ok": false, "reason": "no_value"}
	return {"ok": true, "reason": ""}


## Points of one gift. `cfg` = social.gifts. birthday: "" | "day" | "belated"; repeated = the same item was given recently.
static func points(cfg: Dictionary, cls: StringName, rarity: String, birthday: String = "", repeated: bool = false) -> int:
	var base := LuaData.num(cfg.get(String(cls), 0), 0.0)
	if base <= 0.0:
		return 0
	var m := 1.0
	if rarity == "uncommon":
		m *= LuaData.num(cfg.get("rarity_uncommon", 1.25), 1.25)
	elif rarity == "rare":
		m *= LuaData.num(cfg.get("rarity_rare", 1.5), 1.5)
	if birthday == "day":
		m *= LuaData.num(cfg.get("birthday_mult", 4.0), 4.0)
	elif birthday == "belated":
		m *= LuaData.num(cfg.get("belated_mult", 2.0), 2.0)
	if repeated:
		m *= LuaData.num(cfg.get("repeat_mult", 0.5), 0.5)
	return mini(int(roundf(base * m)), LuaData.int_of(cfg.get("max_points", 160), 160))


static func needs_confirm(_item_id: String, def: Dictionary, sell_value: int) -> bool:
	return str(def.get("category", "")) == "tool" or str(def.get("rarity", "normal")) == "rare" or sell_value >= 100
