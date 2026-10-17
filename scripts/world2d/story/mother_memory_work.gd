class_name MotherMemoryWork
extends RefCounted
## Small, retryable acts of care. Scalar flags preserve partial work independently
## of generated cells. Existing recorded evidence already includes the work.
const IDS := ["memory_lamp", "traveller_account", "route_stone"]
const STITCHES := ["FM_WORK_STITCH_TOP", "FM_WORK_STITCH_MIDDLE", "FM_WORK_STITCH_BOTTOM"]

static func state(id: String) -> int:
	return clampi(GameManager.flag_int(StringName(MotherStory.PREFIX+"work_"+id), 0), 0, 7)

static func complete(id: String) -> bool:
	if id not in IDS or MotherStory.has(id): return true
	var value := state(id)
	return value == 7 if id == "memory_lamp" else (value == 1 if id == "traveller_account" else value >= 4)

static func instructions(id: String) -> String:
	if id == "route_stone": return "FM_WORK_STONE_"+["N", "E", "S", "W"][state(id) % 4]
	return "FM_WORK_LAMP" if id == "memory_lamp" else "FM_WORK_NAME"

static func choices(id: String) -> Array:
	var result: Array = []
	if id == "memory_lamp":
		for index in 3:
			if (state(id) & (1 << index)) == 0:
				result.append({"text_key":STITCHES[index], "action":"stitch_"+str(index)})
	elif id == "traveller_account":
		for name_id in ["iva", "guest", "keeper"]:
			result.append({"text_key":"FM_WORK_NAME_"+name_id.to_upper(), "action":"name_"+name_id})
	elif id == "route_stone":
		for turn in ["left", "right", "match"]:
			result.append({"text_key":"FM_WORK_STONE_"+turn.to_upper(), "action":"stone_"+turn})
	result.append({"text_key":"REL_TALK_GOODBYE", "action":"close"})
	return result

static func apply(id: String, action: String) -> String:
	if not MotherStory.enabled() or id not in IDS or complete(id): return ""
	var value := state(id)
	if id == "memory_lamp":
		var actions := ["stitch_0", "stitch_1", "stitch_2"]
		if action not in actions: return ""
		value |= 1 << actions.find(action)
	elif id == "traveller_account":
		if action == "name_guest" or action == "name_keeper": return "FM_WORK_NAME_RETRY"
		if action != "name_iva": return ""
		value = 1
	else:
		if action == "stone_left": value = posmod(value-1, 4)
		elif action == "stone_right": value = posmod(value+1, 4)
		elif action == "stone_match":
			if value != 1: return "FM_WORK_STONE_RETRY"
			value += 4
		else: return ""
	if value != state(id):
		GameManager.set_flag(StringName(MotherStory.PREFIX+"work_"+id), value)
		SaveManager.autosave()
		EventBus.game_event.emit(&"forest_mother_work", {"id":id, "complete":complete(id)})
	return ""
