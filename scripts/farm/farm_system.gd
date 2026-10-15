extends Node3D
## Treetop farm: grid of crop plots, watering, growth, harvest.

const PlotState = {
	EMPTY = 0,
	TILLED = 1,
	PLANTED = 2,
	WATERED = 3,
	READY = 4,
}

@export var plot_scene: PackedScene
@export var grid_width: int = 4
@export var grid_height: int = 3
@export var plot_spacing: float = 2.5

var plots: Dictionary = {}  # "x,y" -> PlotData
var farm_level: int = 1
var upgrades: Array[StringName] = []

# Lua-configurable crop definitions
var crop_defs: Dictionary = {}


class PlotData:
	var id: StringName
	var grid_x: int
	var grid_y: int
	var state: int = PlotState.EMPTY
	var crop_id: StringName = &""
	var growth_stage: int = 0
	var watered: bool = false
	var planted_day: int = 0
	var world_position: Vector3 = Vector3.ZERO

	func to_dict() -> Dictionary:
		return {
			"id": id, "grid_x": grid_x, "grid_y": grid_y, "state": state,
			"crop_id": crop_id, "growth_stage": growth_stage, "watered": watered,
			"planted_day": planted_day,
		}

	static func from_dict(d: Dictionary) -> PlotData:
		var p := PlotData.new()
		p.id = d.get("id", &"")
		p.grid_x = d.get("grid_x", 0)
		p.grid_y = d.get("grid_y", 0)
		p.state = d.get("state", PlotState.EMPTY)
		p.crop_id = d.get("crop_id", &"")
		p.growth_stage = d.get("growth_stage", 0)
		p.watered = d.get("watered", false)
		p.planted_day = d.get("planted_day", 0)
		return p


func _ready() -> void:
	crop_defs = LuaRuntime.get_config("crops", {})
	_generate_plots()
	EventBus.day_started.connect(_on_day_started)
	EventBus.crop_watered.connect(_on_crop_watered)


func _generate_plots() -> void:
	for x in grid_width:
		for y in grid_height:
			var key := "%d,%d" % [x, y]
			var plot := PlotData.new()
			plot.id = StringName("plot_%d_%d" % [x, y])
			plot.grid_x = x
			plot.grid_y = y
			plot.world_position = Vector3(
				(x - grid_width / 2.0) * plot_spacing,
				0,
				(y - grid_height / 2.0) * plot_spacing
			)
			plots[key] = plot
			_spawn_plot_mesh(plot)


func _spawn_plot_mesh(plot: PlotData) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.8, 0.3, 1.8)
	mesh.mesh = box
	mesh.position = plot.world_position
	mesh.position.y = -0.15

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.3, 0.18)  # soil
	mesh.material_override = mat

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 0.3, 1.8)
	col.shape = shape
	body.add_child(col)
	body.collision_layer = 32  # farm_plot layer
	body.collision_mask = 0
	body.set_meta("plot_id", plot.id)
	body.set_script(load("res://scripts/farm/farm_plot_interactable.gd"))
	mesh.add_child(body)
	add_child(mesh)


func till_plot(plot_id: StringName) -> bool:
	var plot := _find_plot(plot_id)
	if plot == null or plot.state != PlotState.EMPTY:
		return false
	plot.state = PlotState.TILLED
	EventBus.crop_stage_changed.emit(plot_id, plot.state)
	return true


func plant_crop(plot_id: StringName, crop_id: StringName) -> bool:
	var plot := _find_plot(plot_id)
	if plot == null or plot.state != PlotState.TILLED:
		return false
	if not EconomyManager.has_item(StringName("%s_seeds" % crop_id), 1):
		return false
	EconomyManager.remove_item(StringName("%s_seeds" % crop_id), 1)
	plot.crop_id = crop_id
	plot.state = PlotState.PLANTED
	plot.growth_stage = 0
	plot.planted_day = GameManager.day
	plot.watered = false
	EventBus.crop_planted.emit(plot_id, crop_id)
	return true


func water_plot(plot_id: StringName) -> bool:
	var plot := _find_plot(plot_id)
	if plot == null:
		return false
	if plot.state != PlotState.PLANTED and plot.state != PlotState.WATERED:
		return false
	plot.watered = true
	plot.state = PlotState.WATERED
	EventBus.crop_watered.emit(plot_id)
	return true


func harvest_plot(plot_id: StringName) -> int:
	var plot := _find_plot(plot_id)
	if plot == null or plot.state != PlotState.READY:
		return 0
	var crop_id := plot.crop_id
	var amount := 1
	# Bonus for watering every day
	if plot.watered:
		amount += 1
	EconomyManager.add_item(crop_id, amount)
	plot.state = PlotState.TILLED
	plot.crop_id = &""
	plot.growth_stage = 0
	plot.watered = false
	EventBus.crop_harvested.emit(plot_id, crop_id, amount)
	return amount


func _on_day_started(_day: int, _season: StringName) -> void:
	for key in plots:
		var plot: PlotData = plots[key]
		if plot.state != PlotState.PLANTED and plot.state != PlotState.WATERED:
			continue

		var def: Dictionary = crop_defs.get(str(plot.crop_id), {})
		var days_per_stage: int = def.get("days_per_stage", 1)
		var max_stages: int = def.get("stages", 4)
		var growth_mod := TimeManager.get_growth_modifier()

		if plot.watered:
			# Watered crops grow
			if randf() < growth_mod:
				plot.growth_stage += 1
			plot.watered = false
			plot.state = PlotState.PLANTED
		else:
			# Unwatered crops grow slower or stall
			if randf() < growth_mod * 0.4:
				plot.growth_stage += 1

		if plot.growth_stage >= max_stages:
			plot.state = PlotState.READY
			EventBus.crop_stage_changed.emit(plot.id, plot.state)
		else:
			EventBus.crop_stage_changed.emit(plot.id, plot.growth_stage)


func _on_crop_watered(_plot_id: StringName) -> void:
	pass


func _find_plot(plot_id: StringName) -> PlotData:
	for key in plots:
		var p: PlotData = plots[key]
		if p.id == plot_id:
			return p
	return null


func get_plot_at(grid_x: int, grid_y: int) -> PlotData:
	return plots.get("%d,%d" % [grid_x, grid_y], null)


func get_all_plots() -> Array:
	return plots.values()


func unlock_additional_plots(count: int) -> void:
	# Future: expand grid
	pass


func to_dict() -> Dictionary:
	var out := {}
	for key in plots:
		out[key] = (plots[key] as PlotData).to_dict()
	return {
		"plots": out,
		"farm_level": farm_level,
		"upgrades": upgrades.duplicate(),
	}


func from_dict(data: Dictionary) -> void:
	farm_level = data.get("farm_level", 1)
	upgrades.assign(data.get("upgrades", []))
	var saved_plots: Dictionary = data.get("plots", {})
	for key in saved_plots:
		if plots.has(key):
			plots[key] = PlotData.from_dict(saved_plots[key])
