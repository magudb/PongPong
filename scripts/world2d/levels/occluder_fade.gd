class_name OccluderFade
extends Node
## Lets the player be seen behind the tall things of the treetop city (package V3-levels): trunk upper segments, huts, the Raadhus. A prop that
## is registered here fades its alpha to FADE_ALPHA (0.5) while the watched actor (the player) is BEHIND it - its feet are above the prop's pivot
## on screen, inside the sprite's x range and below the sprite's top, and it is drawn under the prop (its z_index is not above the prop's) -
## and back to 1.0 when it steps out. Without it the player vanishes for up to 232 sketch px behind the main trunk.
##
##   fade.register(node, pivot_y, x_range, top_y, rank)   world px; `node` is the CanvasItem whose modulate.a is driven
##   fade.watch = actor                                    optional: the actor to watch (default: the first node of group `player`)
## The alpha moves SPEED units per second (0.125 s for the full step), so a prop never pops.

const FADE_ALPHA := 0.5
const SPEED := 4.0

var targets: Array[Dictionary] = []     # {node, pivot_y, x0, x1, top_y, rank, alpha, fading}
var watch: Node2D = null


func register(node: CanvasItem, pivot_y: float, x_range: Vector2, top_y: float, rank: int, fade_to: float = FADE_ALPHA) -> void:
	targets.append({"node": node, "pivot_y": pivot_y, "x0": minf(x_range.x, x_range.y), "x1": maxf(x_range.x, x_range.y), "top_y": top_y, "rank": rank, "fade_to": fade_to, "fading": false})


## The alpha a registered node has right now (1.0 for an unknown node).
func alpha_of(node: CanvasItem) -> float:
	return node.modulate.a if is_instance_valid(node) else 1.0


## Is the actor behind the registered target `t` right now (the pure rule, no tween)?
static func is_behind(t: Dictionary, actor_pos: Vector2, actor_rank: int) -> bool:
	return actor_pos.y < (t["pivot_y"] as float) and actor_pos.y > (t["top_y"] as float) and actor_pos.x >= (t["x0"] as float) and actor_pos.x <= (t["x1"] as float) and actor_rank <= (t["rank"] as int)


func _actor() -> Node2D:
	if watch != null and is_instance_valid(watch):
		return watch
	var tree: SceneTree = get_tree()
	return tree.get_first_node_in_group("player") as Node2D if tree != null else null


func _process(delta: float) -> void:
	var actor: Node2D = _actor()
	for t in targets:
		var node: CanvasItem = t["node"]
		if not is_instance_valid(node):
			continue
		var want: float = 1.0
		if actor != null and actor.is_inside_tree() and is_behind(t, actor.global_position, actor.z_index):
			want = t["fade_to"]
		t["fading"] = want < 1.0
		var c: Color = node.modulate
		var a: float = move_toward(c.a, want, SPEED * delta)
		if a != c.a:
			c.a = a
			node.modulate = c
