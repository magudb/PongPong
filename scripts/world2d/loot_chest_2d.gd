class_name LootChest2D
extends Interactable2D
## A chest of the world (package F4). Marker (lua/config/marker_handlers.lua: chest):
##   chest tier=trae|jern|fe|konge|noegle [role=main|nook|lake|boss] [lock=<item id>] [boss=<kind>] [hidden=1] [when=...]
## Static maps (farm, hand-authored zones): E opens it through LootService.open_container(area id, tier, "<area id>:<cell>"), a sparkle burst, then the sprite is DARKENED
## (props_features: opened modulate 0.55, there is no open-lid art: honest stub) until respawn_days have passed (loot.containers.<tier>.respawn_days: 7 / 14 / 21 / 7 days).
## Generated dungeon floors (area.map.extra has `floor`): uid = DungeonFloors.uid_of(area, cell); a cell that is `done` already builds the chest OPEN (darkened, no prompt);
## mark_done_cell after the opening; the zone is the floor's band; the tier is the container.
##   lock=<item>   the lake chest: it needs that key item and consumes it in the SAME transaction (ctx.consume), the first locked chest of a band holds the band's unique gem (the spot
##                 whose `container` is this tier, claim_spot), later ones are ordinary rolls; without the key: whisper LOOT_LAKE_LOCKED
##   boss=<kind>   the sealed boss chest (it is behind `when=flag:dg_boss_clear`): opening calls LootService.on_boss_defeated(kind, {uid, floor, band, dungeon})
##   hidden=1      invisible and not interactable until the player is within 240 ground px; within the CHEST SENSE (LootMarkers.sense_px: DungeonRun.chest_sense_px() and the species
##                 perk of the hero, never the sum) the glint sprite `unique_glimmer` shows where it is
## A refused opening ({ok = false, reason = &"full"}: the plan does not fit the backpack as a WHOLE) leaves the chest closed and NOT done and changes nothing; LootService whispers why.
## Art: chest_<tier> of A1 (props_features.lua); the lake tier uses `chest_noegle` and, while that art does not exist, chest_konge with a brass padlock drawn in code (honest stub S20).

const OPENED_MODULATE := 0.55
const SOLID_RADIUS := 24.0
const PADLOCK_COLOUR := Color(0.78, 0.56, 0.2)
const PADLOCK_ART := "chest_noegle"
const FALLBACK_ART := "chest_konge"

## test seam: draw the padlock fallback even when chest_noegle exists
static var force_fallback_art: bool = false

var tier: String = "trae"
var role: String = "main"
var lock_item: String = ""
var boss_kind: String = ""
var concealed: bool = false
var cell: Vector2i = Vector2i.ZERO
var area: Node = null
var ctx: Dictionary = {}              # LootMarkers.context_for: dungeon, floor, band, zone, uid
var uid: String = ""
var zone: String = ""
var art_id: String = "chest_trae"
var padlock_drawn: bool = false
var is_open: bool = false             # the chest is spent (darkened) right now
var revealed: bool = true             # a hidden chest becomes revealed once
var glimmer_shown: bool = false

var _sprite: Sprite2D
var _glow: Sprite2D
var _glimmer: Sprite2D
var _padlock: Node2D
var _body: StaticBody2D
var _poll: float = 0.0


static func create_marker(params: Dictionary, p_pos: Vector2, p_cell: Vector2i, p_area: IsoArea) -> Node:
	var c := LootChest2D.new()
	c.setup_marker(params, p_pos, p_cell, p_area)
	return c


## Also usable as `script.new()` + setup_marker (the framework's second entry point); the node is built in _ready.
func setup_marker(params: Dictionary, _p_pos: Vector2, p_cell: Vector2i, p_area: IsoArea) -> void:
	tier = str(params.get("tier", "trae"))
	role = str(params.get("role", "main"))
	lock_item = str(params.get("lock", ""))
	boss_kind = str(params.get("boss", ""))
	concealed = LuaData.int_of(params.get("hidden", 0)) == 1 or str(params.get("hidden", "")) == "true"
	cell = p_cell
	area = p_area
	ctx = LootMarkers.context_for(p_area, p_cell)
	uid = str(ctx["uid"])
	zone = str(ctx["zone"])
	name = "Chest_%s_%d_%d" % [tier, p_cell.x, p_cell.y]
	prompt_key = "LOOT_PROMPT_OPEN"
	radius = Vector2(70, 36)
	# a dungeon cell that was consumed on this seed day is built OPEN (darkened, no prompt): the same room looks the same when the player comes back
	is_open = LootMarkers.is_done(p_area, p_cell, ctx)
	revealed = not concealed or is_open


func _ready() -> void:
	super._ready()
	_build_visuals()
	refresh()
	set_process(concealed and not is_open)


## The signals are connected on every ENTRY into the tree (a parked iso area leaves and re-enters it without a second _ready) and the state is read again at once:
## days may have passed while the area was parked.
func _enter_tree() -> void:
	if not EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.connect(_on_day_started)
	if not EventBus.load_completed.is_connected(_on_load_completed):
		EventBus.load_completed.connect(_on_load_completed)
	if _sprite != null:
		refresh()


# ------------------------------------------------------------------ visuals

func _build_visuals() -> void:
	art_id = "chest_%s" % tier
	padlock_drawn = false
	if tier == "noegle" and (force_fallback_art or not ArtCatalog.has_real_prop(StringName(PADLOCK_ART))):
		art_id = FALLBACK_ART
		padlock_drawn = true
	var art := ArtCatalog.prop(StringName(art_id))
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture = art["texture"]
	_sprite.centered = false
	_sprite.offset = -(art["pivot"] as Vector2)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_sprite)
	var glow: Dictionary = art.get("glow", {}) as Dictionary
	if not glow.is_empty():
		_glow = Sprite2D.new()
		_glow.name = "Glow"
		_glow.texture = glow["texture"]
		var gsize: Vector2 = glow["size"]
		var gt: Texture2D = glow["texture"]
		_glow.scale = Vector2(gsize.x / maxf(gt.get_width(), 1.0), gsize.y / maxf(gt.get_height(), 1.0))
		_glow.position = (glow["center"] as Vector2) - (art["pivot"] as Vector2)
		_glow.modulate = Color(glow["color"] as Color, 0.55)
		_glow.material = Glow.additive_material()
		_glow.z_index = 1
		add_child(_glow)
	if padlock_drawn:
		_padlock = _make_padlock()
		add_child(_padlock)
	_body = StaticBody2D.new()
	_body.name = "Solid"
	_body.collision_layer = Iso.LAYER_WORLD
	_body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := ConvexPolygonShape2D.new()
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Iso.to_screen(Vector2(cos(a), sin(a)) * SOLID_RADIUS))
	sh.points = pts
	cs.shape = sh
	_body.add_child(cs)
	add_child(_body)
	if concealed:
		var gl := ArtCatalog.prop(&"unique_glimmer")
		_glimmer = Sprite2D.new()
		_glimmer.name = "Glimmer"
		_glimmer.texture = gl["texture"]
		_glimmer.centered = false
		_glimmer.offset = -(gl["pivot"] as Vector2)
		_glimmer.material = Glow.additive_material()
		_glimmer.visible = false
		add_child(_glimmer)


## the brass padlock of the lake chest while chest_noegle has no art: a code-drawn shackle and body over the front of the chest
func _make_padlock() -> Node2D:
	var n := Node2D.new()
	n.name = "Padlock"
	n.position = Vector2(0, -34)
	n.z_index = 2
	n.draw.connect(func() -> void:
		n.draw_arc(Vector2(0, -7), 7.0, PI, TAU, 14, PADLOCK_COLOUR.darkened(0.25), 3.0)
		n.draw_rect(Rect2(-9, -2, 18, 14), PADLOCK_COLOUR)
		n.draw_rect(Rect2(-9, -2, 18, 14), PADLOCK_COLOUR.darkened(0.45), false, 1.5)
		n.draw_circle(Vector2(0, 5), 2.0, PADLOCK_COLOUR.darkened(0.55)))
	n.queue_redraw()
	return n


## `when=` of IsoArea: a hidden chest is neither seen nor solid
func set_enabled(on: bool) -> void:
	super.set_enabled(on)
	if _body != null:
		_body.collision_layer = Iso.LAYER_WORLD if on else 0


# ------------------------------------------------------------------ state

## Shows the right state: open (darkened) or closed, hidden or revealed. Cheap; called on day changes, loads and after every interaction.
func refresh() -> void:
	var l := LootMarkers.loot()
	if not bool(ctx.get("dungeon", false)) and l != null and l.has_method("days_left"):
		is_open = int(l.call("days_left", uid, int(l.call("respawn_days_of", zone, tier)))) > 0
	if _sprite == null:
		return
	var dim := OPENED_MODULATE if is_open else 1.0
	_sprite.modulate = Color(dim, dim, dim, 1.0)
	if _glow != null:
		_glow.visible = not is_open and revealed
	_sprite.visible = revealed
	if _padlock != null:
		_padlock.visible = revealed and not is_open
	if _body != null and is_enabled():
		_body.collision_layer = Iso.LAYER_WORLD if revealed else 0
	prompt_key = "LOOT_PROMPT_OPEN" if (not is_open and revealed) else ""
	if _glimmer != null:
		_glimmer.visible = glimmer_shown and not revealed and not is_open


func is_closed() -> bool:
	return not is_open


func _on_day_started(_day: int, _season: StringName) -> void:
	refresh()


func _on_load_completed(_slot: int) -> void:
	refresh()


func _exit_tree() -> void:
	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)
	if EventBus.load_completed.is_connected(_on_load_completed):
		EventBus.load_completed.disconnect(_on_load_completed)


func _process(delta: float) -> void:
	if not concealed or revealed or is_open:
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.15
	update_reveal(LootMarkers.player_distance(self))


## The reveal of a hidden chest for a player at `distance` ground px: within 240 px it shows itself for good; within the chest sense (but farther than 240) its glint shows.
func update_reveal(distance: float) -> void:
	if not concealed or revealed or is_open:
		return
	if distance <= LootMarkers.REVEAL_PX:
		revealed = true
		glimmer_shown = false
		set_process(false)
	else:
		glimmer_shown = distance <= LootMarkers.sense_px()
	refresh()


# ------------------------------------------------------------------ interaction

## The E-query contract (PlayerBody2D.nearest_interactable): an opened or still hidden chest has nothing to give, so a live host in reach wins E.
func is_spent() -> bool:
	return is_open or not revealed


func get_interaction_prompt() -> String:
	return tr(prompt_key) if prompt_key != "" and revealed and not is_open else ""


func interact(player: Node) -> void:
	if not is_enabled() or not revealed:
		return
	if is_open:
		_whisper_resting()
		return
	var l := LootMarkers.loot()
	if l == null:
		return
	var c := ctx.duplicate()
	var res: Dictionary
	if boss_kind != "":
		res = l.call("on_boss_defeated", boss_kind, c)
	elif lock_item != "":
		res = _open_locked(l, c)
	else:
		res = l.call("open_container", zone, tier, uid, c)
	_after(res, player)


## the lake chest: the key is needed (whisper LOOT_LAKE_LOCKED without it) and is consumed in the same transaction; the first one of a band opens the band's spot
func _open_locked(l: Node, c: Dictionary) -> Dictionary:
	if not EconomyManager.has_item(StringName(lock_item), 1):
		EventBus.whisper_requested.emit(LootMarkers.KEY_LAKE_LOCKED)
		return {"ok": false, "results": [], "reason": &"locked"}
	var spot := str(l.call("container_spot", zone, tier))
	if spot != "":
		var cs := c.duplicate()
		cs["lock_ok"] = true
		cs["consume"] = {lock_item: 1}               # the chest's own lock takes ONE key; a spot that also lists the key in requires.items / consume does not take a second
		return l.call("claim_spot", spot, cs)
	c["lock_ok"] = true
	c["consume"] = {lock_item: 1}
	return l.call("open_container", zone, tier, uid, c)


func _after(res: Dictionary, player: Node) -> void:
	var reason := str(res.get("reason", ""))
	if not bool(res.get("ok", false)):
		if reason == "cooldown":
			is_open = true
			refresh()
			_whisper_resting()
		return                                          # full / locked / missing_items: the chest stays closed and NOT done (LootService said why)
	is_open = true
	EventBus.game_event.emit(&"audio_cue",{"cue":"sfx/chest_open"})
	LootMarkers.mark_done(area, cell, ctx)
	LootMarkers.burst(self, global_position + Vector2(0, -30))
	LootMarkers.whisper_found(res)
	refresh()
	interacted.emit(player)


## The chest is spent: it says it fills again in a few days (nothing to say on a dungeon floor, where a spent cell stays spent for the seed day).
func _whisper_resting() -> void:
	EventBus.whisper_requested.emit(LootMarkers.KEY_CHEST_RESTING)
