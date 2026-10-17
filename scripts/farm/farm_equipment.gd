class_name FarmEquipment
extends Node
## Placed records belong to WorldRoot2D. This service advances automation once
## per morning, after both crop models have evaluated yesterday's watering.
var world: WorldRoot2D
var _last_day := -1

static func attach(target: Node) -> Node:
	var existing := target.get_node_or_null("FarmEquipment")
	if existing != null: return existing
	var service := FarmEquipment.new()
	service.name = "FarmEquipment"
	service.world = target
	target.add_child(service)
	return service

func _ready() -> void:
	_last_day = GameManager.total_day()
	EventBus.day_started.connect(_morning)
	EventBus.load_completed.connect(func(_slot): _last_day = GameManager.total_day())

static func current_world() -> WorldRoot2D:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group("world_2d") as WorldRoot2D if tree != null else null

static func at(area_id: StringName, cell: Vector2i) -> Dictionary:
	var world := current_world()
	if world != null:
		for piece in world.placed_items:
			if str(piece.get("area", "farm")) == str(area_id) and piece.get("cell", []) == [cell.x, cell.y]:
				return piece
	return {}

static func spec(item: StringName) -> Dictionary:
	var kind := str(GameData.item_def(item).get("farm_machine", ""))
	return GameData.dict_of(GameData.cfg("farm_equipment." + kind, {}))

static func greenhouse_built() -> bool:
	var w := current_world()
	return w != null and bool(w.get_area_flag(&"farm", "greenhouse_built", false))

static func greenhouse_days_left() -> int:
	var w := current_world()
	return maxi(0, int(w.get_area_flag(&"farm", "greenhouse_ready_day", 0)) - GameManager.total_day()) if w != null else 0

static func greenhouse_building() -> bool:
	var w := current_world()
	return w != null and int(w.get_area_flag(&"farm", "greenhouse_ready_day", 0)) > 0

static func build_greenhouse() -> bool:
	var w := current_world()
	var row := GameData.dict_of(GameData.cfg("greenhouse", {}))
	if w == null or greenhouse_built() or greenhouse_building() or HomeManager.tier < int(row.get("min_home_tier", 2)):
		return false
	var cost := LuaData.int_map(row.get("build_cost", {}))
	var gold := int(cost.get("gold", 0))
	cost.erase("gold")
	var ok := EconomyManager.consume_backpack_items(cost, func():
		w.set_area_flag(&"farm", "greenhouse_ready_day", GameManager.total_day() + maxi(1, int(row.get("build_days", 3)))), gold)
	if ok: EventBus.game_event.emit(&"greenhouse_changed", {})
	return ok

func _morning(_day: int, _season: StringName) -> void:
	var today := GameManager.total_day()
	if today == _last_day: return
	_last_day = today
	var ready := int(world.get_area_flag(&"farm", "greenhouse_ready_day", 0))
	if ready > 0 and today >= ready:
		world.set_area_flag(&"farm", "greenhouse_ready_day", null)
		world.set_area_flag(&"farm", "greenhouse_built", true)
		EventBus.game_event.emit(&"greenhouse_changed", {})
		EventBus.notification_posted.emit(tr("FARMSITE_GREENHOUSE"), tr("FARMSITE_GREENHOUSE_READY"), "build")
	for piece in world.placed_items:
		var item := StringName(str(piece.get("item", "")))
		var offsets := LuaData.arr(spec(item).get("offsets", []))
		if offsets.is_empty(): continue
		var model: FarmGrid = world.farm_for_area(StringName(str(piece.get("area", "farm"))))
		var cell := Vector2i(int(piece.cell[0]), int(piece.cell[1]))
		for offset in offsets:
			model.water(cell + Vector2i(int(offset[0]), int(offset[1])), 6.0)

static func load_crop(piece: Dictionary, crop: StringName) -> bool:
	if piece.is_empty() or piece.has("batch") or not FarmGrid.crop_definitions().has(str(crop)):
		return false
	var row := spec(StringName(str(piece.item)))
	var prefix := str(row.get("output_prefix", ""))
	if prefix == "": return false
	var output := prefix + str(crop)
	if GameData.item_def(StringName(output)).is_empty(): return false
	return EconomyManager.consume_backpack_items({crop: 1}, func():
		piece["batch"] = {"input": str(crop), "output": output, "ready_day": GameManager.total_day() + maxi(1, int(row.get("days", 1)))})

static func collect(piece: Dictionary) -> bool:
	var batch: Dictionary = piece.get("batch", {})
	if batch.is_empty() or GameManager.total_day() < int(batch.ready_day): return false
	return EconomyManager.receive_backpack_item(StringName(str(batch.output)), 1, func(): piece.erase("batch"), false)

static func pickup(area: IsoArea, cell: Vector2i, picture: Node2D) -> bool:
	var w := current_world()
	var piece := at(area.map.id, cell)
	if w == null or piece.is_empty() or piece.has("batch"): return false
	var index := w.placed_items.find(piece)
	if index < 0: return false
	if not EconomyManager.receive_backpack_item(StringName(str(piece.item)), 1, func(): w.placed_items.remove_at(index)):
		return false
	area.remove_prop(picture)
	var model: FarmGrid = w.farm_for_area(area.map.id)
	model.plot_changed.emit(cell)
	return true

## Save preflight rejects malformed jobs before any live owner is replaced.
static func validate_placed(value: Variant) -> bool:
	if not value is Array: return false
	var seen := {}
	var crops := FarmGrid.crop_definitions()
	for piece in value:
		if not piece is Dictionary or not piece.get("item", "") is String or not piece.get("area", "farm") is String:
			return false
		var def := GameData.item_def(StringName(str(piece.item)))
		if str(def.get("placeable", "")) != "farm" or str(piece.get("area", "farm")) not in ["farm", "greenhouse"]:
			return false
		var cell: Variant = piece.get("cell", [])
		if not cell is Array or cell.size() != 2: return false
		for n in cell:
			if not (n is int or n is float) or not is_finite(float(n)) or float(n) < 0 or float(n) != floorf(float(n)) or float(n) > 1024:
				return false
		var key := "%s:%d:%d" % [piece.get("area", "farm"), int(cell[0]), int(cell[1])]
		if seen.has(key): return false
		seen[key] = true
		if piece.has("batch"):
			var batch: Variant = piece.batch
			var row := spec(StringName(str(piece.item)))
			if not batch is Dictionary or str(row.get("output_prefix", "")) == "": return false
			if not batch.get("input", "") is String or not batch.get("output", "") is String: return false
			if not crops.has(str(batch.input)) or str(batch.output) != str(row.output_prefix) + str(batch.input): return false
			var ready: Variant = batch.get("ready_day", 0)
			if not (ready is int or ready is float) or not is_finite(float(ready)) or float(ready) < 1 or float(ready) != floorf(float(ready)) or float(ready) > 2147483647:
				return false
	return true
