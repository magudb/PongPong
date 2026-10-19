extends RefCounted
## Regressions from the 2026-10-19 review of player interaction, combat input and world hosts:
## telegraph-only damage (DUN-01).
const SECTION := "interaction_review"
const TIMEOUT_S := 180.0


func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0)
	var world: WorldRoot2D = t.world()
	await world.travel(&"_fixture_ortho", &"from_iso")
	for node in t.tree.get_nodes_in_group("enemy"):
		node.queue_free()
	await t.frames(2)
	DungeonRun.apply_preset("none")
	await _telegraph_only(t)
	gm.clear_config_overrides()


## DUN-01: a lunge hits only inside its drawn band. Walking into the region from the south during the lunge used to hit through an
## upper-body hurtbox capsule while the feet were still ~100 ground px outside the band.
func _telegraph_only(t) -> void:
	var world: WorldRoot2D = t.world()
	var area := world.area
	var player: Player2D = world.player
	var origin := player.global_position + Vector2(300, 0)
	var enemy: Enemy2D = Enemy2D.create_marker({"kind": "ugleoje"}, origin, area.global_to_cell(origin), area)
	area.objects.add_child(enemy)
	enemy.set_awake(true)
	enemy.set_physics_process(false)
	enemy.begin_windup({"shape": "line", "width": 80, "length": 300, "direction": Vector2.LEFT}, .5, "dash")
	enemy.remaining = 0
	enemy._windup(Vector2.LEFT)
	player.combat._iframes = 0
	player.state = PlayerBody2D.S.FREE
	var hearts: int = player.half_hearts
	var lost := [0]
	var damage := func(amount: int) -> void: lost[0] += amount
	player.damaged.connect(damage)
	# feet walk north from 200 to 60 screen px south of the band's centre line (band half width 40 ground = 23.75 screen px)
	for y in [200.0, 160.0, 120.0, 90.0, 60.0]:
		player.global_position = origin + Vector2(-150, y)
		await t.physics(2)
		enemy._during_attack(1.0 / 60.0)
	t.check("lunge_spares_feet_outside_band", enemy.state == Enemy2D.S.LUNGE and lost[0] == 0 and player.half_hearts == hearts,
		"state %d, lost %d half hearts with the feet 60 screen px south of the band" % [enemy.state, lost[0]])
	player.global_position = origin + Vector2(-150, 0)
	await t.physics(1)
	enemy._during_attack(1.0 / 60.0)
	t.check("lunge_hits_feet_inside_band", lost[0] == enemy.hit_damage() and player.half_hearts == hearts - enemy.hit_damage(), "lost %d" % lost[0])
	player.damaged.disconnect(damage)
	enemy.queue_free()
	for ring in area.ground_fx.get_node("TelegraphPool").get_children():
		ring.finish()
	player.revive(origin + Vector2(-300, 0))
	player.combat._iframes = 0
	await t.physics(2)

