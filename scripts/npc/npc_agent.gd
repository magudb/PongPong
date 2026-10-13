extends CharacterBody3D
## NPC with NavigationAgent3D pathfinding, wandering, daily schedules.

@export var npc_id: StringName = &""
@export var display_name_key: String = ""
@export var dialogue_id: StringName = &""
@export var shop_id: StringName = &""
@export var offers_quests: Array[StringName] = []

@export_group("Movement")
@export var walk_speed: float = 2.5
@export var run_speed: float = 5.0
@export var acceleration: float = 6.0
@export var wander_radius: float = 12.0
@export var wander_interval_min: float = 4.0
@export var wander_interval_max: float = 12.0
@export var idle_chance: float = 0.35

@export_group("Schedule")
@export var wake_hour: int = 7
@export var sleep_hour: int = 21
@export var home_position: Vector3 = Vector3.ZERO
@export var work_position: Vector3 = Vector3.ZERO
@export var market_position: Vector3 = Vector3.ZERO

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var visual_root: Node3D = $VisualRoot
@onready var name_label: Label3D = $NameLabel
@onready var interact_area: Area3D = $InteractArea

enum NPCState { IDLE, WALKING, TALKING, WORKING, SLEEPING, FOLLOWING }

var current_state: int = NPCState.IDLE
var is_talking: bool = false
var target_position: Vector3 = Vector3.ZERO
var home_base: Vector3 = Vector3.ZERO

var _wander_timer: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _velocity_y: float = 0.0
var _schedule_target: Vector3 = Vector3.ZERO
var _player_nearby: bool = false
var _current_animation: String = "idle"


func _ready() -> void:
	add_to_group("npc")
	add_to_group("npc_%s" % str(npc_id))
	collision_layer = 4  # npc
	collision_mask = 1   # world

	if home_position == Vector3.ZERO:
		home_position = global_position
	home_base = home_position

	if name_label and display_name_key != "":
		name_label.text = tr(display_name_key)

	_setup_navigation()
	_setup_interaction()
	_apply_npc_visual()
	_wander_timer = randf_range(1.0, wander_interval_max)

	EventBus.day_started.connect(_on_day_started)
	EventBus.time_of_day_changed.connect(_on_time_changed)


func _physics_process(delta: float) -> void:
	if GameManager.current_phase != GameManager.GamePhase.PLAYING:
		return

	_apply_gravity(delta)
	_update_schedule()
	_update_movement(delta)
	_update_animation(delta)


# --- Navigation ---

func _setup_navigation() -> void:
	if nav_agent == null:
		nav_agent = NavigationAgent3D.new()
		add_child(nav_agent)

	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 1.0
	nav_agent.path_max_distance = 2.0
	nav_agent.avoidance_enabled = true
	nav_agent.radius = 0.4
	nav_agent.height = 1.6
	nav_agent.velocity_computed.connect(_on_velocity_computed)


func move_to(target: Vector3, running: bool = false) -> void:
	target_position = target
	nav_agent.target_position = target
	current_state = NPCState.WALKING
	_current_animation = "run" if running else "walk"


func move_to_random_point() -> void:
	var angle := randf() * TAU
	var dist := randf_range(2.0, wander_radius)
	var offset := Vector3(cos(angle) * dist, 0, sin(angle) * dist)
	var target := home_base + offset

	# Snap to navigation mesh if available
	if NavigationServer3D.map_get_iteration_id(nav_agent.get_navigation_map()) != 0:
		target = NavigationServer3D.map_get_closest_point(nav_agent.get_navigation_map(), target)

	move_to(target)


func stop_moving() -> void:
	current_state = NPCState.IDLE
	_current_animation = "idle"
	velocity.x = 0
	velocity.z = 0


func _update_movement(delta: float) -> void:
	if current_state == NPCState.TALKING or current_state == NPCState.SLEEPING:
		velocity.x = move_toward(velocity.x, 0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0, acceleration * delta)
		move_and_slide()
		return

	if current_state == NPCState.WALKING:
		if nav_agent.is_navigation_finished():
			current_state = NPCState.IDLE
			_current_animation = "idle"
			_wander_timer = randf_range(wander_interval_min, wander_interval_max)
			return

		var next_pos := nav_agent.get_next_path_position()
		var direction := (next_pos - global_position).normalized()
		var speed := run_speed if _current_animation == "run" else walk_speed

		var target_vel := Vector3(direction.x * speed, 0, direction.z * speed)
		if nav_agent.avoidance_enabled:
			nav_agent.velocity = target_vel
		else:
			_on_velocity_computed(target_vel)

		# Face movement direction
		if target_vel.length() > 0.1:
			var target_yaw := atan2(-target_vel.x, -target_vel.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, 8.0 * delta)
	else:
		# IDLE — consider wandering
		_wander_timer -= delta
		if _wander_timer <= 0 and not is_talking:
			if randf() > idle_chance:
				move_to_random_point()
			_wander_timer = randf_range(wander_interval_min, wander_interval_max)


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	velocity.x = safe_velocity.x
	velocity.z = safe_velocity.z
	move_and_slide()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		_velocity_y = -0.1
	else:
		_velocity_y -= _gravity * delta
	velocity.y = _velocity_y


# --- Schedule ---

func _update_schedule() -> void:
	var hour := GameManager.hour
	if is_talking:
		return

	match hour:
		var h when h >= sleep_hour or h < wake_hour:
			if current_state != NPCState.SLEEPING:
				_go_home_to_sleep()
		var h when h == wake_hour:
			if current_state == NPCState.SLEEPING:
				current_state = NPCState.IDLE
				_current_animation = "idle"
		_:
			pass

	# Move toward work during work hours
	if hour >= 9 and hour < 17 and work_position != Vector3.ZERO:
		if current_state == NPCState.IDLE and global_position.distance_to(work_position) > 3.0:
			if randf() < 0.02:  # occasionally head to work
				move_to(work_position)

	# Visit market midday
	if hour == 12 and market_position != Vector3.ZERO:
		if current_state == NPCState.IDLE and randf() < 0.05:
			move_to(market_position)


func _go_home_to_sleep() -> void:
	if global_position.distance_to(home_base) > 2.0:
		move_to(home_base)
	else:
		current_state = NPCState.SLEEPING
		_current_animation = "sleep"
		stop_moving()


func _on_day_started(_day: int, _season: StringName) -> void:
	current_state = NPCState.IDLE
	_current_animation = "idle"
	_wander_timer = randf_range(1.0, wander_interval_max)


func _on_time_changed(_hour: int, _minute: int) -> void:
	pass  # handled in _update_schedule


# --- Interaction ---

func _setup_interaction() -> void:
	if interact_area == null:
		interact_area = Area3D.new()
		add_child(interact_area)

	interact_area.collision_layer = 0
	interact_area.collision_mask = 2  # player
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.5
	col.shape = shape
	interact_area.add_child(col)

	interact_area.body_entered.connect(_on_player_near)
	interact_area.body_exited.connect(_on_player_far)


func _on_player_near(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		_face_player(body)


func _on_player_far(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_nearby = false


func _face_player(player: Node3D) -> void:
	var dir := (player.global_position - global_position).normalized()
	var target_yaw := atan2(-dir.x, -dir.z)
	var tween := create_tween()
	tween.tween_property(self, "rotation:y", target_yaw, 0.3)


func get_interaction_prompt() -> String:
	if is_talking:
		return ""
	return tr("UI_TALK") if display_name_key != "" else str(npc_id)


func interact(player: Node3D) -> void:
	if is_talking:
		return
	is_talking = true
	current_state = NPCState.TALKING
	_current_animation = "talk"
	stop_moving()
	_face_player(player)

	var context := GameManager.world_flags.duplicate()
	context["intro_done"] = context.get("intro_done", false)
	context["maja_roof_fixed"] = context.get("maja_roof_fixed", false)
	context["lost_cat_active"] = context.get("lost_cat_active", false)

	var dialogue: Dictionary = LuaRuntime.get_dialogue(str(dialogue_id), context)
	if dialogue.is_empty():
		is_talking = false
		current_state = NPCState.IDLE
		return

	EventBus.dialogue_started.emit(npc_id, dialogue_id)
	_show_dialogue(dialogue)


func _show_dialogue(dialogue: Dictionary) -> void:
	var speaker_name: String = tr(dialogue.get("speaker_name_key", str(npc_id)))

	for line in dialogue.get("lines", []):
		var text_key: String = line.get("text_key", "")
		var voice_key: String = line.get("voice_key", "")
		var text: String = tr(text_key) if text_key != "" else ""

		EventBus.dialogue_line_shown.emit(speaker_name, text, voice_key)
		if voice_key != "":
			LocalizationManager.play_voice(str(npc_id), voice_key)

		await get_tree().create_timer(2.5).timeout

	var choices: Array = dialogue.get("choices", [])
	if not choices.is_empty():
		EventBus.ui_panel_toggled.emit(&"dialogue_choices", true)

	EventBus.dialogue_ended.emit()
	is_talking = false
	current_state = NPCState.IDLE
	_current_animation = "idle"


func handle_choice(action: String, data: Dictionary = {}) -> void:
	match action:
		"quest_accept":
			QuestManager.accept_quest(StringName(data.get("quest_id", "")))
		"quest_offer":
			QuestManager.offer_quest(StringName(data.get("quest_id", "")))
		"open_shop":
			ShopSystem.open_shop(StringName(data.get("shop_id", "")))
		"open_journal":
			EventBus.ui_panel_toggled.emit(&"journal", true)
		"show_info":
			EventBus.notification_posted.emit(tr("UI_INFO"), tr(data.get("info_key", "")), "info")
		"math_answer":
			_handle_math_answer(data)
		"close":
			pass


func _handle_math_answer(data: Dictionary) -> void:
	if int(data.get("answer", -9999)) == int(data.get("correct", -1)):
		var flag := StringName(data.get("result_flag", ""))
		if flag != &"":
			GameManager.set_flag(flag, true)
		var quest_id := StringName(data.get("quest_id", ""))
		var objective_id := StringName(data.get("objective_id", ""))
		if quest_id != &"" and objective_id != &"":
			QuestManager.update_objective(quest_id, objective_id)
		EventBus.notification_posted.emit(tr("MATH_CORRECT_TITLE"), tr("MATH_CORRECT_MSG"), "success")
	else:
		EventBus.notification_posted.emit(tr("MATH_WRONG_TITLE"), tr("MATH_WRONG_MSG"), "info")


# --- Visual ---

func _apply_npc_visual() -> void:
	for child in visual_root.get_children():
		child.queue_free()

	var scene_path := "res://scenes/npc/skins/%s.tscn" % npc_id
	if ResourceLoader.exists(scene_path):
		var scene := load(scene_path) as PackedScene
		if scene:
			visual_root.add_child(scene.instantiate())
			return

	# Placeholder capsule
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = 1.4
	capsule.radius = 0.35
	mesh.mesh = capsule
	mesh.position.y = 0.7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _npc_color()
	mesh.material_override = mat
	visual_root.add_child(mesh)


func _npc_color() -> Color:
	match npc_id:
		&"mayor_lyra": return Color(0.8, 0.7, 0.9)
		&"baker_maja": return Color(0.9, 0.75, 0.55)
		&"fairy_lily": return Color(0.95, 0.8, 0.85)
		&"smith_thorin": return Color(0.6, 0.5, 0.4)
		&"merchant_pip": return Color(0.5, 0.8, 0.7)
		&"guard_oak": return Color(0.4, 0.5, 0.3)
	return Color(0.7, 0.7, 0.7)


func _update_animation(_delta: float) -> void:
	# Hook for AnimationTree when models are ready
	pass
