extends SceneTree
## Dumps what the REAL LuaRuntime made of the social data as JSON, so the Python validator (tools/social/core/validate_social.py), the balance Monte Carlo
## (tools/social/core/balance_mc.py) and SocialValidator read exactly what the game reads. The shape is the one of tests/lib/social/fixtures/design_dump.json:
##
##   {format, source, social (the EFFECTIVE config: the Lua values over the code defaults), citizens, gift_tastes, npcs{id:{friendship, role, home_area, shop_id,
##    name_key}}, time{days_per_season, seasons, first_weekday, day_start_hour, day_end_hour, weather_chances}, events, festivals, shops{id:{}},
##    items{id:{category, rarity, sell_price, buy_price, furniture_type, slot, set, protected, giftable}}, towns{max_live_visuals_festival}}
##
##   godot --headless --path <project> -s res://tests/lib/social/dump_social_json.gd -- --out=<file>
## Autoloads are reached through root.get_node (the driver compiles before they exist); the social classes are static and late bound.

const ITEM_KEYS := ["category", "rarity", "sell_price", "buy_price", "furniture_type", "slot", "set", "protected", "giftable"]
const NPC_KEYS := ["friendship", "role", "home_area", "shop_id", "name_key"]


func _initialize() -> void:
	call_deferred("_go")


func _go() -> void:
	await process_frame
	var out_path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_path = a.substr(6)
	var lr: Node = root.get_node("LuaRuntime")
	var gm: Node = root.get_node("GameManager")
	var items := {}
	for id in lr.get_all_item_ids():
		var def: Dictionary = lr.get_item_def(id)
		var row := {}
		for k in ITEM_KEYS:
			if def.has(k):
				row[k] = def[k]
		items[str(id)] = row
	var npcs := {}
	var raw_npcs: Dictionary = lr.get_config("npcs", {})
	for id in raw_npcs:
		var row := {}
		for k in NPC_KEYS:
			if (raw_npcs[id] as Dictionary).has(k):
				row[k] = (raw_npcs[id] as Dictionary)[k]
		npcs[str(id)] = row
	var social := {}
	for k in SocialData.DEFAULTS:
		var v: Variant = SocialData.cfg(k, null)
		social[k] = SocialData.cfg_dict(k) if typeof(SocialData.DEFAULTS[k]) == TYPE_DICTIONARY else v
	var shops := {}
	for id in lr.get_shops():
		shops[str(id)] = {}
	var seasons: Array = []
	for s in gm.seasons():
		seasons.append(String(s))
	var data := {
		"format": 1, "source": "live", "social": social, "citizens": lr.get_config("citizens", {}), "gift_tastes": lr.get_config("gift_tastes", {}), "npcs": npcs,
		"time": {"days_per_season": gm.days_per_season(), "seasons": seasons, "first_weekday": int(gm.config_value("time.first_weekday", 0)), "day_start_hour": gm.day_start_hour(), "day_end_hour": gm.day_end_hour(), "weather_chances": lr.get_config("time.weather_chances", {})},
		"events": lr.get_registry("events"), "festivals": lr.get_registry("festivals"), "shops": shops, "items": items,
		"towns": {"max_live_visuals_festival": int(lr.get_config("towns.max_live_visuals_festival", 20))},
	}
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		print("DUMP failed: cannot write ", out_path)
		quit(1)
		return
	f.store_string(JSON.stringify(data, "", true))
	f.close()
	print("DUMP ok ", out_path, " items=", items.size(), " npcs=", npcs.size(), " citizens=", (data["citizens"] as Dictionary).size(), " festivals=", (data["festivals"] as Dictionary).size())
	quit()
