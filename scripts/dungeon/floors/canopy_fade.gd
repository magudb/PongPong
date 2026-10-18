class_name CanopyFade
extends Node
## Only canopy discs covering the player fade. Poll at 10 Hz; interpolate
## locally so the generator and physics geometry remain unchanged.
var area: IsoArea
var _crowns: Array = []
var _poll := 0.0
func attach(target: IsoArea) -> void:
	area = target
	for record in area.prop_nodes:
		if str(record.id).begins_with("crown_"):
			var cls := 0 if str(record.id).begins_with("crown_s") else (1 if str(record.id).begins_with("crown_m") else 2)
			_crowns.append({"cell":record.cell,"class":cls,"nodes":record.nodes,"alpha":1.0})
func _process(dt: float) -> void:
	_poll -= dt
	var player := PlayerRegistry.local_player(get_tree()) as Node2D
	if player == null or area == null: return
	if _poll <= 0:
		_poll = 0.1
		var cell := area.global_to_cell(player.global_position)
		for crown in _crowns:
			crown.alpha = 0.45 if DungeonGen.crown_covers(crown["class"],crown.cell.x,crown.cell.y,cell.x,cell.y) else 1.0
	for crown in _crowns:
		for node in crown.nodes:
			if is_instance_valid(node): node.modulate.a = move_toward(node.modulate.a,float(crown.alpha),dt/0.15)
