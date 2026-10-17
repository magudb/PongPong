class_name FestivalDecor
extends Node
## Lifecycle owner for the already reviewed painted festival pieces.
var director: TownDirector
var art: Node2D
var active_id := ""

static func attach(target: TownDirector) -> Node:
	var existing := target.get_node_or_null("FestivalDecor")
	if existing != null:
		existing.call("refresh")
		return existing
	var node := FestivalDecor.new()
	node.name = "FestivalDecor"
	node.director = target
	target.add_child(node)
	return node

func _enter_tree() -> void:
	EventBus.game_event.connect(_event)
	EventBus.time_of_day_changed.connect(_clock)
	EventBus.day_started.connect(_day)
	if is_node_ready(): refresh.call_deferred()
func _ready() -> void:
	refresh()
func _exit_tree() -> void:
	for pair in [[EventBus.game_event,_event],[EventBus.time_of_day_changed,_clock],[EventBus.day_started,_day]]:
		if pair[0].is_connected(pair[1]): pair[0].disconnect(pair[1])
	_clear()
func _event(id: StringName,_payload: Dictionary) -> void:
	if id in [&"town_festival_started",&"town_festival_ended"]: refresh()
func _clock(_hour: int,_minute: int) -> void:
	refresh()
func _day(_day_num: int,_season: StringName) -> void:
	refresh()
func _clear() -> void:
	if is_instance_valid(art):
		art.visible = false
		art.queue_free()
	art = null
	active_id = ""
func refresh() -> void:
	if not is_inside_tree() or not is_instance_valid(director) or not director.ready_for_population: return
	var sm := Svc.node("SocialManager")
	var id := str(sm.call("festival_active")) if sm != null and sm.has_method("festival_active") else ""
	var meta := LuaData.dict(SocialData.festival(id).get("meta",{}))
	if str(meta.get("area","")) != director.area_id: id = ""
	if id != active_id or (id != "" and not is_instance_valid(art)):
		_clear()
		if id != "": _build(id,meta)
	if is_instance_valid(art):
		var glow := InteriorRoom.outdoor_glow(float(GameManager.hour)+float(GameManager.minute)/60.0)
		for child in art.get_children():
			var accent := child.get_node_or_null("PaintedAccent") as Sprite2D
			if accent != null: accent.modulate.a = glow
func _rank(level_id: Variant) -> int:
	if director.level_nav == null: return 0
	var index := int(level_id)
	if index < 0 or index >= director.level_nav.levels.size(): return 0
	var id := StringName(str(director.level_nav.levels[index].id))
	var level := CityBuilder.of(director.area).registry.get_level(id)
	return level.rank if level != null else 0
func _build(id: String,meta: Dictionary) -> void:
	var spot := str(meta.get("spot",""))
	var posts := {}
	for role in FestSet.roles():
		var ground := director.post_ground(StringName("fest_"+spot+"_"+str(role[0])))
		if ground != Vector2.INF: posts[str(role[0])] = Iso.to_screen(ground)
	var doors: Array = []
	for door in LuaData.arr(director.col.get("doors",[])):
		var point := director.door_ground(StringName(str(door.building)))
		if point != Vector2.INF:
			doors.append({"at":Iso.to_screen(point)+Vector2(0,-130),"rank":_rank(door.get("level",""))+1})
	var rank := 0
	for row in LuaData.arr(director.col.get("fest_sets",[])):
		if str(row.spot) == spot: rank = _rank(row.get("level",""))
	art = PaintedFestivalArt.create(director.area.objects,id,posts,doors,rank,true)
	active_id = id
