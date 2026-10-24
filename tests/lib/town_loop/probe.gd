class_name TownProbe
extends RefCounted
## One adapter to production names and one owned event log for every loop leg.
var events: Array[Dictionary] = []
var bus: Node

## Prototype area budgets predate the HUD and equipment. Keep their original
## geometry limits, while callers record the presented costs separately.
static func area_draw_calls(t) -> float:
	var ui: CanvasLayer = t.world().game_ui
	var held: HeldEquipment2D = t.player().held_equipment
	var clothes: WardrobeLayers = t.player().outfit_layers
	var shown := [ui.visible, held.rear.visible, held.front.visible, clothes.root.visible]
	var processing := held.is_processing()
	ui.hide()
	held.set_process(false)
	held.rear.hide()
	held.front.hide()
	clothes.root.hide()
	await t.frames(3)
	var calls := float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	held.set_process(processing)
	held.sync_pose()
	ui.visible = shown[0]
	held.rear.visible = shown[1]
	held.front.visible = shown[2]
	clothes.root.visible = shown[3]
	await t.frames(3)
	return calls

func attach(t) -> void:
	bus = t.autoload("EventBus")
	bus.game_event.connect(_event)

func dispose() -> void:
	if is_instance_valid(bus) and bus.game_event.is_connected(_event):
		bus.game_event.disconnect(_event)
	bus = null

func _event(id: StringName, payload: Dictionary) -> void:
	events.append({"id": str(id), "payload": payload.duplicate(true)})

func named(id: String) -> Array[Dictionary]:
	return events.filter(func(row): return row.id == id)

static func director(t) -> TownDirector:
	for node in t.tree.get_nodes_in_group("town_director"):
		if node.area == t.world().area:
			return node
	return null

static func hosts(t, kind: String, shop := "") -> Array[Node]:
	var out: Array[Node] = []
	for node in t.world().area.objects.get_children():
		if node is ShopCounter and node.kind == kind and (shop == "" or node.shop_id == shop):
			out.append(node)
	return out

static func door(t, building: String) -> Door2D:
	for node in t.world().area.triggers.get_children():
		if node is Door2D and node.building_id == building:
			return node
	return null

static func screens(t) -> GameUI:
	return t.tree.get_first_node_in_group("game_ui")

static func dialogue(t) -> Control:
	return t.tree.get_first_node_in_group("dialogue_ui")

static func context_digest(t) -> String:
	var people := NpcDirector.locations(SocialData.npcs().keys())
	var shops := {}
	for id in t.autoload("LuaRuntime").get_shops():
		shops[id] = t.autoload("ShopSystem").is_open(id)
	var payload: Dictionary = t.autoload("SaveManager").gather_payload()
	payload["loop_context"] = {"citizens": people, "shops": shops, "area": str(t.world().area.map.id)}
	return LoopDigest.of_payload(payload)
