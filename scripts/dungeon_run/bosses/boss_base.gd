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
	if not _birth_continue(): return
	cfg["lunge_mult"] = float(cfg.patterns.dash_speed)/float(cfg.speed)
	super._ready()
	if not _birth_continue(): return
	arena_ring = load("res://scripts/dungeon_run/bosses/arena_ring.gd").new()
	arena_ring.player = player
	area.ground_fx.add_child(arena_ring)
	if not _birth_continue(): return
	arena_ring.global_position = global_position
	EventBus.boss_bar_changed.emit(str(cfg.name_key),1,false)
	if not _birth_continue(): return
	var halo := Sprite2D.new()
	halo.texture = Glow.light_texture()
	halo.modulate = Color(str(cfg.glow),.16)
	halo.material = Glow.additive_material()
	halo.position.y = -70
	visual.add_child(halo)
	if _birth_continue(): _birth_current = Callable()
func set_awake(on: bool) -> void:
	if not on and awake:reset_fight()
	super.set_awake(on)
func _physics_process(dt: float) -> void:
	if state == S.DEAD or GameManager.is_modal_open(): return
	if not is_instance_valid(player): player = PlayerRegistry.local_player(get_tree()) as Node2D
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
	_next_combat_request()
	_cancel_attack()
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
## A hit stuns the boss as it does any enemy, but never shortens a daze or a running pattern: the punish window after a
## dash (and the wait while rain or clouds fall) keeps its full length instead of the 0.38 s stagger and 0.4 s cooldown.
func stun(seconds: float) -> void:
	var dazed := remaining if state in [S.RECOVER,S.STUN] else 0.0
	var wait := cooldown
	super.stun(seconds)
	remaining = maxf(remaining,dazed)
	cooldown = maxf(cooldown,wait)
func stun_owned(seconds: float, receipt: Dictionary, request: Dictionary) -> void:
	if not Enemy2D._combat_request_current(receipt, request): return
	var dazed := remaining if state in [S.RECOVER,S.STUN] else 0.0
	var wait := cooldown
	super.stun_owned(seconds, receipt, request)
	if not Enemy2D._combat_request_current(receipt, request): return
	remaining = maxf(remaining,dazed)
	cooldown = maxf(cooldown,wait)
func _on_health_changed() -> void:
	# A terminal health refresh is still a public notification, not a revival
	# request that can revoke the exact committed corpse's cleanup.
	if state == S.DEAD:
		EventBus.boss_bar_changed.emit(str(cfg.name_key),float(hp)/max_hp,awake)
		return
	var receipt := EventBus.combat_receipt(EventBus.combat_origin(), self)
	if EventBus.combat_current(receipt):
		PlayerRegistry.for_player(&"p0", func(): _on_health_changed_owned(receipt, _combat_request(receipt)))
func _on_health_changed_owned(receipt: Dictionary, request: Dictionary) -> void:
	if not EventBus.combat_current(receipt): return
	if not Enemy2D._combat_request_current(receipt, request): return
	EventBus.boss_bar_changed.emit(str(cfg.name_key),float(hp)/max_hp,awake)
	if not Enemy2D._combat_request_current(receipt, request): return
	while phase < 2 and hp <= max_hp*([.66,.33][phase]):
		phase += 1 # committed phase prefix, never rolled back after an observer
		LootDrop2D.spawn_owned(area.objects,global_position+Vector2(45 if phase == 1 else -45,40),"tornebaer",1,Enemy2D._combat_request_current.bind(receipt, request))
		if not Enemy2D._combat_request_current(receipt, request): return
		spawn_add_owned("bat",adds/2,receipt,request)
		if not Enemy2D._combat_request_current(receipt, request): return
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
func spawn_add_owned(kind_id: String, count: int, receipt: Dictionary, request: Dictionary) -> void:
	for i in count:
		if not Enemy2D._combat_request_current(receipt, request): return
		if not DungeonEnemyRoster.of(area).has_room(): return
		var candidate := home+Iso.to_screen(Vector2.from_angle(TAU*i/maxi(count,1)+phase)*250)
		if not area.is_walkable(area.global_to_cell(candidate)): candidate = home+Vector2(100,0)
		var enemy: Variant = Enemy2D.create_marker({"kind":kind_id,"tier":tier,"persist":0},candidate,area.global_to_cell(candidate),area)
		if not Enemy2D._combat_request_current(receipt, request):
			if is_instance_valid(enemy): enemy.queue_free()
			return
		if enemy == null: continue
		enemy.persist_cell = false
		enemy.uid = uid+":add:"+str(phase)+":"+str(summoned.size())
		enemy.context["uid"] = enemy.uid
		summoned.append(weakref(enemy))
		enemy._birth_current = Enemy2D._combat_request_current.bind(receipt,request)
		area.objects.add_child(enemy)
		if not Enemy2D._combat_request_current(receipt, request): return
		if not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.is_queued_for_deletion(): return
		enemy._stun_if(.6,Enemy2D._combat_request_current.bind(receipt,request))
		if not Enemy2D._combat_request_current(receipt, request): return
		TelegraphRing2D.play_owned(area.ground_fx,candidate,{"radius":55,"duration":.6},Enemy2D._combat_request_current.bind(receipt,request))
		if not Enemy2D._combat_request_current(receipt, request): return

func reset_fight() -> void:
	var was_dead := state == S.DEAD
	_next_combat_request()
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
	if was_dead:
		set_physics_process(true)
		_hurtbox.monitorable = true
	cooldown = 0
	global_position = home
	ground_velocity = Vector2.ZERO
	arena_ring.visible = true
	arena_ring.set_process(true)
	EventBus.boss_bar_changed.emit(str(cfg.name_key),1,false)
func _die() -> void:
	if state == S.DEAD: return
	var receipt := EventBus.combat_receipt(EventBus.combat_origin(), self)
	if EventBus.combat_current(receipt):
		PlayerRegistry.for_player(&"p0", func(): _die_owned(receipt, _combat_request(receipt)))

func _death_cleanup_owned(_receipt: Dictionary, request: Dictionary) -> void:
	var sequences := get_children().filter(func(n): return n.get_script() == Sequence).map(func(n): return weakref(n))
	var adds_before := summoned.duplicate()
	EventBus.boss_bar_changed.emit(str(cfg.name_key),0,false)
	# Do not discover resources after an observer could start another fight.
	if not Enemy2D._combat_attachment_current(request): return
	for ref in sequences + adds_before:
		var node: Variant = ref.get_ref()
		if is_instance_valid(node) and not node.is_queued_for_deletion(): node.queue_free()
func _exit_tree() -> void:
	var old_ring: WeakRef = weakref(arena_ring) if is_instance_valid(arena_ring) else null
	EventBus.boss_bar_changed.emit(str(cfg.get("name_key","")),0,false)
	# The bar observer can install a replacement; retire only the captured ring.
	if old_ring != null and is_instance_valid(old_ring.get_ref()): old_ring.get_ref().queue_free()
