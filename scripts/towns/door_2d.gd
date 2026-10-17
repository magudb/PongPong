class_name Door2D
extends Warp2D
## The door of a building (marker `door building=<id>`, T-towns-core, TOWNS addendum 4.2 / DT49): a Warp2D that knows the OPENING HOURS. Outside: the door sits on the doorstep cell, travels to
## the building's interior area (spawn `default`) and creates the arrival spawn `from_int_<building>` one cell in front of it; inside: the exit door of an InteriorRoom (`always_open`: closing time
## EVICTS, it never traps). Lifted from D3/final_editor/te1/drafts/door_2d.gd and edited: no class of a later wave is named (Routines is reached through Hours.where_is, a path string), a
## nameplate door is a first-class state, the sign is built here.
##
## is_open() and the reason of a refusal (last_reason; one whisper per approach through EventBus.whisper_requested, no travel):
##   hours      before opening / after closing        HOURS_CLOSED_NOW  "Lukket lige nu. Aabner kl. 07:00."
##   day        a closed weekday                      HOURS_CLOSED_DAY  "Lukket i dag. Aabner igen tirsdag."
##   festival   closed by a festival (SocialManager)  HOURS_CLOSED_FESTIVAL
##   away       a home whose owner is out or asleep   HOURS_HOME_AWAY
##   stranger   a home, friend flag friend_<npc> < 1  HOURS_HOME_STRANGER
##   locked     a NAMEPLATE door: no room built, a decor hut, or no registry row at all (hyggebyen.map carries door markers of the EXTENDED buildings whose rows are T-ext-content's and
##              may be dropped); labelled with the convention key BLD_<BUILDING_ID> of towns.csv. Without Routines (wave 4) every home is a locked nameplate as well.
##              HOURS_HOME_LOCKED "Doeren er laast."
## Homes open only while the owner is at home AND awake (Routines.where_is: state stay | inside, place int_<building>, act not sleep) and the friend flag friend_<npc> >= 1
## (SocialManager.hearts first, then the flag). The switch config towns.hours_enabled off = the opening-hours rule does not exist: shops and services are always open.
## THE SIGN (a world Label within 3 cells of the door, no screen): the name BLD_<ID> over HOURS_SIGN "%s - aabent %s-%s", plus "Lukket: tirsdag" when the building is closed on weekdays;
## when the I3 kit is baked the sign bracket and the emblem plate of the building row (`emblem = "seed"`) are drawn above the door (no glyph is ever baked into art).

const _Svc := preload("res://scripts/data/svc.gd")
const SIGN_CELLS := 3.0
const SIGN_OFFSET := Vector2(0, -250)
const SIGN_FONT_SIZE := 54
const EMBLEM_OFFSET := Vector2(0, -330)

var building_id: String = ""
var owner_npc: String = ""
var min_hearts: int = 1
var always_open: bool = false
## A nameplate door: never opens (the whisper says so).
var locked: bool = false
## Tests: a fixed moment instead of the live clock (a Hours context).
var ctx_override: Dictionary = {}
var last_reason: String = "open"
var last_opens_at: float = 0.0
var last_next_weekday: int = -1
var last_state: Dictionary = {}
var name_key: String = ""
var sign_label: Label
var emblem_sprite: Sprite2D
var bracket_sprite: Sprite2D

var _sign_zone: Area2D
var _sign_near := false


## The marker handler of `door` (contract of IsoArea.resolve_handler: static create_marker(params, pos, cell, area) -> Node): builds the door on the doorstep cell, adds it to the area's
## triggers and creates the arrival spawn from_int_<building> one cell in front of it.
static func create_marker(params: Dictionary, pos: Vector2, cell: Vector2i, area: IsoArea) -> Node:
	var d := Door2D.new()
	d.setup_building(params, area, cell)
	d.position = area.to_local(pos)
	area.triggers.add_child(d)
	if d.building_id != "":
		area.spawns["from_int_" + d.building_id] = area.cell_to_global(cell + Vector2i(0, 1))
	return d


## m: the marker parameters {building, interior?, always_open?, to?, spawn?, label?}. The row of the building comes from the buildings registry.
func setup_building(m: Dictionary, area: IsoArea, cell: Vector2i) -> void:
	building_id = str(m.get("building", ""))
	always_open = bool(m.get("always_open", false))
	var b: Dictionary = Hours.building(building_id)
	owner_npc = str(b.get("owner", ""))
	name_key = str(b.get("name_key", "BLD_%s" % building_id.to_upper())) if building_id != "" else ""
	var interior: String = str(m.get("to", m.get("interior", b.get("interior", ""))))
	if interior == "":
		interior = str(b.get("interior", ""))
	var mm: Dictionary = m.duplicate()
	mm["to"] = interior
	# a nameplate: no room to go to (no `interior`), a decor hut, or no row at all
	locked = not always_open and building_id != "" and (interior == "" or b.is_empty() or str(b.get("kind", "")) == "decor")
	setup(mm, area, cell)
	if building_id != "":
		name = "Door_%s" % building_id


func _ready() -> void:
	if always_open or building_id == "":
		return
	_build_sign()
	var bus := _Svc.node("EventBus")
	if bus != null: bus.modal_changed.connect(func(_stack): _sign_visibility())


# ------------------------------------------------------------------------------------------------ the rule

func is_open() -> bool:
	last_reason = "open"
	last_state = {}
	if locked:
		last_reason = "locked"
		return false
	if always_open or building_id == "":
		return true
	var ctx: Dictionary = ctx_override if not ctx_override.is_empty() else Hours.now_ctx()
	var b: Dictionary = Hours.building(building_id)
	if b.has("hours"):
		if not Hours.enabled():
			return true
		var st: Dictionary = Hours.state(building_id, ctx)
		last_state = st
		last_reason = str(st["reason"])
		last_opens_at = float(st["opens_at"])
		last_next_weekday = int(st["next_weekday"])
		return bool(st["open"])
	if owner_npc != "":                                    # a home: the owner is in it, awake, and the friendship allows it
		var w: Variant = Hours.where_is(owner_npc, ctx)
		if not (w is Dictionary):
			last_reason = "locked"                          # no Routines (wave 4): every home is a locked nameplate
			return false
		var wd: Dictionary = w
		var home_ok: bool = str(wd.get("state", "")) in ["stay", "inside"] and str(wd.get("place", "")).begins_with("int_%s" % building_id) and str(wd.get("act", "")) != "sleep"
		var hearts_ok: bool = _hearts(owner_npc, ctx) >= min_hearts
		last_reason = "open" if (home_ok and hearts_ok) else ("away" if not home_ok else "stranger")
		return home_ok and hearts_ok
	return true


## Hearts of the owner: the context of the routines when it carries them (Routines.now_ctx), else SocialManager, else the friend flag.
func _hearts(npc: String, ctx: Dictionary) -> int:
	var table: Variant = ctx.get("hearts", null)
	if table is Dictionary and (table as Dictionary).has(npc):
		return int((table as Dictionary)[npc])
	return Hours.hearts_of(npc)


## The translation key of the current refusal (towns.csv HOURS_*).
func closed_key() -> String:
	match last_reason:
		"hours":
			return "HOURS_CLOSED_NOW"
		"day":
			return "HOURS_CLOSED_DAY"
		"festival":
			return "HOURS_CLOSED_FESTIVAL"
		"away":
			return "HOURS_HOME_AWAY"
		"stranger":
			return "HOURS_HOME_STRANGER"
		"locked":
			return "HOURS_HOME_LOCKED"
	return "WORLD_WARP_LOCKED"


## The whisper text of the current refusal: tr(KEY) % args (the opening time, the weekday).
func whisper_text() -> String:
	match last_reason:
		"hours", "day", "festival":
			return Hours.closed_text(last_state)
	return tr(closed_key())


func _on_body_entered(body: Node) -> void:
	if not armed or not body.is_in_group("player"):
		return
	if not is_open():
		if not _told:
			_told = true
			EventBus.whisper_requested.emit(whisper_text())
		return
	EventBus.area_change_requested.emit(to_area, to_spawn)


# ------------------------------------------------------------------------------------------------ the sign

## The text of the sign now: the name (BLD_<ID>) over HOURS_SIGN with today's hours, plus the closed weekdays. A nameplate shows the name only.
func sign_text() -> String:
	var title: String = TranslationServer.translate(name_key) if name_key != "" else ""
	var b: Dictionary = Hours.building(building_id)
	if locked or not b.has("hours") or always_open:
		return title
	var today: int = int(Hours.now_ctx()["weekday"]) if ctx_override.is_empty() else int(ctx_override.get("weekday", 0))
	var oc: Array = Hours.hours_on(b, today)
	var line: String = TranslationServer.translate("HOURS_SIGN") % [title, Hours.format_hour_short(float(oc[0])), Hours.format_hour_short(float(oc[1]))]
	var closed: Array = Hours.closed_days(b)
	if not closed.is_empty():
		var names: PackedStringArray = PackedStringArray()
		for wd in closed:
			names.append(Hours.weekday_text(int(wd)))
		line += "\n" + TranslationServer.translate("HOURS_SIGN_DAYS") % ", ".join(names)
	return line


func _build_sign() -> void:
	sign_label = Label.new()
	sign_label.name = "Sign"
	sign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	sign_label.z_index = Iso.Z_FLYING
	sign_label.z_as_relative = false
	sign_label.add_theme_font_size_override("font_size", SIGN_FONT_SIZE)
	sign_label.add_theme_color_override("font_color", Color("fbf5e6"))
	sign_label.add_theme_color_override("font_outline_color", Color("2b2340"))
	sign_label.add_theme_constant_override("outline_size", 14)
	sign_label.visible = false
	sign_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sign_label)
	_refresh_sign()
	# the plate of the I3 kit above the door, when it is baked: sign bracket + emblem (nothing is drawn while the art is missing)
	var b: Dictionary = Hours.building(building_id)
	var emblem_id: String = str(b.get("emblem", ""))
	if emblem_id != "":
		var plate: Dictionary = PieceCatalog.emblem(emblem_id)
		if not plate.is_empty():
			var bracket: Dictionary = PieceCatalog.sign_bracket()
			if not bracket.is_empty() and str(bracket["file"]) != "":
				bracket_sprite = Sprite2D.new()
				bracket_sprite.name = "SignBracket"
				bracket_sprite.texture = PieceCatalog.texture(str(bracket["file"]))
				bracket_sprite.centered = false
				bracket_sprite.offset = -(bracket["pivot"] as Vector2)
				bracket_sprite.position = EMBLEM_OFFSET
				bracket_sprite.z_index = Iso.Z_FLYING
				bracket_sprite.z_as_relative = false
				add_child(bracket_sprite)
			emblem_sprite = Sprite2D.new()
			emblem_sprite.name = "Emblem"
			emblem_sprite.texture = plate["texture"]
			emblem_sprite.centered = false
			emblem_sprite.offset = -(plate["pivot"] as Vector2)
			emblem_sprite.position = EMBLEM_OFFSET
			emblem_sprite.z_index = Iso.Z_FLYING
			emblem_sprite.z_as_relative = false
			add_child(emblem_sprite)
	# within 3 cells: a ground ellipse of 3 cell widths around the doorstep (the sign shows while the player stands inside it)
	_sign_zone = Area2D.new()
	_sign_zone.name = "SignZone"
	_sign_zone.collision_layer = 0
	_sign_zone.collision_mask = Iso.LAYER_PLAYER
	var cs := CollisionShape2D.new()
	var sh := ConvexPolygonShape2D.new()
	var pts := PackedVector2Array()
	var cell_ground: float = float(Iso.TILE_W) * 0.7071
	for i in 16:
		var a: float = TAU * float(i) / 16.0
		pts.append(Iso.to_screen(Vector2(cos(a), sin(a)) * cell_ground * SIGN_CELLS))
	sh.points = pts
	cs.shape = sh
	_sign_zone.add_child(cs)
	add_child(_sign_zone)
	_sign_zone.body_entered.connect(_on_sign_zone_entered)
	_sign_zone.body_exited.connect(_on_sign_zone_exited)
	_position_sign()


func _position_sign() -> void:
	if sign_label == null:
		return
	sign_label.size = Vector2.ZERO
	var size: Vector2 = sign_label.get_minimum_size()
	sign_label.position = SIGN_OFFSET - Vector2(size.x * 0.5, size.y)


func _refresh_sign() -> void:
	if sign_label == null:
		return
	sign_label.text = sign_text()
	_position_sign()


func _on_sign_zone_entered(body: Node) -> void:
	if body.is_in_group("player") and sign_label != null:
		_refresh_sign()
		_sign_near = true
		_sign_visibility()


func _on_sign_zone_exited(body: Node) -> void:
	if body.is_in_group("player") and sign_label != null:
		_sign_near = false
		_sign_visibility()

func _sign_visibility() -> void:
	if sign_label == null:return
	var gm := _Svc.node("GameManager")
	sign_label.visible = _sign_near and (gm == null or not gm.is_modal_open())
