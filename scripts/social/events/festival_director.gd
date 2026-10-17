class_name SocialEventDirector
extends Node
## Owns the short queue. Actors, event progress and friendship remain in their existing owners.
const RUNNER := preload("res://scripts/social/events/event_runner.gd")
var runner: SocialEventRunner
var queue: Array[Dictionary] = []
var _waiting := false
var _starting := false
var _tick := 0.0
var _stage: Node

static func attach(manager: Node) -> Node:
	if manager.has_node("EventDirector"): return manager.get_node("EventDirector")
	var node := SocialEventDirector.new()
	node.name = "EventDirector"
	manager.add_child(node)
	return node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	runner = RUNNER.new()
	runner.name = "EventRunner"
	add_child(runner)
	runner.finished.connect(func(_id,_skip): _schedule())
	EventBus.game_event.connect(_event)
	EventBus.modal_changed.connect(func(_stack): _schedule())
	EventBus.day_started.connect(func(_day,_season): _schedule())
	EventBus.time_of_day_changed.connect(func(_hour,_minute): _schedule())
	EventBus.area_changed.connect(func(_id): _schedule())
	EventBus.load_completed.connect(func(_slot): reset())
	EventBus.new_game_started.connect(reset)
	set_process(false)

func reset() -> void:
	queue.clear()
	runner.cancel()
	if is_instance_valid(_stage): _stage.queue_free()
	_stage = null
	_schedule()

func _event(id: StringName, payload: Dictionary) -> void:
	if id == &"start_heart_event":
		var npc := str(payload.get("npc",""))
		var event_id := str(payload.get("id",""))
		if event_id in SocialManager.events_ready(npc): request(event_id)
	elif id in [&"town_festival_started",&"town_festival_ended"]: _schedule()
	elif id == &"event_skip_requested":
		var ui := get_tree().get_first_node_in_group("game_ui")
		var overlay: Node = ui.get_screen(&"event_overlay") if ui != null else null
		if overlay != null: overlay.request_skip()

func request(id: String, automatic := false, definition: Dictionary = {}) -> bool:
	var data := definition if not definition.is_empty() else SocialData.event(id)
	if data.is_empty() or runner.seen(id,data) or runner.active == id or queue.any(func(row): return str(row.id) == id) or queue.size() >= 4: return false
	queue.append({"id":id,"automatic":automatic,"day":SocialManager.today(),"definition":data.duplicate(true)})
	_schedule()
	return true

func _schedule() -> void:
	if not _waiting:
		_waiting = true
		_flush.call_deferred()

func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 0.1:
		_tick = 0.0
		_schedule()

func _flush() -> void:
	_waiting = false
	if _starting or runner.active != "": return
	var world := get_tree().get_first_node_in_group("world_2d")
	if world == null:
		set_process(false)
		return
	for row in queue.duplicate():
		if bool(row.automatic) and SocialManager.today()-int(row.day) >= 2:
			queue.erase(row)
			EventBus.notification_posted.emit(tr("SOC_EV_TITLE"),tr("SOC_EV_MISSED"),"social")
	var busy := bool(world.get("traveling")) or bool(world.get("sleeping"))
	set_process(busy)
	if busy or GameManager.current_phase != GameManager.GamePhase.PLAYING or GameManager.is_modal_open(): return
	_sync_festival(world)
	if queue.is_empty(): return
	var row: Dictionary = queue.pop_front()
	var meta := LuaData.dict(row.definition.get("meta",{}))
	if str(meta.get("trigger","talk")) == "talk" and str(meta.get("npc","")) != "" and not str(row.id) in SocialManager.events_ready(str(meta.npc)):
		_schedule()
		return
	_starting = true
	await runner.play(str(row.id),row.definition)
	_starting = false
	_schedule()

func _sync_festival(world: Node) -> void:
	var id := str(SocialManager.festival_active())
	var meta := LuaData.dict(SocialData.festival(id).get("meta",{}))
	var area: Node = world.get("area")
	var wanted := id != "" and area != null and str(area.map.id) == str(meta.get("area",""))
	if is_instance_valid(_stage) and (not wanted or str(_stage.get("festival_id")) != id or _stage.get("area") != area):
		_stage.queue_free()
		_stage = null
	if not wanted: return
	if not is_instance_valid(_stage):
		_stage = Svc.static_call("res://scripts/social/events/festival_stage.gd",&"attach",[area,id,self],null)
	var scenes := LuaData.dict(SocialData.festival(id).get("scenes",{}))
	var ending := float(GameManager.hour)+GameManager.minute/60.0 >= float(SocialManager.festival_window(id).to)-1.0
	var suffix := "end" if ending else "open"
	var event_id := str(scenes.get("finale" if ending else "opening","ev_"+id+"_"+suffix))
	var data := SocialData.event(event_id)
	if data.is_empty():
		data = {"meta":{"trigger":"automatic","repeat":"year","festival":id},"steps":[{"act":"say","who":str(meta.get("host","")),"text_key":"FEST_"+id.to_upper()+"_"+suffix.to_upper()}]}
	if ending:
		data = data.duplicate(true)
		var rewards := LuaData.dict(SocialData.festival(id).get("rewards",{}))
		data["rewards"] = LuaData.dict(rewards.get("finale",{})).duplicate(true)
		if is_instance_valid(_stage) and _stage.potluck_count() >= 12:
			var bonus := LuaData.dict(LuaData.dict(rewards.get("potluck",{})).get("items",{}))
			var items := LuaData.dict(data.rewards.get("items",{}))
			for item in bonus: items[item] = int(items.get(item,0))+int(bonus[item])
			data.rewards["items"] = items
	request(event_id,true,data)
