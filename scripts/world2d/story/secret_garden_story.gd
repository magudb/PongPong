class_name SecretGardenStory
extends RefCounted
## Quest objectives are the saved source of truth for both the restored place
## and its evidence. No second stage counter, autoload or inventory keepsake.
const QUEST := &"secret_garden"
const WATER_DAY := &"secret_garden_watered_day"
const STEPS := [
	{"id": "clear_path", "kind": "path"},
	{"id": "ask_hoppe", "npc": "gardener_hoppe"},
	{"id": "ask_brumme", "npc": "carpenter_brumme"},
	{"id": "restore_bench", "kind": "bench"},
	{"id": "plant_beds", "kind": "beds"},
	{"id": "water_beds", "kind": "beds"},
	{"id": "see_blossoms", "kind": "beds"},
	{"id": "read_letter", "kind": "letter"},
	{"id": "ask_pip", "npc": "postman_pip"},
	{"id": "ask_oak", "npc": "guard_oak"},
	{"id": "follow_trace", "kind": "trail"},
	{"id": "homecoming", "kind": "bench"},
]
const HELPERS := ["gardener_hoppe", "carpenter_brumme", "postman_pip", "guard_oak", "ghostfam_dyne", "ghostfam_silke"]

static func step() -> int:
	if QuestManager.is_completed(QUEST):
		return STEPS.size()
	if not QuestManager.is_active(QUEST):
		return -1
	var progress := QuestManager.get_quest_progress(QUEST)
	var objectives := LuaData.dict(progress.get("objectives", {}))
	for i in STEPS.size():
		if not bool(LuaData.dict(objectives.get(STEPS[i].id, {})).get("done", false)):
			return i
	return STEPS.size()

static func bloom_ready() -> bool:
	return step() > 6 or (step() == 6 and GameManager.total_day() > GameManager.flag_int(WATER_DAY, GameManager.total_day()))

static func has_evidence(id: String) -> bool:
	var threshold := {"letter_watermark": 8, "post_route": 9, "lift_record": 10, "garden_trail": 11}
	return threshold.has(id) and step() >= int(threshold[id])

static func advance(expected: int) -> bool:
	if expected < 0 or expected >= STEPS.size() or step() != expected:
		return false
	if expected == 6 and not bloom_ready():
		return false
	# Store the date before publishing objective progress. A save from an
	# objective listener then sees the complete watering transaction.
	if expected == 5:
		GameManager.set_flag(WATER_DAY, GameManager.total_day())
	return QuestManager.complete_manual(QUEST, StringName(STEPS[expected].id))

static func choice(npc: String) -> Dictionary:
	if npc not in HELPERS or step() < 0:
		return {}
	var available_from := {"gardener_hoppe": 1, "carpenter_brumme": 2, "postman_pip": 8, "guard_oak": 9}
	if available_from.has(npc) and step() < int(available_from[npc]):
		return {}
	if npc.begins_with("ghostfam_") and not has_evidence("letter_watermark"):
		return {}
	return {"id": "secret_garden", "text_key": "SG_TOPIC", "action": "garden_story"}

static func topic_page(npc: String) -> Dictionary:
	if choice(npc).is_empty():
		return {}
	var current := step()
	var key := "SG_RECALL_" + npc.to_upper()
	if npc.begins_with("ghostfam_"):
		key = "SG_FAMILY_KIN" if GameManager.character_type == GameManager.CharacterType.GHOST else "SG_FAMILY_FRIEND"
	elif current < STEPS.size() and str(STEPS[current].get("npc", "")) == npc:
		key = "SG_TALK_" + str(STEPS[current].id).to_upper()
	return {"speaker": npc, "social": false, "garden_npc": npc, "garden_step": current,
		"lines": [{"text_key": key}], "choices": [{"text_key": "REL_TALK_GOODBYE", "action": "close"}]}

static func finish_topic(npc: String, page: Dictionary, completed: bool, shown: int) -> bool:
	if not page.has("garden_step"):
		return false
	var expected := int(page.garden_step)
	if completed and shown >= LuaData.arr(page.get("lines", [])).size() and str(page.get("garden_npc", "")) == npc:
		if expected >= 0 and expected < STEPS.size() and str(STEPS[expected].get("npc", "")) == npc:
			advance(expected)
	return true

static func guide_key() -> String:
	var current := step()
	if current < 0:
		return "QUEST_SECRET_GARDEN_OFFER"
	if current >= STEPS.size():
		return "SG_COMPLETE"
	if current == 6 and not bloom_ready():
		return "SG_WAIT_MORNING"
	return "SG_GUIDE_" + str(STEPS[current].id).to_upper()
