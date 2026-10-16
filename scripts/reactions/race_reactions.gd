class_name RaceReactions
extends RefCounted
## Text-only first-meeting hooks. Dialogue completion owns friendship points.
static func line_for(npc: String, moment: String, ctx: Dictionary) -> Dictionary:
	var table := LuaData.dict(Svc.lua_config("race_reactions." + str(ctx.get("race", "")), {}))
	var row := LuaData.dict(table.get(npc, {}))
	if str(row.get("when", "")) != moment or str(row.get("text_key", "")) == "":
		return {}
	return {"id": "ghost_intro" if moment == "intro" else "ghost_first", "text_key": str(row.text_key), "voice_key": str(row.get("voice_key", ""))}

static func apply(npc: String, ctx: Dictionary, dialogue: Dictionary) -> Dictionary:
	var flag := StringName("ghost_met_" + npc)
	if bool(GameManager.get_flag(flag, false)):
		return dialogue
	var line := line_for(npc, "first_meet", ctx)
	if line.is_empty():
		return dialogue
	var result := dialogue.duplicate(true)
	var lines := LuaData.arr(result.get("lines", [])).duplicate()
	lines.push_front(line)
	result["lines"] = lines
	GameManager.set_flag(flag, 1)
	return result
