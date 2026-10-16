class_name ClimbLane
extends Interactable2D
## One END of a climbing lane (package V3-levels): the ladder between two decks, or the monkey's trunk climb (`climb_zone`). E at either end
## takes the actor along the lane in `seconds` (the ladder 1.1 s, 180 sketch px = 540 world px), then puts it on the far level.
##
##   * the actor is LOCKED like begin_talk (input stops, `begin_talk()` when it has one) and ActorLevel.lock keeps the LevelTracker off it;
##     it walks to the lane's entry on its current level first, without snapping.
##     While climbing it is drawn at the higher rank and collides with no level (ActorLevel.set_transit);
##   * the duration is divided by a PERK PROVIDER: Callable(actor, key) -> float. The default asks SpeciesPerks.value(skin, "climb_speed_mult", 1.0)
##     through Svc.static_call (Kiki, the monkey, has 2.2: 1.1 s -> 0.5 s); it answers 1.0 while V1's class does not exist or for an NPC.
##     Tests inject a fake with `perk_provider = func(_actor, _key): return 2.2`;
##   * the `climb_zone` variant (`perk_only = true`) is a ring marker around a trunk: usable ONLY when the perk is above 1.0 (the species
##     perk), joining two levels without the ladder; for everybody else it is disabled (hidden, no prompt, not findable);
##   * game_event(&"ladder_climbed", {actor, lane, from, to, seconds}) fires when the climb BEGINS (the audio cue);
##   * when the lane leaves the tree DURING a climb (the world switched areas, a rebuild) the climb is ABANDONED synchronously: the tween dies,
##     the actor is unlocked and given its old z / mask / shadow back (ActorLevel.restore), its clip and its free state return (end_talk), so
##     it enters the next area as a normal actor and the next tracker derives its level from the position.
## A lane has two ends, each is its own ClimbLane node (the player's E query finds the Area2D of the nearest one): create_pair().

signal climbed(actor: Node, from_id: StringName, to_id: StringName)

const PERK_KEY := "climb_speed_mult"
const SPECIES_PERKS_PATH := "res://scripts/data/species_perks.gd"
const END_RADIUS := Vector2(110, 60)

var registry: LevelRegistry
var lane_id: StringName = &""
var from_id: StringName = &""           # the level of THIS end
var to_id: StringName = &""             # the level of the far end
var start_pos: Vector2 = Vector2.ZERO   # world px, this end
var finish_pos: Vector2 = Vector2.ZERO  # world px, the far end
var seconds: float = 1.1
var perk_only: bool = false
var perk_provider: Callable = Callable()
var climbing: bool = false
var last_duration: float = 0.0
var climbs: int = 0

var _tween: Tween
var _body: Node2D                      # who is climbing right now (null otherwise), for the abandon path
var _forced_before: Variant = null     # its forced_clip before the climb


func _init() -> void:
	prompt_key = "LEVEL_PROMPT_CLIMB"
	radius = END_RADIUS
	perk_provider = ClimbLane.default_perk


## The two ends of a ladder record of the registry ({id, from, to, bottom, top, seconds}): [bottom end, top end].
static func create_pair(rec: Dictionary, reg: LevelRegistry) -> Array[ClimbLane]:
	var out: Array[ClimbLane] = []
	out.append(_make(reg, rec["id"], rec["from"], rec["to"], rec["bottom"], rec["top"], rec["seconds"], false, rec.get("prompt", "LEVEL_PROMPT_CLIMB")))
	out.append(_make(reg, rec["id"], rec["to"], rec["from"], rec["top"], rec["bottom"], rec["seconds"], false, rec.get("prompt", "LEVEL_PROMPT_CLIMB")))
	return out


## The two ends of a climb zone record ({id, from, to, a, b, r, seconds}) - perk only.
static func create_zone_pair(rec: Dictionary, reg: LevelRegistry) -> Array[ClimbLane]:
	var out: Array[ClimbLane] = []
	out.append(_make(reg, rec["id"], rec["from"], rec["to"], rec["a"], rec["b"], rec["seconds"], true, rec.get("prompt", "LEVEL_PROMPT_CLIMB")))
	out.append(_make(reg, rec["id"], rec["to"], rec["from"], rec["b"], rec["a"], rec["seconds"], true, rec.get("prompt", "LEVEL_PROMPT_CLIMB")))
	return out


static func _make(reg: LevelRegistry, id: StringName, from_level: StringName, to_level: StringName, a: Vector2, b: Vector2, secs: float, zone: bool, prompt: String) -> ClimbLane:
	var c := ClimbLane.new()
	c.registry = reg
	c.lane_id = id
	c.from_id = from_level
	c.to_id = to_level
	c.start_pos = a
	c.finish_pos = b
	c.seconds = secs
	c.perk_only = zone
	c.prompt_key = prompt
	c.position = a
	c.name = "%s_%s_%s" % [("Zone" if zone else "Lane"), id, from_level]
	return c


func _ready() -> void:
	super._ready()
	if perk_only:
		set_enabled(perk_multiplier(null) > 1.0)


## The default perk provider: the player's species perk (SpeciesPerks.value, V1), 1.0 for an NPC or while V1's class is absent.
static func default_perk(actor: Node, key: StringName) -> float:
	if actor != null and not actor.is_in_group("player"):
		return 1.0
	var gm: Node = Svc.node("GameManager")
	var skin: StringName = StringName(str(gm.get("character_skin"))) if gm != null else &""
	return float(Svc.static_call(SPECIES_PERKS_PATH, &"value", [skin, String(key), 1.0], 1.0))


## What the perk provider answers for an actor (>= 0.01).
func perk_multiplier(actor: Node) -> float:
	var v: Variant = perk_provider.call(actor, StringName(PERK_KEY)) if perk_provider.is_valid() else 1.0
	return maxf(float(v), 0.01)


## Is this end usable by the actor right now (a zone needs the perk)?
func usable_by(actor: Node) -> bool:
	if climbing:
		return false
	if perk_only and perk_multiplier(actor) <= 1.0:
		return false
	return true


func get_interaction_prompt() -> String:
	if not is_enabled() or climbing:
		return ""
	return super.get_interaction_prompt()


func interact(player: Node) -> void:
	if not is_enabled():
		return
	if climb(player):
		interacted.emit(player)


## Starts the climb of an actor from this end to the far one. False when the actor cannot (not on this end's level, perk missing, busy).
func climb(actor: Node) -> bool:
	if not (actor is Node2D) or not usable_by(actor):
		return false
	var here: StringName = ActorLevel.level_id(actor)
	if here == &"" and registry != null:
		here = registry.level_id_at((actor as Node2D).global_position)
	if here != from_id:
		return false
	var from_level: Level = registry.get_level(from_id)
	var to_level: Level = registry.get_level(to_id)
	if from_level == null or to_level == null:
		return false
	climbing = true
	climbs += 1
	last_duration = seconds / perk_multiplier(actor)
	var body: Node2D = actor as Node2D
	ActorLevel.lock(body, from_id)
	var forced_before: Variant = body.get("forced_clip") if "forced_clip" in body else null
	_body = body
	_forced_before = forced_before
	body.tree_exiting.connect(_abandon, CONNECT_ONE_SHOT)
	if actor.has_method("begin_talk"):
		actor.call("begin_talk", global_position)
	_tween = create_tween()
	_tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	var approach: Vector2 = start_pos - body.global_position
	if approach.length_squared() > 0.0001:
		_pose(body, Iso.to_ground(approach))
		var speed: float = float(body.get("_walk")) if "_walk" in body else 285.0
		_tween.tween_method(_approach.bind(body), body.global_position, start_pos, Iso.to_ground(approach).length() / maxf(speed, 1.0))
	_tween.tween_callback(_start_transit.bind(body, from_level, to_level))
	_tween.tween_property(body, "global_position", finish_pos, last_duration)
	_tween.finished.connect(_finish.bind(body, to_level, forced_before), CONNECT_ONE_SHOT)
	return true


## Only the ground approach uses collision. A blocked entry cancels the action
## rather than jumping through a railing to reach the climbing lane.
func _approach(at: Vector2, body: Node2D) -> void:
	if body is CharacterBody2D:
		(body as CharacterBody2D).move_and_collide(at - body.global_position)
	else:
		body.global_position = at


func _start_transit(body: Node2D, from_level: Level, to_level: Level) -> void:
	if body.global_position.distance_to(start_pos) > 1.0:
		_abandon()
		return
	ActorLevel.set_transit(body, from_level, to_level)
	_pose(body, Vector2(0, -1 if finish_pos.y < start_pos.y else 1))
	EventBus.game_event.emit(&"ladder_climbed", {"actor": str(body.name), "lane": str(lane_id), "from": str(from_id), "to": str(to_id), "seconds": last_duration})


## The player stops its normal animation updater while input is locked. Start
## the loop directly and keep its facing state in sync for the landing frame.
func _pose(body: Node2D, direction: Vector2) -> void:
	if "forced_clip" in body:
		body.set("forced_clip", &"walk")
	var facing := Iso.dir8_of(direction)
	if "facing8" in body:
		body.set("facing8", facing)
	if "facing_vec" in body:
		body.set("facing_vec", Iso.dir8_vector(facing))
	var vis: Variant = body.get("visual")
	if vis is Object and (vis as Object).has_method("set_direction_index"):
		(vis as Object).call("set_direction_index", facing)
	if vis is Object and (vis as Object).has_method("play_loop"):
		(vis as Object).call("play_loop", &"walk")


func _finish(body: Node2D, to_level: Level, forced_before: Variant) -> void:
	climbing = false
	_body = null
	_forced_before = null
	if not is_instance_valid(body):
		return
	_disconnect_actor(body)
	body.global_position = finish_pos
	ActorLevel.unlock(body)
	ActorLevel.set_level(body, to_level)
	_release_actor(body, forced_before)
	climbed.emit(body, from_id, to_id)


## The actor is free again: its clip back, the talk state over (what begin_talk froze).
func _release_actor(body: Node2D, forced_before: Variant) -> void:
	if body.has_method("end_talk"):
		body.call("end_talk")
	if forced_before != null and "forced_clip" in body:
		body.set("forced_clip", forced_before)
	var vis: Variant = body.get("visual")
	# Normal movement chooses its next clip; keep the stride through the landing.
	if forced_before != null and str(forced_before) != "" and vis is Object and (vis as Object).has_method("play_loop"):
		(vis as Object).call("play_loop", StringName(str(forced_before)))


func _disconnect_actor(body: Node2D) -> void:
	if body.tree_exiting.is_connected(_abandon):
		body.tree_exiting.disconnect(_abandon)


func _exit_tree() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if climbing:
		_abandon()


## The lane left the tree mid-climb: nobody will ever finish the tween, so the actor is released now (see the header).
func _abandon() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	climbing = false
	var body: Node2D = _body
	var forced_before: Variant = _forced_before
	_body = null
	_forced_before = null
	if body == null or not is_instance_valid(body):
		return
	_disconnect_actor(body)
	ActorLevel.restore(body)
	_release_actor(body, forced_before)
