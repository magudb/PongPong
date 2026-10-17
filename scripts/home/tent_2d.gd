extends Node2D
var area: IsoArea
var _picture: Node2D
static func create_marker(_params: Dictionary, pos: Vector2, _cell: Vector2i, target: IsoArea) -> Node:
	var result: Node2D = load("res://scripts/home/tent_2d.gd").new()
	result.position = target.to_local(pos)
	result.area = target
	return result
func _ready() -> void:
	refresh()
	EventBus.home_upgrade_started.connect(func(_a, _b, _c): refresh())
	EventBus.home_upgraded.connect(func(_a, _b): refresh())
	EventBus.load_completed.connect(func(_slot): refresh())
func refresh() -> void:
	if is_instance_valid(_picture):
		area.remove_prop(_picture)
		_picture = null
	if HomeManager.is_under_construction():
		_picture = area.place_prop(&"tent", area.global_to_cell(global_position))
