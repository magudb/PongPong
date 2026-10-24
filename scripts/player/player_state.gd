class_name PlayerState
extends RefCounted
## Per-player persistent state (MP3-player-state, MULTIPLAYER_ADDENDUM 3.5).
##
## One row per player slot (`p0`..`p3`). Single-player keeps exactly one row and the
## EconomyManager / QuestManager / WardrobeManager facades delegate to it, so behaviour
## is unchanged until a second player exists. Shared world state (farm, shops, calendar,
## home/household) stays on the managers and is NOT stored here.
##
## Layout matches the save `players[]` section (payload v3, RM5).

const DEFAULT_STARTING_GOLD := 500

var player_id: StringName = &"p0"
var peer_id: int = 1
var name: String = ""
var character_type: int = 0
var character_skin: StringName = &""
## World position / hotbar are travel state; they ride along so one row is the full profile.
var area: StringName = &""
var player_pos: Vector2 = Vector2.ZERO
var hotbar: Variant = {}
## Vitals are not in the v2 save; they are restored full on sleep/load.
var half_hearts: int = 10
var max_half_hearts: int = 10
var stamina: float = 100.0
var max_stamina: float = 100.0
var oil: float = 150.0
var max_oil: float = 150.0
## Economy (was EconomyManager's single backpack).
var gold: int = DEFAULT_STARTING_GOLD
var inventory: Array[Dictionary] = []
var equipment: Dictionary = {}
var arsenal: Dictionary = {}
var arsenal_orphans: Dictionary = {}
## Quest log (was QuestManager's single log).
var quests: Dictionary = {}
## Derived friend_<npc> and friend_last_<npc> mirrors belong to this hero.
var flags: Dictionary = {}
var owed: Array = []
## Wardrobe (was WardrobeManager's single owned/equipped/presets).
var wardrobe: Dictionary = {}


func _init(id: StringName = &"p0", peer: int = 1) -> void:
	player_id = id
	peer_id = peer


## JSON-safe row for the save `players[]` section. Field names match RM5.
func to_dict() -> Dictionary:
	return {
		"id": str(player_id),
		"peer_ordinal": peer_id,
		"name": name,
		"character_type": character_type,
		"character_skin": str(character_skin),
		"gold": gold,
		"inventory": inventory.map(func(slot: Dictionary) -> Dictionary:
			return {"id": str(slot.get("id", "")), "amount": int(slot.get("amount", 0)), "meta": (slot.get("meta") as Dictionary).duplicate(true) if typeof(slot.get("meta")) == TYPE_DICTIONARY else {}}),
		"equipment": equipment.duplicate(true),
		"arsenal": _arsenal_dict(),
		"hotbar": hotbar.duplicate(true),
		"half_hearts": half_hearts,
		"stamina": stamina,
		"oil": oil,
		"area": str(area),
		"player_pos": [player_pos.x, player_pos.y],
		"quests": _quest_dict(),
		"flags": flags.duplicate(true),
		"owed": owed.duplicate(true),
		"wardrobe": wardrobe.duplicate(true),
	}


func _arsenal_dict() -> Dictionary:
	var out := arsenal.duplicate(true)
	if not arsenal_orphans.is_empty(): out["_orphans"] = arsenal_orphans.duplicate(true)
	return out


func _quest_dict() -> Dictionary:
	var out := quests.duplicate(true)
	var active: Dictionary = out.get("active", {})
	for id in active:
		if active[id] is Object and active[id].has_method("to_dict"):
			active[id] = active[id].to_dict()
	return out


## Rebuild from a save row. Unknown / unsafe values are dropped; returns false only on a missing id.
func from_dict(d: Dictionary) -> bool:
	var id := StringName(str(d.get("id", "")))
	if id == &"":
		return false
	player_id = id
	peer_id = int(d.get("peer_ordinal", 1))
	name = str(d.get("name", ""))
	character_type = int(d.get("character_type", 0))
	character_skin = StringName(str(d.get("character_skin", "")))
	gold = int(d.get("gold", DEFAULT_STARTING_GOLD))
	inventory.clear()
	var inv: Variant = d.get("inventory")
	if inv is Array:
		for slot in (inv as Array):
			if slot is Dictionary:
				var sid := StringName(str((slot as Dictionary).get("id", "")))
				var n := int((slot as Dictionary).get("amount", 0))
				if sid != &"" and n > 0:
					var meta: Variant = (slot as Dictionary).get("meta")
					inventory.append({"id": sid, "amount": n, "meta": (meta as Dictionary).duplicate(true) if meta is Dictionary else {}})
	equipment = {}
	var eq: Variant = d.get("equipment")
	if eq is Dictionary:
		for k in (eq as Dictionary):
			equipment[StringName(str(k))] = StringName(str((eq as Dictionary)[k]))
	var ar: Variant = d.get("arsenal")
	arsenal = (ar as Dictionary).duplicate(true) if ar is Dictionary else {}
	arsenal_orphans = LuaData.dict(arsenal.get("_orphans", {})).duplicate(true)
	arsenal.erase("_orphans")
	var hb: Variant = d.get("hotbar")
	hotbar = hb.duplicate(true) if hb is Array or hb is Dictionary else {}
	half_hearts = int(d.get("half_hearts", 10))
	stamina = float(d.get("stamina", 100.0))
	oil = float(d.get("oil", 150.0))
	area = StringName(str(d.get("area", "")))
	var pp: Variant = d.get("player_pos")
	if pp is Array and (pp as Array).size() >= 2:
		player_pos = Vector2(float((pp as Array)[0]), float((pp as Array)[1]))
	else:
		player_pos = Vector2.ZERO
	flags = LuaData.dict(d.get("flags", {})).duplicate(true)
	owed = LuaData.arr(d.get("owed", [])).duplicate(true)
	var q: Variant = d.get("quests")
	quests = (q as Dictionary).duplicate(true) if q is Dictionary else {}
	var w: Variant = d.get("wardrobe")
	wardrobe = (w as Dictionary).duplicate(true) if w is Dictionary else {}
	return true


## New-game defaults for one hero (matches EconomyManager.reset + GameManager.start_new_game profile).
func reset_profile(p_name: String = "", p_type: int = 0, p_skin: StringName = &"") -> void:
	name = p_name
	character_type = p_type
	character_skin = p_skin
	gold = DEFAULT_STARTING_GOLD
	inventory.clear()
	equipment.clear()
	arsenal = {}
	arsenal_orphans = {}
	hotbar = {}
	quests = {}
	flags = {}
	owed = []
	wardrobe = {}
	half_hearts = 10
	stamina = 100.0
	oil = 150.0
	area = &""
	player_pos = Vector2.ZERO
