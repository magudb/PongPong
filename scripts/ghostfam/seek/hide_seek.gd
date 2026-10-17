class_name GhostSeek
extends Node2D
## Count real routine slots, never clock guesses. Progress lives in scalar world flags.
const NPC := "ghostfam_blund"
var npc: Npc2D
var shimmer: Node2D
var _dots: Array[Sprite2D] = []
static var _feedback := {}
static var _feedback_day := -1
var _tick := 0.0
var _phase := 0.0
static var _kin_hint := false
var _claiming := false
static func cfg() -> Dictionary:
	return LuaData.dict(Svc.lua_config("ghostfam_seek",{}))
static func attach(actor: Node) -> Node:
	if actor.has_node("HideSeek"):return actor.get_node("HideSeek")
	if str(actor.get("npc_id"))!=NPC or not actor is Npc2D:return null
	var node := GhostSeek.new()
	node.name = "HideSeek"
	node.npc = actor
	actor.add_child(node)
	return node
static func slot_now(context: Dictionary = {}) -> Dictionary:
	var ctx := Routines.now_ctx() if context.is_empty() else context
	var at := NpcDirector.where_is(NPC,ctx)
	if str(at.get("state",""))!="stay" or str(at.get("act",""))!="hide":return {}
	for day in LuaData.arr(cfg().get("slots",[])):
		if int(day.weekday)!=int(ctx.get("weekday",CalendarUtil.weekday_of(GameManager.total_day()))):continue
		for name in ["a","b"]:
			var slot := LuaData.dict(day.get(name,{}))
			if str(at.get("area",""))==str(slot.get("area","")) and str(at.get("place",""))==str(slot.get("area",""))+"."+str(slot.get("post","")):
				return {"number":1 if name=="a" else 2,"area":str(slot.area),"post":str(slot.post)}
	return {}
static func found_slot(number: int) -> bool:
	if number not in [1,2]:return false
	return GameManager.flag_int(&"ghostfam_seek_day",0)==GameManager.total_day() and (GameManager.flag_int(&"ghostfam_seek_today",0)&(1<<(number-1)))!=0
static func shimmer_radius() -> float:
	var data := cfg()
	var radius := float(LuaData.dict(data.get("hint",{})).get("shimmer_px",260))
	var mult := float(LuaData.dict(data.get("kin",{})).get("shimmer_mult",1.5)) if GameManager.character_type==GameManager.CharacterType.GHOST else 1.0
	return radius*mult
static func reset_feedback(_slot: int = -1) -> void:
	_feedback.clear()
	_feedback_day = -1
	_kin_hint = false
func _ready() -> void:
	if not EventBus.new_game_started.is_connected(reset_feedback):EventBus.new_game_started.connect(reset_feedback)
	if not EventBus.load_completed.is_connected(reset_feedback):EventBus.load_completed.connect(reset_feedback)
	shimmer = Node2D.new()
	shimmer.name = "Shimmer"
	# Keep the clue over foliage on this floor, below every higher deck.
	shimmer.z_index = 1
	add_child(shimmer)
	for offset in [Vector2(-13,-110),Vector2(8,-145),Vector2(23,-115)]:
		var dot := Sprite2D.new()
		dot.texture = Glow.halo_texture()
		dot.material = Glow.additive_material()
		dot.modulate = Color("cfe6f2")
		dot.scale = Vector2.ONE*.16
		dot.position = offset
		shimmer.add_child(dot)
		_dots.append(dot)
	_refresh()
func _process(delta: float) -> void:
	_phase += delta
	_tick += delta
	if _tick<.1:return
	_tick = 0
	_refresh()
func _live_slot() -> Dictionary:
	var slot := slot_now()
	if slot.is_empty() or not is_instance_valid(npc.area) or str(npc.area.map.id)!=str(slot.area):return {}
	var ground := NpcDirector.post_ground(str(slot.area),StringName(str(slot.post)))
	if ground==Vector2.INF:return {}
	var actual := Iso.to_ground(npc.area.to_local(npc.global_position))
	return slot if actual.distance_to(ground)<=20.0 else {}
func _refresh() -> void:
	if not is_instance_valid(npc) or npc.visual==null:return
	var slot := _live_slot()
	var hiding := not slot.is_empty() and not found_slot(int(slot.number)) and not npc.is_talking and not npc._event
	npc.set_meta("ghostfam_hiding",hiding)
	npc.visual.modulate.a = 0.0 if hiding else 1.0
	if hiding:npc._bubble_label.visible = false
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var distance := Iso.to_ground(player.global_position-npc.global_position).length() if player!=null else INF
	shimmer.visible = hiding and distance<=shimmer_radius()
	for i in _dots.size():_dots[i].modulate.a = .4+.35*(.5+.5*sin(_phase*2.7+i*2.0))
	if not hiding or GameManager.is_modal_open():return
	if _feedback_day!=GameManager.total_day():
		_feedback.clear()
		_feedback_day = GameManager.total_day()
	var stamp := str(GameManager.total_day())+":"+str(slot.number)
	var hints := LuaData.dict(cfg().get("hint",{}))
	for warmth in ["warm","hot"]:
		var key: String = stamp+":"+str(warmth)
		if distance<=float(hints.get(warmth+"_px",320 if warmth=="warm" else 140)) and not _feedback.has(key):
			_feedback[key] = true
			EventBus.whisper_requested.emit(tr("SEEK_GHOSTFAM_HINT_"+warmth.to_upper()))
	if shimmer.visible and GameManager.character_type==GameManager.CharacterType.GHOST and not _kin_hint:
		_kin_hint = true
		EventBus.whisper_requested.emit(tr("SEEK_GHOSTFAM_KIN_GLOW"))
func before_talk(player: Node) -> bool:
	var slot := _live_slot()
	if not slot.is_empty() and not found_slot(int(slot.number)):
		if not player is Node2D or Iso.to_ground(player.global_position-npc.global_position).length()>float(LuaData.dict(cfg().get("hint",{})).get("find_px",72)):return false
		_find(int(slot.number))
	else:
		# A full furniture stack can defer a gift; ordinary conversation retries it.
		GameManager.set_flag(&"ghostfam_seek_gift_now",claim_rewards())
	_refresh()
	return true
func _find(number: int) -> bool:
	if number not in [1,2] or found_slot(number):return false
	var today := GameManager.total_day()
	var mask := GameManager.flag_int(&"ghostfam_seek_today",0) if GameManager.flag_int(&"ghostfam_seek_day",0)==today else 0
	var cap := int(cfg().get("daily_cap",2))
	if int((mask&1)!=0)+int((mask&2)!=0)>=cap:return false
	EconomyManager.defer_notifications(func() -> void:
		var total := GameManager.flag_int(&"ghostfam_seek_total",0)+1
		GameManager.set_flags({"ghostfam_seek_total":total,"ghostfam_seek_day":today,"ghostfam_seek_today":mask|(1<<(number-1)),"ghostfam_seek_found_now":number,"ghostfam_seek_gift_now":0})
		SocialManager.add_points(NPC,int(cfg().get("find_points",5)),&"seek",{"toast":false})
		var gift := claim_rewards()
		GameManager.set_flag(&"ghostfam_seek_gift_now",gift)
		EconomyManager.after_transaction(func() -> void:
			EventBus.whisper_requested.emit(tr("SEEK_GHOSTFAM_TOAST_FOUND_FMT")%total)
		)
	)
	return true
## Check all unclaimed steps so a migrated save or a deferred gift catches up.
## No automatic duplicate sale: a full target store leaves the reward pending.
func claim_rewards() -> int:
	if _claiming:return 0
	_claiming = true
	var granted := [0]
	EconomyManager.defer_notifications(func() -> void:
		var total := GameManager.flag_int(&"ghostfam_seek_total",0)
		var mask := GameManager.flag_int(&"ghostfam_seek_claimed",0)
		var ladder := LuaData.arr(cfg().get("ladder",[]))
		for i in ladder.size():
			var step := LuaData.dict(ladder[i])
			if int(step.finds)>total or (mask&(1<<i))!=0:continue
			var item := str(step.item)
			var owned := ItemKinds.is_one_of_a_kind(item) and (EconomyManager.count_item(StringName(item))>0 or LootService.found(item))
			if owned:item = str(step.get("fallback",""))
			if item=="" or not EconomyManager.can_add_item(StringName(item)):
				EconomyManager.after_transaction(func() -> void:EventBus.whisper_requested.emit(tr("SEEK_GHOSTFAM_TOAST_BAG_FULL")))
				continue
			var result := LootService.deliver(item)
			if not bool(result.get("ok",false)):continue
			mask |= (1<<i)
			GameManager.set_flag(&"ghostfam_seek_claimed",mask)
			granted[0] = i+1+(10 if owned else 0)
			var shown := tr(str(ItemKinds.def(item).get("name_key","ITEM_"+item.to_upper())))
			EconomyManager.after_transaction(func() -> void:EventBus.whisper_requested.emit(tr("SEEK_GHOSTFAM_TOAST_GIFT_FMT")%shown))
	)
	_claiming = false
	return int(granted[0])
static func card_choice(npc_id: String) -> Dictionary:
	return {"id":"seek_card","text_key":"SEEK_GHOSTFAM_CARD_TITLE","action":"seek_card"} if npc_id==NPC else {}
static func card_page() -> Dictionary:
	var total := GameManager.flag_int(&"ghostfam_seek_total",0)
	var lines: Array = [{"text_key":"SEEK_GHOSTFAM_CARD_TITLE"},{"text_key":"SEEK_GHOSTFAM_CARD_COUNT_FMT","format_values":[total]}]
	for step in LuaData.arr(cfg().get("ladder",[])):
		if int(step.finds)>total:
			lines.append({"text_key":"SEEK_GHOSTFAM_TOAST_NEXT_FMT","format_values":[int(step.finds)-total]})
			break
	return {"speaker":NPC,"social":false,"lines":lines,"choices":[{"id":"close","text_key":"REL_TALK_GOODBYE","action":"close"}]}
func _exit_tree() -> void:
	if is_instance_valid(npc):
		npc.set_meta("ghostfam_hiding",false)
		if is_instance_valid(npc.visual):npc.visual.modulate.a = 1.0

static func hint_choice(npc_id: String,choice: Dictionary) -> Dictionary:
	if npc_id!="ghostfam_silke" or str(choice.get("id",""))!="ask_blund":return choice
	var result := choice.duplicate(true)
	result["action"] = "seek_hint"
	return result
static func hint_key(context: Dictionary = {}) -> String:
	var ctx := Routines.now_ctx() if context.is_empty() else context
	var slot := slot_now(ctx)
	if not slot.is_empty():return "DLG_GHOSTFAM_SILKE_SEEK_"+str(ctx.weekday)+("_A" if int(slot.number)==1 else "_B")
	if str(ctx.get("festival",""))!="":return "SEEK_GHOSTFAM_HINT_FESTIVAL"
	if int(ctx.weekday)==2:return "DLG_GHOSTFAM_SILKE_SEEK_OFF"
	var at := NpcDirector.where_is(NPC,ctx)
	if str(at.get("act",""))=="sleep":return "DLG_GHOSTFAM_SILKE_SEEK_SLEEP"
	if float(ctx.hour)>=23.5:return "SEEK_GHOSTFAM_HINT_REST"
	return "SEEK_GHOSTFAM_HINT_MOVING"
static func hint_page() -> Dictionary:
	return {"speaker":"ghostfam_silke","social":false,"lines":[{"text_key":hint_key()}],"choices":[{"id":"close","text_key":"REL_TALK_GOODBYE","action":"close"}]}
