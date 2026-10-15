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


## Hides / shows the node and makes its Area2D findable / unfindable (the `when=` condition of the marker).
func set_enabled(on: bool) -> void:
	_enabled = on
	if is_inside_tree():
		_apply_enabled()


func _apply_enabled() -> void:
	visible = _enabled
	if _area != null:
		_area.set_deferred("monitorable", _enabled)
		_area.collision_layer = Iso.LAYER_INTERACTABLE if _enabled else 0
