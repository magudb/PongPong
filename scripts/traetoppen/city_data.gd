class_name CityData
extends RefCounted
## What the city map (package V4-city-map) reads and derives from data/traetoppen/traetoppen.json (V3's file, READ here, never copied), from
## assets/iso_props/city/props.json (V5's art manifest) and from lua/config/traetoppen.lua (V3's numbers): pure functions, no nodes, so the
## builder, the preview citizens and the section share ONE reading of the data.
##
##   load_data()                  the parsed JSON ({} on a problem, LevelRegistry.last_error says why)
##   world(data, [x, y])          a sketch point in WORLD px (x K, the header `scale`)
##   hut_art / pennant_art / disc_art / trunk_art(...)   the art ids of the city (ArtCatalog ids, never file names)
##   markers(data)                the NORMALISED marker list the builder places: the JSON's npc / seed_basket / lift / climb markers plus the three
##                                kitchen-garden `node` markers (planter_herb x2, planter_berry x1: the kinds of design 4.4 landmark 7) and the
##                                ambient owls of the other owl holes (landmark 9: Fru Ugle has the first hole)
##   art_ids(data)                every ArtCatalog prop id the built city draws (the section proves ArtCatalog.has_real_prop for each)
##   config()                     lua/config/traetoppen.lua, read through GameData.cfg (post board bath swap stall caches skovlift fast_travel)

const DATA_PATH := "res://data/traetoppen/traetoppen.json"
const PROPS_PATH := "res://assets/iso_props/city/props.json"
const MAP_PATH := "res://data/maps/traetoppen.map"
## The viewBox of the sketch (Miljoeer v2): the unit of "within 3 percent of the sketch".
const SKETCH_SIZE := Vector2(1800.0, 1240.0)
## Kitchen gardens (landmark 7): the prop id -> the node kind of P19's resource nodes (two herb beds and one berry bed, design 4.4).
const PLANTER_KINDS := {"planter1": "planter_herb", "planter2": "planter_herb", "planter3": "planter_berry"}
const PLANTER_ART := {"planter_herb": &"planter_box", "planter_berry": &"planter_box_berry"}
## The other owl holes hold an ambient owl each (a plain idle pack owl, no NPC). The first hole (index 0) is Fru Ugle's.
const AMBIENT_OWL_VISUAL := "owl"
## Sofus sits IN the tub of landmark 6 (level E, design 4.4): the marker is the sketch's drawn position of his head and shoulders, which is inside the tub's
## keep-out; a figure standing there would stand behind the tub. A drawn stand-in puts his feet at the water centre of the tub prop (feet offset, world px),
## so the tub's front half (drawn one sort step after him) covers his lower body.
const POSE_PROPS := {"bathkeeper_sofus": {"prop": "bath_tub", "offset": Vector2(0, 14)}}

static var _props_cache: Dictionary = {}


# ------------------------------------------------------------------ data files

static func load_data() -> Dictionary:
	return LevelRegistry.load_data(DATA_PATH)


## V5's manifest (assets/iso_props/city/props.json), parsed once.
static func city_props() -> Dictionary:
	if _props_cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROPS_PATH)) if FileAccess.file_exists(PROPS_PATH) else null
		_props_cache = parsed as Dictionary if parsed is Dictionary else {}
		# Geometry mappings remain V5's data; image dimensions, pivots and night
		# anchors follow the effective art pack, just like the builder's textures.
		for id in _props_cache.keys():
			if str(id).begins_with("_"):
				continue
			var effective: Dictionary = ArtCatalog.prop_metadata(StringName(str(id)))
			if not effective.is_empty():
				_props_cache[id] = effective
	return _props_cache


static func clear_cache() -> void:
	_props_cache = {}


static func scale_of(data: Dictionary) -> float:
	return maxf(LuaData.num(data.get("scale", 3.0), 3.0), 0.0001)


## A sketch point [x, y] in WORLD px.
static func world(data: Dictionary, p: Variant) -> Vector2:
	var a: Array = LuaData.arr(p)
	if a.size() < 2:
		return Vector2.ZERO
	return Vector2(LuaData.num(a[0]), LuaData.num(a[1])) * scale_of(data)


## The record of a list of the data by id ({} when there is none).
static func record(data: Dictionary, list_key: String, id: String) -> Dictionary:
	for rec in LuaData.arr(data.get(list_key, [])):
		if rec is Dictionary and str((rec as Dictionary).get("id", "")) == id:
			return rec as Dictionary
	return {}


static func rank_of(data: Dictionary, level_id: Variant) -> int:
	var lid: String = str(level_id)
	for key in ["levels", "bridges"]:
		var rec: Dictionary = record(data, key, lid)
		if not rec.is_empty():
			return LuaData.int_of(rec.get("rank", 0))
	return 0


# ------------------------------------------------------------------ art ids

## The hut sprite of a building id (V5's `_city.hut_of`), "" when the manifest does not know it.
static func hut_art(building_id: String) -> StringName:
	var hut_of: Dictionary = LuaData.dict(LuaData.dict(city_props().get("_city", {})).get("hut_of", {}))
	return StringName(str(hut_of.get(building_id, "")))


## The pennant sprite whose colour is `hex` (the building's `pennant` field): pennant_pink / blue / gold / mint.
static func pennant_art(hex: String) -> StringName:
	var props: Dictionary = city_props()
	for id in props:
		var rec: Variant = props[id]
		if rec is Dictionary and str((rec as Dictionary).get("kind", "")) == "pennant" and str((rec as Dictionary).get("colour", "")).to_lower() == hex.to_lower() \
				and (rec as Dictionary).has("frames"):
			return StringName(str(id))
	return &""


## The sprite ids a multi-frame piece is made of (V5: `frames` on the first frame, in order), the id itself for a single frame.
static func frames_of(id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	var rec: Dictionary = LuaData.dict(city_props().get(String(id), {}))
	for f in LuaData.arr(rec.get("frames", [])):
		out.append(StringName(str(f)))
	if out.is_empty():
		out.append(id)
	return out


## The disc sprite of a platform: the one whose `rx` (sketch px) is nearest.
static func disc_art(rx_sketch: float) -> StringName:
	return _nearest(&"platform_disc", rx_sketch)


## The tileable bark of a trunk: the one whose `rx` (sketch px) is nearest. foot_art / root_art of the same width follow from the bark id.
static func trunk_art(rx_sketch: float) -> StringName:
	return _nearest(&"trunk_bark", rx_sketch)


static func foot_art(bark: StringName) -> StringName:
	return StringName(String(bark).replace("trunk_bark_", "trunk_foot_"))


static func root_art(bark: StringName) -> StringName:
	return StringName(String(bark).replace("trunk_bark_", "trunk_root_"))


static func _nearest(kind_prefix: StringName, rx_sketch: float) -> StringName:
	var best: StringName = &""
	var best_d: float = INF
	var props: Dictionary = city_props()
	for id in props:
		var rec: Variant = props[id]
		if not (rec is Dictionary) or not str(id).begins_with(String(kind_prefix)) or not (rec as Dictionary).has("rx"):
			continue
		var d: float = absf(LuaData.num((rec as Dictionary)["rx"]) - rx_sketch)
		if d < best_d:
			best_d = d
			best = StringName(str(id))
	return best


## The night layer of a hut sprite (additive), "" for a sprite without one.
static func night_art(hut: StringName) -> StringName:
	return StringName(str(LuaData.dict(city_props().get(String(hut), {})).get("night", "")))


## Every ArtCatalog prop id the built city draws.
static func art_ids(data: Dictionary) -> Array[String]:
	var seen: Dictionary = {}
	for lv in LuaData.arr(data.get("levels", [])):
		seen[String(disc_art(LuaData.num((lv as Dictionary).get("rx", 0.0))))] = true
	for t in LuaData.arr(data.get("trunks", [])):
		var bark: StringName = trunk_art(LuaData.num((t as Dictionary).get("rx", 0.0)))
		seen[String(bark)] = true
		seen[String(foot_art(bark))] = true
		seen[String(root_art(bark))] = true
	for b in LuaData.arr(data.get("buildings", [])):
		var bd: Dictionary = b
		var hut: StringName = hut_art(str(bd.get("id", "")))
		seen[String(hut)] = true
		seen[String(night_art(hut))] = true
		if bd.has("pennant"):
			for f in frames_of(pennant_art(str(bd["pennant"]))):
				seen[String(f)] = true
	for p in LuaData.arr(data.get("props", [])):
		seen[str((p as Dictionary).get("art", ""))] = true
	for id in ["bath_tub_back", "bath_tub_front", "fire_flame", "fire_flame_f1", "fire_flame_f2", "planter_box", "planter_box_berry", "lantern_hang", "lamp_door",
			"foliage_front_a", "foliage_front_b", "trunk_hole_owl", "trunk_hole_owl_b", "owl_shelf", "bat_house_hanging", "bat_hang", "bat_hang_f1", "ladder_tile",
			"rope_tile", "lift_basket", "lift_pulley", "bridge_deck_tile_w43", "bridge_post", "canopy_top_strip", "signpost", "mailbox_red", "shadow_soft"]:
		seen[id] = true
	seen.erase("")
	var out: Array[String] = []
	for k in seen.keys():
		out.append(str(k))
	out.sort()
	return out


# ------------------------------------------------------------------ markers

## The marker list of the built city (world px). Each: {type, id, kind, at: Vector2 (world), level, when, window, reach, params: Dictionary (the
## dictionary a marker handler receives: `marker` = type plus the key=value parameters), source: "data" | "derived"}.
static func markers(data: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var k: float = scale_of(data)
	for rec in LuaData.arr(data.get("markers", [])):
		if not (rec is Dictionary):
			continue
		var m: Dictionary = rec
		var type: String = str(m.get("type", ""))
		var params: Dictionary = {"marker": type}
		for key in m:
			if key != "type" and key != "at" and key != "level":
				params[str(key)] = m[key]
		var at: Vector2 = world(data, m.get("at", [0, 0])) if m.has("at") else Vector2.ZERO
		if type == "lift":
			var lift: Dictionary = record(data, "lifts", str(m.get("id", "")))
			at = world(data, lift.get("stand", m.get("at", [0, 0])))
		var row: Dictionary = {"type": type, "id": str(m.get("id", "")), "kind": str(m.get("kind", "")), "at": at, "level": str(m.get("level", "")),
			"when": str(m.get("when", "")), "window": bool(m.get("window", false)), "reach": LuaData.num(m.get("reach", 0.0)), "params": params, "source": "data"}
		row["pose"] = at
		var pose: Dictionary = LuaData.dict(POSE_PROPS.get(str(m.get("id", "")), {}))
		if not pose.is_empty():
			row["pose"] = world(data, record(data, "props", str(pose["prop"])).get("at", [0, 0])) + (pose["offset"] as Vector2)
		out.append(row)
	# the kitchen gardens: three `node` markers on level G at the planter beds
	for pr in LuaData.arr(data.get("props", [])):
		var pd: Dictionary = pr
		var kind: String = str(PLANTER_KINDS.get(str(pd.get("id", "")), ""))
		if kind == "":
			continue
		out.append({"type": "node", "id": str(pd["id"]), "kind": kind, "at": world(data, pd.get("at", [0, 0])), "level": str(pd.get("level", "")), "when": "", "window": false,
			"reach": 0.0, "params": {"marker": "node", "kind": kind}, "source": "derived"})
	# ambient owls: the holes after the first one
	var holes: Array = LuaData.arr(data.get("owl_holes", []))
	for i in range(1, holes.size()):
		var hd: Dictionary = holes[i]
		out.append({"type": "ambient_owl", "id": "owl_hole_%d" % i, "kind": "", "at": world(data, hd.get("at", [0, 0])), "level": "", "when": "", "window": true, "reach": 0.0,
			"params": {"marker": "ambient_owl", "visual": AMBIENT_OWL_VISUAL}, "source": "derived", "rank": LuaData.int_of(hd.get("rank", 175))})
	return out


## The markers of one type.
static func markers_of(data: Dictionary, type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for m in markers(data):
		if str(m["type"]) == type:
			out.append(m)
	return out


# ------------------------------------------------------------------ config (lua/config/traetoppen.lua)

## The keys V4 reads (design 4.5). `config()` answers them through GameData.cfg, so a test can override one with GameManager.set_config_override.
const CONFIG_KEYS: Array[String] = ["scale", "zoom", "post", "board", "bath", "swap", "stall", "caches", "skovlift", "fast_travel"]


static func config() -> Dictionary:
	var out: Dictionary = {}
	for key in CONFIG_KEYS:
		out[key] = GameData.cfg("traetoppen.%s" % key, null)
	return out


## The weekdays (0 = Monday) on which Brumme sells at the Torvet stall.
static func stall_weekdays() -> Array[int]:
	var out: Array[int] = []
	for d in LuaData.arr(LuaData.dict(GameData.cfg("traetoppen.stall", {})).get("weekdays", [])):
		out.append(LuaData.int_of(d))
	return out
