class_name DayNight
extends CanvasModulate
## The ONE CanvasModulate of the world (one per canvas: areas never add their own). Its colour is keyed by the clock hour through
## the keyframes of an ambient PRESET in lua/config/ambient.lua (farm, hyggebyen, forest, cave, home; `@ambient` of a map picks one),
## multiplied by a SEASON tint (foraar neutral, sommer warm, efteraar orange, vinter cool) and, where the preset allows weather, by
## the colour of the current weather (only rain has one). Dark presets are a fixed night that the player's lantern and the glowing
## mushrooms (PointLight2D) punch holes into.
##
## `glow_factor` (0..1) is the same preset's `glow` curve: the factor that fades additive glow sprites and PointLights in at dusk.
## It is emitted as glow_changed (only when it moved), IsoArea.set_night_factor() listens through WorldRoot2D.
signal glow_changed(factor: float)
signal ambient_changed(preset_id: StringName)

const FALLBACK_PRESET := &"farm"

var ambient: StringName = &"farm"
## Screenshots and tests can pin the hour (-1 = follow GameManager).
var override_hour: float = -1.0
var glow_factor: float = 0.0
var vignette_strength: float = 0.0
var weather_allowed: bool = true
var wind: float = 1.0

var _keys: Array[Dictionary] = []     # [{hour: float, color: Color}]
var _glow_keys: Array[Dictionary] = []   # [{hour: float, v: float}]
var _preset_id: StringName = &""
var _snap_next: bool = true


func _ready() -> void:
	set_ambient(ambient)


## Picks the preset of a map header (`farm`, `farm_day`, `forest`, ...). Unknown ids use the default preset of the Lua file.
func set_ambient(id: StringName) -> void:
	ambient = id
	var cfg: Dictionary = GameData.dict_of(GameData.cfg("ambient", {}))
	var aliases: Dictionary = GameData.dict_of(cfg.get("aliases", {}))
	var presets: Dictionary = GameData.dict_of(cfg.get("presets", {}))
	var key: String = str(aliases.get(String(id), String(id)))
	if not presets.has(key):
		key = str(cfg.get("default_preset", String(FALLBACK_PRESET)))
	var preset: Dictionary = GameData.dict_of(presets.get(key, {}))
	_preset_id = StringName(key)
	_keys = _parse_keys(GameData.array_of(preset.get("keys", [])), "color")
	_glow_keys = _parse_keys(GameData.array_of(preset.get("glow", [])), "v")
	weather_allowed = bool(preset.get("weather", true))
	wind = float(preset.get("wind", 1.0))
	vignette_strength = float(preset.get("vignette", 0.0))
	_snap_next = true
	ambient_changed.emit(_preset_id)


func preset_id() -> StringName:
	return _preset_id


static func _parse_keys(rows: Array, value_key: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r in rows:
		if not (r is Dictionary):
			continue
		var d: Dictionary = r
		var v: Variant = Color.from_string(str(d.get("color", "ffffff")), Color.WHITE) if value_key == "color" else float(d.get("v", 0.0))
		out.append({"hour": float(d.get("hour", 0.0)), value_key: v})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["hour"]) < float(b["hour"]))
	return out


## The hour the world shows right now (override, else GameManager hour + minute).
func hour_now() -> float:
	if override_hour >= 0.0:
		return override_hour
	var gm: Node = GameData.gm()
	if gm == null:
		return 12.0
	return float(gm.get("hour")) + float(gm.get("minute")) / 60.0


## Preset colour at an hour (no season, no weather).
func preset_color_at(h: float) -> Color:
	if _keys.is_empty():
		return Color.WHITE
	var hh: float = fposmod(h, 24.0)
	if hh <= float(_keys[0]["hour"]):
		return _keys[0]["color"]
	for i in range(_keys.size() - 1):
		var a: Dictionary = _keys[i]
		var b: Dictionary = _keys[i + 1]
		if hh >= float(a["hour"]) and hh <= float(b["hour"]):
			var t: float = (hh - float(a["hour"])) / maxf(float(b["hour"]) - float(a["hour"]), 0.001)
			return (a["color"] as Color).lerp(b["color"] as Color, smoothstep(0.0, 1.0, t))
	return _keys[_keys.size() - 1]["color"]


func glow_at(h: float) -> float:
	if _glow_keys.is_empty():
		return 0.0
	var hh: float = fposmod(h, 24.0)
	if hh <= float(_glow_keys[0]["hour"]):
		return float(_glow_keys[0]["v"])
	for i in range(_glow_keys.size() - 1):
		var a: Dictionary = _glow_keys[i]
		var b: Dictionary = _glow_keys[i + 1]
		if hh >= float(a["hour"]) and hh <= float(b["hour"]):
			var t: float = (hh - float(a["hour"])) / maxf(float(b["hour"]) - float(a["hour"]), 0.001)
			return lerpf(float(a["v"]), float(b["v"]), smoothstep(0.0, 1.0, t))
	return float(_glow_keys[_glow_keys.size() - 1]["v"])


## Season multiplier of lua/config/ambient.lua (white when the season is unknown).
func season_color(season: StringName) -> Color:
	var table: Dictionary = GameData.dict_of(GameData.cfg("ambient.season", {}))
	return Color.from_string(str(table.get(String(season), "ffffff")), Color.WHITE)


func weather_color(weather: StringName) -> Color:
	var table: Dictionary = GameData.dict_of(GameData.cfg("ambient.weather", {}))
	return Color.from_string(str(table.get(String(weather), "ffffff")), Color.WHITE)


## The colour the modulate is heading for right now.
func target_color() -> Color:
	var c: Color = preset_color_at(hour_now())
	var gm: Node = GameData.gm()
	if gm != null:
		c = c * season_color(StringName(str(gm.get("season"))))
	var tm: Node = GameData.tm()
	if weather_allowed and tm != null:
		c = c * weather_color(StringName(str(tm.get("weather"))))
	c.a = 1.0
	return c


## Colour and glow jump to their targets at once (behind the fade of an area switch, in tests).
func snap() -> void:
	color = target_color()
	_set_glow(glow_at(hour_now()))
	_snap_next = false


func _process(delta: float) -> void:
	var target: Color = target_color()
	if _snap_next:
		snap()
		return
	color = color.lerp(target, clampf(delta * 5.0, 0.0, 1.0))
	_set_glow(glow_at(hour_now()))


func _set_glow(v: float) -> void:
	if absf(v - glow_factor) > 0.004 or (v == 0.0 and glow_factor != 0.0) or (v == 1.0 and glow_factor != 1.0):
		glow_factor = v
		glow_changed.emit(v)
