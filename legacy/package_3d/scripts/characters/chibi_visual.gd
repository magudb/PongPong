extends Node3D
## Reusable visual-only adapter. The owning CharacterBody3D moves; this never moves it.
## GLB skinning deforms limbs, wings, ears and tails. Clips are all in-place.

@export var base_color_texture: Texture2D
@export var character_id: StringName = &"rabbit"
@export var nominal_walk_speed: float = 2.0
@export var nominal_run_speed: float = 4.0
@export var transition_seconds: float = 0.14

var animation_player: AnimationPlayer
var current_clip: StringName = &""
var _clips: Dictionary = {}
var _priority_left: float = 0.0
var _was_grounded: bool = true
var _was_flying: bool = false
var _flight_session: bool = false
var _manual: bool = false

const LOOPING := [&"idle", &"walk", &"run", &"fall", &"talk", &"sleep", &"hover", &"fly", &"turn_left", &"turn_right"]

func _ready() -> void:
	for mesh in find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).extra_cull_margin = 0.5
	if base_color_texture != null:
		for child in find_children("*", "MeshInstance3D", true, false):
			var instance := child as MeshInstance3D
			if instance.mesh == null or instance.mesh.get_surface_count() == 0:
				continue
			var source: Material = instance.get_active_material(0)
			if source is StandardMaterial3D:
				var copy := source.duplicate() as StandardMaterial3D
				copy.albedo_texture = base_color_texture
				instance.material_override = copy
	var players: Array[Node] = find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		push_error("No AnimationPlayer in chibi asset: %s" % character_id)
		return
	animation_player = players[0] as AnimationPlayer
	for full_name in animation_player.get_animation_list():
		if full_name == &"RESET":
			continue
		var short_name := StringName(String(full_name).get_file().split("|")[-1].trim_suffix("-loop"))
		_clips[short_name] = full_name
		var animation: Animation = animation_player.get_animation(full_name)
		animation.loop_mode = Animation.LOOP_LINEAR if short_name in LOOPING else Animation.LOOP_NONE
	animation_player.animation_finished.connect(_on_finished)
	_play(&"idle")

func has_clip(clip: StringName) -> bool:
	return _clips.has(clip)

func play_clip(clip: StringName) -> void:
	## For an NPC, preview or cutscene; locomotion takes over on the next update_motion().
	_manual = true
	_priority_left = 0.0
	_play(clip)

func play_action(clip: StringName) -> void:
	if animation_player == null or not has_clip(clip):
		return
	_manual = false
	var animation: Animation = animation_player.get_animation(_clips[clip])
	_priority_left = animation.length
	_play(clip)

func update_motion(speed: float, vertical_speed: float, grounded: bool, flying: bool, running: bool, delta: float) -> void:
	if animation_player == null:
		return
	_manual = false
	_priority_left = maxf(_priority_left - delta, 0.0)
	if flying and not _was_flying:
		_flight_session = true
		play_action(&"takeoff")
	if grounded and not _was_grounded and not flying:
		play_action(&"flight_land" if _flight_session else &"land")
		_flight_session = false
	_was_grounded = grounded
	_was_flying = flying
	if _priority_left > 0.0:
		return
	var next: StringName = &"idle"
	if flying:
		next = &"fly" if speed > 0.12 else &"hover"
	elif not grounded:
		next = &"jump" if vertical_speed > 0.15 else &"fall"
	elif speed > 0.12:
		next = &"run" if running else &"walk"
	var rate := 1.0
	if next in [&"walk", &"run"]:
		var size_factor: float = maxf(global_transform.basis.get_scale().x, 0.10)
		var nominal: float = nominal_run_speed if next == &"run" else nominal_walk_speed
		rate = clampf(speed / (nominal * size_factor), 0.35, 2.75)
	_play(next, rate)

func _play(clip: StringName, rate: float = 1.0) -> void:
	if animation_player == null:
		return
	if not has_clip(clip):
		clip = &"idle"
	if not has_clip(clip):
		return
	animation_player.speed_scale = rate
	if clip == current_clip:
		return
	# Preserve gait phase when switching between walking and running.
	var phase := 0.0
	var keep_phase := current_clip in [&"walk", &"run"] and clip in [&"walk", &"run"]
	if keep_phase and animation_player.current_animation_length > 0.0:
		phase = fposmod(animation_player.current_animation_position / animation_player.current_animation_length, 1.0)
	current_clip = clip
	animation_player.play(_clips[clip], transition_seconds)
	if keep_phase:
		var animation: Animation = animation_player.get_animation(_clips[clip])
		animation_player.seek(phase * animation.length, true)

func _on_finished(_animation: StringName) -> void:
	_priority_left = 0.0
	if _manual:
		_play(&"idle")
