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
var _drop_origin: Dictionary = {}
var _generation := 0
var _collecting := false
var _drop_parent: WeakRef
var _drop_attachment: WeakRef

class PendingDrops extends Node:
	var rows: Array[Dictionary] = []
	var full_told := false
	var elapsed: float = 0
	func _process(dt: float) -> void:
		elapsed += dt
		if elapsed < .5 or rows.is_empty(): return
		elapsed = 0
		var parent := get_parent()
		if not LootDrop2D._live(parent): return
		var row: Dictionary = rows[0]
		# Legacy direct rows begin here; production rows already retain enqueue's
		# model. Never replace that stored origin on a subsequent retry.
		if not row.has("origin"):
			row["origin"] = EventBus.interaction_origin(&"p0")
			row["owner"] = weakref(parent)
			row["queue"] = weakref(self)
			row["attachment"] = weakref(parent.get_parent())
		if not row.get("attachment") is WeakRef or row.attachment.get_ref() != parent.get_parent(): return
		var origin: Dictionary = row.origin
		var row_state := row.duplicate()
		var attachment: WeakRef = row.attachment
		var queue_ref: WeakRef = row.queue
		var parent_ref: WeakRef = row.owner
		if queue_ref.get_ref() != self or parent_ref.get_ref() != parent: return
		if not EventBus.interaction_current(origin):
			# Retire only the exact obsolete front row, never adopt its successor.
			# A temporary load/rollback barrier is not retirement authority.
			if LootDrop2D._live(self) and not rows.is_empty() and is_same(rows[0],row) and NetAuthority.can_write() and SaveManager.continuation_available(PlayerRegistry.peek_state(&"p0")):
				rows.pop_front()
			return
		var current := func() -> bool:
			var queue: Variant = queue_ref.get_ref()
			var owner: Variant = parent_ref.get_ref()
			return LootDrop2D._live(queue) and LootDrop2D._live(owner) and queue.get_parent() == owner and owner.get_parent() == attachment.get_ref() and not queue.rows.is_empty() and is_same(queue.rows[0],row) and queue.rows[0] == row_state and EventBus.interaction_current(origin)
		if not current.call(): return
		var orbs := parent.get_children().filter(func(n): return n is LootDrop2D and not n.collected and not n.is_queued_for_deletion() and EventBus.interaction_current(n._drop_origin) and n._drop_attached())
		if orbs.size() >= CAP: orbs[0].collect()
		if not current.call(): return
		if orbs.size() < CAP or orbs[0].collected:
			rows.pop_front()
			# Row ownership is consumed before spawn; retain its model and exact
			# queue attachment rather than capturing a fresh root in spawn().
			var spawn_current := func() -> bool:
				var queue: Variant = queue_ref.get_ref()
				var owner: Variant = parent_ref.get_ref()
				return LootDrop2D._live(queue) and LootDrop2D._live(owner) and queue.get_parent() == owner and owner.get_parent() == attachment.get_ref() and EventBus.interaction_current(origin)
			LootDrop2D.spawn_owned(parent,row_state.position,row_state.id,int(row_state.amount),spawn_current,origin)

static func queue_for(parent: Node) -> PendingDrops:
	var origin := EventBus.interaction_origin(&"p0")
	if not _live(parent) or not EventBus.interaction_current(origin): return null
	var parent_ref: WeakRef = weakref(parent)
	var attachment: WeakRef = weakref(parent.get_parent()) if parent.get_parent() != null else null
	var queue: PendingDrops = parent.get_node_or_null("PendingDrops")
	if queue == null:
		queue = PendingDrops.new()
		queue.name = "PendingDrops"
		parent.add_child(queue)
	var owner: Variant = parent_ref.get_ref()
	if not _live(owner) or owner.get_parent() != (attachment.get_ref() if attachment != null else null) or not EventBus.interaction_current(origin): return null
	if not _live(queue) or queue.get_parent() != owner or owner.get_node_or_null("PendingDrops") != queue: return null
	return queue

static func create(params: Dictionary, origin: Variant = null) -> LootDrop2D:
	var orb := LootDrop2D.new()
	orb.setup(StringName(str(params.get("item",params.get("id","")))),int(params.get("amount",1)))
	if origin != null: orb._drop_origin = origin
	return orb

static func spawn(parent: Node, at: Vector2, item: Variant, count: int = 1) -> LootDrop2D:
	var origin := EventBus.interaction_origin()
	return spawn_owned(parent, at, item, count, EventBus.interaction_current.bind(origin))

## Retain the original producer through CAP collection and add-child callbacks.
static func spawn_owned(parent: Node, at: Vector2, item: Variant, count: int, current: Callable, retained: Variant = null) -> LootDrop2D:
	var model: Dictionary = EventBus.interaction_origin(&"p0") if retained == null else retained
	if not current.is_valid() or not current.call() or not _live(parent) or not EventBus.interaction_current(model): return null
	var parent_ref: WeakRef = weakref(parent)
	var attachment: WeakRef = weakref(parent.get_parent()) if parent.get_parent() != null else null
	var attached := func() -> bool:
		var node: Variant = parent_ref.get_ref()
		return _live(node) and node.get_parent() == (attachment.get_ref() if attachment != null else null) and current.call()
	var orbs := parent.get_children().filter(func(n): return n is LootDrop2D and not n.collected and not n.is_queued_for_deletion() and EventBus.interaction_current(n._drop_origin) and n._drop_attached())
	if orbs.size() >= CAP:
		var taken: bool = orbs[0].collect()
		if not attached.call(): return null
		if not taken:
			var queue := queue_for(parent)
			if attached.call() and _live(queue) and queue.get_parent() == parent:
				queue.rows.append({"id":str(item),"amount":count,"position":at,"origin":model,"owner":parent_ref,"queue":weakref(queue),"attachment":weakref(parent.get_parent())})
			return null
	var orb := create({"id":item,"amount":count},model)
	orb._spawn_current = attached
	parent.add_child(orb)
	if not attached.call() or not _live(orb) or orb.get_parent() != parent: return null
	orb.global_position = at
	return orb

static func _live(node: Variant) -> bool:
	return is_instance_valid(node) and node is Node and node.is_inside_tree() and not node.is_queued_for_deletion()

func _bind_drop_attachment() -> void:
	var parent := get_parent()
	_drop_parent = weakref(parent) if parent != null else null
	_drop_attachment = weakref(parent.get_parent()) if parent != null and parent.get_parent() != null else null

func _drop_attached() -> bool:
	var parent: Variant = _drop_parent.get_ref() if _drop_parent != null else null
	return _live(self) and _live(parent) and get_parent() == parent and parent.get_parent() == (_drop_attachment.get_ref() if _drop_attachment != null else null)

func setup(item: StringName, count: int) -> void:
	_generation += 1
	_collecting = false
	_spawn_current = Callable()
	_drop_origin = EventBus.interaction_origin(&"p0")
	_bind_drop_attachment()
	item_id = item
	amount = maxi(1,count)

func _ready() -> void:
	_bind_drop_attachment()
	var parent := get_parent()
	var serial := _generation
	var self_ref: WeakRef = weakref(self)
	var parent_ref: WeakRef = weakref(parent)
	var origin := _drop_origin
	var inherited := _spawn_current
	var current := func() -> bool:
		var node: Variant = self_ref.get_ref()
		var owner: Variant = parent_ref.get_ref()
		return _live(node) and node._drop_attached() and _live(owner) and node.get_parent() == owner and node._generation == serial and EventBus.interaction_current(origin) and (not inherited.is_valid() or inherited.call())
	if not current.call(): return
	var siblings := parent.get_children().filter(func(node): return node is LootDrop2D and node != self and not node.collected and not node.is_queued_for_deletion() and EventBus.interaction_current(node._drop_origin) and node._drop_attached())
	if siblings.size() >= CAP:
		var taken: bool = siblings[0].collect()
		if not current.call(): return
		if not taken:
			var queue := queue_for(parent)
			if not current.call() or not _live(queue) or queue.get_parent() != parent: return
			queue.rows.append({"id":str(item_id),"amount":amount,"position":global_position,"origin":origin,"owner":parent_ref,"queue":weakref(queue),"attachment":weakref(parent.get_parent())})
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
	if not current.call(): return
	var colors := {"gem":"b9c3e3","magic":"e3c372","forage":"6fd6c4","mineral":"c4bad6","crop":"e8863a"}
	tint = Color(colors.get(str(GameData.item_def(item_id).get("category","")),"fbf5e6"))
	_player = PlayerRegistry.local_player(get_tree()) as Node2D
	queue_for(parent)
	if not current.call(): return
	# The issuing enemy/body owns admission only. Future collection is a new
	# root under the existing local collector/economy policy, not its killer.
	_spawn_current = Callable()
	body_entered.connect(func(body):
		if body.is_in_group("player") and age >= .25: collect())

func pickup_mult() -> float:
	var item: Variant = Svc.static_call("res://scripts/combat/lantern_gem.gd",&"equipped",[],&"")
	var gem: Dictionary = Svc.static_call("res://scripts/combat/lantern_gem.gd",&"effects",[item],{})
	return maxf(1,float(gem.get("pickup_mult",1)))

func _process(dt: float) -> void:
	if collected or not _drop_attached() or not EventBus.interaction_current(_drop_origin): return
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
	if _collecting: return false
	_collecting = true
	var serial := _generation
	var self_ref: WeakRef = weakref(self)
	var result := _collect_once()
	var node: Variant = self_ref.get_ref()
	if is_instance_valid(node) and node._generation == serial: node._collecting = false
	return result

func _collect_once() -> bool:
	if not _drop_attached() or not EventBus.interaction_current(_drop_origin): return false
	var serial := _generation
	var origin := _drop_origin
	var self_ref: WeakRef = weakref(self)
	var parent_ref: WeakRef = weakref(get_parent())
	var collector_ref: WeakRef = weakref(_player) if is_instance_valid(_player) else null
	var resource_current := func() -> bool:
		var node: Variant = self_ref.get_ref()
		var parent: Variant = parent_ref.get_ref()
		return _live(node) and node._drop_attached() and _live(parent) and node.get_parent() == parent and node._generation == serial and node._player == (collector_ref.get_ref() if collector_ref != null else null)
	var current := func() -> bool: return resource_current.call() and EventBus.interaction_current(origin)
	var def := GameData.item_def(item_id)
	if bool(def.get("heal_on_pickup",false)) and is_instance_valid(_player) and int(_player.get("half_hearts")) < int(_player.get("max_half_hearts")):
		var body_origin := EventBus.interaction_origin(PlayerRegistry.registered_id(_player),_player,_player)
		var receipt := EventBus.combat_receipt(body_origin)
		if body_origin.is_empty() or receipt.is_empty(): return false
		_player.call("heal_half_owned",int(def.get("heal_half_hearts",2))*amount,receipt,body_origin)
		if current.call() and EventBus.interaction_body_current(body_origin,_player,_player):
			DungeonSpark2D.play_owned(parent_ref.get_ref(),_player.global_position+Vector2(0,-50),Color("f2c3cf"),current)
	else:
		var loot := Svc.node("LootService")
		var eco := Svc.node("EconomyManager")
		var ok := false
		if loot != null: ok = bool(loot.deliver(item_id,amount).get("ok",false))
		elif eco != null: ok = bool(eco.add_item(item_id,amount))
		if not ok:
			if not current.call(): return false
			_retry = .5
			var queue := queue_for(parent_ref.get_ref())
			if not current.call() or not _live(queue) or queue.get_parent() != parent_ref.get_ref(): return false
			if not queue.full_told:
				queue.full_told = true
				EventBus.whisper_requested.emit("DEXP_BACKPACK_FULL")
			return false
	# Delivery/healing is an earned prefix. A model replacement does not revoke
	# cleanup of this exact old resource, but transfer/reuse/queued deletion does.
	if not resource_current.call(): return true
	collected = true
	visible = false
	if not resource_current.call(): return true
	set_process(false)
	queue_free()
	return true

func _draw() -> void:
	var point := Vector2(0,-30-8*sin(age*4))
	draw_circle(point,20,Color(tint,.12))
	draw_circle(point,11,Color(tint,.35))
	draw_circle(point,6,tint)
	draw_circle(point+Vector2(-2,-2),2,Color("fbf5e6"))
