class_name AreaMap
extends RefCounted
## ASCII area description (res://data/maps/<id>.map). Pure data; no nodes, no autoloads (it compiles in `-s` drivers).
##
## File format (plan 3.7):
##   # comment
##   @id farm                      @title ZONE_FARM (a translation key)          @zone farm|city|dark_forest|...   (quest / zone id)
##   @projection iso|ortho         @ambient farm|hyggebyen|forest|cave|home      @theme farm|hyggebyen|forest|cave
##   @depth 2   (ortho; minimap)   @flight true|false                            @music <track|none>
##   @zoom 0.4 @zoom_min 0.3 @zoom_max 0.7                                        camera zoom range (1280 x 720 base)
##   @builder res://scripts/home/home_room.gd                                     header-only area built by a script
##   @prop <char> <prop_id> [key=value ...]                                       an object char -> an art prop id
##   @marker <char> <type> key=value ...                                          an object char -> a marker
##   @ground                       ground rows follow  (one char per cell; ' ' or '#' = void)
##   @objects                      object rows follow  (same size; '.' = nothing)
## Orientation (iso, layout DIAMOND_DOWN): text COLUMNS run to the screen lower-RIGHT (+x), text ROWS to the lower-LEFT (+y);
## top-left char = NORTH corner, top-right = EAST, bottom-right = SOUTH, bottom-left = WEST.
## Rows are padded with '#' (ground) / '.' (objects) to the widest row, so editors may strip trailing blanks.
## Unknown header keys are kept in `extra` (no warning: later packages may add keys); malformed lines go to `errors`.

const KNOWN_KEYS := ["id", "title", "projection", "ambient", "theme", "zone", "depth", "flight", "music", "zoom", "zoom_min", "zoom_max",
	"builder", "prop", "marker", "ground", "objects"]
const ZOOM_UNSET := -1.0

var id: StringName = &""
var title: String = ""
var projection: StringName = &"iso"            # iso (diamond floor) | ortho (rectangular floor)
var ambient: StringName = &"farm"              # farm | hyggebyen | forest | cave | home (preset of lua/config/ambient.lua)
var theme: StringName = &""                    # art theme (terrain family and backdrop); default from the ambient
var zone: StringName = &""                     # quest / zone id; "" = ask lua/config/ambient.lua `area_zone`
var depth: int = 0
var flight_allowed: bool = false
var music: String = ""
var builder: String = ""                       # script that builds the area (header-only maps)
var zoom: float = ZOOM_UNSET
var zoom_min: float = ZOOM_UNSET
var zoom_max: float = ZOOM_UNSET
var width: int = 0
var height: int = 0
var ground: PackedStringArray = PackedStringArray()
var objects: PackedStringArray = PackedStringArray()
var markers: Dictionary = {}                   # char -> {"marker": type, ...params}
var props: Dictionary = {}                     # char -> {"prop": art id, ...params}
var extra: Dictionary = {}                     # unknown header key -> value text
var errors: Array[String] = []
var path: String = ""

## Why the last load_file() failed ("" = it did not). A missing file is NOT an engine error.
static var last_error: String = ""


static func load_file(res_path: String) -> AreaMap:
	last_error = ""
	if not FileAccess.file_exists(res_path):
		last_error = "no such map file: %s" % res_path
		return null
	var text: String = FileAccess.get_file_as_string(res_path)
	if text.strip_edges().is_empty():
		last_error = "empty map file: %s" % res_path
		return null
	return parse_text(text, res_path)


## Parses map text (tests and tools build maps in memory).
static func parse_text(text: String, p_path: String = "") -> AreaMap:
	var m := AreaMap.new()
	m.path = p_path
	m._parse(text)
	return m


func _parse(text: String) -> void:
	var section: String = "header"
	var g_rows: Array[String] = []
	var o_rows: Array[String] = []
	for raw in text.split("\n"):
		var line: String = raw.trim_suffix("\r")
		var is_header: bool = false
		if line.begins_with("@"):
			var first: String = line.substr(1).split(" ", false)[0] if line.length() > 1 and line[1] != " " else ""
			# an objects row may start with the '@' spawn char: only a KNOWN key makes a row a header line
			is_header = first in KNOWN_KEYS or section == "header"
		if section == "header" and not is_header:
			if line.strip_edges().is_empty() or line.begins_with("#"):
				continue
			errors.append("not a header line: %s" % line.left(60))
			continue
		if is_header:
			if line.begins_with("@ground"):
				section = "ground"
			elif line.begins_with("@objects"):
				section = "objects"
			else:
				_parse_header(line)
			continue
		if section == "ground":
			g_rows.append(line)
		elif section == "objects":
			o_rows.append(line)
	# drop trailing blank rows left by the final newline
	while not g_rows.is_empty() and g_rows[-1].strip_edges().is_empty():
		g_rows.pop_back()
	while not o_rows.is_empty() and o_rows[-1].strip_edges().is_empty():
		o_rows.pop_back()
	height = g_rows.size()
	for r in g_rows:
		width = maxi(width, r.length())
	for r in g_rows:
		ground.append(r.rpad(width, "#").replace(" ", "#"))
	for i in height:
		var r2: String = o_rows[i] if i < o_rows.size() else ""
		objects.append(r2.rpad(width, ".").replace(" ", "."))
	if o_rows.size() > height:
		errors.append("@objects has %d rows, @ground only %d" % [o_rows.size(), height])
	if theme == &"":
		theme = _default_theme()


func _default_theme() -> StringName:
	match String(ambient):
		"hyggebyen":
			return &"hyggebyen"
		"forest", "forest_night":
			return &"forest"
		"cave":
			return &"cave"
		"home":
			return &"home"
	return &"farm"


func _parse_header(line: String) -> void:
	var parts: PackedStringArray = line.substr(1).split(" ", false)
	if parts.is_empty():
		return
	var key: String = parts[0]
	var rest: String = " ".join(parts.slice(1))
	match key:
		"id":
			id = StringName(parts[1]) if parts.size() > 1 else &""
		"title":
			title = rest
		"projection":
			projection = StringName(parts[1]) if parts.size() > 1 else &"iso"
		"ambient":
			ambient = StringName(parts[1]) if parts.size() > 1 else &"farm"
		"theme":
			theme = StringName(parts[1]) if parts.size() > 1 else &""
		"zone":
			zone = StringName(parts[1]) if parts.size() > 1 else &""
		"depth":
			depth = int(parts[1]) if parts.size() > 1 else 0
		"flight":
			flight_allowed = parts.size() > 1 and parts[1] == "true"
		"music":
			music = parts[1] if parts.size() > 1 else ""
		"zoom":
			zoom = float(parts[1]) if parts.size() > 1 else ZOOM_UNSET
		"zoom_min":
			zoom_min = float(parts[1]) if parts.size() > 1 else ZOOM_UNSET
		"zoom_max":
			zoom_max = float(parts[1]) if parts.size() > 1 else ZOOM_UNSET
		"builder":
			builder = parts[1] if parts.size() > 1 else ""
		"marker":
			if parts.size() < 3 or parts[1].length() != 1:
				errors.append("bad @marker line: %s" % line.left(60))
				return
			var d: Dictionary = {"marker": parts[2]}
			for i in range(3, parts.size()):
				var kv: PackedStringArray = parts[i].split("=", true, 1)
				if kv.size() == 2:
					d[kv[0]] = kv[1]
			markers[parts[1]] = d
		"prop":
			if parts.size() < 3 or parts[1].length() != 1:
				errors.append("bad @prop line: %s" % line.left(60))
				return
			var p: Dictionary = {"prop": parts[2]}
			for i in range(3, parts.size()):
				var kv2: PackedStringArray = parts[i].split("=", true, 1)
				if kv2.size() == 2:
					p[kv2[0]] = kv2[1]
			props[parts[1]] = p
		_:
			extra[key] = rest


# ----------------------------------------------------------------------------- queries

func is_iso() -> bool:
	return projection != &"ortho"


## A header-only area: the builder script constructs it (no @ground / @objects rows needed).
func is_builder() -> bool:
	return builder != ""


func has_grid() -> bool:
	return width > 0 and height > 0


## The camera zoom range of this area in the 1280 x 720 base: Vector2(min, max); the default is Iso.ZOOM_MIN .. Iso.ZOOM_MAX.
func zoom_range() -> Vector2:
	var lo: float = zoom_min if zoom_min > 0.0 else Iso.ZOOM_MIN
	var hi: float = zoom_max if zoom_max > 0.0 else Iso.ZOOM_MAX
	return Vector2(minf(lo, hi), maxf(lo, hi))


## The default camera zoom, clamped into zoom_range().
func zoom_default() -> float:
	var r: Vector2 = zoom_range()
	return clampf(zoom if zoom > 0.0 else Iso.DEFAULT_ZOOM, r.x, r.y)


func ground_at(c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= width or c.y >= height:
		return "#"
	return ground[c.y][c.x]


func object_at(c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= width or c.y >= height:
		return "."
	return objects[c.y][c.x]


func is_void(c: Vector2i) -> bool:
	return ground_at(c) == "#"


func find_objects(ch: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in height:
		for x in width:
			if objects[y][x] == ch:
				out.append(Vector2i(x, y))
	return out


## Number of non-void ground cells.
func walkable_count() -> int:
	var n: int = 0
	for row in ground:
		n += row.length() - row.count("#")
	return n


## Replaces one ground char (tests and tools; the cell must be inside the grid).
func set_ground(c: Vector2i, ch: String) -> void:
	if c.x < 0 or c.y < 0 or c.x >= width or c.y >= height:
		return
	var row: String = ground[c.y]
	ground[c.y] = row.substr(0, c.x) + ch + row.substr(c.x + 1)


## Replaces one object char.
func set_object(c: Vector2i, ch: String) -> void:
	if c.x < 0 or c.y < 0 or c.x >= width or c.y >= height:
		return
	var row: String = objects[c.y]
	objects[c.y] = row.substr(0, c.x) + ch + row.substr(c.x + 1)
