class_name FieldExpansion2D
extends Interactable2D
var area: IsoArea
var world: Node
var zone := ""
var price := 0
var cells: Array[Vector2i] = []
var _ropes: Array[Node2D] = []
var _stake: Node2D
var _busy := false
var _built := false

static func create_marker(params: Dictionary, _pos: Vector2, cell: Vector2i, target: IsoArea) -> Node:
	var expansion := FieldExpansion2D.new()
	expansion.area = target
	expansion.world = target.get_tree().get_first_node_in_group("world_2d")
	expansion.zone = str(params.get("id", ""))
	expansion.price = maxi(0, int(params.get("price", 0)))
	expansion.cells = IsoArea.parse_cells(str(params.get("cells", "")), Vector2i(target.map.width, target.map.height))
	expansion.set_meta("cell", cell)
	return expansion

func _ready() -> void:
	super._ready()
	_refresh.call_deferred()

func _enter_tree() -> void:
	if is_node_ready():
		_refresh.call_deferred()

func _name_of_zone() -> String:
	return tr(str(GameManager.config_value("farm_site.expansions." + zone + ".name_key", "FARMSITE_ZONE_EAST")))

func get_interaction_prompt() -> String:
	return tr("FARMSITE_EXPAND_PROMPT") % _name_of_zone()

func _refresh() -> void:
	if not is_inside_tree() or not is_instance_valid(world):
		return
	if bool(world.get_area_flag(&"farm", "zone_" + zone, false)):
		_replay()
	elif not _built:
		_built = true
		_stake = area.place_prop("stake_sign", get_meta("cell"))
		_build_ring()

func _build_ring() -> void:
	if cells.is_empty():
		return
	var bounds := Rect2i(cells[0], Vector2i.ONE)
	for cell in cells:
		bounds = bounds.merge(Rect2i(cell, Vector2i.ONE))
	var groups := {"rope_stake_x": [], "rope_stake_z": []}
	for cell in cells:
		if cell.y == bounds.position.y or cell.y == bounds.end.y - 1:
			groups.rope_stake_x.append(cell)
		elif cell.x == bounds.position.x or cell.x == bounds.end.x - 1:
			groups.rope_stake_z.append(cell)
	# Two instanced draws preserve the painted stake art without 22 scene subtrees.
	for id in groups:
		var art := ArtCatalog.prop(StringName(id))
		var texture: Texture2D = art.texture
		var quad := QuadMesh.new()
		quad.size = texture.get_size()
		var mesh := MultiMesh.new()
		mesh.transform_format = MultiMesh.TRANSFORM_2D
		mesh.mesh = quad
		mesh.instance_count = groups[id].size()
		for i in groups[id].size():
			var point: Vector2 = area.objects.to_local(area.cell_to_global(groups[id][i])) - (art.pivot as Vector2) + texture.get_size() * 0.5
			mesh.set_instance_transform_2d(i, Transform2D(0, point))
		var draw := MultiMeshInstance2D.new()
		draw.name = id
		draw.set_meta("farm_rope_cells", groups[id].duplicate())
		draw.multimesh = mesh
		draw.texture = texture
		area.objects.add_child(draw)
		_ropes.append(draw)

func _replay() -> void:
	for cell in cells:
		area.map.set_ground(cell, "f")
		area.farmable[cell] = true
		area.set_terrain(cell, &"field_grass")
	for draw in _ropes:
		if is_instance_valid(draw):
			draw.queue_free()
	_ropes.clear()
	if is_instance_valid(_stake):
		area.remove_prop(_stake)
	_stake = null
	set_enabled(false)
	if world.farm != null:
		world.farm.unlock_cells(zone)
		var view := area.get_node_or_null("FarmView")
		if view != null:
			view.refresh_all()

func interact(_player: Node) -> void:
	if _busy or not is_enabled() or cells.is_empty():
		return
	_busy = true
	var confirmed := await WorldConfirm.ask(self, "FARMSITE_ZONE_EAST", tr("FARMSITE_EXPAND_CONFIRM") % [_name_of_zone(), price, cells.size()], "UI_BUY")
	if confirmed and is_inside_tree() and not bool(world.get_area_flag(&"farm", "zone_" + zone, false)):
		if not EconomyManager.consume_backpack_items({}, func():
			world.set_area_flag(&"farm", "zone_" + zone, 1)
			_replay()
			EconomyManager.after_transaction(func():
				var dust := Dust2D.new()
				area.ground_fx.add_child(dust)
				dust.global_position = global_position
				EventBus.game_event.emit(&"field_expanded", {"id": zone, "cells": cells.size(), "price": price})
				EventBus.whisper_requested.emit(tr("FARMSITE_EXPAND_DONE") % [_name_of_zone(), cells.size()])), price):
			EventBus.whisper_requested.emit(tr("FARMSITE_EXPAND_NEEDGOLD") % [maxi(0, price - EconomyManager.gold), _name_of_zone()])
	_busy = false
