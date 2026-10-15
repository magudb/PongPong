class_name GiftFlow
extends RefCounted
## Validates against live free stock immediately before handing over one item.
## Social state is committed before inventory or friendship observers can save/reenter.
const TALK := "res://scripts/social/talk/social_talk.gd"
static var _busy := false

static func _stock() -> Array[Dictionary]:
	var eco := Svc.node("EconomyManager")
	if eco == null:
		return []
	var by_id := {}
	for r in eco.call("list_sellable"):
		by_id[str(r.id)] = r.duplicate()
	# Explicitly giftable zero-value backpack items are allowed by the data contract.
	var pack: Dictionary = eco.call("get_inventory_dict")
	for id in pack:
		if not by_id.has(str(id)):
			by_id[str(id)] = {"id": str(id), "amount": int(pack[id]), "value": eco.call("sell_value", id)}
	# Garments cannot be sold. Only free, unworn stock can be given.
	var wardrobe := Svc.node("WardrobeManager")
	if wardrobe != null and wardrobe.has_method("owned_ids"):
		for id in wardrobe.call("owned_ids"):
			var free := 0
			if wardrobe.has_method("count_free"):
				free = int(wardrobe.call("count_free", id))
			elif wardrobe.has_method("count_stock"):
				free = int(wardrobe.call("count_stock", id))
			if free > 0:
				by_id[str(id)] = {"id": str(id), "amount": free, "value": eco.call("sell_value", id)}
	var out: Array[Dictionary] = []
	for id in by_id:
		out.append(by_id[id])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.id) < str(b.id))
	return out

static func protection(item: String, def: Dictionary) -> String:
	var qm := Svc.node("QuestManager")
	if qm != null and qm.has_method("item_in_use") and bool(qm.call("item_in_use", item)):
		return "quest_needs_it"
	var eco := Svc.node("EconomyManager")
	if str(def.get("category", "")) == "tool":
		if eco == null or int(eco.call("count_item", StringName(item))) <= 1:
			return "last_tool"
		var tree := Engine.get_main_loop() as SceneTree
		var player := tree.get_first_node_in_group("player") if tree != null else null
		var hotbar: Variant = player.get("hotbar") if player != null and "hotbar" in player else null
		if hotbar is Object and hotbar.has_method("to_dict"):
			var slots := LuaData.arr(LuaData.dict(hotbar.call("to_dict")).get("slots", []))
			if item in slots:
				return "hotbar_tool"
	var home := Svc.node("HomeManager")
	if home != null and home.has_method("requirements") and "tier" in home:
		for r in home.call("requirements", int(home.get("tier")) + 1):
			if str(r.get("kind", "")) == "material" and str(r.get("id", "")) == item and int(r.get("have", 0)) <= int(r.get("need", 0)):
				return "home_material"
	var set_id := str(def.get("set", ""))
	var loot := Svc.node("LootService")
	if str(def.get("category", "")) == "clothing" and set_id != "" and loot != null and loot.has_method("set_capstone_granted") and not bool(loot.call("set_capstone_granted", set_id)):
		return "incomplete_set"
	return ""

static func gift_options(npc: String) -> Array[Dictionary]:
	var sm := Svc.node("SocialManager")
	var eco := Svc.node("EconomyManager")
	var out: Array[Dictionary] = []
	if sm == null or eco == null or not bool(sm.call("can_befriend", npc)):
		return out
	var row: Dictionary = sm.call("row_of", npc, false)
	var known := LuaData.dict(row.get("kn", {}))
	for candidate in _stock():
		var id := str(candidate.id)
		var def: Dictionary = eco.call("item_def", id)
		if int(candidate.get("amount", 0)) <= 0 or not GiftRules.giftable(id, def, int(candidate.get("value", 0))).ok or protection(id, def) != "":
			continue
		var r := candidate.duplicate()
		r["known"] = str(known.get(id, ""))
		r["confirm"] = GiftRules.needs_confirm(id, def, int(candidate.get("value", 0)))
		out.append(r)
	return out

static func hidden_quest_items(npc: String) -> int:
	var sm := Svc.node("SocialManager")
	var eco := Svc.node("EconomyManager")
	if sm == null or eco == null or not bool(sm.call("can_befriend", npc)):
		return 0
	var count := 0
	for r in _stock():
		var id := str(r.id)
		var def: Dictionary = eco.call("item_def", id)
		if protection(id, def) == "quest_needs_it" and GiftRules.giftable(id, def, int(r.value)).ok:
			count += int(r.amount)
	return count

static func give_gift(npc: String, item: String) -> Dictionary:
	if _busy:
		return {"ok": false, "reason": "busy"}
	var sm := Svc.node("SocialManager")
	var eco := Svc.node("EconomyManager")
	if sm == null or eco == null or not bool(sm.call("can_befriend", npc)):
		return {"ok": false, "reason": "not_a_friend"}
	var def: Dictionary = eco.call("item_def", item)
	var g := GiftRules.giftable(item, def, int(eco.call("sell_value", item)))
	if not bool(g.ok):
		return g
	var protected := protection(item, def)
	if protected != "":
		return {"ok": false, "reason": protected}
	var found := false
	for option in gift_options(npc):
		found = found or str(option.id) == item
	if not found:
		return {"ok": false, "reason": "no_item"}
	var limits: Dictionary = sm.call("gift_limits", npc)
	var birthday := str(sm.call("birthday_state", npc))
	if int(limits.left_today) <= 0:
		return {"ok": false, "reason": "today"}
	if birthday == "" and int(limits.left_week) <= 0:
		return {"ok": false, "reason": "week"}
	_busy = true
	var result := {"ok": false, "reason": "no_item"}
	var commit := func() -> void:
		if not bool(eco.call("remove_item", StringName(item), 1)):
			return
		var today := int(sm.call("today"))
		var week := int(sm.call("week"))
		var row: Dictionary = sm.call("row_of", npc)
		var taste: Dictionary = sm.call("taste_of", npc, item)
		var cls := StringName(str(taste.get("class", "neutral")))
		var repeated := false
		for entry in LuaData.arr(row.get("ls", [])):
			if str(entry[0]) == item and today - int(entry[1]) < SocialData.cfg_int("gifts.repeat_days", 14):
				repeated = true
		var points := GiftRules.points(SocialData.cfg_dict("gifts"), cls, str(def.get("rarity", "normal")), birthday, repeated)
		row["gd"] = today
		if birthday == "":
			row["gw"] = (int(row.get("gw", 0)) if int(row.get("gwk", -1)) == week else 0) + 1
			row["gwk"] = week
		else:
			row["bd"] = sm.call("last_birthday", npc)
		var recent := LuaData.arr(row.get("ls", [])).duplicate()
		recent.push_front([item, today])
		recent.resize(mini(recent.size(), 3))
		row["ls"] = recent
		var known := LuaData.dict(row.get("kn", {}))
		known.erase(item)
		known[item] = str(cls)
		while known.size() > SocialData.cfg_int("gifts.known_cap", 40):
			known.erase(known.keys()[0])
		row["kn"] = known
		var before_hearts := int(sm.call("hearts", npc))
		var before_stage := str(sm.call("stage", npc))
		# All gift ledger fields and the item deduction are already committed.
		if points > 0:
			sm.call("add_points", npc, points, &"gift", {"toast": false})
		result.clear()
		result.merge({"ok": true, "item": item, "class": str(cls), "points": points, "birthday": birthday, "repeated": repeated, "hearts": sm.call("hearts", npc), "hearts_before": before_hearts, "stage_before": before_stage, "stage_after": sm.call("stage", npc)})
		var bus := Svc.node("EventBus")
		if bus != null:
			eco.call("after_transaction", func() -> void: bus.emit_signal("game_event", &"gift_given", {"npc": npc, "item": item, "taste": str(cls), "points": points, "birthday": birthday != ""}))
	eco.call("defer_notifications", commit)
	_busy = false
	return result

## Called only after the gift picker has closed and released its modal.
static func react(npc: String, result: Dictionary) -> Dictionary:
	if not bool(result.get("ok", false)):
		return {}
	var key := str(Svc.static_call(TALK, &"pick", [npc, "GIFT_" + str(result.get("class", "neutral")).to_upper(), {}], ""))
	var eco := Svc.node("EconomyManager")
	var item := str(result.get("item", ""))
	var d: Dictionary = eco.call("item_def", item) if eco != null else {}
	var name := str(TranslationServer.translate(str(d.get("name_key", item))))
	var bus := Svc.node("EventBus")
	if bus != null:
		var message := str(TranslationServer.translate("REL_GIFT_TOAST_FMT")) % name
		var gained := int(result.get("hearts", 0)) - int(result.get("hearts_before", 0))
		if gained > 0:
			message += " · " + str(TranslationServer.translate("REL_GIFT_HEARTS_FMT")) % gained
		if result.get("stage_after") != result.get("stage_before"):
			message += " · " + str(TranslationServer.translate("REL_STAGE_" + str(result.get("stage_after", "")).to_upper()))
		bus.emit_signal("notification_posted", str(TranslationServer.translate("SOC_SYS_TOAST_TITLE")), message, "social")
	var tree := Engine.get_main_loop() as SceneTree
	var ui := tree.get_first_node_in_group("dialogue_ui") if tree != null else null
	var line := {"id": key.to_lower(), "text_key": key}
	if key.ends_with("_V"):
		line["voice_key"] = "voice/%s/%s" % [npc, key.to_lower()]
	if key != "" and ui != null and ui.has_method("start_dialogue"):
		ui.call("start_dialogue", {"name_key": SocialData.npc_row(npc).get("name_key", ""), "npc_id": npc}, [line], [])
	return line
