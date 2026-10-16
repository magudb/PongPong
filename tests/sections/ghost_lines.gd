extends RefCounted
const SECTION := "ghost_lines"
const TIMEOUT_S := 90.0
const REACTIONS := preload("res://scripts/reactions/race_reactions.gd")
const DA_STEMS := ["skræm", "bange", "uhyggelig", "frygt", "gyser", "forskrække", "rædsel"]
const EN_STEMS := ["scare", "frighten", "afraid", "creepy", "terrif", "horror", "spooky"]
const TONE_ALLOW := ["DLG_GHOST_KING_INTRO"]

func run(t) -> void:
	await t.start_world("ghost")
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	var rows := LuaData.dict(gm.config_value("race_reactions.ghost", {}))
	t.check("table_loads_through_lua_runtime", rows.size() == 9 and not rows.has("ghostfam_dyne"))
	var page := {"lines": [{"id": "base", "text_key": "DLG_NEUTRAL"}]}
	var resolved := true
	var once := true
	var other := true
	var allow_used: Array[String] = []
	var tone := true
	var locale: Node = t.autoload("LocalizationManager")
	for npc in rows:
		var row: Dictionary = rows[npc]
		var flag := StringName("ghost_met_" + str(npc))
		for race in ["animal", "fairy", "hobbit", "absent"]:
			gm.clear_flag(flag)
			other = other and REACTIONS.apply(npc, {"race": race}, page) == page and not gm.world_flags.has(flag)
		if row.when == "first_meet":
			gm.clear_flag(flag)
			var first := REACTIONS.apply(npc, {"race": "ghost"}, page)
			var second := REACTIONS.apply(npc, {"race": "ghost"}, page)
			once = once and first.lines.size() == 2 and first.lines[0].text_key == row.text_key and second == page and gm.get_flag(flag) is int and int(gm.get_flag(flag)) == 1
		for lang in ["da", "en"]:
			locale.set_locale(lang)
			var text: String = tr(row.text_key)
			resolved = resolved and text != row.text_key and text != "" and str(row.voice_key).begins_with("voice/" + str(npc) + "/")
			var stems: Array = DA_STEMS if lang == "da" else EN_STEMS
			var banned: bool = stems.any(func(stem): return text.to_lower().contains(stem))
			if banned and str(row.text_key) not in TONE_ALLOW:
				tone = false
			if banned and str(row.text_key) in TONE_ALLOW and str(row.text_key) not in allow_used:
				allow_used.append(str(row.text_key))
	locale.set_locale("da")
	t.check("every_key_resolves_da_en", resolved)
	t.check("reaction_once_per_npc", once)
	t.check("no_reaction_for_other_races", other and REACTIONS.apply("absent", {"race": "ghost"}, page) == page)
	t.check("tone_gate", tone)
	t.check("tone_allow_list_is_minimal", allow_used == TONE_ALLOW)
	t.check("king_uses_intro_only", REACTIONS.apply("fairy_king", {"race": "ghost"}, page) == page and not REACTIONS.line_for("fairy_king", "intro", {"race": "ghost"}).is_empty())
	await _live_npc(t)
	await _letter(t)
	gm.clear_config_overrides()

func _live_npc(t) -> void:
	var gm: Node = t.autoload("GameManager")
	gm.hour = 10
	await t.world().travel(&"traetoppen", &"default")
	var npc: Node = NpcDirector.node_of("guard_oak")
	t.check("live_citizen_present", npc != null)
	if npc == null:
		return
	gm.clear_flag(&"ghost_met_guard_oak")
	var sm: Node = t.autoload("SocialManager")
	var hearts: int = sm.hearts("guard_oak")
	npc.interact(t.player())
	await t.frames(3)
	var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
	t.check("live_reaction_precedes_social_first_meeting", screen.is_open() and screen._lines[0].text_key == "DLG_GHOST_GUARD")
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	t.check("escape_releases_without_weekly_heart", sm.hearts("guard_oak") == hearts and not npc.is_talking and not gm.is_modal_open())
	npc.interact(t.player())
	await t.frames(3)
	t.check("live_reaction_once_per_npc", screen.is_open() and not screen._lines.any(func(row): return str(row.get("text_key", "")) == "DLG_GHOST_GUARD"))
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	var payload: Dictionary = t.autoload("SaveManager").gather_payload()
	t.check("reaction_flag_saved_in_game_section", int(payload.game.world_flags.get("ghost_met_guard_oak", 0)) == 1)

func _letter(t) -> void:
	var gm: Node = t.autoload("GameManager")
	gm.clear_flag(&"intro_letter_seen")
	var seen: Array[String] = []
	var endings: Array = []
	var ended := func(): endings.append(true)
	t.autoload("EventBus").dialogue_ended.connect(ended)
	preload("res://scripts/world2d/intro_sequence.gd").letter(t.world())
	var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
	for i in 100:
		if bool(gm.get_flag(&"intro_letter_seen", false)):
			break
		if screen.is_open():
			for row in screen._lines:
				var key := str(row.text_key)
				if key not in seen:
					seen.append(key)
			screen.chars_per_second = 100000
			t.tap(&"interact")
		await t.frames(2)
	t.autoload("EventBus").dialogue_ended.disconnect(ended)
	t.check("intro_line_after_the_letter", seen == ["DLG_KING_LETTER", "DLG_GHOST_KING_INTRO"] and endings.size() == 1 and bool(gm.get_flag(&"intro_letter_seen", false)), str(seen))
	await preload("res://scripts/world2d/intro_sequence.gd").letter(t.world())
	t.check("intro_reaction_once", not screen.is_open())
