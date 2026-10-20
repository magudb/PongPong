class_name PlayerCombat2D
extends Node
signal weapon_drawn(item_id: StringName)
## Combat timing and hit detection are isolated from movement, farming and saved state.
const S := PlayerBody2D.S
const RULES := "res://scripts/dungeon_run/dungeon_run.gd"
const FX := "res://scripts/combat/weapon_fx.gd"
## The slash is drawn, and its hits are tested, this far above the feet: a cursor aim measures from the same point.
const SLASH_LIFT := -6.0 * Iso.S
var player: PlayerBody2D
var cooldowns := {"slash": 0.0, "dodge": 0.0, "light": 0.0, "drink": 0.0}
var durations := {"slash": 0.4, "dodge": 0.9, "light": 7.0, "drink": 1.0}
var hit_stop: int = 0
var stopped_this_tick: bool = false
var extra_altitude: float = 0.0
var attack_held: bool = false
var _iframes: float = 0.0
var _remaining: float = 0.0
var _swing_duration: float = 0.28
var _dodge_direction: Vector2
var _knockback := Vector2.ZERO
var _swing_direction := Vector2.RIGHT
var _swing_radius: float = 197
var _swing_half: float = 1.0
var _hit: Dictionary = {}
var _buffer: StringName = &""
var _buffer_time: float = 0.0
## The weapon a buffered or held slash swings ("" = the equipped one; a hotbar weapon in an iso area names itself).
var _buffer_item: StringName = &""
## The clicked ground point a buffered slash aims at (null: the live aim of aim_ground when it fires).
var _buffer_aim: Variant = null
var _last_spark: bool = false
var _burst: PointLight2D
var _query := PhysicsShapeQueryParameters2D.new()
var _shape := ConvexPolygonShape2D.new()
var _weapon: Dictionary = {}
var _shake: float = 0.0
var _shake_strength: float = 0.0

func setup(body: PlayerBody2D) -> void:
	player = body
	_query.shape = _shape
	_query.collision_mask = Iso.LAYER_ENEMY
	_query.collide_with_areas = true
	_query.collide_with_bodies = true
	# No hurtbox Area2D: attacks hit only through the ground-plane tests at the
	# feet (Enemy2D._during_attack, hazards), which match the drawn telegraph.
	# An upper-body capsule overlapping the ground polygon hit players standing
	# up to ~120 screen px south of the band.
	_burst = PointLight2D.new()
	_burst.name = "BurstLight"
	_burst.texture = Glow.light_texture()
	_burst.position.y = -40.0 * Iso.S
	_burst.energy = 0.0
	player.add_child(_burst)

func _assist(key: String, fallback: Variant = 0.0) -> Variant:
	return Svc.static_call(RULES, &"assist", [key], fallback)

func _feel(key: String, fallback: Variant) -> Variant:
	return GameData.cfg("dungeon_run.feel." + key, fallback)

## `aim` is the clicked ground point (global) of a mouse press: the slash goes there even when the buffer fires it later.
func request(ability: StringName, item: StringName = &"", aim: Variant = null) -> void:
	_buffer = ability
	_buffer_time = float(_feel("input_buffer", 0.15))
	if ability == &"slash":
		_buffer_item = item
		_buffer_aim = aim
		attack_held = true
	_attempt_buffer()

func _attempt_buffer() -> void:
	if _buffer == &"":
		return
	var ok := swing(_buffer_item, _buffer_aim) if _buffer == &"slash" else dodge()
	if ok:
		_buffer = &""
		_buffer_time = 0.0
		_buffer_aim = null

func tick(delta: float) -> void:
	stopped_this_tick = hit_stop > 0
	if stopped_this_tick:
		hit_stop -= 1
		return
	for key in cooldowns:
		cooldowns[key] = maxf(0.0, float(cooldowns[key]) - delta)
	_iframes = maxf(0.0, _iframes - delta)
	player.set("invulnerable", _iframes > 0.0)
	if _buffer_time > 0.0:
		_attempt_buffer()
		_buffer_time -= delta
		if _buffer_time <= 0.0:
			_buffer = &""
	if attack_held and bool(_assist("assist_auto_swing", false)) and player.world_input_allowed():
		swing(_buffer_item)
	var flash_reduced := bool(_assist("assist_reduce_flash", false))
	player.visual.modulate.a = 0.6 if _iframes > 0 and player.state != S.DODGE and not flash_reduced and int(_iframes * 14.0) % 2 == 0 else 1.0
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		player.camera.position = Vector2(sin(_shake * 190.0), cos(_shake * 230.0)) * _shake_strength if _shake > 0.0 else Vector2.ZERO
	if player.state in [S.SWING, S.DODGE, S.HURT]:
		_remaining -= delta
		match player.state:
			S.SWING:
				var phase := 1.0 - _remaining / _swing_duration
				if phase >= float(GameData.combat("swing_active_start", 0.22)) and phase <= float(GameData.combat("swing_active_end", 0.72)):
					_apply_hits()
			S.DODGE:
				var phase := 1.0 - _remaining / float(GameData.combat("dodge_time", 0.3))
				player.visual.set_spin(TAU * phase * (1 if _dodge_direction.x >= 0 else -1))
				extra_altitude = sin(phase * PI) * 14.0 * Iso.S
		if _remaining <= 0.0:
			player.state = S.FREE
			player.visual.set_spin(0.0)
			extra_altitude = 0.0

func movement(default_velocity: Vector2, delta: float) -> Vector2:
	if player.state == S.DODGE:
		return _dodge_direction * (float(GameData.combat("dodge_distance", 317)) / float(GameData.combat("dodge_time", 0.3)))
	if player.state == S.HURT:
		_knockback = _knockback.move_toward(Vector2.ZERO, 900.0 * Iso.S * delta)
		return _knockback
	return default_velocity

func active_weapon_id() -> StringName:
	return StringName(str(_weapon.get("id", "")))

func _read_weapon(item: StringName = &"") -> Dictionary:
	if item == &"":
		item = GameData.eco().equipped_item(&"weapon")
	if item == &"" or not GameData.eco().has_item(item) or str(GameData.item_def(item).get("category", "")) != "weapon":
		return {}
	var info := GameData.item_def(item).duplicate(true)
	var late: Variant = Svc.static_call("res://scripts/combat/weapon_info.gd", &"of", [item], {})
	if late is Dictionary:
		info.merge(late, true)
	var family := str(info.get("family", "sword"))
	var params := GameData.dict_of(GameData.cfg("dungeon_run.weapon_families." + family, {}))
	params.merge(GameData.dict_of(info.get("swing",{})),true)
	var family_keys := {"swing_time":"time","swing_radius":"radius","swing_half_angle_deg":"half_angle","swing_cooldown":"cooldown","knockback":"knockback"}
	for key in family_keys:
		info[key] = params.get(family_keys[key], GameData.combat(key, {"swing_time": 0.28, "swing_radius": 197, "swing_half_angle_deg": 62, "swing_cooldown": 0.12, "knockback": 433}[key]))
	info["id"] = item
	return info

## The ground direction of a swing: toward `at` (a clicked ground point), else toward the cursor while the mouse is the
## device in use, else the precise walking direction. A point is measured from the slash's own origin (SLASH_LIFT), so the
## drawn arc is centred on the clicked spot.
func aim_ground(at: Variant = null) -> Vector2:
	if at == null and bool(player.get("mouse_aim")) and player.has_method("cursor_global"):
		at = player.call("cursor_global")
	if at is Vector2:
		var point: Vector2 = at
		var direction := Iso.to_ground(point - player.global_position - Vector2(0, SLASH_LIFT))
		if direction.length() > 8.0 * Iso.S:
			return direction.normalized()
	var precise: Variant = player.get("combat_aim")
	if precise is Vector2 and precise.length_squared() > .01:
		return precise.normalized()
	return Iso.to_ground(player.facing_vec).normalized()

func swing(item: StringName = &"", aim: Variant = null) -> bool:
	if not player.world_input_allowed() or player.state != S.FREE or float(cooldowns.slash) > 0.0 or player.is_flying:
		return false
	_weapon = _read_weapon(item)
	if _weapon.is_empty():
		return false
	_swing_direction = aim_ground(aim)
	# Eight keyboard directions need half a 45-degree sector of assistance;
	# otherwise a 22-degree spear leaves blind angles between directions.
	var nudge := deg_to_rad(15.0) if aim is Vector2 or bool(player.get("mouse_aim")) else PI/8
	var closest := INF
	var target_angle := _swing_direction.angle()
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D:
			var offset := Iso.to_ground(enemy.global_position - player.global_position)
			if offset.length() < float(_weapon.swing_radius) and offset.length() < closest and absf(angle_difference(target_angle, offset.angle())) <= nudge:
				closest = offset.length()
				_swing_direction = offset.normalized()
	player.event_face(Iso.to_screen(_swing_direction))
	player.state = S.SWING
	_swing_duration = maxf(0.05, float(_weapon.swing_time))
	_remaining = _swing_duration
	durations.slash = _swing_duration + float(_weapon.swing_cooldown)
	cooldowns.slash = durations.slash
	_hit.clear()
	var radius := float(_weapon.swing_radius)
	var half := deg_to_rad(clampf(float(_weapon.swing_half_angle_deg) * (1.0 + float(Svc.static_call(RULES,&"arc_pct",[],0))/100.0), 1.0, 175.0))
	_swing_radius = radius
	_swing_half = half
	# Broad-phase ellipse followed by the exact arc. This also supports the club's
	# 190-degree sector, which cannot be one convex physics polygon.
	var points := PackedVector2Array()
	for i in 32: points.append(Iso.to_screen(Vector2.from_angle(TAU*i/32.0)*radius))
	_shape.points = points
	var slash := Slash2D.new()
	slash.setup(_swing_direction, radius, half, _swing_duration)
	slash.position.y = SLASH_LIFT
	slash.tint = Rarity.ui(_weapon.get("rarity", "normal")).ring
	player.add_child(slash)
	player.visual.play_action(&"interact", player.visual.clip_duration(&"interact", 1.0) / _swing_duration)
	_effect(&"on_swing", [player, _weapon])
	weapon_drawn.emit(active_weapon_id())
	player.emit_signal("swung", Iso.to_screen(_swing_direction))
	return true

func _apply_hits() -> void:
	_query.transform = Transform2D(0.0, player.global_position + Vector2(0, SLASH_LIFT))
	for result in player.get_world_2d().direct_space_state.intersect_shape(_query, 32):
		var target: Node = result.collider
		if target is Area2D:
			target = target.get_parent()
		if target == null or not target.has_method("take_hit") or _hit.has(target.get_instance_id()):
			continue
		if target is Node2D:
			var offset := Iso.to_ground(target.global_position-player.global_position)
			if offset.length() > _swing_radius or absf(angle_difference(_swing_direction.angle(),offset.angle())) > _swing_half:
				continue
		_hit[target.get_instance_id()] = true
		target.call("take_hit", int(_weapon.get("damage", 5)), player.global_position, player)
		hit_stop = int(_feel("hit_stop_frames", 3))
		if is_instance_valid(target) and target.has_method("hit_stop"):
			target.call("hit_stop", hit_stop)
		_effect(&"on_hit", [player, target, _weapon])
		_shake_camera(2.0)

func dodge() -> bool:
	if not player.world_input_allowed() or player.is_flying or float(cooldowns.dodge) > 0:
		return false
	if player.state == S.SWING:
		if 1.0 - _remaining / _swing_duration < 0.4:
			return false
	elif player.state != S.FREE:
		return false
	# The stick / keys are already a GROUND vector (walking uses them as one), so the
	# dodge runs parallel to the walk; only the screen facing row needs converting.
	var direction := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if direction == Vector2.ZERO:
		var precise: Variant = player.get("combat_aim")
		direction = precise if precise is Vector2 and precise.length_squared() > .01 else Iso.to_ground(player.facing_vec)
	_dodge_direction = direction.normalized()
	player.state = S.DODGE
	_remaining = float(GameData.combat("dodge_time", 0.3))
	durations.dodge = float(GameData.combat("dodge_cooldown", 0.9))
	cooldowns.dodge = durations.dodge
	_iframes = float(GameData.combat("dodge_iframes", 0.42)) + float(Svc.static_call(RULES,&"dodge_bonus",[],0.0))
	player.set("invulnerable", true)
	player.visual.cancel_action()
	var dust := Dust2D.new()
	player.area.ground_fx.add_child(dust)
	dust.global_position = player.global_position
	_effect(&"on_dodge", [player, _weapon])
	player.emit_signal("dodged")
	return true

func fairy_light(free: bool = false) -> bool:
	if not free and (not player.world_input_allowed() or float(cooldowns.light) > 0 or player.state == S.DODGE):
		return false
	var gem: Dictionary = player._gem_effects()
	var params := {"cooldown":float(GameData.combat("light_cooldown",7))-float(gem.get("light_cd_minus_s",0)),"radius":float(GameData.combat("light_radius",550)),"stun":float(GameData.combat("light_stun",1.6)),"weapon":_read_weapon()}
	params = Svc.static_call(FX,&"on_light",[player,params],params)
	durations.light = maxf(float(GameData.cfg("dungeon_loot.limits.light_cd_min_s",3)),float(params.cooldown))
	cooldowns.light = durations.light
	var radius := float(params.radius)
	_burst.energy = 0.35 if bool(_assist("assist_reduce_flash", false)) else 1.5
	_burst.texture_scale = 1.0 * Iso.S
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_burst, "texture_scale", radius / 128.0 * 1.25, 0.55)
	tween.tween_property(_burst, "energy", 0.0, 0.7).set_delay(0.12)
	var ring := LightRing2D.new()
	ring.setup(radius)
	player.area.ground_fx.add_child(ring)
	ring.global_position = player.global_position
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node2D and enemy.has_method("stun") and Iso.ground_dist(player.global_position, enemy.global_position) <= radius:
			if enemy.has_method("reveal"): enemy.call("reveal")
			enemy.call("stun",float(params.stun))
	player.emit_signal("light_burst", radius)
	return true

func drink() -> bool:
	if not player.world_input_allowed() or float(cooldowns.drink) > 0.0:
		return false
	for item in [&"health_tonic", &"svampe_eliksir"]:
		if GameData.eco().use_item(item):
			cooldowns.drink = durations.drink
			return true
	return false

func cd_ratio(ability: String) -> float:
	return clampf(float(cooldowns.get(ability, 0.0)) / maxf(0.001, float(durations.get(ability, 1.0))), 0.0, 1.0)

func take_damage(amount: int, from: Vector2 = Vector2.ZERO) -> bool:
	if amount <= 0 or _iframes > 0.0 or player.state == S.FAINTED:
		return false
	player.half_hearts = maxi(0, player.half_hearts - amount)
	_iframes = float(GameData.combat("hurt_iframes", 0.9))
	player.set("invulnerable", true)
	cancel_action()
	if player.half_hearts == 0 and not _last_spark and not bool(DungeonRulesData.flag("dungeon_last_spark_used",false)) and bool(_assist("assist_last_spark", false)):
		_last_spark = true
		var gm := Svc.node("GameManager")
		if gm != null: gm.set_flag(&"dungeon_last_spark_used",true)
		player.half_hearts = 1
		_iframes = 1.2
		fairy_light(true)
		EventBus.whisper_requested.emit("DEXP_LAST_SPARK")
	player._emit_stats_on_bus()
	player.emit_signal("damaged", amount)
	if not bool(_assist("assist_reduce_flash", false)):
		player.visual.flash(Color("e58fa6"), 0.3)
	_shake_camera(4.0)
	if player.half_hearts == 0:
		player.state = S.FAINTED
		player.visual.play_loop(&"sleep")
		player.emit_signal("fainted")
		EventBus.player_defeated.emit()
	else:
		player.state = S.HURT
		_remaining = 0.28
		_knockback = Iso.to_ground(player.global_position - from).normalized() * float(GameData.combat("knockback", 433))
		player.visual.play_action(&"hit")
	return true

func _shake_camera(strength: float) -> void:
	if not bool(_assist("assist_reduce_flash", false)):
		_shake = 0.08
		_shake_strength = strength

func _effect(method: StringName, args: Array) -> void:
	Svc.static_call(FX, method, args)

## A press buffered before a pause or modal is dropped: it never fires on resume.
func clear_buffer() -> void:
	_buffer = &""
	_buffer_time = 0.0
	_buffer_item = &""
	_buffer_aim = null

func cancel_action() -> void:
	_hit.clear()
	clear_buffer()
	attack_held = false
	hit_stop = 0
	extra_altitude = 0.0
	if player != null:
		player.visual.set_spin(0.0)
		player.camera.position = Vector2.ZERO

func reset() -> void:
	cancel_action()
	for key in cooldowns:
		cooldowns[key] = 0.0
	_iframes = 1.2
	_last_spark = false

func begin_run() -> void:
	_last_spark = false
