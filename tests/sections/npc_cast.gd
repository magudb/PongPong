extends RefCounted
## V7 evaluates every contextual return through the project Lua interpreter.
const SECTION := "npc_cast"
const IDS := ["gardener_hoppe", "carpenter_brumme", "postman_pip", "bathkeeper_sofus", "appraiser_fru_ugle", "mapseller_natteblik", "beekeeper_birk"]

func run(t) -> void:
	var lr: Node = t.autoload("LuaRuntime")
	var loc: Node = t.autoload("LocalizationManager")
	var base := {"total_day": 29, "day": 1, "swap_day": 0, "bath_day": 0, "hour": 12, "stamina_ratio": 1.0, "race": "animal", "weather": "klart"}
	var cases: Array[Dictionary] = []
	for weather in ["klart", "regn", "taage", "sne", "torden"]:
		cases.append({"id": IDS[0], "ctx": {"weather": weather}, "line": weather, "choice": "swap"})
		cases.append({"id": IDS[0], "ctx": {"weather": weather, "swap_day": 29}, "line": "swap_done", "absent": "swap"})
	# Calendar day is deliberately different from total_day across a season boundary.
	cases.append({"id": IDS[0], "ctx": {"swap_day": 1}, "line": "swap_offer", "choice": "swap"})
	cases.append_array([
		{"id": IDS[1], "ctx": {"brumme_at_stall": true}, "line": "market", "choice": "shop"},
		{"id": IDS[1], "ctx": {"quest_active_fix_roof": true}, "line": "roof", "choice": "shop"},
		{"id": IDS[2], "ctx": {}, "line": "offer", "choice": "quest"},
		{"id": IDS[2], "ctx": {"quest_active_pips_runde": true}, "line": "remind", "absent": "quest"},
		{"id": IDS[2], "ctx": {"quest_done_pips_runde": true}, "line": "thanks", "absent": "quest"},
		{"id": IDS[2], "ctx": {"quest_done_pips_runde": true, "post_waiting": true}, "line": "mail"},
		{"id": IDS[2], "ctx": {"post_waiting": true}, "line": "mail", "choice": "quest"},
		{"id": IDS[3], "ctx": {}, "line": "orange", "choice": "bath"},
		{"id": IDS[3], "ctx": {"bath_day": 29}, "line": "once", "absent": "bath"},
		{"id": IDS[3], "ctx": {"stamina_ratio": 0.2}, "line": "tired", "choice": "bath"},
		{"id": IDS[3], "ctx": {"hour": 24}, "line": "evening", "choice": "bath"},
		{"id": IDS[4], "ctx": {}, "line": "finds", "choice": "appraise", "absent": "key"},
		{"id": IDS[4], "ctx": {"quest_offer_ugles_noegle": true}, "line": "lake", "choice": "key"},
		{"id": IDS[4], "ctx": {"quest_offer_rune_vandring": true}, "line": "runes", "choice": "runes"},
		{"id": IDS[4], "ctx": {"quest_offer_ugles_noegle": true, "quest_offer_rune_vandring": true}, "line": "lake", "choice": "runes"},
		{"id": IDS[5], "ctx": {}, "line": "no_maps", "absent": "shop"},
		{"id": IDS[5], "ctx": {"shop_natteblik_maps": true}, "line": "maps", "choice": "shop"},
		{"id": IDS[5], "ctx": {"shop_natteblik_maps": true, "hour": 25}, "line": "night", "choice": "shop"},
		{"id": IDS[6], "ctx": {}, "line": "bees"},
		{"id": IDS[6], "ctx": {"race": "fairy"}, "line": "family"},
	])
	var seen := {}
	for c in cases:
		var ctx: Dictionary = base.merged(c.ctx, true)
		var dlg: Dictionary = lr.get_dialogue(c.id, ctx)
		var lines := LuaData.arr(dlg.get("lines", []))
		var choices := LuaData.arr(dlg.get("choices", []))
		var line_ids: Array = lines.map(func(x): return str(x.get("id", "")))
		var choice_ids: Array = choices.map(func(x): return str(x.get("id", "")))
		t.expect(dlg.get("speaker") == c.id and c.line in line_ids and (not c.has("choice") or c.choice in choice_ids) and (not c.has("absent") or c.absent not in choice_ids), "%s branch %s -> %s / %s" % [c.id, str(c.ctx), str(line_ids), str(choice_ids)])
		for line in lines:
			seen[str(line.text_key)] = true
			t.expect(line.get("voice_key") == "voice/%s/%s" % [c.id, line.id], "Voice hook follows the speaker and line id")
		for choice in choices:
			seen[str(choice.text_key)] = true
			var action := str(choice.get("action", ""))
			t.expect(action in ["close", "quest_accept", "open_shop", "emit_event"], "Declared dialogue action")
			if action == "open_shop":
				t.expect(lr.get_shop(str(choice.shop_id)).get("keeper") == c.id, "Shop belongs to the speaker")
			if action == "emit_event":
				t.expect(choice.get("event") in ["bath_request", "swap_seeds_request", "open_appraisal"] and choice.get("npc") == c.id, "Service event has its named NPC")
	for key in seen:
		for language in ["da", "en"]:
			t.expect(loc.text_in(key, language) not in ["", key], "%s resolves in %s" % [key, language])
	t.check("runs_through_lua_runtime", lr.lint_report.is_empty() and seen.size() > 60, "Every cast branch uses real Lua, with complete copy and declared service choices: %s" % str(lr.lint_report))
