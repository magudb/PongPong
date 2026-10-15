class_name UniqueSpot2D
extends Interactable2D
## A hidden one-time treasure (package F4). Marker (lua/config/marker_handlers.lua: unique_spot):
##   unique_spot id=<spot id from lua/data/loot_tables.lua `spots`> [when=...]
## The glimmer (A1 `unique_glimmer`, additive) shines until the spot is CLAIMED; E claims it once through LootService.claim_spot(id): the spot's keepsake enters the pack (or the
## wardrobe / furniture store). The spot honours `requires` ({quests, day_min, home_tier_min, items}) and `consume` through LootService, and `when=` through IsoArea.
## When `requires` is NOT met the glimmer stays but the player standing at it gets the spot's hint_key as a whisper, ONCE PER VISIT (the in-world use of the keepsake hints: "Dybt i
## Krystalgrotten staar et alter. Det aabner kun for den, der har baaret Maanekronen"); pressing E there says the same. A spot that wants items it lacks says so with
## LOOT_RUNE_VAULT_NEEDS when the missing items are rune shards (dng_rune_*), else with the hint. A visit ends with the next EventBus.area_changed.
## Generated floors: the spot's state is read through LootService.spot_state (open | claimed | cooldown | locked: the dungeon's 7-day unique pace says cooldown with LOOT_SPOT_PACED), a `done`
## cell builds no spot (create_marker answers null) and mark_done_cell runs after the claim.

const GLIMMER_ART := "unique_glimmer"
const HINT_RADIUS_PX := 70.0
const PULSE_SECONDS := 2.6
const POLL_SECONDS := 0.2

var spot_id: String = ""
var cell: Vector2i = Vector2i.ZERO
var area: Node = null
var ctx: Dictionary = {}
var claimed: bool = false
var state: StringName = &"open"
var hint_told: bool = false           # the hint was whispered during this visit

var _glimmer: Sprite2D
var _t: float = 0.0
var _poll: float = 0.0


static func create_marker(params: Dictionary, p_pos: Vector2, p_cell: Vector2i, p_area: IsoArea) -> Node:
	var c := UniqueSpot2D.new()
	c.setup_marker(params, p_pos, p_cell, p_area)
	if c.spot_id == "" or LootMarkers.is_done(p_area, p_cell, c.ctx):
		c.free()
		return null
	return c


func setup_marker(params: Dictionary, _p_pos: Vector2, p_cell: Vector2i, p_area: IsoArea) -> void:
	spot_id = str(params.get("id", ""))
	cell = p_cell
	area = p_area
	ctx = LootMarkers.context_for(p_area, p_cell)
	name = "UniqueSpot_%s" % spot_id
	prompt_key = "LOOT_PROMPT_SEARCH"
	radius = Vector2(60, 30)


func _ready() -> void:
	super._ready()
	var art := ArtCatalog.prop(StringName(GLIMMER_ART))
	_glimmer = Sprite2D.new()
	_glimmer.name = "Glimmer"
	_glimmer.texture = art["texture"]
	_glimmer.centered = false
	_glimmer.offset = -(art["pivot"] as Vector2)
	_glimmer.material = Glow.additive_material()
	add_child(_glimmer)
	_t = fmod(float(cell.x * 5 + cell.y * 11), PULSE_SECONDS)
	refresh()


## connected on every entry into the tree (a parked iso area re-enters without a second _ready), the state is read again at once
func _enter_tree() -> void:
	if not EventBus.area_changed.is_connected(_on_area_changed):
		EventBus.area_changed.connect(_on_area_changed)
	if not EventBus.load_completed.is_connected(_on_load_completed):
		EventBus.load_completed.connect(_on_load_completed)
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)
	if _glimmer != null:
		refresh()


func _exit_tree() -> void:
	if EventBus.area_changed.is_connected(_on_area_changed):
		EventBus.area_changed.disconnect(_on_area_changed)
	if EventBus.load_completed.is_connected(_on_load_completed):
		EventBus.load_completed.disconnect(_on_load_completed)
	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)


## a new visit: the hint may be whispered again
func _on_area_changed(_area_id: StringName) -> void:
	hint_told = false


func _on_load_completed(_slot: int) -> void:
	refresh()


func _on_day_started(_day: int, _season: StringName) -> void:
	refresh()


## Reads the state from LootService: claimed spots lose their glimmer for good.
func refresh() -> void:
	var l := LootMarkers.loot()
	state = StringName(str(l.call("spot_state", spot_id))) if l != null and l.has_method("spot_state") else &"open"
	claimed = state == &"claimed"
	prompt_key = "" if claimed else "LOOT_PROMPT_SEARCH"
	if _glimmer != null:
		_glimmer.visible = not claimed
	set_process(not claimed)


func _process(delta: float) -> void:
	_t += delta
	if _glimmer != null and not claimed:
		_glimmer.modulate = Color(1, 1, 1, 0.7 + 0.3 * sin(_t * TAU / PULSE_SECONDS))
	_poll -= delta
	if _poll <= 0.0:
		_poll = POLL_SECONDS
		if not hint_told and is_enabled() and LootMarkers.player_distance(self) <= HINT_RADIUS_PX:
			check_hint()


## The player stands at the glimmer: when the spot is locked, its hint is whispered (once per visit). True when a hint was whispered.
func check_hint() -> bool:
	if hint_told or claimed:
		return false
	refresh()
	if state != &"locked":
		return false
	hint_told = true
	_whisper_locked()
	return true


func get_interaction_prompt() -> String:
	return tr(prompt_key) if prompt_key != "" else ""


func interact(player: Node) -> void:
	if not is_enabled() or claimed:
		return
	var l := LootMarkers.loot()
	if l == null:
		return
	refresh()
	match str(state):
		"locked":
			hint_told = true
			_whisper_locked()
			return
		"cooldown":
			EventBus.whisper_requested.emit(LootMarkers.KEY_SPOT_PACED)
			return
		"claimed":
			return
	var res: Dictionary = l.call("claim_spot", spot_id, ctx.duplicate())
	if not bool(res.get("ok", false)):
		if str(res.get("reason", "")) == "locked":
			_whisper_locked()
		return                                              # full: the glimmer stays, nothing happened
	LootMarkers.mark_done(area, cell, ctx)
	LootMarkers.burst(self, global_position + Vector2(0, -20), Color(1.0, 0.85, 0.93), 22)
	LootMarkers.whisper_found(res)
	refresh()
	interacted.emit(player)


## the whisper of an unmet `requires`: the vault's message for missing rune shards, else the spot's hint_key
func _whisper_locked() -> void:
	var l := LootMarkers.loot()
	if l == null:
		return
	for id in l.call("missing_items", spot_id):
		if str(id).begins_with("dng_rune"):
			EventBus.whisper_requested.emit(LootMarkers.KEY_VAULT_NEEDS)
			return
	var hint := str(LuaData.dict(l.call("spot_def", spot_id)).get("hint_key", ""))
	if hint != "":
		EventBus.whisper_requested.emit(hint)
