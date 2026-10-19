class_name Warp2D
extends Area2D
## Zone door between two areas. Walk into it (player body) -> EventBus.area_change_requested(area, spawn).
## Marker:  warp to=<area id> spawn=<spawn name> label=<translation key> [req_day=N] [r=<cells>] [prop=<art id>] [when=...]
##   req_day  the door stays shut until GameManager.total_day() >= N (adventure.dark_forest_unlock_day feeds it); a closed door
##            whispers WORLD_WARP_LOCKED once per approach instead of travelling
##   r        extra reach in cells around the door cell (0 = exactly the cell)
##   when     gated by IsoArea (evaluated on enter and on quest / flag / clock changes), which calls set_enabled(): the warp keeps no
##            copy of the condition
##   label    the translation key of the destination's name (ZONE_DARK_FOREST). It is DATA for the map chip and the HUD (P16 / P17);
##            P04 does not draw it: a warp is a walk-in trigger, so there is no "E:" prompt to put it on, and the HUD prompt slot
##            (EventBus.interaction_prompt_changed) belongs to the player's nearest-interactable query, which rewrites it every frame -
##            a warp that wrote there would be overwritten or stick. Deferred, see the report of P04 (fix round 2).

var to_area: StringName = &""
var to_spawn: StringName = &"default"
var label_key: String = ""
var req_day: int = 0
var reach: float = 0.0
var armed: bool = true

var _told: bool = false
## The player who stepped on the warp in the middle of a tool use: it travels once that use ends, still standing here.
var _waiting: PlayerBody2D


func setup(m: Dictionary, area: IsoArea, _cell: Vector2i) -> void:
	to_area = StringName(m.get("to", ""))
	to_spawn = StringName(m.get("spawn", "default"))
	label_key = m.get("label", "")
	req_day = int(m.get("req_day", 0))
	reach = float(m.get("r", 0))
	add_to_group("warp")
	collision_layer = 0
	collision_mask = Iso.LAYER_PLAYER
	monitoring = true
	var grow: float = 1.0 + 2.0 * reach
	if area.projection == &"iso":
		var pts := PackedVector2Array()
		for p in Iso.iso_diamond(Vector2i.ZERO):
			pts.append((p - Iso.iso_center(Vector2i.ZERO)) * grow)
		var poly := CollisionPolygon2D.new()
		poly.polygon = pts
		add_child(poly)
	else:
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(Iso.ORTHO_W, Iso.ORTHO_H) * grow
		cs.shape = sh
		add_child(cs)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func is_open() -> bool:
	if req_day <= 0:
		return true
	var gm: Node = GameData.gm()
	return gm == null or int(gm.call("total_day")) >= req_day


## `when=` support (IsoArea.refresh_when): a hidden warp neither fires nor lets anything in.
func set_enabled(on: bool) -> void:
	armed = on
	visible = on
	set_deferred("monitoring", on)
	if not on:
		_stop_waiting()


func _on_body_entered(body: Node) -> void:
	if not armed or not body.is_in_group("player"):
		return
	# Enter deliberately on foot. A dodge or combat knockback can cross a
	# stair while the player is fighting beside it; travelling then also
	# disposes the live encounter. Step out and walk back in after the action.
	# A tool use (hoe hold-repeat walks at reduced speed) is not combat: that
	# player travels as soon as the use ends, if still standing on the warp.
	if body is PlayerBody2D and body.state != PlayerBody2D.S.FREE:
		if body.state == PlayerBody2D.S.USING:
			_waiting = body
			set_physics_process(true)
		return
	_enter()


## Every door and warp shares the gate above; this is what happens once the player is through it.
func _enter() -> void:
	if not is_open():
		if not _told:
			_told = true
			EventBus.whisper_requested.emit("WORLD_WARP_LOCKED")
		return
	# a target the world does not know still fires the request: travel() owns the refusal (and whispers it)
	EventBus.area_change_requested.emit(to_area, to_spawn)


## Runs only while a player waits on the warp (the first tick after _ready switches it off again).
func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_waiting) or not armed:
		_stop_waiting()
	elif _waiting.state == PlayerBody2D.S.FREE:
		_stop_waiting()
		_enter()
	elif _waiting.state != PlayerBody2D.S.USING:
		_stop_waiting()


func _stop_waiting() -> void:
	_waiting = null
	set_physics_process(false)


func _on_body_exited(body: Node) -> void:
	_told = false
	if body == _waiting:
		_stop_waiting()
