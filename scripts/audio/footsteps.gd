class_name PlayerFootsteps
extends Node
const WALK_INTERVAL := 1.0/3.0
const RUN_INTERVAL := 0.25
var player: Player2D
var _last := Vector2.ZERO
var _elapsed := 0.0
var _variant: Dictionary = {}
var _rng := RandomNumberGenerator.new()
func _ready() -> void:
	player = get_parent() as Player2D
	_last = player.global_position
	_rng.randomize()
func _physics_process(delta: float) -> void:
	var distance := Iso.ground_dist(_last,player.global_position)
	_last = player.global_position
	var free := player.world_input_allowed() and player.state==Player2D.S.FREE and not player.is_flying and not player.is_jumping and not player._landing
	var moving := free and distance>0.05 and distance<=player._run*delta*2.0
	advance(delta,moving,player.visual.current_clip==&"run" if player.visual!=null else false,"")
func advance(delta: float,moving: bool,running: bool,surface: String) -> void:
	if not moving:
		_elapsed = 0
		return
	_elapsed += delta
	var interval := RUN_INTERVAL if running else WALK_INTERVAL
	if _elapsed+0.000001<interval:return
	_elapsed = fmod(maxf(_elapsed,interval),interval)
	if surface=="":surface = Surface.at(player.area,player.global_position)
	var count := clampi(int(Svc.lua_config("audio_map.variants."+surface,3)),2,3)
	var previous := int(_variant.get(surface,0))
	var selected := _rng.randi_range(1,count-1)
	if selected>=previous and previous>0:selected += 1
	_variant[surface] = selected
	AudioManager.play_sfx("step_%s_%d" % [surface,selected],-20,_rng.randf_range(0.94,1.06))
