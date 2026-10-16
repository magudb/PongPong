class_name WeatherFx
extends CanvasLayer
## Screen-space weather overlay. ONLY rain has a visual: a CPUParticles2D curtain of thin streaks while TimeManager.is_raining()
## in an area whose ambient preset allows weather (iso areas outdoors: never in the forest, the cave or the home interior).
## Fog, snow and thunder are LABEL-ONLY (the HUD names them, nothing is drawn): a stub by design (plan 3.9, section 9.2).
## The streaks slant with the preset's `wind` (lua/config/ambient.lua).

## The weather ids that have a visual (tests assert the rest stay label-only).
const VISUAL_WEATHER: Array[StringName] = [&"regn"]
const RAIN_LAYER := 6

var raining: bool = false
var wind: float = 1.0
var area_allows: bool = true

var _rain: CPUParticles2D
var _tex: ImageTexture


func _ready() -> void:
	layer = RAIN_LAYER
	name = "WeatherFx"
	_rain = CPUParticles2D.new()
	_rain.name = "Rain"
	_rain.emitting = false
	_rain.amount = 260
	_rain.lifetime = 0.8
	_rain.preprocess = 0.8
	_rain.texture = _streak_texture()
	_rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_rain.direction = Vector2(0.18, 1.0)
	_rain.spread = 4.0
	_rain.gravity = Vector2.ZERO
	_rain.initial_velocity_min = 1100.0
	_rain.initial_velocity_max = 1350.0
	_rain.color = Color(0.82, 0.88, 0.98, 0.55)
	_rain.local_coords = true
	add_child(_rain)
	get_viewport().size_changed.connect(_fit)
	EventBus.weather_changed.connect(_on_weather_changed)
	_fit()
	_sync()


func _streak_texture() -> ImageTexture:
	if _tex == null:
		var img: Image = Image.create_empty(3, 18, false, Image.FORMAT_RGBA8)
		for y in 18:
			var a: float = clampf(float(y) / 6.0, 0.0, 1.0) * clampf(float(17 - y) / 4.0, 0.0, 1.0)
			for x in 3:
				img.set_pixel(x, y, Color(1, 1, 1, a * (1.0 if x == 1 else 0.5)))
		_tex = ImageTexture.create_from_image(img)
	return _tex


func _fit() -> void:
	if _rain == null:
		return
	var size: Vector2 = get_viewport().get_visible_rect().size
	_rain.position = Vector2(size.x * 0.5, -30.0)
	_rain.emission_rect_extents = Vector2(size.x * 0.65, 4.0)
	_rain.lifetime = (size.y + 80.0) / 1225.0


## The area decides whether the weather may be seen (preset `weather` flag) and how strongly the wind slants it.
func set_area(allows_weather: bool, p_wind: float) -> void:
	area_allows = allows_weather
	wind = p_wind
	if _rain != null:
		_rain.direction = Vector2(0.18 * p_wind, 1.0)
	_sync()


func _on_weather_changed(_weather: StringName) -> void:
	_sync()


## Rain shows exactly while it rains and the area allows it.
func _sync() -> void:
	var tm: Node = GameData.tm()
	raining = tm != null and tm.has_method("is_raining") and bool(tm.call("is_raining"))
	if _rain != null:
		# Existing particles outlive emission; never carry that curtain indoors.
		_rain.visible = area_allows
		_rain.emitting = raining and area_allows


func is_emitting() -> bool:
	return _rain != null and _rain.emitting
