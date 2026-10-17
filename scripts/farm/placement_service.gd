class_name PlacementService
extends Node2D
## Authored housing slots and persistent farm placeables. All purchases and
## placement transactions use the same EconomyManager ownership operations.
const PROPS := {"coop":"coop_small","barn":"barn_small","house":"animal_house"}
var area: IsoArea
var cell := Vector2i.ZERO
var kind := ""
var _prop: Node2D
var _built := false
var _placed_visuals: Array[Node2D] = []

static func create_marker(params: Dictionary, _pos: Vector2, at: Vector2i, target: IsoArea) -> Node:
	var service := PlacementService.new()
	service.area = target
	service.cell = at
	service.kind = str(params.get("type","coop"))
	return service
func _enter_tree() -> void:
	if is_node_ready():
		refresh.call_deferred()
		if kind == "coop": restore.call_deferred()

func _ready() -> void:
	AnimalHusbandry.state_changed.connect(refresh)
	refresh()
	# Only the first slot replays the player-owned placeables once per area.
	if kind == "coop":
		EventBus.load_completed.connect(func(_slot): restore.call_deferred())
		restore.call_deferred()
func refresh() -> void:
	if not is_inside_tree(): return
	var built := AnimalHusbandry.has_building(StringName(kind))
	if built == _built and is_instance_valid(_prop): return
	_built = built
	if is_instance_valid(_prop): area.remove_prop(_prop)
	_prop = area.place_prop(StringName(PROPS.get(kind,"coop_small")) if built else &"build_stake",cell)
	for building in AnimalHusbandry.buildings.values():
		if str(building.building_type) == kind and building.cell == Vector2i(-1,-1): building.cell = cell
func restore() -> void:
	if not is_inside_tree(): return
	var world := get_tree().get_first_node_in_group("world_2d")
	if world == null: return
	for picture in _placed_visuals:
		if is_instance_valid(picture): area.remove_prop(picture)
	_placed_visuals.clear()
	for piece in world.placed_items:
		if piece is Dictionary and piece.get("cell") is Array and piece.cell.size() == 2:
			var node := _draw_prop(area,str(piece.get("item","")),Vector2i(int(piece.cell[0]),int(piece.cell[1])))
			if node != null: _placed_visuals.append(node)
static func _draw_prop(target: IsoArea, item: String, at: Vector2i) -> Node2D:
	var def := ItemKinds.def(item)
	var prop := str(def.get("prop",def.get("art_id",{"fence":"fence_x","mushroom_lantern":"lantern_post"}.get(item,item))))
	var picture := target.place_prop(StringName(prop),at)
	if picture != null:
		var interaction: Interactable2D = load("res://scripts/farm/placed_decoration_2d.gd").new()
		interaction.area = target
		interaction.item = StringName(item)
		interaction.cell = at
		interaction.picture = picture
		interaction.position = target.objects.to_local(target.cell_to_global(at)) - picture.position
		picture.add_child(interaction)
	return picture
static func place(item: StringName, at: Vector2i) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := tree.get_first_node_in_group("world_2d") if tree != null else null
	if world == null or world.area == null or world.area.map.id != &"farm": return false
	var def := ItemKinds.def(item)
	if str(def.get("placeable","")) != "farm" or not world.area.is_walkable(at) or FarmReserve.blocked(world.area,at) != "": return false
	for marker in world.area.markers:
		if marker.cell == at: return false
	for piece in world.placed_items:
		if piece.cell == [at.x,at.y]: return false
	# World geometry, resources and actors also reserve their occupied cells.
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world.area.cell_to_global(at)
	query.collision_mask = Iso.MASK_WALKING
	query.collide_with_areas = false
	if not world.area.get_world_2d().direct_space_state.intersect_point(query).is_empty(): return false
	var picture := _draw_prop(world.area,str(item),at)
	if picture == null: return false
	if not EconomyManager.consume_backpack_items({item:1},func(): world.placed_items.append({"item":str(item),"cell":[at.x,at.y]})):
		world.area.remove_prop(picture)
		return false
	for marker in world.area.find_markers("building_slot"):
		if marker.params.get("type","") == "coop" and marker.node != null:
			marker.node._placed_visuals.append(picture)
	EventBus.game_event.emit(&"farm_item_placed",{"item":str(item),"cell":[at.x,at.y]})
	return true
