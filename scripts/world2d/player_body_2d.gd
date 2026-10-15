class_name PlayerBody2D
extends CharacterBody2D
## Shared body, camera and cached interaction query for the player and area fixtures.

signal stats_changed

enum S { FREE, TALKING, USING, DODGE, SWING, HURT, FAINTED }

var area: IsoArea
var farm: Node
var visual: IsoChibiSprite2D
var camera: Camera2D
var state: int = S.FREE
var facing8: int = 0
var facing_vec: Vector2 = Vector2(0, 1)
var forced_clip: StringName = &""
var stamina: float = 100.0
var max_stamina: float = 100.0
var half_hearts: int = 10
var max_half_hearts: int = 10
var is_flying: bool = false

var _gvel: Vector2 = Vector2.ZERO
var _walk: float = 285.0
var _run: float = 450.0
var _accel: float = 2500.0
var _decel: float = 3300.0
var _target_zoom: float = Iso.DEFAULT_ZOOM
var _prompt: String = ""
## Cached E-query (rebuilt only when the range changes): allocating a shape + params every
## physics tick was steady garbage at 60 Hz.
var _interact_shape: CircleShape2D
var _interact_query: PhysicsShapeQueryParameters2D
var _interact_range: float = 45.0
## Skip the prompt query when the body has not moved and the facing has not changed (a slow
## fallback still catches an interactable that appears while standing still).
var _prompt_last_pos: Vector2 = Vector2(INF, INF)
var _prompt_last_facing: int = -1
var _prompt_stale: float = 0.0
const PROMPT_REFRESH_S := 0.5


func _ready() -> void:
	add_to_group("player")
	collision_layer = Iso.LAYER_PLAYER
	collision_mask = Iso.MASK_WALKING
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_read_config()
	var cs := CollisionShape2D.new()
	cs.name = "Body"
	var sh := ConvexPolygonShape2D.new()
	var rx: float = float(GameData.player_cfg("body_rx", 25.0))
	var ry: float = float(GameData.player_cfg("body_ry", 14.8))
	var pts := PackedVector2Array()
	for i in 12:
		var a: float = TAU * float(i) / 12.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	sh.points = pts
	cs.shape = sh
	add_child(cs)
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_smoothed = true
	camera.zoom = Vector2.ONE * Iso.DEFAULT_ZOOM
	add_child(camera)
	camera.make_current()
	var gm: Node = GameData.gm()
	set_character(GameData.visual_for_skin(StringName(str(gm.get("character_skin")))) if gm != null else "fox")
	EventBus.player_character_changed.connect(_on_character_changed)
	get_viewport().size_changed.connect(_apply_camera_limits)


func _read_config() -> void:
	_walk = float(GameData.player_cfg("walk_speed", 285.0))
	_run = float(GameData.player_cfg("run_speed", 450.0))
	_accel = float(GameData.player_cfg("accel", 2500.0))
	_decel = float(GameData.player_cfg("decel", 3300.0))
	max_stamina = float(GameData.player_cfg("max_stamina", 100.0))
	stamina = max_stamina
	_interact_range = float(GameData.player_cfg("interaction_range", 45.0))
	_ensure_interact_query()


func _ensure_interact_query() -> void:
	if _interact_shape == null:
		_interact_shape = CircleShape2D.new()
		_interact_query = PhysicsShapeQueryParameters2D.new()
		_interact_query.shape = _interact_shape
		_interact_query.collision_mask = Iso.LAYER_INTERACTABLE
		_interact_query.collide_with_areas = true
		_interact_query.collide_with_bodies = false
	_interact_shape.radius = _interact_range


## The body asks for the head of the skin's chain (fox_base ...); IsoChibiSprite2D walks the fallback chain to real art.
func set_character(visual_id: String) -> void:
	if visual == null:
		visual = IsoChibiSprite2D.create(visual_id)
		visual.name = "Visual"
		add_child(visual)
		move_child(visual, 1)
	else:
		visual.load_character(visual_id)


func _on_character_changed(_character_id: StringName) -> void:
	var gm: Node = GameData.gm()
	if gm != null:
		set_character(GameData.visual_for_skin(StringName(str(gm.get("character_skin")))))


## Called by WorldRoot2D whenever the player is put into an area.
func enter_area(p_area: IsoArea, spawn_global: Vector2) -> void:
	area = p_area
	var old: Node = get_parent()
	if old != null:
		old.remove_child(self)
	area.objects.add_child(self)
	global_position = spawn_global
	_gvel = Vector2.ZERO
	velocity = Vector2.ZERO
	_target_zoom = area.zoom_default
	camera.zoom = Vector2.ONE * _target_zoom
	_apply_camera_limits()
	camera.position_smoothing_enabled = true
	camera.make_current()
	camera.reset_smoothing()
	z_index = 0


## Camera limits follow the area (its builder's `bounds`, else the playable rect); a rect smaller than the view is centred.
func _apply_camera_limits() -> void:
	if area == null or camera == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size / maxf(camera.zoom.x, 0.01)
	var r: Rect2 = IsoArea.camera_limits_for(area.camera_rect(), view)
	camera.limit_left = int(r.position.x)
	camera.limit_top = int(r.position.y)
	camera.limit_right = int(r.end.x)
	camera.limit_bottom = int(r.end.y)


func _unhandled_input(event: InputEvent) -> void:
	if GameData.gm().is_modal_open() or state == S.TALKING or area == null:
		return
	if event.is_action_pressed("zoom_in"):
		_set_zoom(_target_zoom + 0.05)
	elif event.is_action_pressed("zoom_out"):
		_set_zoom(_target_zoom - 0.05)
	elif event.is_action_pressed("interact"):
		if try_interact():
			get_viewport().set_input_as_handled()


## Mouse wheel zoom: steps accumulate on the TARGET value and stay inside the area's zoom range.
func _set_zoom(z: float) -> void:
	_target_zoom = clampf(z, area.zoom_range.x, area.zoom_range.y)
	camera.zoom = Vector2.ONE * _target_zoom
	_apply_camera_limits()


func _physics_process(delta: float) -> void:
	if area == null:
		return
	var in_dir := Vector2.ZERO
	if state == S.FREE:
		in_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var speed: float = _run if Input.is_action_pressed("run") else _walk
	_gvel = _gvel.move_toward(in_dir * speed, (_accel if in_dir != Vector2.ZERO else _decel) * delta)
	velocity = Iso.to_screen(_gvel)
	move_and_slide()
	_gvel = Iso.to_ground(velocity)
	if in_dir != Vector2.ZERO:
		facing8 = Iso.dir8_of(in_dir)
		facing_vec = Iso.dir8_vector(facing8)
	if visual != null:
		if forced_clip != &"":
			visual.play_loop(forced_clip)
		else:
			visual.update_motion(velocity, Input.is_action_pressed("run"), false, false, in_dir)
	_update_prompt(delta)


# ------------------------------------------------------------------ the Player contract

func take_damage(_half_hearts: int, _from_global: Vector2 = Vector2.ZERO) -> bool:
	return false


func begin_talk(_pos: Vector2 = Vector2.ZERO) -> void:
	state = S.TALKING
	velocity = Vector2.ZERO
	_gvel = Vector2.ZERO


func end_talk() -> void:
	state = S.FREE


func revive(at_global: Vector2) -> void:
	global_position = at_global
	half_hearts = max_half_hearts
	stamina = max_stamina
	state = S.FREE
	forced_clip = &""
	stats_changed.emit()
	_emit_stats_on_bus()


## Restores energy and hearts (the bed and the pass-out of WorldRoot2D call it).
func restore_after_sleep() -> void:
	stamina = max_stamina
	half_hearts = max_half_hearts
	stats_changed.emit()
	_emit_stats_on_bus()


## Mirrors the local stats_changed on the contract signals: the HUD screens listen to the bus, not to this stub.
func _emit_stats_on_bus() -> void:
	EventBus.player_health_changed.emit(half_hearts, max_half_hearts)
	EventBus.player_stats_changed.emit({"half_hearts": half_hearts, "max_half_hearts": max_half_hearts, "stamina": stamina, "max_stamina": max_stamina})


## The cell in front of the feet (the one a tool or E acts on).
func target_cell() -> Vector2i:
	return area.global_to_cell(global_position) + area.facing_step(facing8)


func target_global() -> Vector2:
	return area.cell_to_global(target_cell())


## E-query: a circle of r = interaction_range ground px at the facing cell on layer `interactable` (D20), nearest host wins.
func nearest_interactable() -> Node:
	if state != S.FREE or area == null:
		return null
	_ensure_interact_query()
	_interact_query.transform = Transform2D(Vector2.RIGHT, Vector2(0.0, Iso.squash()), target_global())
	var best: Node = null
	var best_d: float = 1e9
	for r in get_world_2d().direct_space_state.intersect_shape(_interact_query, 8):
		var a: Object = r["collider"]
		var host: Node = (a as Node).get_parent() if a is Area2D else null
		if host != null and host != self and host.has_method("interact") and host is Node2D:
			var d: float = Iso.ground_dist((host as Node2D).global_position, global_position)
			if d < best_d:
				best_d = d
				best = host
	return best


func try_interact() -> bool:
	var it: Node = nearest_interactable()
	if it == null:
		return false
	it.call("interact", self)
	return true


func _update_prompt(delta: float = 0.0) -> void:
	_prompt_stale += delta
	# The prompt only changes when the player moves or turns; skip the physics query otherwise,
	# but still refresh at PROMPT_REFRESH_S so a newly-available interactable is not missed.
	if global_position.is_equal_approx(_prompt_last_pos) and facing8 == _prompt_last_facing \
			and _prompt_stale < PROMPT_REFRESH_S:
		return
	_prompt_stale = 0.0
	_prompt_last_pos = global_position
	_prompt_last_facing = facing8
	var it: Node = nearest_interactable()
	var text: String = str(it.call("get_interaction_prompt")) if it != null and it.has_method("get_interaction_prompt") else ""
	if text != _prompt:
		_prompt = text
		EventBus.interaction_prompt_changed.emit(text)
