class_name PostBox2D
extends Interactable2D
var area: IsoArea
var prop_node: Node2D
var letter: Dictionary = {}
var _busy := false
var _busy_origin: Dictionary = {}
var _busy_ticket: RefCounted
var _attachment: RefCounted
var _refresh_ticket: RefCounted

static func create_marker(params: Dictionary, _pos: Vector2, cell: Vector2i, target: IsoArea) -> Node:
	var box := PostBox2D.new()
	box.area = target
	box.prompt_key = "LIFE_POST_PROMPT"
	if not str(target.map.id).begins_with("int_"):
		box.prop_node = target.place_prop(str(params.get("prop", "mailbox_red")), cell)
	return box

func _ready() -> void:
	super._ready()
	_queue_refresh()

func _enter_tree() -> void:
	_attachment = RefCounted.new()
	EventBus.day_started.connect(_morning)
	if is_node_ready():
		_queue_refresh()

func _exit_tree() -> void:
	_attachment = null
	if EventBus.day_started.is_connected(_morning):
		EventBus.day_started.disconnect(_morning)

func _morning(_day: int, _season: StringName) -> void:
	refresh()

## Independent current world refreshes use p0, never an ambient caller.
## Deferred roots capture before queueing, not when an obsolete callback wakes.
func _queue_refresh() -> void:
	var origin := EventBus.interaction_origin(&"p0")
	if not is_instance_valid(area): return
	_refresh_owned.call_deferred(origin, weakref(area), _attachment)

func refresh() -> void:
	if not is_instance_valid(area): return
	_refresh_owned(EventBus.interaction_origin(&"p0"), weakref(area), _attachment)

func _refresh_current(origin: Dictionary, area_ref: WeakRef, attachment: RefCounted, ticket: RefCounted) -> bool:
	var retained: Variant = area_ref.get_ref()
	var world := PlayerRegistry.world()
	return EventBus.interaction_current(origin) and attachment != null and _attachment == attachment and _refresh_ticket == ticket and is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(retained) and retained.is_inside_tree() and not retained.is_queued_for_deletion() and area == retained and world != null and world.area == retained and retained.is_ancestor_of(self)

func _refresh_owned(origin: Dictionary, area_ref: WeakRef, attachment: RefCounted) -> void:
	var ticket := RefCounted.new()
	_refresh_ticket = ticket
	if not _refresh_current(origin, area_ref, attachment, ticket): return
	var rows: Array[Dictionary] = []
	var selected: Dictionary = {}
	if str(area.map.id) in ["farm", "int_postkontoret"] and GameManager.total_day() > 1 and GameManager.flag_int(&"post_read_day") != GameManager.total_day():
		rows = LifeFlow.offers("post", origin)
		if not _refresh_current(origin, area_ref, attachment, ticket): return
		# Pip's own route is distinct from the everyday merchant giver.
		var pip := QuestManager.offerable_owned("postman_pip", origin)
		if not _refresh_current(origin, area_ref, attachment, ticket): return
		if &"pips_runde" in pip:
			rows.push_front({"quest_id": &"pips_runde", "giver": &"postman_pip"})
		if not rows.is_empty():
			selected = rows[GameManager.total_day() % rows.size()]
			for row in rows:
				if str(row.quest_id) == "pips_runde":
					selected = row
					break
	letter = selected.duplicate()
	if not letter.is_empty() and str(area.map.id) == "farm" and GameManager.flag_int(&"post_toast_day") != GameManager.total_day():
		GameManager.set_flag(&"post_toast_day", GameManager.total_day())
		if not _refresh_current(origin, area_ref, attachment, ticket): return
		EventBus.whisper_requested.emit("LIFE_POST_TOAST")
	if _refresh_current(origin, area_ref, attachment, ticket): queue_redraw()

func _draw() -> void:
	# A paper pennant uses the UI's matte ink/parchment palette above the painted box.
	if not letter.is_empty():
		draw_line(Vector2(35, -50), Vector2(35, -125), Color("35263e"), 4)
		draw_colored_polygon(PackedVector2Array([Vector2(35, -125), Vector2(80, -112), Vector2(35, -96)]), Color("d6a84b"))

func interact(player: Node) -> void:
	if (_busy and LifeFlow.current(_busy_origin, self)) or not is_enabled(): return
	var origin := LifeFlow.service_origin(self, player)
	if origin.is_empty(): return
	var ticket := RefCounted.new()
	_busy = true
	_busy_origin = origin
	_busy_ticket = ticket
	_refresh_owned(origin, weakref(area), _attachment)
	if not LifeFlow.current(origin, self) or _busy_ticket != ticket:
		_finish(ticket)
		return
	if GameManager.total_day() <= 1 or GameManager.flag_int(&"post_read_day") == GameManager.total_day():
		EventBus.whisper_requested.emit("LIFE_POST_EMPTY")
		_finish(ticket)
		return
	var row := letter.duplicate()
	# Reading earns model progress before observers can remove the body. This
	# narrow receipt retains every original model/world/session guard, not UI.
	var receipt := QuestManager.post_read_receipt(origin)
	GameManager.set_flag(&"post_read_day", GameManager.total_day())
	if not EventBus.interaction_current(origin) or _busy_ticket != ticket:
		_finish(ticket)
		return
	letter = {}
	if is_inside_tree(): queue_redraw()
	EventBus.publish_post_read(origin, {"quest_id": str(row.get("quest_id", ""))}, receipt)
	if LifeFlow.current(origin, self) and _busy_ticket == ticket:
		if row.is_empty(): EventBus.whisper_requested.emit("LIFE_POST_EMPTY")
		else: await LifeFlow.offer(self, row, origin)
	_finish(ticket)

func _finish(ticket: RefCounted) -> void:
	if _busy_ticket != ticket: return
	_busy_ticket = null
	_busy_origin = {}
	_busy = false
