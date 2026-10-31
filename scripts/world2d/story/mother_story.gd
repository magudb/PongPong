class_name MotherStory
extends RefCounted
## Evidence uses versioned scalar flags, independent of daily dungeon cells and
## backpack space. Quest objectives are a catch-up projection of that record.
const VERSION := 1
const PREFIX := "forest_mother_v1_"
const EVIDENCE := [
	{"id":"marked_lamp","floor":1,"art":"mother_repaired_lantern","kind":"seen"},
	{"id":"map_account","npc":"mapseller_natteblik","kind":"witness"},
	{"id":"memory_lamp","floor":5,"art":"mother_repaired_lantern","kind":"memory"},
	{"id":"memory_table","floor":5,"art":"table_tea","kind":"memory"},
	{"id":"memory_basket","floor":5,"art":"seed_basket","kind":"memory"},
	{"id":"memory_map","floor":5,"art":"mother_route_map","kind":"memory"},
	{"id":"echo_account","npc":"appraiser_fru_ugle","area":"secret_garden","art":"mother_route_map","kind":"witness"},
	{"id":"traveller_account","floor":7,"art":"root_scribe_waymarker","kind":"remembered"},
	{"id":"return_promise","floor":9,"art":"mother_route_map","kind":"remembered"},
	{"id":"route_stone","floor":10,"art":"runestone_dormant","kind":"seen"},
	{"id":"route_witness","npc":"mapseller_natteblik","kind":"witness"},
	{"id":"last_journey","floor":11,"art":"mother_route_map","kind":"remembered"},
	{"id":"mother_fate","floor":12,"art":"root_scribe_waymarker","kind":"confirmed"},
	{"id":"legacy_home","area":"secret_garden","art":"mother_seed_tin","kind":"confirmed"},
]
const CHAPTERS := [
	{"id":"s03","needs":["marked_lamp","map_account"],"boss_floor":4},
	{"id":"s04","needs":["memory_lamp","memory_table","memory_basket","memory_map","echo_account"]},
	{"id":"s05","needs":["traveller_account"],"boss_floor":8},
	{"id":"s06","needs":["return_promise","route_stone","route_witness"]},
	{"id":"s07","needs":["last_journey"],"boss_floor":12},
	{"id":"s08","needs":["mother_fate","legacy_home"]},
]
const HELPERS := ["mapseller_natteblik","appraiser_fru_ugle","postman_pip","guard_oak","ghostfam_dyne","ghostfam_silke"]
static var _syncing := false
static var _sync_origin: Dictionary = {}
static func enabled() -> bool:
	return SecretGardenStory.has_evidence("garden_trail") or GameManager.flag_int(&"forest_mother_version",0) == VERSION
static func has(id: String) -> bool:
	return GameManager.flag_int(StringName(PREFIX+id),0) > 0
static func definition(id: String) -> Dictionary:
	for row in EVIDENCE:
		if row.id == id: return row
	return {}
static func evidence_text_key(id: String) -> String:
	if id == "last_journey" and not QuestManager.is_completed(quest_id("s06")):
		return "FM_E_LAST_JOURNEY_OBSERVATION"
	return "FM_E_"+id.to_upper()+"_TEXT"
static func quest_id(chapter: String) -> StringName:
	return StringName("forest_mother_"+chapter)
static func boss_cleared(number: int) -> bool:
	var spec := DungeonSpec.spec_for(LuaData.dict(Svc.lua_config("dungeon",{})),number)
	var kind := str(spec.get("boss_kind",""))
	if kind == "": return false
	return GameManager.flag_int(StringName("dungeon_boss_"+kind),0) > 0
static func can_read(id: String) -> bool:
	if not enabled() or definition(id).is_empty(): return false
	if id == "mother_fate": return QuestManager.is_completed(quest_id("s07"))
	if id == "legacy_home": return has("mother_fate")
	if id == "echo_account": return has("memory_lamp") and has("memory_table") and has("memory_basket") and has("memory_map")
	if id == "memory_map": return has(id) or MotherMemoryWork.complete("memory_lamp")
	return MotherMemoryWork.complete(id)
static func record(id: String) -> bool:
	return record_owned(id, EventBus.interaction_origin())

static func record_owned(id: String, origin: Dictionary) -> bool:
	if not EventBus.interaction_current(origin): return false
	if not can_read(id) or has(id): return false
	if not EventBus.interaction_current(origin): return false
	var changes := {"forest_mother_version":VERSION,PREFIX+id:GameManager.total_day()}
	if id == "mother_fate":
		# One commit owns the truth, refusal and keepsake. No inventory insert
		# can fail between the revelation and the return-home objective.
		changes[PREFIX+"own_name_restored"] = true
		changes[PREFIX+"role_refused"] = true
		changes[PREFIX+"seed_tin_homeward"] = true
	GameManager.set_flags(changes)
	# The atomic evidence commit is earned even when its observer supersedes
	# the operation. Only the remaining projection/save/notification is revoked.
	if not EventBus.interaction_current(origin): return true
	sync_owned(origin)
	if not EventBus.interaction_current(origin): return true
	SaveManager.autosave()
	if not EventBus.interaction_current(origin): return true
	var current_chapter := chapter()
	if not EventBus.interaction_current(origin): return true
	EventBus.game_event.emit(&"forest_mother_evidence",{"id":id,"chapter":current_chapter,"version":VERSION})
	if EventBus.interaction_current(origin): EventBus.mother_progressed.emit(origin)
	return true

static func sync() -> void:
	sync_owned(EventBus.interaction_origin())

static func sync_owned(origin: Dictionary) -> void:
	if not EventBus.interaction_current(origin) or not enabled(): return
	if not EventBus.interaction_current(origin): return
	# Suppress recursive projection of the same current operation, not a
	# genuine newer load/area root after the suspended origin was revoked.
	if _syncing and EventBus.interaction_current(_sync_origin): return
	var previous_syncing := _syncing
	var previous_origin := _sync_origin
	_syncing = true
	_sync_origin = origin
	_sync_chapters_owned(origin)
	_sync_origin = previous_origin
	_syncing = previous_syncing

## Keep unwind outside the cancellable loop; a refused suffix must not strand
## future genuine work, nor latch a temporary failed-load barrier.
static func _sync_chapters_owned(origin: Dictionary) -> void:
	GameManager.set_flag(&"forest_mother_version",VERSION)
	if not EventBus.interaction_current(origin): return
	for row in CHAPTERS:
		if not EventBus.interaction_current(origin): return
		var quest := quest_id(row.id)
		if QuestManager.is_completed(quest): continue
		if not EventBus.interaction_current(origin): return
		if not QuestManager.is_active(quest):
			if not EventBus.interaction_current(origin): return
			GameManager.set_flag(StringName("forest_mother_ready_"+str(row.id)),true)
			if not EventBus.interaction_current(origin): return
			QuestManager.accept_quest_owned(quest, origin)
			if not EventBus.interaction_current(origin): return
		for id in row.needs:
			if not EventBus.interaction_current(origin): return
			if has(id):
				QuestManager.complete_manual_owned(quest,StringName(id),{},false,origin)
				if not EventBus.interaction_current(origin): return
		if row.has("boss_floor") and boss_cleared(row.boss_floor):
			if not EventBus.interaction_current(origin): return
			QuestManager.complete_manual_owned(quest,&"checkpoint",{},false,origin)
			if not EventBus.interaction_current(origin): return
		if not QuestManager.is_completed(quest): break
static func chapter() -> String:
	for row in CHAPTERS:
		if not QuestManager.is_completed(quest_id(row.id)): return row.id
	return "complete"
static func next_lead() -> String:
	if not enabled(): return "FM_NEXT_GARDEN"
	for row in CHAPTERS:
		for id in row.needs:
			if not has(id): return "FM_LEAD_"+str(id).to_upper()
		if row.has("boss_floor") and not boss_cleared(row.boss_floor): return "FM_LEAD_CHECKPOINT_"+str(row.id).to_upper()
	return "FM_NEXT_COMPLETE"
static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in ["letter_watermark","post_route","lift_record","garden_trail"]:
		if SecretGardenStory.has_evidence(id): result.append({"id":id,"kind":"seen"})
	for row in EVIDENCE:
		if has(row.id): result.append(row)
	return result
static func choice(npc: String) -> Dictionary:
	return {"id":"forest_mother","text_key":"FM_TOPIC","action":"mother_story"} if enabled() and npc in HELPERS else {}
static func _npc_evidence(npc: String) -> String:
	if npc == "mapseller_natteblik":
		if has("return_promise") and has("route_stone") and not has("route_witness"): return "route_witness"
		if has("marked_lamp") and not has("map_account"): return "map_account"
	if npc == "appraiser_fru_ugle" and has("memory_lamp") and has("memory_table") and has("memory_basket") and has("memory_map") and not has("echo_account"): return "echo_account"
	return ""
static func topic_page(npc: String) -> Dictionary:
	if choice(npc).is_empty(): return {}
	var evidence := _npc_evidence(npc)
	var key := "FM_NPC_"+npc.to_upper()
	if npc.begins_with("ghostfam_"): key = "FM_FAMILY_KIN" if GameManager.character_type == GameManager.CharacterType.GHOST else "FM_FAMILY_FRIEND"
	if has("legacy_home"): key = "FM_AFTER_"+npc.to_upper()
	if evidence != "": key = "FM_E_"+evidence.to_upper()+"_TEXT"
	return {"speaker":npc,"social":false,"mother_npc":npc,"mother_evidence":evidence,"lines":[{"text_key":key},{"text_key":"FM_RECORD_ACCOUNT" if evidence != "" else next_lead()}],"choices":[{"text_key":"REL_TALK_GOODBYE","action":"close"}]}
static func finish_topic(npc: String,page: Dictionary,completed: bool,shown: int) -> bool:
	return finish_topic_owned(npc, page, completed, shown, EventBus.interaction_origin())

static func finish_topic_owned(npc: String,page: Dictionary,completed: bool,shown: int,origin: Dictionary) -> bool:
	if not EventBus.interaction_current(origin) or not page.has("mother_npc"): return false
	var id := str(page.get("mother_evidence",""))
	if completed and shown >= LuaData.arr(page.get("lines",[])).size() and str(page.mother_npc) == npc and id != "" and id == _npc_evidence(npc):
		if EventBus.interaction_current(origin): record_owned(id, origin)
	return true
