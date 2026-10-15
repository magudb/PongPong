class_name TargetMarker2D
extends Node2D
## Highlight of the tile in front of the player (the cell a tool / interaction will act on).
## Gold ring = the cell is a valid farm target ("guld betyder valgt"), cream ring = just a walkable cell.

var projection: StringName = &"iso"
var valid: bool = false
var _pulse: float = 0.0


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func _outline() -> PackedVector2Array:
	if projection == &"iso":
		var pts := PackedVector2Array()
		var hw: float = Iso.TILE_W * 0.5 - 3.0 * Iso.S
		var hh: float = Iso.TILE_H * 0.5 - 1.5 * Iso.S
		pts.append(Vector2(0, -hh))
		pts.append(Vector2(hw, 0))
		pts.append(Vector2(0, hh))
		pts.append(Vector2(-hw, 0))
		return pts
	var w: float = Iso.ORTHO_W * 0.5 - 3.0 * Iso.S
	var h: float = Iso.ORTHO_H * 0.5 - 2.0 * Iso.S
	return PackedVector2Array([Vector2(-w, -h), Vector2(w, -h), Vector2(w, h), Vector2(-w, h)])


func _draw() -> void:
	var pts: PackedVector2Array = _outline()
	var a: float = 0.75 + 0.25 * sin(_pulse * 5.0)
	var gold := Color("e3c372")
	var ink := Color("2b2340")
	var fill: Color = Color(gold.r, gold.g, gold.b, 0.20 * a) if valid else Color(1, 1, 1, 0.08)
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color(ink.r, ink.g, ink.b, 0.9), 5.0 * Iso.S, true)
	draw_polyline(closed, gold if valid else Color("fbf5e6"), 2.5 * Iso.S, true)
