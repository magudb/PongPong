class_name DungeonFightBot
extends RefCounted
## Test-only controller: normal movement, swing and dodge APIs against real physics.
const MOVES := ["move_left","move_right","move_forward","move_back"]
static func release() -> void:
	for action in MOVES: Input.action_release(action)
static func steer(direction: Vector2) -> void:
	release()
	var screen := Iso.to_screen(direction).normalized()
	if screen.x < -.15: Input.action_press("move_left",absf(screen.x))
	if screen.x > .15: Input.action_press("move_right",absf(screen.x))
	if screen.y < -.15: Input.action_press("move_forward",absf(screen.y))
	if screen.y > .15: Input.action_press("move_back",absf(screen.y))
static func duel(t, player: Player2D, enemy: Enemy2D, seed_value: int, limit: float = 8) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var began: float = t.game_seconds()
	var starting_hearts := player.half_hearts
	var dodge_at := INF
	var previous := -1
	var in_range_at := INF
	var swings := [0]
	var record := func(_direction): swings[0] += 1
	player.swung.connect(record)
	player.mouse_aim = false
	enemy.player = player
	enemy.set_awake(true)
	enemy.set_physics_process(true)
	while is_instance_valid(enemy) and enemy.state != Enemy2D.S.DEAD and player.half_hearts > 0 and t.game_seconds()-began < limit:
		var now: float = t.game_seconds()
		var direction := Iso.to_ground(enemy.global_position-player.global_position)
		var distance := direction.length()
		direction = direction.normalized()
		var radius := float(player.combat._read_weapon().get("swing_radius",197))
		steer(direction if distance > radius*.75 else Vector2.ZERO)
		player.event_face(Iso.to_screen(direction))
		if enemy.state == Enemy2D.S.WINDUP and previous != Enemy2D.S.WINDUP: dodge_at = now+clampf(rng.randfn(.4,.13),.12,.65)
		if now >= dodge_at:
			steer(Vector2(-enemy.aim.y,enemy.aim.x))
			player.combat.dodge()
			dodge_at = INF
		if distance <= radius*.9:
			if in_range_at == INF: in_range_at = now
			if now-in_range_at >= .22: player.combat.swing()
		else: in_range_at = INF
		previous = enemy.state
		await t.physics(1)
	release()
	player.swung.disconnect(record)
	return {"won":is_instance_valid(enemy) and enemy.state == Enemy2D.S.DEAD,"seconds":t.game_seconds()-began,"lost":maxi(0,starting_hearts-player.half_hearts),"seed":seed_value,"swings":swings[0]}
