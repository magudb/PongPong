class_name LootDrop2D
extends Area2D
## Delivery is retriable. A full pack never destroys a drop or repeats the floor warning.
const CAP := 50
var item_id: StringName = &""
var amount: int = 1
var age: float = 0
var collected := false
var tint := Color("fbf5e6")
var _retry: float = 0
var _player: Node2D
var _spawn_current := Callable()

class PendingDrops extends Node:
	var rows: Array[Dictionary] = []
	var full_told := false
	var elapsed: float = 0
	func _process(dt: float) -> void:
		elapsed += dt
		if elapsed < .5 or rows.is_empty(): return
		elapsed = 0
		var parent := get_parent()
		var orbs := parent.get_children().filter(func(n): return n is LootDrop2D and not n.collected and not n.is_queued_for_deletion())
		if orbs.size() >= CAP: orbs[0].collect()
		if orbs.size() < CAP or orbs[0].collected:
			var row: Dictionary = rows.pop_front()
			LootDrop2D.spawn(parent,row.position,row.id,int(row.amount))

static func queue_for(parent: Node) -> PendingDrops:
	var queue: PendingDrops = parent.get_node_or_null("PendingDrops")
	if queue == null:
		queue = PendingDrops.new()
		queue.name = "PendingDrops"
		parent.add_child(queue)
	return queue

static func create(params: Dictionary) -> LootDrop2D:
	var orb := LootDrop2D.new()
	orb.setup(StringName(str(params.get("item",params.get("id","")))),int(params.get("amount",1)))
	return orb

static func spawn(parent: Node, at: Vector2, item: Variant, count: int = 1) -> LootDrop2D:
	var orbs := parent.get_children().filter(func(n): return n is LootDrop2D and not n.collected and not n.is_queued_for_deletion())
	if orbs.size() >= CAP and not orbs[0].collect():
		queue_for(parent).rows.append({"id":str(item),"amount":count,"position":at})
		return null
	var orb := create({"id":item,"amount":count})
	parent.add_child(orb)
	orb.global_position = at
	return orb

## H2 owns only admission and the immediate add-child suffix. Cap collection,
## _ready queue/cap policy and PendingDrops inheritance remain the H4 boundary.
static func spawn_owned(parent: Node, at: Vector2, item: Variant, count: int, current: Callable) -> LootDrop2D:
	if not current.call(): return null
	var orbs := parent.get_children().filter(func(n): return n is LootDrop2D and not n.collected and not n.is_queued_for_deletion())
	if orbs.size() >= CAP:
		# Keep the existing collector/queue economics; not certified owned by H2.
		return spawn(parent, at, item, count)
	var orb := create({"id":item,"amount":count})
	orb._spawn_current = current
	parent.add_child(orb)
	if not current.call() or not is_instance_valid(orb) or not orb.is_inside_tree() or orb.is_queued_for_deletion(): return null
	orb.global_position = at
	return orb

func setup(item: StringName, count: int) -> void:
	item_id = item
	amount = maxi(1,count)

func _ready() -> void:
	if _spawn_current.is_valid() and not _spawn_current.call():
		set_process(false)
		return
	var siblings := get_parent().get_children().filter(func(node): return node is LootDrop2D and node != self and not node.collected and not node.is_queued_for_deletion())
	if siblings.size() >= CAP and not siblings[0].collect():
		queue_for(get_parent()).rows.append({"id":str(item_id),"amount":amount,"position":global_position})
		collected = true
		queue_free()
		return
	collision_layer = Iso.LAYER_PICKUP
	collision_mask = Iso.LAYER_PLAYER
	var shape := ConvexPolygonShape2D.new()
	var points := PackedVector2Array()
	for i in 16: points.append(Vector2(cos(TAU*i/16)*43,sin(TAU*i/16)*22))
	shape.points = points
	var collision := CollisionShape2D.new()
	collision.shape = shape
	add_child(collision)
	var colors := {"gem":"b9c3e3","magic":"e3c372","forage":"6fd6c4","mineral":"c4bad6","crop":"e8863a"}
	tint = Color(colors.get(str(GameData.item_def(item_id).get("category","")),"fbf5e6"))
	_player = PlayerRegistry.local_player(get_tree()) as Node2D
	queue_for(get_parent())
	body_entered.connect(func(body):
		if body.is_in_group("player") and age >= .25: collect())

func pickup_mult() -> float:
	var item: Variant = Svc.static_call("res://scripts/combat/lantern_gem.gd",&"equipped",[],&"")
	var gem: Dictionary = Svc.static_call("res://scripts/combat/lantern_gem.gd",&"effects",[item],{})
	return maxf(1,float(gem.get("pickup_mult",1)))

func _process(dt: float) -> void:
	if collected: return
	age += dt
	_retry = maxf(0,_retry-dt)
	queue_redraw()
	if not is_instance_valid(_player): _player = PlayerRegistry.local_player(get_tree()) as Node2D
	if _player == null: return
	var offset := Iso.to_ground(_player.global_position-global_position)
	if age >= .5 and offset.length() < 183*pickup_mult():
		global_position += Iso.to_screen(offset.limit_length(433*dt))
	if age >= .25 and offset.length() <= 43 and _retry == 0: collect()

func collect() -> bool:
	if collected: return true
	var def := GameData.item_def(item_id)
	if bool(def.get("heal_on_pickup",false)) and is_instance_valid(_player) and int(_player.get("half_hearts")) < int(_player.get("max_half_hearts")):
		_player.call("heal_half",int(def.get("heal_half_hearts",2))*amount)
		HealSparkle2D.play(get_parent(),_player.global_position+Vector2(0,-50))
	else:
		var loot := Svc.node("LootService")
		var eco := Svc.node("EconomyManager")
		var ok := false
		if loot != null: ok = bool(loot.deliver(item_id,amount).get("ok",false))
		elif eco != null: ok = bool(eco.add_item(item_id,amount))
		if not ok:
			_retry = .5
			var queue := queue_for(get_parent())
			if not queue.full_told:
				queue.full_told = true
				EventBus.whisper_requested.emit("DEXP_BACKPACK_FULL")
			return false
	collected = true
	visible = false
	set_process(false)
	queue_free()
	return true

func _draw() -> void:
	var point := Vector2(0,-30-8*sin(age*4))
	draw_circle(point,20,Color(tint,.12))
	draw_circle(point,11,Color(tint,.35))
	draw_circle(point,6,tint)
	draw_circle(point+Vector2(-2,-2),2,Color("fbf5e6"))
