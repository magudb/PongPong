class_name LevelTracker
extends Node
## The node a levelled builder adds to its area (package V3-levels): it gives every actor its level and keeps it right.
##   * every CharacterBody2D that enters area.objects (player, Npc2D, animals) is put on its level ONE FRAME LATER (call_deferred after
##     child_entered_tree: the position is final only after the marker / enter_area code ran);
##   * once per PHYSICS frame every known actor is re-derived (LevelRegistry.level_at of its global position, ~20 actors x a few polygons
##     behind bounding boxes; an actor that did not move is skipped); a level change calls ActorLevel.set_level;
##   * a locked actor (ActorLevel.lock: a ladder tween) is skipped; a position on no level (the void, a keep-out) keeps the old level;
##   * an actor that LEAVES Objects (the player walking into the next area) or is still inside when the tracker leaves the tree gets
##     ActorLevel.restore(): z, collision mask and shadow go back to what they were before the first level, so the next area (the farm's
##     pond, the shadow under every floor) never sees a city-levelled actor.
## Nothing in P05 / P06 / P14 calls any of this. Tests of it must await physics_frame, not process frames (measured: one tracker tick per
## three process frames in the headless harness).

signal level_changed(actor: Node, from_id: StringName, to_id: StringName)

var registry: LevelRegistry
var area: Node2D
var actors: Array[Node2D] = []
var ticks: int = 0
var changes: int = 0
var last_tick_usec: int = 0

var _objects: Node
# parallel to `actors` (index = position in the list): where the actor was derived, the z the tracker left it with (someone else changing
# it re-applies), the Level object it was put on
var _pos: PackedVector2Array = PackedVector2Array()
var _zs: PackedInt32Array = PackedInt32Array()
var _levels: Array = []


## Binds the tracker to an area (anything with an `objects` node) and the registry that answers level_at. Calling it again with the same
## area and registry is a no-op (a builder that wires the stage twice); another area releases the first one (its actors are restored).
func attach(p_area: Node2D, p_registry: LevelRegistry) -> void:
	if _objects != null and is_instance_valid(_objects):
		if p_area == area and p_registry == registry:
			return
		_detach()
	area = p_area
	registry = p_registry
	_objects = p_area.get("objects") as Node
	if _objects == null:
		return
	_connect_objects()
	for c in _objects.get_children():
		_on_child_entered(c)


func _connect_objects() -> void:
	if not _objects.child_entered_tree.is_connected(_on_child_entered):
		_objects.child_entered_tree.connect(_on_child_entered)
	if not _objects.child_exiting_tree.is_connected(_on_child_exiting):
		_objects.child_exiting_tree.connect(_on_child_exiting)


func _disconnect_objects() -> void:
	if _objects != null and is_instance_valid(_objects):
		if _objects.child_entered_tree.is_connected(_on_child_entered):
			_objects.child_entered_tree.disconnect(_on_child_entered)
		if _objects.child_exiting_tree.is_connected(_on_child_exiting):
			_objects.child_exiting_tree.disconnect(_on_child_exiting)


## Lets go of the current area: disconnects and restores every actor it still knows.
func _detach() -> void:
	_disconnect_objects()
	_restore_all()
	actors.clear()
	_pos.clear()
	_zs.clear()
	_levels.clear()
	_objects = null


## ActorLevel.restore() for every tracked actor that is still alive; the tracker forgets what it derived, so an actor that is still inside
## when the tracker comes back into the tree (a parked area) is levelled again.
func _restore_all() -> void:
	for i in actors.size():
		if is_instance_valid(actors[i]):
			ActorLevel.restore(actors[i])
		_pos[i] = Vector2(INF, INF)
		_zs[i] = -99999
		_levels[i] = null


func _enter_tree() -> void:
	# an area that was taken out of the tree and put back (parked): wire the signals up again and level the actors that stayed inside
	if _objects != null and is_instance_valid(_objects):
		_connect_objects()
		for c in _objects.get_children():
			_on_child_entered(c)


func _exit_tree() -> void:
	_disconnect_objects()
	_restore_all()


func _on_child_entered(n: Node) -> void:
	if not (n is CharacterBody2D):
		return
	var body: Node2D = n as Node2D
	var i: int = actors.find(body)
	if i < 0:
		actors.append(body)
		_pos.append(Vector2(INF, INF))
		_zs.append(-99999)
		_levels.append(null)
	else:
		_pos[i] = Vector2(INF, INF)
		_zs[i] = -99999
		_levels[i] = null
	ActorLevel.clear(body)
	_apply.call_deferred(body)


func _on_child_exiting(n: Node) -> void:
	if n is Node2D:
		var i: int = actors.find(n as Node2D)
		if i >= 0:
			ActorLevel.restore(n)
			_remove_at(i)


func _remove_at(i: int) -> void:
	if i < 0 or i >= actors.size():
		return
	actors.remove_at(i)
	_pos.remove_at(i)
	_zs.remove_at(i)
	_levels.remove_at(i)


## The level of an actor right now (re-derived from its position), applied when it changed. `i` is its index in `actors` (-1: unknown).
func _apply(actor: Node2D, i: int = -2) -> void:
	if not is_instance_valid(actor) or not actor.is_inside_tree() or registry == null:
		return
	if ActorLevel.is_locked(actor):
		return
	if i == -2:
		i = actors.find(actor)
	if i < 0:
		return                                   # no longer ours: it left Objects before this deferred call ran (it must not be levelled by the area it left)
	var lv: Level = registry.level_at(actor.global_position)
	if lv == null:
		return
	if i >= 0 and _levels[i] == lv and actor.z_index == lv.rank and ((actor as CollisionObject2D).collision_mask & lv.mask_bit()) != 0 and actor.has_meta(ActorLevel.META_LEVEL):
		return
	var old: StringName = ActorLevel.level_id(actor)
	ActorLevel.set_level(actor, lv)
	if i >= 0:
		_levels[i] = lv
		_zs[i] = lv.rank
	changes += 1
	level_changed.emit(actor, old, lv.id)


## Re-derives one actor now (tests, teleports, the end of a climb): the same code as the physics tick.
func refresh(actor: Node2D) -> void:
	var i: int = actors.find(actor)
	if i >= 0:
		_pos[i] = Vector2(INF, INF)
		_levels[i] = null
	_apply(actor)


func _physics_process(_delta: float) -> void:
	var t0: int = Time.get_ticks_usec()
	ticks += 1
	var i: int = actors.size() - 1
	while i >= 0:
		var a: Node2D = actors[i]
		if not is_instance_valid(a):
			_remove_at(i)
		elif not ActorLevel.is_locked(a):
			var pos: Vector2 = a.global_position
			# an actor that did not move and still carries the z the tracker gave it needs nothing; a locked one is skipped
			if pos != _pos[i] or a.z_index != _zs[i]:
				_pos[i] = pos
				_apply(a, i)
		i -= 1
	last_tick_usec = Time.get_ticks_usec() - t0
