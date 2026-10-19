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
		if kind in ["coop", "equipment"]: restore.call_deferred()

func _ready() -> void:
	AnimalHusbandry.state_changed.connect(refresh)
	refresh()
	# Only the first slot replays the player-owned placeables once per area.
	if kind in ["coop", "equipment"]:
		EventBus.load_completed.connect(func(_slot): restore.call_deferred())
		restore.call_deferred()
func refresh() -> void:
	if not is_inside_tree() or kind == "equipment": return
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
		if piece is Dictionary and str(piece.get("area", "farm")) == str(area.map.id) and piece.get("cell") is Array and piece.cell.size() == 2:
			var node := _draw_prop(area,str(piece.get("item","")),Vector2i(int(piece.cell[0]),int(piece.cell[1])))
			if node != null: _placed_visuals.append(node)
static func _draw_prop(target: IsoArea, item: String, at: Vector2i) -> Node2D:
	var def := ItemKinds.def(item)
	var prop := str(def.get("prop",def.get("art_id",{"fence":"fence_x","mushroom_lantern":"lantern_post"}.get(item,item))))
	var picture := target.place_prop(StringName(prop),at)
	if picture != null:
		var machine := str(def.get("farm_machine", "")) != ""
		var interaction: Interactable2D = load("res://scripts/farm/farm_machine_2d.gd" if machine else "res://scripts/farm/placed_decoration_2d.gd").new()
		interaction.area = target
		if not machine: interaction.item = StringName(item)
		interaction.cell = at
		interaction.picture = picture
		interaction.position = target.objects.to_local(target.cell_to_global(at)) - picture.position
		picture.add_child(interaction)
	return picture
## Why `item` cannot stand on `at` right now, as the whisper key of the reason ("" = it can). The farm marker and place()
## share this answer, so the gold ring and the refusal never disagree.
##   FARM_PLACE_ONLY_FARM  not on the farm or in the greenhouse   FARM_CELL_RESERVED  the steading keeps the cell free
##   FARM_PLACE_FIELD      a decoration on a field cell          FARM_PLACE_GROWING  a machine on a cell with a living crop
##   FARM_PLACE_WITHERED   a machine on a cell with a dead crop (it cannot be harvested: the scythe clears it)
##   FARM_PLACE_BLOCKED    not walkable, or a marker, a placed piece, world geometry, a resource or an actor is there
static func can_place(item: StringName, at: Vector2i) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var world := tree.get_first_node_in_group("world_2d") if tree != null else null
	var def := ItemKinds.def(item)
	if world == null or world.area == null or world.area.map.id not in [&"farm", &"greenhouse"] or str(def.get("placeable","")) != "farm": return "FARM_PLACE_ONLY_FARM"
	var machine := str(def.get("farm_machine", "")) != ""
	var model: FarmGrid = world.farm_for_area(world.area.map.id)
	if not world.area.is_walkable(at): return "FARM_PLACE_BLOCKED"
	var reserved := FarmReserve.blocked(world.area,at)
	if reserved == "field" or at in model.farmable_cells():
		if not machine: return "FARM_PLACE_FIELD"
		if model.state_of(at) == FarmGrid.State.WITHERED: return "FARM_PLACE_WITHERED"
		if model.state_of(at) not in [FarmGrid.State.EMPTY, FarmGrid.State.TILLED]: return "FARM_PLACE_GROWING"
	if reserved not in (["", "field", "zone"] if machine else [""]): return "FARM_CELL_RESERVED"
	for marker in world.area.markers:
		if marker.cell == at: return "FARM_PLACE_BLOCKED"
	for piece in world.placed_items:
		if str(piece.get("area", "farm")) == str(world.area.map.id) and piece.cell == [at.x,at.y]: return "FARM_PLACE_BLOCKED"
	# World geometry, resources and actors also reserve their occupied cells.
	var query := PhysicsPointQueryParameters2D.new()
	query.position = world.area.cell_to_global(at)
	query.collision_mask = Iso.MASK_WALKING
	query.collide_with_areas = false
	if not world.area.get_world_2d().direct_space_state.intersect_point(query).is_empty(): return "FARM_PLACE_BLOCKED"
	return ""

static func place(item: StringName, at: Vector2i) -> bool:
	if can_place(item, at) != "": return false
	var world: Node = (Engine.get_main_loop() as SceneTree).get_first_node_in_group("world_2d")
	var picture := _draw_prop(world.area,str(item),at)
	if picture == null: return false
	if not EconomyManager.consume_backpack_items({item:1},func(): world.placed_items.append({"item":str(item),"cell":[at.x,at.y],"area":str(world.area.map.id)})):
		world.area.remove_prop(picture)
		return false
	for marker in world.area.markers:
		if str(marker.params.get("type", "")) in ["coop", "equipment"] and marker.node != null:
			marker.node._placed_visuals.append(picture)
	EventBus.game_event.emit(&"farm_item_placed",{"item":str(item),"cell":[at.x,at.y]})
	return true
