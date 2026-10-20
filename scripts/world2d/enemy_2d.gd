class_name Enemy2D
extends CharacterBody2D
signal died(enemy: Enemy2D)
enum S { IDLE, CHASE, WINDUP, LUNGE, RECOVER, STUN, DEAD }
const BEHAVIORS := {
	"chase_lunge":preload("res://scripts/dungeon_run/enemies/chase_lunge.gd"),
	"hop":preload("res://scripts/dungeon_run/enemies/hop.gd"),
	"flee":preload("res://scripts/dungeon_run/enemies/flee.gd"),
	"stationary":preload("res://scripts/dungeon_run/enemies/stationary.gd"),
	"spore":preload("res://scripts/dungeon_run/enemies/spore.gd"),
	"keeper":preload("res://scripts/dungeon_run/enemies/keeper.gd")}
var kind := "bat"
var cfg: Dictionary = {}
var area: IsoArea
var cell := Vector2i.ZERO
var context: Dictionary = {}
var uid := ""
var tier := 1
var floor_number := 1
var is_boss := false
var critter := false
var armor := false
var ambush := false
var persist_cell := true
var ambush_state := ""
var adds := 0
var hp := 1
var max_hp := 1
var speed: float = 160
var detect: float = 550
var dmg_half := 1
var state := S.IDLE
var player: Node2D
var visual: IsoChibiSprite2D
var rng := RandomNumberGenerator.new()
var home := Vector2.ZERO
var ground_velocity := Vector2.ZERO
var hop_altitude: float = 0
var cooldown: float = 0
var clock: float = 0
var behavior_clock: float = 0
var remaining: float = 0
var stun_generation := 0
var attack_mode := "dash"
var aim := Vector2.RIGHT
var warning: TelegraphRing2D
var warning_serial := 0
var attack_geometry: Dictionary = {}
var attack_origin := Vector2.ZERO
var _attack: Area2D
var _attack_shape: CollisionShape2D
var _hurtbox: Area2D
var _host: Node2D
var _eyes: Sprite2D
var _stop := 0
static var _aggro_run := ""
static func begin_run() -> void:
	_aggro_run = ""

static func create_marker(params: Dictionary, pos: Vector2, marker_cell: Vector2i, target: IsoArea) -> Node:
	var ctx := LootMarkers.context_for(target,marker_cell)
	if str(params.get("persist","1")) != "0" and LootMarkers.is_done(target,marker_cell,ctx): return null
	var kind_id := str(params.get("kind","bat"))
	if kind_id == "boss": kind_id = "snurresvamp"
	var boss := str(params.get("boss","0")) in ["1","true"] or kind_id.begins_with("snurresvamp")
	var row := LuaData.dict(Svc.lua_config(("bosses." if boss else "enemies.")+kind_id,{}))
	if row.is_empty(): return null
	var roster := DungeonEnemyRoster.of(target)
	if not roster.has_room(): return null
	var node: Enemy2D
	if boss and ResourceLoader.exists("res://scripts/dungeon_run/bosses/boss_base.gd"):
		node = load("res://scripts/dungeon_run/bosses/boss_base.gd").new()
	else: node = Enemy2D.new()
	node.kind = kind_id
	node.cfg = row.duplicate(true)
	node.area = target
	node.cell = marker_cell
	node.context = ctx
	node.uid = str(ctx.uid)
	node.tier = clampi(int(params.get("tier",1)),1,4)
	node.floor_number = int(ctx.floor) if int(ctx.floor) > 0 else node.tier*3-2
	node.is_boss = boss
	node.critter = str(params.get("critter","0")) in ["1","true"] or str(row.get("behavior","")) == "flee"
	node.ambush = str(params.get("ambush","0")) in ["1","true"] and bool(row.get("ambush_ok",false))
	node.adds = int(params.get("adds",row.get("adds",0)))
	var floors := LootMarkers.floors()
	node.rng.seed = int(floors.rng_for(target,marker_cell,"enemy").next_u32()) if floors != null and int(ctx.floor) > 0 else DungeonRng.hash_key(str(target.map.id),1,marker_cell.y*target.map.width+marker_cell.x)
	node.position = pos
	node.name = "Enemy_"+kind_id+"_"+str(marker_cell.x)+"_"+str(marker_cell.y)
	roster.register(node)
	return node

func _ready() -> void:
	add_to_group("enemy")
	max_hp = DungeonRun.boss_hp(kind) if is_boss else DungeonRun.enemy_hp(kind,floor_number)
	hp = max_hp
	speed = float(cfg.get("speed",160))
	detect = float(cfg.get("detect",900 if is_boss else 550))
	dmg_half = 0 if critter else int(cfg.get("damage",DungeonCombatRules.enemy_damage(kind,tier,0)))
	armor = bool(cfg.get("armor",is_boss))
	collision_layer = 0
	collision_mask = Iso.LAYER_WORLD if cfg.get("flying",false) else Iso.LAYER_WORLD|Iso.LAYER_GROUND_BLOCK
	motion_mode = MOTION_MODE_FLOATING
	var body := CollisionShape2D.new()
	var body_shape := ConvexPolygonShape2D.new()
	body_shape.points = _ellipse(24,14)
	body.shape = body_shape
	add_child(body)
	visual = IsoChibiSprite2D.create(str(cfg.get("visual",CharacterCatalog.enemy_visual(kind))))
	add_child(visual)
	visual.self_modulate = Color(str(cfg.get("tint","ffffff")))
	_hurtbox = Area2D.new()
	_hurtbox.name = "Hurtbox"
	_hurtbox.collision_layer = Iso.LAYER_ENEMY
	_hurtbox.collision_mask = 0
	var shape := CollisionShape2D.new()
	var hurt := ConvexPolygonShape2D.new()
	var altitude := float(cfg.get("altitude",0))
	hurt.points = _ellipse(43,altitude*.5+36)
	shape.shape = hurt
	shape.position.y = -altitude*.5-10
	_hurtbox.add_child(shape)
	add_child(_hurtbox)
	_attack = Area2D.new()
	_attack.name = "Attack"
	_attack.collision_layer = Iso.LAYER_ENEMY_ATTACK
	_attack.collision_mask = 0
	_attack.monitorable = false
	_attack_shape = CollisionShape2D.new()
	_attack_shape.shape = ConvexPolygonShape2D.new()
	_attack.add_child(_attack_shape)
	add_child(_attack)
	home = global_position
	player = PlayerRegistry.local_player(get_tree()) as Node2D
	if ambush:
		ambush_state = "hidden"
		visual.visible = false
		_host = area.place_prop("bush_eyes_a" if rng.randi()%2 == 0 else "bush_eyes_b",cell)
		var art := ArtCatalog.prop(&"eyes_glow")
		_eyes = Sprite2D.new()
		_eyes.texture = art.texture
		_eyes.centered = false
		_eyes.offset = -art.pivot
		_eyes.material = Glow.additive_material()
		add_child(_eyes)
	DungeonEnemyRoster.of(area).register(self)
	set_awake(false)

static func _ellipse(rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 16: points.append(Vector2(cos(TAU*i/16)*rx,sin(TAU*i/16)*ry))
	return points

func is_awake() -> bool:
	return process_mode != PROCESS_MODE_DISABLED

func set_awake(on: bool) -> void:
	if state == S.DEAD: return
	if not on and process_mode != PROCESS_MODE_DISABLED:
		_cancel_attack()
		state = S.IDLE
		ground_velocity = Vector2.ZERO
		hop_altitude = 0
	if not on and is_instance_valid(_eyes): _eyes.visible = false
	process_mode = PROCESS_MODE_INHERIT if on else PROCESS_MODE_DISABLED

func protected_by_stone() -> bool:
	if player == null: return false
	var tree := get_tree()
	# Avoid constructing an empty group array for every enemy update.
	if not tree.has_group(&"runestone"):return false
	for stone in tree.get_nodes_in_group("runestone"):
		if stone is Node2D and bool(stone.get("lit")) and Iso.ground_dist(stone.global_position,player.global_position) < 520: return true
	return false

func _physics_process(dt: float) -> void:
	if state == S.DEAD: return
	if _stop > 0:
		_stop -= 1
		return
	if not is_instance_valid(player): player = PlayerRegistry.local_player(get_tree()) as Node2D
	if player == null: return
	var gm := Svc.node("GameManager")
	if gm != null and gm.is_modal_open(): return
	clock += dt
	cooldown = maxf(0,cooldown-dt)
	remaining -= dt
	var offset := Iso.to_ground(player.global_position-global_position)
	var direction := offset.normalized()
	var distance := offset.length()
	var down: bool = player is Player2D and player.state == PlayerBody2D.S.FAINTED
	if protected_by_stone() or down:
		_cancel_attack()
		state = S.IDLE
		ground_velocity = Iso.to_ground(home-global_position).limit_length(speed*dt)/maxf(.001,dt)
	elif ambush_state == "hidden":
		var gem := LanternGem.effects(LanternGem.equipped())
		_eyes.visible = distance <= 780*float(gem.ambush_mult)
		_eyes.modulate.a = .6+.4*sin(clock*3)
		if distance <= 330:
			if begin_windup({"shape":"line","width":80,"length":speed*3.1*.3+40,"direction":direction},.6,"ambush"):
				ambush_state = "rustle"
				EventBus.game_event.emit(&"audio_cue",{"cue":"sfx/bush_rustle"})
		return
	else:
		match state:
			S.IDLE:
				ground_velocity = Vector2.ZERO
				if distance <= detect:
					state = S.CHASE
					EventBus.enemy_encountered.emit(kind)
					var run_id := str(DungeonFloors.inst().seed_day) if DungeonFloors.inst() != null else str(area.get_instance_id())
					if _aggro_run != run_id and not critter:
						_aggro_run = run_id
						EventBus.whisper_requested.emit("WHISPER_FERNS")
			S.CHASE:
				if distance > detect*1.8:
					state = S.IDLE
				else: BEHAVIORS.get(str(cfg.get("behavior","chase_lunge")),BEHAVIORS.chase_lunge).tick(self,dt,direction,distance)
			S.WINDUP: _windup(direction)
			S.LUNGE:
				if remaining <= 0: _recover()
				else: _during_attack(dt)
			S.RECOVER,S.STUN:
				ground_velocity = ground_velocity.move_toward(Vector2.ZERO,1000*dt)
				if remaining <= 0: state = S.CHASE
	velocity = Iso.to_screen(ground_velocity)
	move_and_slide()
	if state == S.LUNGE: _attack.global_position = attack_origin
	ground_velocity = Iso.to_ground(velocity)
	var altitude := float(cfg.get("altitude",0))
	visual.set_altitude(altitude+(sin(clock*5)*6 if altitude > 0 else hop_altitude))
	visual.update_motion(velocity,false,false,bool(cfg.get("flying",false)),Iso.to_screen(direction))

func begin_windup(geometry: Dictionary, seconds: float, mode: String) -> bool:
	_cancel_attack()
	var duration := seconds*DungeonRun.windup_mult()
	geometry["duration"] = duration+.03
	geometry["owner"] = self
	var origin := Vector2(geometry.get("at",global_position))
	var ring := TelegraphRing2D.play(area.ground_fx,origin,geometry)
	if ring == null:
		cooldown = maxf(cooldown,.2)
		return false
	state = S.WINDUP
	attack_mode = mode
	remaining = duration
	attack_origin = origin
	aim = Vector2(geometry.get("direction",Vector2.RIGHT))
	warning = ring
	warning_serial = warning.serial
	ground_velocity = Vector2.ZERO
	hop_altitude = 0
	EventBus.game_event.emit(&"audio_cue",{"cue":"sfx/telegraph_tick"})
	return true

func _windup(direction: Vector2) -> void:
	if remaining > .2 and attack_mode in ["dash","ambush","lance"]:
		aim = direction
		if _warning_valid(): warning.direction = direction
	var hz := 2.0 if DungeonRun.assist("assist_reduce_flash") else 6.0
	visual.modulate = Color.WHITE.lerp(Color("fbf5e6"),.5+.5*sin(clock*TAU*hz))
	if remaining > 0: return
	if attack_mode == "ambush": reveal()
	if _warning_valid():
		attack_geometry = warning.hit_area()
		(_attack_shape.shape as ConvexPolygonShape2D).points = warning.polygon()
		warning.finish()
	visual.modulate = Color.WHITE
	if attack_mode == "spore":
		cloud(attack_origin)
		_recover()
		return
	state = S.LUNGE
	remaining = float(cfg.get("keeper",{}).get("seconds",.2)) if attack_mode == "lance" else float(cfg.get("lunge_time",.3))
	_attack.global_position = attack_origin
	_attack.set_deferred("monitorable",true)
	ground_velocity = aim*speed*float(cfg.get("lunge_mult",3.1)) if attack_mode in ["dash","ambush"] else Vector2.ZERO

func _during_attack(_dt: float) -> void:
	_attack.global_position = attack_origin
	var offset := Iso.to_ground(player.global_position-attack_origin)
	var inside := offset.length() <= float(attack_geometry.get("radius",70)) if str(attack_geometry.get("shape","ring")) == "ring" else (attack_geometry.get("rect",Rect2()) as Rect2).has_point(offset.rotated(-aim.angle()))
	if inside and player.has_method("take_damage"): player.take_damage(hit_damage(),attack_origin)

func _recover() -> void:
	_attack.set_deferred("monitorable",false)
	state = S.RECOVER
	remaining = float(cfg.get("recover",.7))
	cooldown = float(cfg.get("keeper",{}).get("cooldown",4)) if attack_mode == "lance" else float(cfg.get("cooldown",1.6))
	ground_velocity = Vector2.ZERO

func _warning_valid() -> bool:
	return is_instance_valid(warning) and warning.serial == warning_serial
func _cancel_attack() -> void:
	if _warning_valid(): warning.finish()
	if is_instance_valid(_attack): _attack.set_deferred("monitorable",false)
	if is_instance_valid(visual): visual.modulate = Color.WHITE
func reveal() -> void:
	if not ambush or ambush_state == "revealed": return
	ambush_state = "revealed"
	visual.visible = true
	if is_instance_valid(_eyes): _eyes.visible = false
	if is_instance_valid(_host):
		area.remove_prop(_host)
		area.place_prop("empty_bush",cell)
func stun(seconds: float) -> void:
	if state == S.DEAD: return
	stun_generation += 1
	reveal()
	_cancel_attack()
	state = S.STUN
	hop_altitude = 0
	remaining = maxf(.01,seconds)
	cooldown = .4
func hit_stop(frames: int) -> void:
	_stop = maxi(frames,0)
func take_hit(damage: int, from: Vector2, attacker: Node = null) -> void:
	if state == S.DEAD or damage <= 0: return
	set_awake(true)
	reveal()
	hp = maxi(0,hp-damage)
	var armoured := armor and state in [S.WINDUP,S.LUNGE]
	if not armoured:
		ground_velocity = Iso.to_ground(global_position-from).normalized()*550
		stun(.38)
	if not DungeonRun.assist("assist_reduce_flash"): visual.flash(Color("fbf5e6"),.18)
	HitSpark2D.play(area.objects,global_position+Vector2(0,-50),ItemKinds.rarity_of(attacker.combat.active_weapon_id()) if attacker is Player2D else "normal")
	EventBus.game_event.emit(&"audio_cue",{"cue":"sfx/hit_soft"})
	_on_health_changed()
	if hp <= 0:
		if attacker != null: WeaponFx.on_kill(attacker,self)
		_die()
func _on_health_changed() -> void:
	pass
func hit_damage() -> int:
	if critter: return 0
	var damage := int(cfg.get("keeper",{}).get("damage",2)) if attack_mode == "lance" else dmg_half
	return maxi(1,damage-int(DungeonRun.assist("assist_dmg")))
func shoot(direction: Vector2, bolt_speed: float, damage: int) -> void:
	var bolt := EnemyHazard2D.new()
	bolt.mode = "bolt"
	bolt.direction = direction
	bolt.speed = bolt_speed
	bolt.damage = damage
	bolt.radius = 24
	bolt.seconds = 4
	area.ground_fx.add_child(bolt)
	bolt.global_position = global_position
func cloud(at: Vector2) -> void:
	var row := LuaData.dict(cfg.get("spore",{}))
	var node := EnemyHazard2D.new()
	node.radius = float(row.get("radius",150))
	node.seconds = float(row.get("seconds",3))
	area.ground_fx.add_child(node)
	node.global_position = at
func _die() -> void:
	if state == S.DEAD: return
	state = S.DEAD
	process_mode = PROCESS_MODE_INHERIT
	set_physics_process(false)
	_cancel_attack()
	_hurtbox.set_deferred("monitorable",false)
	var loot_rows := []
	var service := Svc.node("LootService")
	if not is_boss and service != null:
		var answer: Dictionary = service.on_enemy_defeated(kind,context)
		if answer.get("ok",false): loot_rows.append_array(answer.get("results",[]))
	for row in LuaData.arr(cfg.get("drops",[])):
		if rng.randf() < float(row.get("chance",0)):
			loot_rows.append({"id":str(row.item),"amount":rng.randi_range(int(row.get("min",1)),int(row.get("max",1)))})
	for row in loot_rows: LootDrop2D.spawn(area.objects,global_position+Vector2(rng.randf_range(-25,25),0),row.id,int(row.amount))
	if persist_cell and not is_boss: LootMarkers.mark_done(area,cell,context)
	EventBus.enemy_defeated.emit(uid,kind,loot_rows)
	died.emit(self)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(visual,"modulate:a",0.0,.5)
	tween.tween_property(visual,"scale",Vector2.ONE*.8,.5)
	tween.chain().tween_callback(queue_free)
