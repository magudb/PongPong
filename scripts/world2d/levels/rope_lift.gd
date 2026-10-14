class_name RopeLift
extends Interactable2D
## The rope basket of the treetop city, the Skovlift (package V3-levels): E at the rim of its tree starts a ride - the basket runs down the rope in
## `seconds` (1.6 s) with the player inside (hidden) - and then asks the world for another area: EventBus.area_change_requested(area, spawn).
##
##   * the target comes from DATA: lua/config/traetoppen.lua `skovlift = {to_area, spawn}` (read through GameData.cfg), the lift record of
##     data/traetoppen/traetoppen.json is the fallback; nothing in this class names an area;
##   * a target that is not registered (WorldRoot2D.has_area) is answered with the whisper LEVEL_LIFT_CLOSED BEFORE anything moves, so the
##     player is never hidden for a ride that cannot arrive;
##   * the player is locked like begin_talk during the ride and shown again when the world has switched areas (EventBus.area_changed),
##     at the latest after FAILSAFE_S;
##   * game_event(&"lift_ride", {lift, to_area, spawn, seconds}) fires when the ride BEGINS (the audio cue).
## The basket and the rope are stand-in shapes (Line2D + polygon) unless `art` carries textures {"basket": Texture2D}; V5's lift_basket drops in.

signal ride_started(actor: Node)
signal ride_finished(actor: Node, area_id: StringName, spawn_name: StringName)

const CFG_PATH := "traetoppen.skovlift"
const FAILSAFE_S := 3.0
const STAND_RADIUS := Vector2(130, 80)
const ROPE_COLOR := Color("2b2340")

var registry: LevelRegistry
var lift_id: StringName = &""
var level_id: StringName = &""
var top_pos: Vector2 = Vector2.ZERO
var basket_pos: Vector2 = Vector2.ZERO
var stand_pos: Vector2 = Vector2.ZERO
var seconds: float = 1.6
var to_area: StringName = &""
var spawn_name: StringName = &"default"
var rope: Line2D
var basket: Node2D
var riding: bool = false
var rides: int = 0
var last_request: Dictionary = {}

var _tween: Tween
var _actor: Node2D
var _hid_actor: bool = false


func _init() -> void:
	prompt_key = "LEVEL_PROMPT_LIFT"
	radius = STAND_RADIUS


## From a lift record of the registry ({id, level, top, basket, stand, to_area, spawn, seconds}). nodes = {objects: Node2D}: the rope and the
## basket are drawn there at the lift rope rank (data decor_ranks.lift_rope, 125) so they sort with everything else.
static func create_lift(rec: Dictionary, reg: LevelRegistry, nodes: Dictionary = {}, art: Dictionary = {}) -> RopeLift:
	var l := RopeLift.new()
	l.registry = reg
	l.lift_id = rec["id"]
	l.level_id = rec["level"]
	l.top_pos = rec["top"]
	l.basket_pos = rec["basket"]
	l.stand_pos = rec["stand"]
	l.seconds = rec["seconds"]
	l.to_area = rec["to_area"]
	l.spawn_name = rec["spawn"]
	l.prompt_key = str(rec.get("prompt", "LEVEL_PROMPT_LIFT"))
	l.position = l.stand_pos
	l.name = "Lift_%s" % l.lift_id
	l._draw_parts(nodes, art, LuaData.int_of(LuaData.dict(reg.data.get("decor_ranks", {})).get("lift_rope", 125), 125))
	return l


func _draw_parts(nodes: Dictionary, art: Dictionary, rank: int) -> void:
	var host: Node = nodes.get("objects", null)
	if host == null:
		return
	rope = Line2D.new()
	rope.name = "Rope"
	rope.points = PackedVector2Array([Vector2.ZERO, basket_pos - top_pos])
	rope.width = 8.0
	rope.default_color = ROPE_COLOR
	rope.position = top_pos
	rope.z_index = rank
	host.add_child(rope)
	basket = Node2D.new()
	basket.name = "Basket"
	basket.position = basket_pos
	basket.z_index = rank + 1
	var tex: Texture2D = art.get("basket", null)
	if tex != null:
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.centered = false
		sp.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
		basket.add_child(sp)
	else:
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(-66, -60), Vector2(66, -60), Vector2(54, 0), Vector2(-54, 0)])
		poly.color = Color("c9925a")
		basket.add_child(poly)
	host.add_child(basket)


## The area, spawn and duration of the ride: lua/config/traetoppen.lua `skovlift` (each key through GameData.cfg, so a test can override it),
## the record of the JSON is the fallback.
func target() -> Dictionary:
	return {
		"area": StringName(str(GameData.cfg(CFG_PATH + ".to_area", to_area))),
		"spawn": StringName(str(GameData.cfg(CFG_PATH + ".spawn", spawn_name))),
		"seconds": float(GameData.cfg(CFG_PATH + ".seconds", seconds)),
	}


func interact(player: Node) -> void:
	if is_enabled():
		ride(player)


## Starts a ride. False when the target is not registered (the whisper answers) or a ride is running.
func ride(actor: Node) -> bool:
	if riding or not (actor is Node2D):
		return false
	var t: Dictionary = target()
	var area_id: StringName = t["area"]
	if area_id == &"" or not WorldRoot2D.has_area(area_id):
		EventBus.whisper_requested.emit("LEVEL_LIFT_CLOSED")
		return false
	riding = true
	rides += 1
	var ride_seconds: float = maxf(float(t["seconds"]), 0.05)
	last_request = {"area": area_id, "spawn": t["spawn"]}
	_actor = actor as Node2D
	if actor.has_method("begin_talk"):
		actor.call("begin_talk", global_position)
	_actor.visible = false
	_hid_actor = true
	EventBus.game_event.emit(&"lift_ride", {"lift": str(lift_id), "to_area": str(area_id), "spawn": str(t["spawn"]), "seconds": ride_seconds})
	ride_started.emit(actor)
	if basket != null:
		basket.position = top_pos
		_tween = create_tween()
		_tween.tween_property(basket, "position", basket_pos, ride_seconds)
		_tween.finished.connect(_arrive, CONNECT_ONE_SHOT)
	else:
		get_tree().create_timer(ride_seconds).timeout.connect(_arrive, CONNECT_ONE_SHOT)
	return true


func _arrive() -> void:
	if not riding:
		return
	var area_id: StringName = last_request["area"]
	var spawn: StringName = last_request["spawn"]
	EventBus.area_changed.connect(_on_area_changed, CONNECT_ONE_SHOT)
	EventBus.area_change_requested.emit(area_id, spawn)
	ride_finished.emit(_actor, area_id, spawn)
	# the world switches areas behind its fade; if it never does (a refused travel) the player must not stay hidden
	if is_inside_tree():
		get_tree().create_timer(FAILSAFE_S).timeout.connect(_release, CONNECT_ONE_SHOT)


func _on_area_changed(_area_id: StringName) -> void:
	_release()


func _release() -> void:
	if not riding:
		return
	riding = false
	if EventBus.area_changed.is_connected(_on_area_changed):
		EventBus.area_changed.disconnect(_on_area_changed)
	if is_instance_valid(_actor):
		if _hid_actor:
			_actor.visible = true
		if _actor.has_method("end_talk"):
			_actor.call("end_talk")
	_hid_actor = false
	if basket != null and is_instance_valid(basket):
		basket.position = basket_pos


func _exit_tree() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if riding:
		_release()
