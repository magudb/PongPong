class_name DungeonBoss2D
extends Enemy2D
const PATTERNS := {"snurresvamp":preload("res://scripts/dungeon_run/bosses/snurre.gd"),"snurresvamp_gloed":preload("res://scripts/dungeon_run/bosses/gloed.gd"),"snurresvamp_konge":preload("res://scripts/dungeon_run/bosses/konge.gd")}
const Sequence := preload("res://scripts/dungeon_run/bosses/attack_sequence.gd")
var awake := false
var phase := 0
var cycle := 0
var combo_left := 1
var summoned: Array = []
var arena_ring: Node2D
func _ready() -> void:
	cfg["lunge_mult"] = float(cfg.patterns.dash_speed)/float(cfg.speed)
	super._ready()
	arena_ring = load("res://scripts/dungeon_run/bosses/arena_ring.gd").new()
	arena_ring.player = player
	area.ground_fx.add_child(arena_ring)
	arena_ring.global_position = global_position
	EventBus.boss_bar_changed.emit(str(cfg.name_key),1,false)
	var halo := Sprite2D.new()
	halo.texture = Glow.light_texture()
	halo.modulate = Color(str(cfg.glow),.16)
	halo.material = Glow.additive_material()
	halo.position.y = -70
	visual.add_child(halo)
func _physics_process(dt: float) -> void:
	if state == S.DEAD: return
	if not is_instance_valid(player): player = get_tree().get_first_node_in_group("player") as Node2D
	if player == null: return
	if (player is Player2D and player.state == PlayerBody2D.S.FAINTED) or Iso.ground_dist(player.global_position,home) > 1800:
		reset_fight()
		return
	if not awake:
		if Iso.ground_dist(player.global_position,global_position) > 520: return
		awake = true
		arena_ring.visible = false
		arena_ring.set_process(false)
		EventBus.boss_bar_changed.emit(str(cfg.name_key),float(hp)/max_hp,true)
		state = S.CHASE
	if state == S.CHASE and cooldown <= 0:
		cycle += 1
		var mode: String = PATTERNS[kind].next(self)
		start_pattern(mode)
	super._physics_process(dt)
func start_pattern(mode: String) -> void:
	var params := LuaData.dict(cfg.patterns)
	var direction := Iso.to_ground(player.global_position-global_position).normalized()
	combo_left = 2 if mode == "dash" and hp <= max_hp*float(params.get("double_below",0)) else 1
	if mode == "dash":
		begin_windup({"shape":"line","width":params.dash_width,"length":float(params.dash_speed)*float(cfg.lunge_time)+40,"direction":direction},float(cfg.windup),"dash")
	elif mode in ["puff","quake"]:
		begin_windup({"radius":params.get("puff_radius",200) if mode == "puff" else params.get("quake_radius",260)},float(cfg.windup),mode)
	else:
		var sequence := Sequence.new()
		sequence.boss = self
		var count := int(params.get("rain_volley",3))*int(params.get("rain_count",3)) if mode == "rain" else 2
		for i in count:
			var offset := Vector2.from_angle(TAU*i/count+float(rng.randf_range(-.2,.2)))*float(80+(i%3)*65)
			var at := player.global_position+Iso.to_screen(offset)
			sequence.rows.append({"delay":i*float(params.get("rain_stagger",.35)) if mode == "rain" else 0.0,"windup":float(params.get("rain_windup",1))*DungeonRun.windup_mult(),"radius":float(params.get("rain_radius",120)) if mode == "rain" else float(params.get("cloud_radius",150)),"kind":mode,"at":at})
		add_child(sequence)
		state = S.RECOVER
		ground_velocity = Vector2.ZERO
		remaining = (count-1)*float(params.get("rain_stagger",.35))+1.0*DungeonRun.windup_mult()+float(cfg.dazed) if mode == "rain" else 1.0*DungeonRun.windup_mult()+float(cfg.dazed)
		cooldown = remaining
		visual.play_action(&"attack")
func _windup(direction: Vector2) -> void:
	var before := state
	super._windup(direction)
	if before == S.WINDUP and state == S.LUNGE:
		visual.play_action(&"spin" if attack_mode == "dash" else &"attack")
		if attack_mode == "puff": spawn_add("lysesvamp",1)
func _recover() -> void:
	if attack_mode == "dash" and combo_left > 1:
		combo_left -= 1
		var direction := Iso.to_ground(player.global_position-global_position).normalized()
		begin_windup({"shape":"line","width":cfg.patterns.dash_width,"length":float(cfg.patterns.dash_speed)*float(cfg.lunge_time)+40,"direction":direction},float(cfg.patterns.get("double_gap",.6)),"dash")
		return
	super._recover()
	remaining = float(cfg.dazed)
	cooldown = remaining
	visual.play_action(&"hit")
func _on_health_changed() -> void:
	EventBus.boss_bar_changed.emit(str(cfg.name_key),float(hp)/max_hp,awake)
	while phase < 2 and hp <= max_hp*([.66,.33][phase]):
		phase += 1
		LootDrop2D.spawn(area.objects,global_position+Vector2(45 if phase == 1 else -45,40),"tornebaer",1)
		spawn_add("bat",adds/2)
func spawn_add(kind_id: String, count: int) -> void:
	for i in count:
		if not DungeonEnemyRoster.of(area).has_room(): return
		var candidate := home+Iso.to_screen(Vector2.from_angle(TAU*i/maxi(count,1)+phase)*250)
		if not area.is_walkable(area.global_to_cell(candidate)): candidate = home+Vector2(100,0)
		var enemy: Enemy2D = Enemy2D.create_marker({"kind":kind_id,"tier":tier,"persist":0},candidate,area.global_to_cell(candidate),area)
		if enemy == null: continue
		enemy.persist_cell = false
		enemy.uid = uid+":add:"+str(phase)+":"+str(summoned.size())
		enemy.context["uid"] = enemy.uid
		summoned.append(weakref(enemy))
		area.objects.add_child(enemy)
		enemy.stun(.6)
		TelegraphRing2D.play(area.ground_fx,candidate,{"radius":55,"duration":.6})
func reset_fight() -> void:
	if not awake and hp == max_hp: return
	_cancel_attack()
	for ref in summoned:
		if ref.get_ref() != null: ref.get_ref().queue_free()
	summoned.clear()
	for node in get_children():
		if node.get_script() == Sequence: node.queue_free()
	hp = max_hp
	phase = 0
	cycle = 0
	awake = false
	state = S.IDLE
	cooldown = 0
	global_position = home
	ground_velocity = Vector2.ZERO
	arena_ring.visible = true
	arena_ring.set_process(true)
	EventBus.boss_bar_changed.emit(str(cfg.name_key),1,false)
func _die() -> void:
	if state == S.DEAD: return
	EventBus.boss_bar_changed.emit(str(cfg.name_key),0,false)
	for node in get_children():
		if node.get_script() == Sequence: node.queue_free()
	for ref in summoned:
		if ref.get_ref() != null: ref.get_ref().queue_free()
	super._die()
	EventBus.combat_finished.emit(true)
func _exit_tree() -> void:
	EventBus.boss_bar_changed.emit(str(cfg.get("name_key","")),0,false)
	if is_instance_valid(arena_ring): arena_ring.queue_free()
