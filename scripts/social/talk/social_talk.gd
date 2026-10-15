class_name SocialTalk
extends RefCounted
## Cached CSV key families, deterministic choice and session no-repeat memory.
static var _loc_id := 0
static var _revision := -1
static var _families: Dictionary = {}
static var _sequence := 0

static func invalidate() -> void:
	_revision = -1
	_families.clear()

static func _ensure_index() -> void:
	var loc := Svc.node("LocalizationManager")
	if loc == null:
		return
	var id := loc.get_instance_id()
	var rev := int(loc.get("revision"))
	if id == _loc_id and rev == _revision:
		return
	_loc_id = id
	_revision = rev
	_families.clear()
	var rx := RegEx.create_from_string("^(.+)_([0-9]+)(_V)?$")
	for key in loc.call("all_keys"):
		var match_key := rx.search(str(key))
		if match_key == null:
			continue
		var family := match_key.get_string(1)
		if not _families.has(family):
			_families[family] = []
		(_families[family] as Array).append(str(key))
	for family in _families:
		(_families[family] as Array).sort()

static func variants(family: String) -> Array:
	_ensure_index()
	return LuaData.arr(_families.get(family, [])).duplicate()

static func band(hearts: int) -> int:
	if hearts < 2:
		return 0
	if hearts < 5:
		return 1
	if hearts < 8:
		return 2
	return 3

static func pick(npc: String, slot: String, context: Dictionary = {}) -> String:
	_ensure_index()
	var sm := Svc.node("SocialManager")
	if sm == null:
		return ""
	var ctx: Dictionary = context if not context.is_empty() else sm.call("dialogue_context", npc)
	var heart_band := band(int(ctx.get("hearts", 0)))
	var arch := str(SocialData.citizen(npc).archetype).to_upper()
	var own := "SOC_" + npc.to_upper() + "_"
	var shared := "SOC_ARCH_" + arch + "_"
	var families: Array[String] = []
	var day := int(sm.call("today"))
	if slot == "GREET":
		if bool(ctx.get("birthday", false)):
			families.append_array(["BDAY_" + npc.to_upper() + "_GREET", shared + "BDAY"])
		var fest := str(ctx.get("festival", ""))
		if fest != "":
			families.append_array(["FEST_" + fest.to_upper() + "_" + npc.to_upper(), shared + "FEST", "SOC_ANY_FEST"])
		var wx := str(ctx.get("weather", "klart")).to_upper()
		if wx != "KLART" and float(sm.call("roll", [npc, day, "weather"])) < 0.6:
			families.append_array([own + "GREET_WX_" + wx, shared + "WX_" + wx, "SOC_ANY_WX_" + wx])
		var gm := Svc.node("GameManager")
		var season := str(ctx.get("season", gm.get("season") if gm != null else "foraar")).to_upper()
		if float(sm.call("roll", [npc, day, "season"])) < 0.2:
			families.append_array([own + "GREET_" + season, shared + "SEASON_" + season, "SOC_ANY_SEASON_" + season])
		var part := str(ctx.get("daypart", "dag")).to_upper()
		families.append_array([own + "GREET_H%d_%s" % [heart_band, part], own + "GREET_H%d" % heart_band, shared + "GREET_H%d" % heart_band, "SOC_ANY_GREET"])
	elif slot.begins_with("GIFT_"):
		var taste := slot.trim_prefix("GIFT_")
		families.append_array(["GIFT_" + npc.to_upper() + "_" + taste, shared + slot, "SOC_ANY_" + slot])
	else:
		families.append_array([own + slot, shared + slot, "SOC_ANY_" + slot])
	var last := str(sm.call("last_line", npc, slot))
	var fallback := ""
	_sequence += 1
	for family in families:
		var available := LuaData.arr(_families.get(family, []))
		if available.is_empty():
			continue
		if fallback == "":
			fallback = str(available[0])
		var candidates: Array = []
		for key in available:
			if key != last:
				candidates.append(key)
		if candidates.is_empty():
			continue
		var choice := mini(int(float(sm.call("roll", [npc, slot, day, _sequence, last])) * candidates.size()), candidates.size() - 1)
		var key := str(candidates[choice])
		sm.call("remember_line", npc, slot, key)
		return key
	if fallback != "":
		sm.call("remember_line", npc, slot, fallback)
	return fallback

static func line(npc: String, key: String) -> Dictionary:
	var prefix := "SOC_" + npc.to_upper() + "_"
	var id := key.trim_prefix(prefix).to_lower()
	var out := {"id": id, "text_key": key}
	if key.ends_with("_V"):
		out["voice_key"] = "voice/%s/%s" % [npc, id]
	return out

static func greeting_for_shop(shop_id: String) -> Dictionary:
	var lr := Svc.node("LuaRuntime")
	var shop: Dictionary = lr.call("get_shop", shop_id) if lr != null else {}
	var npc := str(shop.get("keeper", ""))
	var sm := Svc.node("SocialManager")
	var h := int(sm.call("hearts", npc)) if sm != null else 0
	var part := str(sm.call("daypart")).to_upper() if sm != null else "DAG"
	var stem := "KEEP_" + shop_id.to_upper() + "_GREET_H%d" % band(h)
	_ensure_index()
	for family in [stem + "_" + part, stem]:
		var keys := variants(family)
		if not keys.is_empty() and sm != null:
			var last := str(sm.call("last_line", npc, "SHOP"))
			var candidates: Array = keys.filter(func(k): return k != last)
			var key := str(candidates[0] if not candidates.is_empty() else keys[0])
			sm.call("remember_line", npc, "SHOP", key)
			return line(npc, key)
	return {"text_key": str(shop.get("greeting_key", "SHOP_GREETING_DEFAULT")), "voice_key": ""}

static func bubble_for(npc: String) -> String:
	var qm := Svc.node("QuestManager")
	if qm != null and qm.has_method("offerable") and not LuaData.arr(qm.call("offerable", npc)).is_empty():
		return "quest"
	var sm := Svc.node("SocialManager")
	if sm != null:
		if not LuaData.arr(sm.call("events_ready", npc)).is_empty():
			return "heart"
		if bool(sm.call("is_birthday", npc)):
			return "birthday"
	return "none"
