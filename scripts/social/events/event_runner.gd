class_name SocialEventRunner
extends Node
## Scene data is read-only. Effects commit with the seen stamp at the end, including skip.
signal finished(id: String, skipped: bool)
## Resolves when an actor's own coroutine returns, or when the actor leaves the tree first.
class ActorTicket extends RefCounted:
	signal finished
	var resolved := false
	func done() -> void:
		if resolved: return
		resolved = true
		finished.emit()
const STEPS := ["fade","stand","walk","face","camera","clip","emote","say","choice","give","points","flag","wait","time","sfx","end"]
var active := ""
var skipped_directives := 0
var dialogue_runs := 0
var _generation := 0
var _skip := false
var _actors: Array[WeakRef] = []
var _effects: Array[Dictionary] = []
var _camera_used := false
var _dialogue: Node
var _nested_before := &""
var _meta: Dictionary = {}
var actor_resolver: Callable

static func yearly(meta: Dictionary) -> bool:
	return bool(meta.get("once_per_year",false)) or str(meta.get("repeat","once")) == "year"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.new_game_started.connect(cancel)
	EventBus.load_completed.connect(func(_slot): cancel())

func seen(id: String, definition: Dictionary) -> bool:
	var stamp := SocialManager.event_stamp(id)
	return stamp >= GameManager.year if yearly(LuaData.dict(definition.get("meta",{}))) else stamp > 0

func play(id: String, definition: Dictionary) -> bool:
	if active != "" or definition.is_empty() or seen(id,definition): return false
	if GameManager.current_phase != GameManager.GamePhase.PLAYING or GameManager.is_modal_open(): return false
	var world := get_tree().get_first_node_in_group("world_2d")
	if world == null or bool(world.get("traveling")) or bool(world.get("sleeping")): return false
	active = id
	dialogue_runs = 0
	_generation += 1
	var generation := _generation
	_skip = false
	_effects.clear()
	_camera_used = false
	_meta = LuaData.dict(definition.get("meta",{}))
	GameManager.push_modal(&"event",false)
	var npc := str(_meta.get("npc",""))
	_take_actor(_actor("player"))
	_take_actor(_actor(npc))
	var heart := str(_meta.get("trigger","talk")) == "talk" and npc != ""
	if heart: EventBus.game_event.emit(&"heart_event_started",{"id":id,"npc":npc,"hearts":_meta.get("hearts",0)})
	var steps := eligible_steps(definition)
	var index := 0
	while index < steps.size() and generation == _generation:
		await _hold(generation)
		if generation != _generation: return false
		var step := LuaData.dict(steps[index])
		var act := str(step.get("act",""))
		if act == "say":
			var who := str(step.get("who",npc))
			var lines: Array = []
			while index < steps.size() and str(steps[index].get("act","")) == "say" and str(steps[index].get("who",npc)) == who:
				lines.append({"text_key":str(steps[index].get("text_key",""))})
				index += 1
			var choices: Array = []
			if index < steps.size() and str(steps[index].get("act","")) == "choice":
				choices = LuaData.arr(steps[index].get("options",[]))
				index += 1
			var choice: Dictionary = choices[0] if not choices.is_empty() else {}
			if not _skip:
				var result := await _say(who,lines,choices,generation)
				if not _skip: choice = LuaData.dict(result.get("choice",{}))
			if generation != _generation: return false
			_choice(choice,who)
			if not _skip and str(choice.get("reply_key","")) != "": await _say(who,[{"text_key":str(choice.reply_key)}],[],generation)
			continue
		if act == "choice":
			var choices := LuaData.arr(step.get("options",[]))
			if not choices.is_empty():
				var chosen: Dictionary = choices[0]
				if not _skip:
					var result := await _say(npc,[],choices,generation)
					if not _skip: chosen = LuaData.dict(result.get("choice",{}))
				_choice(chosen,npc)
		elif act in ["give","points","flag","time"]:
			_effects.append(step.duplicate(true))
		elif act == "end": break
		elif not _skip: await _directive(step,generation)
		index += 1
	if generation != _generation: return false
	var rewards := LuaData.dict(definition.get("rewards",{}))
	if str(rewards.get("flag","")) != "": _effects.append({"act":"flag","key":str(rewards.flag),"value":true})
	if int(rewards.get("points",0)) > 0: _effects.append({"act":"points","npc":npc,"amount":int(rewards.points)})
	for item in LuaData.dict(rewards.get("items",{})): _effects.append({"act":"give","item":str(item),"amount":int(rewards.items[item])})
	_commit(id)
	var skipped := _skip
	await _release()
	if generation != _generation: return false
	active = ""
	GameManager.pop_modal(&"event")
	if heart: EventBus.game_event.emit(&"heart_event_finished",{"id":id,"npc":npc,"hearts":_meta.get("hearts",0)})
	finished.emit(id,skipped)
	SaveManager.autosave()
	return true

## Resolve conditional lines/effects once, before playback. Normal play and skip
## consume exactly the same branch; flags still commit atomically at the ending.
func eligible_steps(definition: Dictionary) -> Array:
	return LuaData.arr(definition.get("steps",[])).filter(func(step):
		return SocialManager.eval_when(str(LuaData.dict(step).get("when",""))))

func _choice(option: Dictionary, who: String) -> void:
	if int(option.get("points",0)) > 0: _effects.append({"act":"points","npc":who,"amount":int(option.points)})
	var flag := str(option.get("flag",""))
	if flag != "": _effects.append({"act":"flag","key":flag,"value":true})

## True while another modal (the skip confirm) sits on top of the scene: the scene waits for it instead of running on unseen.
func _covered() -> bool:
	return GameManager.is_modal_open(&"event") and GameManager.top_modal() != &"event"

func _hold(generation: int) -> void:
	while generation == _generation and not _skip and _covered():
		await get_tree().process_frame

func _say(who: String, lines: Array, choices: Array, generation: int) -> Dictionary:
	_take_actor(_actor(who))
	_dialogue = get_tree().get_first_node_in_group("dialogue_ui")
	if _dialogue == null: return {"choice":choices[0] if not choices.is_empty() else {}}
	dialogue_runs += 1
	_nested_before = _dialogue.nested_under
	_dialogue.nested_under = &"event"
	var speaker := {"id":who,"name_key":SocialData.npc_row(who).get("name_key","")}
	if who == "player": speaker = {"id":"player","name_key":"SOC_EV_YOU","portrait":null}
	# A refused page was never shown, so it is never an answer: wait until the scene is on top again and show it then.
	var result: Dictionary = {}
	while generation == _generation and not _skip:
		await _hold(generation)
		if generation != _generation or _skip or not is_instance_valid(_dialogue): break
		result = await _dialogue.show_lines(speaker,lines,choices)
		if not bool(result.get("refused",false)): break
		await get_tree().process_frame
	if is_instance_valid(_dialogue): _dialogue.nested_under = _nested_before
	return result

func _actor(id: String) -> Node:
	if actor_resolver.is_valid(): return actor_resolver.call(id)
	if id == "player": return get_tree().get_first_node_in_group("player")
	return NpcDirector.node_of(id) if id != "" else null

func _take_actor(actor: Node) -> void:
	if not is_instance_valid(actor): return
	for ref in _actors:
		if ref.get_ref() == actor: return
	_actors.append(weakref(actor))
	if actor.has_method("event_begin"): actor.event_begin()

func _point(step: Dictionary, actor: Node) -> Vector2:
	var world := get_tree().get_first_node_in_group("world_2d")
	var mark := str(step.get("mark",step.get("at",""))).trim_prefix("mark:")
	var at := NpcDirector.post_ground(str(world.area.map.id),StringName(mark)) if world != null and world.area != null else Vector2.INF
	if at != Vector2.INF:
		var point: Vector2 = world.area.to_global(Iso.to_screen(at))
		return _clear_stage(world.area,point) if bool(step.get("clear_view",false)) else point
	return actor.global_position if actor is Node2D else Vector2.INF

## A navigable foot point can still be hidden by a tall trunk or roof. Choose
## the nearest unobscured floor cell on the SAME platform for a staged scene.
func _clear_stage(area: IsoArea,point: Vector2) -> Vector2:
	var city := CityBuilder.of(area)
	var town := area.get_node_or_null("TownDirector") as TownDirector
	if city == null or town == null or town.level_nav == null:return point
	var level := city.registry.level_at(point)
	if level == null or _stage_clear(city.stage.fade.targets,point,level.rank):return point
	var chosen := point
	var best := INF
	for floor in town.level_nav.levels:
		if str(floor.id)!=str(level.id):continue
		for cell in LuaData.dict(floor.get("main",{})):
			var ground: Vector2 = town.level_nav._centre(floor,cell)
			var candidate := area.to_global(Iso.to_screen(ground))
			var distance := ground.distance_squared_to(Iso.to_ground(area.to_local(point)))
			if distance<best and distance<=600.0*600.0 and _stage_clear(city.stage.fade.targets,candidate,level.rank):
				best = distance
				chosen = candidate
	return chosen

func _stage_clear(targets: Array,point: Vector2,rank: int) -> bool:
	for target in targets:
		if rank<=int(target.rank) and point.y<float(target.pivot_y) and point.y>float(target.top_y) and point.x>=float(target.x0)-72 and point.x<=float(target.x1)+72:return false
	return true

func _directive(step: Dictionary, generation: int) -> void:
	var act := str(step.get("act",""))
	var actor := _actor(str(step.get("who",_meta.get("npc","player"))))
	_take_actor(actor)
	if act in ["walk","stand","face","clip","emote","camera"]:
		var method := "camera_focus" if act == "camera" else "event_"+act
		if act == "walk": method = "event_walk_to"
		if act == "camera": actor = _actor("player")
		if not is_instance_valid(actor) or not actor.has_method(method):
			skipped_directives += 1
			return
		match act:
			"walk":
				var point := _point(step,actor)
				if point != Vector2.INF: await _await_actor(actor,method,[point,float(step.get("speed",185))])
			"stand":
				var point := _point(step,actor)
				if point != Vector2.INF: actor.event_stand(point,str(step.get("facing","S")))
			"face":
				if actor is Player2D:
					actor.event_face(Iso.dir8_vector(Iso.DIR8_NAMES.find(str(step.get("dir","S")))))
				else: actor.event_face(step.get("dir","S"))
			"clip": actor.event_clip(str(step.get("clip","idle")))
			"emote": actor.event_emote(str(step.get("kind","heart")))
			"camera":
				var focus := str(step.get("focus",step.get("target",_meta.get("npc","player"))))
				var target: Variant = _point({"mark":focus},actor) if focus.begins_with("mark:") else _actor(focus)
				if target != null and not (target is Vector2 and target == Vector2.INF):
					if target is Node: _take_actor(target)
					_camera_used = true
					await _await_actor(actor,"camera_focus",[target,float(step.get("zoom",0.7)),float(step.get("time",step.get("seconds",0.25)))])
	elif act == "sfx": AudioManager.play_sfx(str(step.get("id","")))
	elif act in ["wait","fade"]:
		var seconds := clampf(float(step.get("time",step.get("seconds",0.25))),0.0,10.0)
		if act == "fade":
			var ui := get_tree().get_first_node_in_group("game_ui")
			if ui != null: ui.get_screen(&"event_overlay").fade_to(1.0 if str(step.get("to","clear")) == "black" else 0.0,seconds)
		var elapsed := 0.0
		while elapsed < seconds and generation == _generation and not _skip:
			await get_tree().process_frame
			if not _covered(): elapsed += get_process_delta_time()
	else: skipped_directives += 1

func _commit(id: String) -> void:
	# No save is allowed inside an event. Item notifications are delivered only
	# after the stamp, flags and owed rewards form a complete committed state.
	EconomyManager.defer_notifications(func() -> void:
		SocialManager.mark_event_seen(id,GameManager.year if yearly(_meta) else 1)
		SocialManager.mark_event_seen("day:"+id,SocialManager.today())
		var flags := {}
		var points := {}
		var items := {}
		var minutes := 0
		for step in _effects:
			match str(step.act):
				"give":
					var item := str(step.get("item",""))
					if not ItemKinds.def(item).is_empty() and not ItemKinds.is_one_of_a_kind(item): items[item] = int(items.get(item,0))+clampi(int(step.get("amount",1)),1,99)
				"points":
					var npc := str(step.get("npc",step.get("who",_meta.get("npc",""))))
					points[npc] = mini(100,int(points.get(npc,0))+maxi(0,int(step.get("amount",step.get("points",0)))))
				"flag":
					var key := str(step.get("key",step.get("flag","")))
					if key != "": flags[key] = step.get("value",true)
				"time": minutes += maxi(0,int(step.get("minutes",0)))
		SocialManager.owe_event_items(items)
		GameManager.set_flags(flags)
		for npc in points: SocialManager.add_points(npc,int(points[npc]),&"event")
		var left := maxi(0,GameManager.day_end_hour()*60-1-GameManager.hour*60-GameManager.minute)
		if minutes > 0: GameManager.advance_time(mini(mini(minutes,120),left))
	)

func skip() -> void:
	if active == "": return
	_skip = true
	if is_instance_valid(_dialogue) and _dialogue.is_open(): _dialogue.close()
	for ref in _actors:
		var actor: Node = ref.get_ref()
		if actor != null and actor.has_method("event_end"): actor.event_end()

## Await a coroutine that another node owns (a walk, a camera move) through a ticket: a node freed mid-await never resumes
## its callers, so the actor leaving the tree also ends the wait and the scene goes on.
func _await_actor(actor: Node, method: String, args: Array) -> void:
	var ticket := ActorTicket.new()
	actor.tree_exiting.connect(ticket.done,CONNECT_ONE_SHOT)
	_run_actor(ticket,actor,method,args)
	if not ticket.resolved: await ticket.finished
	if is_instance_valid(actor) and actor.tree_exiting.is_connected(ticket.done): actor.tree_exiting.disconnect(ticket.done)

func _run_actor(ticket: ActorTicket, actor: Node, method: String, args: Array) -> void:
	await actor.callv(method,args)
	ticket.done()

func _release() -> void:
	var player := _actor("player")
	if _camera_used and player != null and player.has_method("camera_release"): await _await_actor(player,"camera_release",[0.0 if _skip else 0.25])
	for ref in _actors:
		var actor: Node = ref.get_ref()
		if actor != null and actor.has_method("event_end"): actor.event_end()
	_actors.clear()

func cancel() -> void:
	_generation += 1
	var player := _actor("player") if is_inside_tree() else null
	if _camera_used and is_instance_valid(player) and player.has_method("camera_release"): player.camera_release(0.0)
	_camera_used = false
	if is_instance_valid(_dialogue) and _dialogue.is_open(): _dialogue.close()
	for ref in _actors:
		var actor: Node = ref.get_ref()
		if actor != null and actor.has_method("event_end"): actor.event_end()
	_actors.clear()
	_effects.clear()
	active = ""
	GameManager.pop_modal(&"event")
