class_name WardrobeTailoring
extends RefCounted
## Fit painted fabric to anatomy, rather than centring it on a tail/wing canvas.
const LANDMARKS := "res://assets/wardrobe/tailoring.json"
const WIDTHS := [1.0, 0.91, 0.64, 0.84, 1.0, 0.84, 0.64, 0.91]
static var _data: Dictionary = {}

static func pose(body_id: String, family: String, direction: int) -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(LANDMARKS))
	var body := WardrobeCatalog.body(body_id)
	var raw: Array = body.fits[family][direction]
	var source := Vector4(raw[0], raw[1], raw[2], raw[3])
	var fit: Dictionary = _data.bodies[body_id.trim_suffix("_base")]
	var center := float(fit.centers[direction])
	var width := float(fit.shoulders) * float(WIDTHS[direction])
	var target := source
	var shape := Vector4(1, 1, 1, 0)
	var volume := 0.0
	var ghost := body_id.begins_with("ghost")
	if family.begins_with("shirt_") or family.begins_with("dress_"):
		var top := float(fit.neck) - 7.0
		var bottom := float(fit.waist) + 5.0
		shape = Vector4(0.94, 1.0, 0.98, fit.drop)
		if family == "shirt_vest":
			width *= 0.73
			shape.w = 0
		if family == "shirt_smock":
			bottom += 4
		if family.begins_with("dress_"):
			bottom = 200.0 if family == "dress_gown" else 195.0
			width += 6
			shape = Vector4(0.90, 1.0, 1.06, fit.drop * 0.45)
		if ghost:
			bottom = 181.0 if family.begins_with("dress_") else 176.0
			shape = Vector4(0.94, 1, 1.06, 0)
		target = Vector4(center-width/2, top, width, bottom-top)
		volume = 0.10
	elif family.begins_with("pants_"):
		width = float(fit.hips) * float(WIDTHS[direction])
		var top := float(fit.waist) - 3
		var bottom := float(fit.ankle)
		if family == "pants_shorts":
			bottom = lerpf(top, bottom, 0.63)
		elif family == "pants_breeches":
			bottom = lerpf(top, bottom, 0.84)
		elif family == "pants_dungarees":
			top = float(fit.neck) + 3
		if ghost:
			top = 177
			bottom = 188
		target = Vector4(center-width/2, top, width, bottom-top)
		volume = 0.07
	elif family.begins_with("shoes_"):
		width = float(fit.feet) * lerpf(1.0, float(WIDTHS[direction]), 0.65)
		var top := float(fit.foot_y)
		var bottom := 205.0 if body_id in ["fox", "monkey"] else 201.0
		if family in ["shoes_clogs", "shoes_slippers"]:
			top += 6
		target = Vector4(center-width/2, top, width, bottom-top)
	elif family.begins_with("hat_") or family.begins_with("circlet_"):
		target.x += float(fit.head_centers[direction]) - (source.x+source.z/2)
		if body_id == "fox":
			target.y += 7
	elif family.begins_with("neck"):
		target = Vector4(center-17, float(fit.neck)-1, 34, 19)
	elif family.begins_with("ears_"):
		target.x += float(fit.head_centers[direction]) - (source.x+source.z/2)
	return {"source": source, "target": target, "shape": shape, "volume": volume}
