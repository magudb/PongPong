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
## Identity (MP1). Single-player defaults: one local hero `p0` on peer 1, slot 0.
var player_id: StringName = &"p0"
var peer_id: int = 1
var is_local: bool = true
var player_slot: int = 0
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
var _prompt_last_ready := false
var _prompt_stale: float = 0.0
const PROMPT_REFRESH_S := 0.5
## The short action states during which the E prompt keeps its last text (E itself still waits for FREE).
const BRIEF_STATES: Array[S] = [S.USING, S.DODGE, S.SWING, S.HURT]
## One mouse-wheel notch of zoom; a trackpad pan counts its delta in notches.
const ZOOM_STEP := 0.05


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
	# Bodies move on the 60 Hz physics tick. A camera that smoothed every rendered frame moved between
	# those steps, so on a 120/144 Hz display the hero and the citizens juddered against the background.
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_smoothed = true
	camera.zoom = Vector2.ONE * Iso.DEFAULT_ZOOM
	add_child(camera)
	if is_local:
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


func _on_character_changed(_player_id: StringName, _character_id: StringName) -> void:
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
	if not is_inside_tree() or area == null or camera == null:
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
	if _zoom_input(event):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		if try_interact():
			get_viewport().set_input_as_handled()


## Wheel notches, and the macOS trackpad, which sends a two-finger scroll as InputEventPanGesture and a pinch as
## InputEventMagnifyGesture instead of wheel buttons (review UX-04). The pad's right stick is held, not stepped:
## _zoom_stick() polls it, so its motion events are skipped here.
func _zoom_input(event: InputEvent) -> bool:
	if event is InputEventPanGesture:
		_set_zoom(_target_zoom - (event as InputEventPanGesture).delta.y * ZOOM_STEP)
	elif event is InputEventMagnifyGesture:
		_set_zoom(_target_zoom * (event as InputEventMagnifyGesture).factor)
	elif event is InputEventJoypadMotion:
		return false
	elif event.is_action_pressed("zoom_in"):
		_set_zoom(_target_zoom + ZOOM_STEP)
	elif event.is_action_pressed("zoom_out"):
		_set_zoom(_target_zoom - ZOOM_STEP)
	else:
		return false
	return true


## The right stick zooms while it is held (player.zoom_stick_per_second at full tilt). A wheel notch is released
## within its own event flush, so it adds nothing here.
func _zoom_stick(delta: float) -> void:
	var push := Input.get_action_strength("zoom_in") - Input.get_action_strength("zoom_out")
	if push != 0.0:
		_set_zoom(_target_zoom + push * float(GameData.player_cfg("zoom_stick_per_second", 0.5)) * delta)


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
	if not GameData.gm().is_modal_open():
		_zoom_stick(delta)
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
	EventBus.player_health_changed.emit(PlayerRegistry.local_id(), half_hearts, max_half_hearts)
	EventBus.player_stats_changed.emit(PlayerRegistry.local_id(), {"half_hearts": half_hearts, "max_half_hearts": max_half_hearts, "stamina": stamina, "max_stamina": max_stamina})


## The cell in front of the feet (the one a tool or E acts on).
func target_cell() -> Vector2i:
	return area.global_to_cell(global_position) + area.facing_step(facing8)


func target_global() -> Vector2:
	return area.cell_to_global(target_cell())


## Centre of the reach circle: one interaction radius ahead of the feet, toward the facing cell (ground space).
func reach_global() -> Vector2:
	var feet := area.global_to_cell(global_position)
	var step: Vector2 = Iso.to_ground(target_global() - area.cell_to_global(feet)).normalized()
	return global_position + Iso.to_screen(step * _interact_range)


## E-query (D20): the hosts on layer `interactable` whose area overlaps a circle of r = interaction_range ground px at
##   * the facing cell (what a tile tool acts on),
##   * the feet, for counter bands only (DT53: the small end host may be underfoot while the facing cell is behind the hatch),
##   * the reach point (reach_global): a host the body touches is found wherever the feet stand inside their cell.
## The facing and counter circles decide: among their hosts the one nearest to the player wins. A host only the reach circle
## finds (an NPC beside or behind, a touching one when the facing circle sits far ahead) wins only when they find no live host,
## so a citizen in the next cell never takes E from the notice board the player faces. A spent host (is_spent(): an opened
## chest, a dug spot) wins only when nothing live is in reach, so it still answers E with its resting whisper but never hides
## a live host. `accept` (host -> bool) narrows the candidates for a tool: the pail looks for a cow, the axe for a tree.
func nearest_interactable(accept: Callable = Callable()) -> Node:
	if state != S.FREE or area == null:
		return null
	_ensure_interact_query()
	var hosts: Array[Node2D] = []
	_query_hosts(target_global(), hosts, "")
	_query_hosts(global_position, hosts, "counter")
	var facing_count := hosts.size()
	_query_hosts(reach_global(), hosts, "world")
	var best: Node2D = null
	# Rank (spent, reach only, distance to the player); Vector3 compares x, then y, then z.
	var best_rank := Vector3.INF
	for i in hosts.size():
		var host := hosts[i]
		if accept.is_valid() and not bool(accept.call(host)):
			continue
		var spent: bool = host.has_method("is_spent") and bool(host.call("is_spent"))
		var rank := Vector3(1.0 if spent else 0.0, 1.0 if i >= facing_count else 0.0, Iso.ground_dist(host.global_position, global_position))
		if rank < best_rank:
			best = host
			best_rank = rank
	return best


## Appends the hosts found by one query circle at `at`; `only` keeps "counter" hosts or the other ("world") ones, "" both.
func _query_hosts(at: Vector2, hosts: Array[Node2D], only: String) -> void:
	_interact_query.transform = Transform2D(Vector2.RIGHT, Vector2(0.0, Iso.squash()), at)
	for hit in get_world_2d().direct_space_state.intersect_shape(_interact_query, 8):
		var collider: Object = hit["collider"]
		var host: Node = (collider as Node).get_parent() if collider is Area2D else null
		if host == null or host == self or not host.has_method("interact") or not host is Node2D or hosts.has(host):
			continue
		var counter := bool(host.get_meta("counter_foot_host", false))
		if (only == "counter" and not counter) or (only == "world" and counter):
			continue
		hosts.append(host as Node2D)


## The one gate of the E prompt and of E itself, so the prompt never offers what E refuses (review GAP3-07).
func can_interact_now() -> bool:
	return state == S.FREE


func try_interact() -> bool:
	if not can_interact_now():
		return false
	var it: Node = nearest_interactable()
	if it == null:
		return false
	it.call("interact", self)
	return true


func _update_prompt(delta: float = 0.0) -> void:
	_prompt_stale += delta
	# A swing, a tool use, a dodge or a hit lasts a moment: keep the last prompt through it instead of blinking
	# the pill off and on with every action. Only a lasting refusal (flight, a talk, fainting) hides it.
	if state in BRIEF_STATES:
		return
	# The prompt only changes when the player moves, turns or can / cannot interact any more (take-off, the end of
	# a talk); skip the physics query otherwise, but still refresh at PROMPT_REFRESH_S so a newly-available
	# interactable is not missed.
	var ready := can_interact_now()
	if global_position.is_equal_approx(_prompt_last_pos) and facing8 == _prompt_last_facing and ready == _prompt_last_ready \
			and _prompt_stale < PROMPT_REFRESH_S:
		return
	_prompt_stale = 0.0
	_prompt_last_pos = global_position
	_prompt_last_facing = facing8
	_prompt_last_ready = ready
	var it: Node = nearest_interactable() if ready else null
	var text := interaction_text(it)
	if text != _prompt:
		_prompt = text
		EventBus.interaction_prompt_changed.emit(PlayerRegistry.local_id(), text)

func interaction_text(it: Node) -> String:
	return str(it.call("get_interaction_prompt")) if it != null and it.has_method("get_interaction_prompt") else ""
