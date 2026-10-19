class_name DungeonFloors
extends Node
## Run state hosted by LootService and applied before WorldRoot2D restores its
## position. Only data generation runs on workers; map registration stays here.
var cfg: Dictionary = {}
var last_error := ""
var world_seed := ""
var seed_day := 0
var active := false
var floor := 0
var deepest := 0
var stones: Dictionary = {}
var seen: Dictionary = {}
var done: Dictionary = {}
var reveal: Dictionary = {}
var gen := 1
var spec := ""
var _texts: Dictionary = {}
var _registered: Dictionary = {}
var _tasks: Dictionary = {}
var _generation := 0
## The deepest floor number a save may name at all (structure). How deep the dungeon goes TODAY is cfg.max_floor; a save made
## when it went deeper is clamped by from_dict, never rejected as damaged.
const SAVED_FLOOR_LIMIT := 999

static func inst() -> DungeonFloors:
	var loot := Svc.node("LootService")
	return loot.get_node_or_null("DungeonFloors") as DungeonFloors if loot != null else null
static func floor_of_id(id: Variant) -> int:
	var prefix := str(LuaData.dict(Svc.lua_config("dungeon.hub",{})).get("floor_prefix","moerkeskoven_f"))
	var text := str(id)
	if not text.begins_with(prefix): return 0
	var number := text.trim_prefix(prefix)
	return int(number) if number.is_valid_int() and str(int(number)) == number else 0
static func ensure_registered(number: int, total_day := -1) -> StringName:
	var service := inst()
	return service._ensure(number,total_day) if service != null else &""
static func floor_of(area: Node) -> int:
	return LuaData.int_of(area.map.extra.get("floor",0)) if area != null and area.get("map") != null else 0
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	cfg = LuaData.dict(Svc.lua_config("dungeon",{})).duplicate(true)
	gen = int(cfg.get("gen_version",1))
	spec = DungeonSpec.spec_hash(cfg)
	EventBus.area_changed.connect(_area_changed)
	EventBus.area_change_requested.connect(_area_requested)
	EventBus.day_started.connect(_morning)
	EventBus.enemy_defeated.connect(_enemy_defeated)
	reset()
func _exit_tree() -> void:
	_drain_tasks()
func reset() -> void:
	_invalidate()
	world_seed = str(DungeonRng.hash_key("newgame",int(Time.get_unix_time_from_system()),Time.get_ticks_usec() & 0x7FFFFFFF))
	seed_day = 0
	active = false
	floor = 0
	deepest = 0
	stones.clear()
	seen.clear()
	done.clear()
	reveal.clear()
func current_floor() -> int:
	return floor
func world_seed_text() -> String:
	return world_seed
func floor_seed(number: int, day := -1) -> int:
	return DungeonRng.hash_key(world_seed,seed_day if day < 0 else day,number)
func rng_keyed(stream: String, key: Variant) -> DungeonRng:
	return DungeonRng.new(DungeonRng.hash_key(world_seed+"|"+stream,seed_day,DungeonRng.hash_key(str(key),0,0) & 0x7FFFFFFF))
func band_of(number: int) -> String:
	return str(DungeonSpec.spec_for(cfg,number).get("band","skovkant"))
func _valid_floor(number: int) -> bool:
	return number >= 1 and number <= int(cfg.get("max_floor",12))
func _id(number: int) -> StringName:
	return StringName(str(LuaData.dict(cfg.get("hub",{})).get("floor_prefix","moerkeskoven_f"))+str(number))
func _clear_day(day: int) -> void:
	_invalidate()
	seed_day = day
	done.clear()
	seen.clear()
	reveal.clear()
func start_run(first_floor: int) -> bool:
	if not _valid_floor(first_floor): return false
	if not active and seed_day != GameManager.total_day(): _clear_day(GameManager.total_day())
	if _ensure(first_floor) == &"": return false
	var fresh := not active
	active = true
	floor = first_floor
	if fresh:
		GameManager.set_flag(&"dungeon_last_spark_used",false)
		var player := get_tree().get_first_node_in_group("player")
		if player != null and player.has_method("begin_dungeon_run"): player.begin_dungeon_run()
		Svc.static_call("res://scripts/world2d/enemy_2d.gd",&"begin_run")
	return true
func enter(number: int) -> bool:
	if not _valid_floor(number): return false
	if not active and not start_run(number): return false
	var id := _ensure(number)
	if id == &"": return false
	GameManager.pop_all_modals()
	EventBus.area_change_requested.emit(id,&"rune" if stones.has(number) else &"default")
	return true
func leave() -> void:
	GameManager.pop_all_modals()
	end_run(&"left")
	EventBus.area_change_requested.emit(StringName(str(cfg.hub.area)),&"from_floor")
func end_run(reason: StringName = &"left") -> void:
	GameManager.pop_all_modals()
	if not active: return
	var reached := floor
	active = false
	floor = 0
	EventBus.game_event.emit(&"dungeon_run_ended",{"reason":str(reason),"deepest":deepest,"floors":seen.size(),"floor":reached,"level":reached})
func _context(number: int) -> Dictionary:
	return {"day":seed_day,"seed_text":str(floor_seed(number)),"spec_hash":spec,"gen_version":gen}
func floor_text(number: int) -> String:
	if not _valid_floor(number): return ""
	if _texts.has(number): return str(_texts[number])
	_finish_task(number,true)
	if not _texts.has(number):
		var result := DungeonGen.build_text(cfg,number,floor_seed(number),_context(number))
		if not result.ok:
			last_error = str(result.get("error","generation_failed"))
			return ""
		_texts[number] = result.text
	return str(_texts[number])
func _ensure(number: int, day := -1) -> StringName:
	if not _valid_floor(number): return &""
	if not active and day >= 0 and seed_day != day: _clear_day(day)
	if _registered.has(number) and WorldRoot2D.has_area(_id(number)): return _id(number)
	var text := floor_text(number)
	if text == "": return &""
	var map := AreaMap.parse_text(text)
	if not map.errors.is_empty():
		last_error = str(map.errors)
		return &""
	WorldRoot2D.register_map(_id(number),map)
	_registered[number] = true
	return _id(number)
func _prefetch(number: int) -> void:
	if not _valid_floor(number): return
	if _texts.has(number):
		_ensure(number)
		return
	if _tasks.has(number): return
	# Capture a snapshot; a reset may invalidate the request while it runs.
	var snapshot := cfg.duplicate(true)
	var seed_value := floor_seed(number)
	var context := _context(number)
	var result := {}
	var task := WorkerThreadPool.add_task(func(): result["value"] = DungeonGen.build_text(snapshot,number,seed_value,context),false,"Forest floor %d" % number)
	_tasks[number] = {"id":task,"box":result,"generation":_generation}
func _finish_task(number: int, wait: bool) -> void:
	if not _tasks.has(number): return
	var task: Dictionary = _tasks[number]
	if not wait and not WorkerThreadPool.is_task_completed(task.id): return
	WorkerThreadPool.wait_for_task_completion(task.id)
	_tasks.erase(number)
	if int(task.generation) != _generation:
		last_error = "stale generation"
		return
	var result: Dictionary = task.box.get("value",{})
	if result.get("ok",false): _texts[number] = result.text
	else: last_error = "worker: " + str(result)
func _process(_dt: float) -> void:
	for number in _tasks.keys():
		if WorkerThreadPool.is_task_completed(_tasks[number].id):
			_finish_task(number,false)
			if (active and absi(int(number)-floor) <= 1) or (not active and number == 1): _ensure(number)
func _drain_tasks() -> void:
	for task in _tasks.values(): WorkerThreadPool.wait_for_task_completion(task.id)
	_tasks.clear()
func _invalidate() -> void:
	_generation += 1
	_drain_tasks()
	for number in _registered: WorldRoot2D.unregister_map(_id(int(number)))
	_registered.clear()
	_texts.clear()
func _area_requested(id: StringName, _spawn: StringName) -> void:
	var number := floor_of_id(id)
	if not _valid_floor(number): return
	if not active: start_run(number)
	_ensure(number)
func _area_changed(id: StringName) -> void:
	GameManager.set_flag(StringName(str(cfg.flags.boss_clear)),false)
	var number := floor_of_id(id)
	if _valid_floor(number):
		if not active: start_run(number)
		floor = number
		var first := not seen.has(number)
		seen[number] = true
		deepest = maxi(deepest,number)
		_restore_boss_flag()
		var player := get_tree().get_first_node_in_group("player")
		if first and player != null and player.has_method("restore_oil"): player.restore_oil()
		_ensure(number-1)
		_prefetch(number+1)
		_prune(number)
		EventBus.game_event.emit(&"dungeon_floor_entered",{"floor":number,"level":number,"band":band_of(number),"zone":band_of(number),"seed_day":seed_day,"first_today":first,"deepest":deepest})
		_attach_world_effects.call_deferred(number)
	else:
		if active: end_run(&"left")
		if str(id) == str(cfg.hub.area):
			if seed_day != GameManager.total_day(): _clear_day(GameManager.total_day())
			_ensure(1)
			_prefetch(2)
func _prune(number: int) -> void:
	for other in _registered.keys():
		if absi(int(other)-number) > 1:
			WorldRoot2D.unregister_map(_id(int(other)))
			_registered.erase(other)
			_texts.erase(other)
func _morning(_day: int, _season: StringName) -> void:
	if not active:
		_clear_day(GameManager.total_day())
func start_floors() -> Array:
	var result: Array = [1]
	for number in stones:
		if int(number) != 1: result.append(int(number))
	result.sort()
	return result
func activate_stone(number: int) -> bool:
	if not _valid_floor(number): return false
	var first := not stones.has(number)
	stones[number] = true
	var payload := {"floor":number,"level":number,"band":band_of(number),"first_time":first,"waypoint":true}
	if first: EventBus.game_event.emit(&"dungeon_runestone_activated",payload)
	return first
func reveal_floor(number: int) -> bool:
	if not _valid_floor(number): return false
	var first := not reveal.has(number)
	reveal[number] = true
	if first: EventBus.game_event.emit(&"dungeon_floor_revealed",{"floor":number,"level":number})
	return true
func is_revealed(number: int) -> bool:
	return reveal.has(number)
func uid_of(area: Node, cell: Vector2i) -> String:
	return "dg:%d:%d:%d" % [seed_day,floor_of(area),cell.y * int(area.map.width)+cell.x]
func rng_for(area: Node, cell: Vector2i, purpose: String) -> DungeonRng:
	return DungeonRng.new(DungeonRng.hash_key(world_seed+"|"+purpose,seed_day,floor_of(area)*65536+cell.y*int(area.map.width)+cell.x))
func is_done_cell(area: Node, cell: Vector2i) -> bool:
	return cell.y*int(area.map.width)+cell.x in done.get(floor_of(area),[])
func mark_done_cell(area: Node, cell: Vector2i) -> void:
	var number := floor_of(area)
	if not _valid_floor(number): return
	if not done.has(number): done[number] = []
	var index := cell.y * int(area.map.width)+cell.x
	if index not in done[number]: done[number].append(index)
func _restore_boss_flag() -> void:
	var world := get_tree().get_first_node_in_group("world_2d")
	if world == null or world.area == null: return
	for marker in world.area.find_markers("enemy"):
		if str(marker.params.get("boss","0")) == "1" and is_done_cell(world.area,marker.cell):
			GameManager.set_flag(StringName(str(cfg.flags.boss_clear)),true)
func _enemy_defeated(_id: StringName, kind: StringName, _drops: Array = []) -> void:
	if not active: return
	var row := DungeonSpec.spec_for(cfg,floor)
	if str(row.get("boss_kind","")) != str(kind): return
	var world := get_tree().get_first_node_in_group("world_2d")
	if world == null or world.area == null: return
	for marker in world.area.find_markers("enemy"):
		if str(marker.params.get("boss","0")) == "1": mark_done_cell(world.area,marker.cell)
	GameManager.set_flag(StringName(str(cfg.flags.boss_clear)),true)
	var result: Dictionary = Svc.static_call("res://scripts/dungeon_run/dungeon_run.gd",&"boss_killed",[str(kind),floor],{})
	EventBus.game_event.emit(&"dungeon_boss_defeated",{"boss":str(kind),"kind":str(kind),"floor":floor,"level":floor,"first_kill":bool(result.get("first",false))})
	EventBus.whisper_requested.emit("HULEN_ROOTS_PART")
func _attach_world_effects(number: int) -> void:
	var world := get_tree().get_first_node_in_group("world_2d")
	if world == null or world.area == null or floor_of(world.area) != number: return
	var canopy := CanopyFade.new()
	world.area.add_child(canopy)
	canopy.attach(world.area)
	Svc.static_call("res://scripts/forest_look/forest_dress.gd",&"attach",[world.area,{"fireflies":14,"mist":2,"unshaded":true}])
func to_dict() -> Dictionary:
	var cells := {}
	for number in done:
		var values: Array = done[number].duplicate()
		values.sort()
		cells[str(number)] = values
	return {"v":1,"gen":gen,"spec":spec,"world_seed":world_seed,"seed_day":seed_day,"active":active,"floor":floor,"deepest":deepest,"stones":_sorted(stones),"seen":_sorted(seen),"done":cells,"reveal":_sorted(reveal)}
func _sorted(values: Dictionary) -> Array:
	var result: Array = values.keys()
	result.sort()
	return result
func from_dict(data: Dictionary) -> bool:
	if not validate_dict(data): return false
	_invalidate()
	world_seed = str(data.get("world_seed",world_seed))
	seed_day = int(data.get("seed_day",0))
	var top := int(cfg.get("max_floor",12))
	deepest = mini(int(data.get("deepest",0)),top)
	stones = _flags(data.get("stones",[]))
	seen = _flags(data.get("seen",[]))
	reveal = _flags(data.get("reveal",[]))
	done.clear()
	var compatible := int(data.get("gen",gen)) == gen and str(data.get("spec",spec)) == spec
	active = bool(data.get("active",false)) and compatible
	floor = mini(int(data.get("floor",0)),top) if active else 0
	if compatible:
		for key in data.get("done",{}):
			if not _valid_floor(int(key)): continue
			var cells: Array = []
			for index in data.done[key]:
				if int(index) not in cells: cells.append(int(index))
			done[int(key)] = cells
	else:
		seen.clear()
		reveal.clear()
		EventBus.whisper_requested.emit("DUNGEON_RUN_RESET")
	if active:
		for number in [floor-1,floor,floor+1]: _ensure(number)
	return true
func _flags(values: Array) -> Dictionary:
	var flags := {}
	for value in values:
		if _valid_floor(int(value)): flags[int(value)] = true
	return flags
func validate_dict(data: Dictionary) -> bool:
	if not _whole(data.get("v",1),1,1) or not _whole(data.get("gen",gen),1,100000): return false
	if not data.get("world_seed",world_seed) is String or not str(data.get("world_seed",world_seed)).is_valid_int(): return false
	if not _whole(data.get("seed_day",0),0,1000000000) or not _whole(data.get("deepest",0),0,SAVED_FLOOR_LIMIT) or not _whole(data.get("floor",0),0,SAVED_FLOOR_LIMIT): return false
	if not data.get("active",false) is bool or (data.get("active",false) and int(data.get("floor",0)) == 0): return false
	if not data.get("spec",spec) is String or not data.get("done",{}) is Dictionary: return false
	for key in ["stones","seen","reveal"]:
		if not data.get(key,[]) is Array: return false
		for value in data.get(key,[]):
			if not _whole(value,1,SAVED_FLOOR_LIMIT): return false
	for key in data.get("done",{}):
		if not str(key).is_valid_int() or not _whole(int(key),1,SAVED_FLOOR_LIMIT) or not data.done[key] is Array: return false
		for value in data.done[key]:
			if not _whole(value,0,65535): return false
	return true
static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum
