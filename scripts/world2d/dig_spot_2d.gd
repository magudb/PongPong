class_name DigSpot2D
extends Interactable2D
## A glinting patch of soil to dig (package F4). Marker (lua/config/marker_handlers.lua: dig_spot):
##   dig_spot [when=...]
## E digs: it costs DIG_STAMINA (4) stamina, LootService.dig(zone, uid) rolls the container `dig` (find_chance 0.12, the farm 0.06: most digs find nothing and are still spent),
## the shimmer sprite (A1 `dig_glimmer`, additive) fades until the next morning (respawn daily, loot.containers.dig.respawn_days = 1). A player without the stamina whispers LOOT_TOO_TIRED and
## nothing is spent. Static maps: zone = the area id, uid = area id + ":" + cell. Generated floors (area.map.extra has `floor`): uid = DungeonFloors.uid_of, zone = the band, a `done` cell
## builds no spot at all (create_marker answers null: nothing is left to dig on this seed day) and mark_done_cell runs after the dig.
## Stamina: Player2D.spend_stamina(cost) -> bool when it exists, else the `stamina` property of the player (LootMarkers.spend_stamina).

const GLIMMER_ART := "dig_glimmer"
const SPENT_ALPHA := 0.0
const PULSE_SECONDS := 2.2

var cell: Vector2i = Vector2i.ZERO
var area: Node = null
var ctx: Dictionary = {}
var uid: String = ""
var zone: String = ""
var spent: bool = false

var _glimmer: Sprite2D
var _t: float = 0.0


static func create_marker(params: Dictionary, p_pos: Vector2, p_cell: Vector2i, p_area: IsoArea) -> Node:
	var c := DigSpot2D.new()
	c.setup_marker(params, p_pos, p_cell, p_area)
	if LootMarkers.is_done(p_area, p_cell, c.ctx):
		c.free()
		return null
	return c


func setup_marker(_params: Dictionary, _p_pos: Vector2, p_cell: Vector2i, p_area: IsoArea) -> void:
	cell = p_cell
	area = p_area
	ctx = LootMarkers.context_for(p_area, p_cell)
	uid = str(ctx["uid"])
	zone = str(ctx["zone"])
	name = "DigSpot_%d_%d" % [p_cell.x, p_cell.y]
	prompt_key = "LOOT_PROMPT_DIG"
	radius = Vector2(60, 30)


func _ready() -> void:
	super._ready()
	var art := ArtCatalog.prop(StringName(GLIMMER_ART))
	_glimmer = Sprite2D.new()
	_glimmer.name = "Shimmer"
	_glimmer.texture = art["texture"]
	_glimmer.centered = false
	_glimmer.offset = -(art["pivot"] as Vector2)
	_glimmer.material = Glow.additive_material()
	add_child(_glimmer)
	_t = fmod(float(cell.x * 7 + cell.y * 13), PULSE_SECONDS)           # neighbouring spots do not pulse in step
	refresh()


## connected on every entry into the tree (a parked iso area re-enters without a second _ready), the state is read again at once
func _enter_tree() -> void:
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)
	if not EventBus.load_completed.is_connected(_on_load_completed):
		EventBus.load_completed.connect(_on_load_completed)
	if _glimmer != null:
		refresh()


func _exit_tree() -> void:
	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)
	if EventBus.load_completed.is_connected(_on_load_completed):
		EventBus.load_completed.disconnect(_on_load_completed)


func _on_day_started(_day: int, _season: StringName) -> void:
	refresh()


func _on_load_completed(_slot: int) -> void:
	refresh()


## Dug today? (static maps: LootService.opened; dungeon floors never see a spent spot: the cell is done and the node was not built)
func refresh() -> void:
	var l := LootMarkers.loot()
	if not bool(ctx.get("dungeon", false)) and l != null and l.has_method("days_left"):
		spent = int(l.call("days_left", uid, int(l.call("respawn_days_of", zone, "dig")))) > 0
	prompt_key = "" if spent else "LOOT_PROMPT_DIG"
	if _glimmer != null:
		_glimmer.visible = not spent
	set_process(not spent)


func _process(delta: float) -> void:
	_t += delta
	if _glimmer != null and not spent:
		_glimmer.modulate = Color(1, 1, 1, 0.72 + 0.28 * sin(_t * TAU / PULSE_SECONDS))


## The E-query contract (PlayerBody2D.nearest_interactable): a dug spot only whispers that it rests, so a live host in reach wins E.
func is_spent() -> bool:
	return spent


func get_interaction_prompt() -> String:
	return tr(prompt_key) if prompt_key != "" else ""


func interact(player: Node) -> void:
	if not is_enabled():
		return
	if spent:
		EventBus.whisper_requested.emit(LootMarkers.KEY_DIG_RESTING)
		return
	var l := LootMarkers.loot()
	if l == null:
		return
	if not LootMarkers.has_stamina(player, LootMarkers.DIG_STAMINA):
		EventBus.whisper_requested.emit(LootMarkers.KEY_TIRED)
		return
	var res: Dictionary = l.call("dig", zone, uid, ctx.duplicate())
	if not bool(res.get("ok", false)):
		if str(res.get("reason", "")) == "cooldown":
			spent = true
			refresh()
			EventBus.whisper_requested.emit(LootMarkers.KEY_DIG_RESTING)
		return                                                  # full: the soil stays as it is and nothing was paid
	LootMarkers.spend_stamina(player, LootMarkers.DIG_STAMINA)  # the dig happened (a miss is a dig too): the work is paid now
	LootMarkers.mark_done(area, cell, ctx)
	LootMarkers.burst(self, global_position + Vector2(0, -8), Color(0.86, 0.74, 0.52), 12)
	LootMarkers.whisper_found(res)
	refresh()
	interacted.emit(player)
