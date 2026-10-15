class_name PaintedFestivalArt
extends RefCounted
## Stateless art presentation. The towns/social owner controls festival lifecycle.
const PACK := "res://assets/iso_props/festival/"
static var _manifest: Dictionary = {}

static func manifest() -> Dictionary:
	if _manifest.is_empty():
		_manifest = JSON.parse_string(FileAccess.get_file_as_string(PACK + "festival.json"))
	return _manifest.duplicate(true)

static func piece(id: String, rotation: int = 0) -> Dictionary:
	if _manifest.is_empty():
		manifest()
	var item: Dictionary = _manifest["items"].get(id, {})
	var rec: Dictionary = item.get("rot", {}).get(str(rotation), {})
	if rec.is_empty():
		return {}
	var out := rec.duplicate(true)
	out["path"] = PACK + str(rec["file"])
	out["layer"] = item["layer"]
	if rec.has("night"):
		out["night_path"] = PACK + str(rec["night"])
	return out

static func placements(festival_id: String, posts: Dictionary, doors: Array = []) -> Array[Dictionary]:
	var config: Dictionary = GameData.cfg("festival_decor", {})
	var event: Dictionary = config.get("festivals", {}).get(festival_id, {})
	if event.is_empty():
		return []
	var set_: Dictionary = config["sets"][event["set"]]
	var out: Array[Dictionary] = []
	for row in LuaData.arr(config["layout"]):
		if str(row["slot"]) not in LuaData.arr(event["slots_used"]) or not posts.has(str(row["post"])):
			continue
		var offset: Array = row["offset"]
		var delta := Vector2((float(offset[0]) - float(offset[1])) * 64, (float(offset[0]) + float(offset[1])) * 38)
		out.append({"id": event["centre"] if row["slot"] == "centre" else set_[row["slot"]],
			"at": (posts[str(row["post"])] as Vector2) + delta, "rot": int(row["rot"]), "slot": str(row["slot"])})
	for id in LuaData.arr(config["season_accents"].get(event["set"], [])):
		if posts.has("judge") and id != event["centre"]:
			out.append({"id": id, "at": (posts["judge"] as Vector2) + Vector2(75, 20), "rot": 0, "slot": "accent"})
	if bool(event["door_wreaths"]):
		for door in doors:
			var wreath := {"id": set_["door"], "at": door["at"], "rot": int(door.get("rot", 0)), "slot": "door"}
			if door.has("rank"):
				wreath["rank"] = int(door["rank"])
			out.append(wreath)
	return out

static func create(host: Node2D, festival_id: String, posts: Dictionary, doors: Array = [], rank: int = 0, evening: bool = false) -> Node2D:
	var root := Node2D.new()
	root.name = "FestivalArt"
	root.y_sort_enabled = true
	root.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	host.add_child(root)
	for row in placements(festival_id, posts, doors):
		var art := piece(str(row["id"]), int(row["rot"]))
		if art.is_empty():
			continue
		var sprite := Sprite2D.new()
		sprite.name = str(row["id"]) + "_" + str(row["slot"])
		sprite.texture = load(str(art["path"])) as Texture2D
		sprite.centered = false
		var pivot: Array = art["pivot"]
		sprite.offset = -Vector2(pivot[0], pivot[1])
		sprite.scale = Vector2.ONE * float(art.get("render_scale", 1.0))
		sprite.position = row["at"]
		sprite.z_index = int(row.get("rank", rank)) + (2 if art["layer"] == "ceiling" else 0)
		root.add_child(sprite)
		if evening and art.has("night"):
			var accent := Sprite2D.new()
			accent.name = "PaintedAccent"
			accent.texture = load(str(art["night_path"])) as Texture2D
			accent.centered = false
			var offset: Array = art["night_offset"]
			accent.position = sprite.offset
			accent.offset = Vector2(offset[0], offset[1])
			accent.material = Glow.additive_material()
			sprite.add_child(accent)
	return root
