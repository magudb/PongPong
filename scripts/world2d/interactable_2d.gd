class_name Interactable2D
extends Node2D
## Generic E-key target (sign, bed, door, notice board, quest spot, chest ...). An Area2D child on collision layer 4
## "interactable" (value 8); the player's facing-cell shape query (r = 45 ground px, D20) finds the Area2D and talks to its PARENT:
## parent.get_interaction_prompt() and parent.interact(player). Subclasses (NPCs, chests, dig spots ...) override both.
##
## `when=` (optional, a marker / prop parameter): a condition of the marker grammar (IsoArea.evaluate_when: quest:<id> | done:<id> | flag:<name> |
## night, `&`, a leading `!` and the social kinds at away open hearts fest hour weekday season birthday stage). IsoArea owns it: it evaluates the
## condition on enter and when quests / flags / the clock / friendships change and calls set_enabled(); a disabled interactable is hidden and
## cannot be found. The node itself keeps no copy of the condition.
signal interacted(player: Node)

## Translation key of the prompt ("E: ..."); "" = no prompt text.
var prompt_key: String = "WORLD_PROMPT_USE"
## Half-extents of the interaction ellipse in screen px (an iso footprint of about one cell).
var radius: Vector2 = Vector2(60, 30)

var _area: Area2D
var _enabled: bool = true
var _enabled_revision: int = 0
var _enabled_entry: Dictionary = {}
var _enabled_apply_entry: Dictionary = {}
var _enabled_lifetimes: Dictionary = {}


func _ready() -> void:
	add_to_group("interactable")
	_area = Area2D.new()
	_area.name = "InteractArea"
	_area.collision_layer = Iso.LAYER_INTERACTABLE
	_area.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := ConvexPolygonShape2D.new()
	var pts := PackedVector2Array()
	for i in 12:
		var a: float = TAU * float(i) / 12.0
		pts.append(Vector2(cos(a) * radius.x, sin(a) * radius.y))
	sh.points = pts
	cs.shape = sh
	_area.add_child(cs)
	add_child(_area)
	_apply_enabled()


func get_interaction_prompt() -> String:
	return tr(prompt_key) if prompt_key != "" else ""


func interact(player: Node) -> void:
	if _enabled:
		interacted.emit(player)


func is_enabled() -> bool:
	return _enabled


## Forward an enclosing presentation receipt without changing legacy virtual
## setter arity. Actual overrides call super first. The base consumes the entry
## before visibility can call an independent setter on this same node.
func set_enabled_guarded(on: bool, current: Callable) -> void:
	var origin := _capture_enabled(current)
	if not _enabled_current(origin): return
	_enabled_entry = origin
	set_enabled(on)
	if is_same(_enabled_entry, origin): _enabled_entry = {}


## Hides / shows the node and makes its Area2D findable / unfindable (the `when=` condition of the marker).
func set_enabled(on: bool) -> void:
	var origin := _enabled_entry
	_enabled_entry = {}
	if origin.is_empty(): origin = _capture_enabled()
	if not _enabled_current(origin): return
	_enabled = on
	if is_inside_tree():
		_enabled_apply_entry = origin
		_apply_enabled()
		if is_same(_enabled_apply_entry, origin): _enabled_apply_entry = {}


func _apply_enabled() -> void:
	var origin := _enabled_apply_entry
	_enabled_apply_entry = {}
	if origin.is_empty(): origin = _capture_enabled()
	if not _enabled_current(origin): return
	var on := _enabled
	visible = on
	if not _enabled_current(origin): return
	var child: Variant = origin.child.ref.get_ref() if not origin.child.is_empty() else null
	if child != null:
		_publish_enabled_monitorable.call_deferred(origin, on)
		child.collision_layer = Iso.LAYER_INTERACTABLE if on else 0


## Deferred delivery retains the original child, activation, model and caller
## receipt. A valid enqueue is not permission to publish into a later model.
func _publish_enabled_monitorable(origin: Dictionary, on: bool) -> void:
	if not _enabled_current(origin): return
	var child: Variant = origin.child.ref.get_ref() if not origin.child.is_empty() else null
	if child != null: child.monitorable = on


func _enabled_attachment(n: Node) -> Dictionary:
	var id := n.get_instance_id()
	var life: Dictionary = _enabled_lifetimes.get(id, {})
	if life.is_empty() or life.ref.get_ref() != n or not life.live or life.inside != n.is_inside_tree():
		life = {"ref": weakref(n), "live": true, "inside": n.is_inside_tree()}
		_enabled_lifetimes[id] = life
		if n.is_inside_tree(): n.tree_exiting.connect(func(): life.live = false, CONNECT_ONE_SHOT)
	return {"ref": weakref(n), "parent": weakref(n.get_parent()) if n.get_parent() != null else null, "inside": n.is_inside_tree(), "life": life}


static func _enabled_attachment_current(row: Dictionary) -> bool:
	var n: Variant = row.ref.get_ref()
	return is_instance_valid(n) and not n.is_queued_for_deletion() and row.life.live and n.is_inside_tree() == row.inside and n.get_parent() == (row.parent.get_ref() if row.parent != null else null)


func _capture_enabled(current: Callable = Callable()) -> Dictionary:
	_enabled_revision += 1
	var model: Variant = PlayerRegistry._states.get(&"p0")
	return {"revision": _enabled_revision, "owner": _enabled_attachment(self), "child": _enabled_attachment(_area) if is_instance_valid(_area) else {}, "model": weakref(model) if model != null else null, "guarded": current.is_valid(), "current": current}


func _enabled_current(origin: Dictionary) -> bool:
	if origin.revision != _enabled_revision or not _enabled_attachment_current(origin.owner): return false
	var model: Variant = origin.model.get_ref() if origin.model != null else null
	if origin.model != null and model == null: return false
	if PlayerRegistry._states.get(&"p0") != model: return false
	if origin.guarded and (not origin.current.is_valid() or not bool(origin.current.call())): return false
	if origin.child.is_empty(): return not is_instance_valid(_area)
	return _enabled_attachment_current(origin.child) and origin.child.ref.get_ref() == _area
