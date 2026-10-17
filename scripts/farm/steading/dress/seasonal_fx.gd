class_name SeasonalFarmFx
extends Node
## One screen-space emitter family, bounded by the existing farm-site data.
## Painted particle pixels retain their source pigment. Fireflies use the shared
## technical light kernel and add no PointLight2D.
const PACK := "res://assets/iso_props/farm_dress/"
const CAPS := {"foraar":20,"sommer":14,"efteraar":16,"vinter":40}
const KEYS := {"foraar":"petals_max","sommer":"fireflies_max","efteraar":"leaves_max","vinter":"snow_max"}
var host: FarmAmbientFx
var family := ""
var _connected := false

static func attach(target: FarmAmbientFx) -> Node:
	var existing := target.get_node_or_null("SeasonalFx")
	if existing!=null:return existing
	var node := SeasonalFarmFx.new()
	node.name = "SeasonalFx"
	node.host = target
	target.add_child(node)
	return node

func _ready() -> void:
	_connect()
	refresh()
func _enter_tree() -> void:
	if is_node_ready():
		_connect()
		refresh.call_deferred()
func _exit_tree() -> void:
	if not _connected:return
	for pair in [[EventBus.season_changed,_season],[EventBus.day_started,_day],[EventBus.weather_changed,_weather],[EventBus.time_of_day_changed,_clock]]:
		if pair[0].is_connected(pair[1]):pair[0].disconnect(pair[1])
	if is_instance_valid(host.world) and host.world.day_night!=null and host.world.day_night.glow_changed.is_connected(_glow):host.world.day_night.glow_changed.disconnect(_glow)
	if get_viewport()!=null and get_viewport().size_changed.is_connected(_resize):get_viewport().size_changed.disconnect(_resize)
	_connected = false
func _connect() -> void:
	if _connected:return
	EventBus.season_changed.connect(_season)
	EventBus.day_started.connect(_day)
	EventBus.weather_changed.connect(_weather)
	EventBus.time_of_day_changed.connect(_clock)
	get_viewport().size_changed.connect(_resize)
	if is_instance_valid(host.world) and host.world.day_night!=null:host.world.day_night.glow_changed.connect(_glow)
	_connected = true

func limit() -> int:
	return clampi(int(GameManager.config_value("farm_site.fx."+str(KEYS.get(str(GameManager.season),"leaves_max")),16)),0,int(CAPS.get(str(GameManager.season),16)))
func count() -> int:
	var maximum := limit()
	if str(GameManager.season)=="vinter" and TimeManager.weather!=&"sne":return mini(maximum,20)
	return maximum
func _night() -> bool:
	return is_instance_valid(host.world) and host.world.day_night!=null and float(host.world.day_night.glow_factor)>0.2
func refresh() -> void:
	if not is_inside_tree() or not is_instance_valid(host):return
	var season := str(GameManager.season)
	if family!=season:
		var old := host.leaves
		if is_instance_valid(old):
			old.emitting = false
			old.visible = false
			old.queue_free()
		var emitter := CPUParticles2D.new()
		emitter.name = "SeasonalParticles"
		emitter.add_to_group("farm_seasonal_particles")
		emitter.emitting = false
		emitter.lifetime = 9.0
		emitter.preprocess = 9.0
		emitter.gravity = Vector2.ZERO
		emitter.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		emitter.direction = Vector2(-0.35,1)
		emitter.spread = 20
		emitter.initial_velocity_min = 35
		emitter.initial_velocity_max = 65
		emitter.angular_velocity_min = -70
		emitter.angular_velocity_max = 70
		emitter.scale_amount_min = 0.7
		emitter.scale_amount_max = 1.2
		emitter.color = Color(1,1,1,0.85)
		if season=="sommer":
			emitter.texture = Glow.halo_texture()
			emitter.material = Glow.additive_material()
			emitter.color = Color(1.0,0.86,0.46,0.6)
			emitter.direction = Vector2(0,-1)
			emitter.spread = 150
			emitter.initial_velocity_min = 4
			emitter.initial_velocity_max = 9
			emitter.scale_amount_min = 0.045
			emitter.scale_amount_max = 0.085
		elif season=="vinter":
			emitter.texture = load(PACK+"snowflake.webp")
			emitter.initial_velocity_min = 25
			emitter.initial_velocity_max = 45
			emitter.scale_amount_min = 0.3
			emitter.scale_amount_max = 0.6
		elif season=="foraar":emitter.texture = load(PACK+"petal.webp")
		else:emitter.texture = load(PACK+"leaf_b.webp")
		host.get_node("LeafFx").add_child(emitter)
		host.leaves = emitter
		family = season
	if family=="efteraar":host.leaves.texture = load(PACK+("leaf_a.webp" if GameManager.day%2==0 else "leaf_b.webp"))
	host.leaves.amount = maxi(1,count())
	host.leaves.emitting = count()>0 and (family!="sommer" or _night())
	host.leaves.visible = host.leaves.emitting
	_resize()
func _resize() -> void:
	if not is_inside_tree() or not is_instance_valid(host.leaves):return
	host._resize()
	if family=="sommer":
		var viewport := get_viewport().get_visible_rect().size
		host.leaves.position = Vector2(viewport.x*0.5,viewport.y*0.6)
		host.leaves.emission_rect_extents = Vector2(viewport.x*0.45,viewport.y*0.12)
func _season(_id: StringName) -> void:refresh()
func _day(_day_id: int,_season_id: StringName) -> void:refresh()
func _weather(_id: StringName) -> void:refresh()
func _clock(_hour: int,_minute: int) -> void:
	if family=="sommer":refresh()

func _glow(_factor: float) -> void:
	if family!="sommer" or not is_inside_tree() or not is_instance_valid(host.leaves):return
	var on := count()>0 and _night()
	if host.leaves.emitting!=on:
		host.leaves.emitting = on
		host.leaves.visible = on
