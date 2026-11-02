class_name PostBox2D
extends Interactable2D
var area: IsoArea
var prop_node: Node2D
var letter: Dictionary = {}
var _busy := false
var _busy_origin: RefCounted
func _admit_operation(player: Variant) -> RefCounted:
	if not is_enabled() or (_busy_origin != null and _busy_origin.current()): return null
	var origin: RefCounted = preload("res://scripts/traetoppen/life/presenter_origin.gd").capture(self, player)
	if origin == null: return null
	_busy_origin = origin
	_busy = true
	return origin

func _finish_operation(origin: RefCounted) -> void:
	if _busy_origin != origin: return
	_busy_origin = null
	_busy = false


static func create_marker(params: Dictionary, _pos: Vector2, cell: Vector2i, target: IsoArea) -> Node:
	var box := PostBox2D.new()
	box.area = target
	box.prompt_key = "LIFE_POST_PROMPT"
	if not str(target.map.id).begins_with("int_"):
		box.prop_node = target.place_prop(str(params.get("prop", "mailbox_red")), cell)
	return box

func _ready() -> void:
	super._ready()
	refresh.call_deferred()

func _enter_tree() -> void:
	EventBus.day_started.connect(_morning)
	if is_node_ready():
		refresh.call_deferred()

func _exit_tree() -> void:
	if EventBus.day_started.is_connected(_morning):
		EventBus.day_started.disconnect(_morning)

func _morning(_day: int, _season: StringName) -> void:
	refresh()

func refresh() -> void:
	var origin: RefCounted = preload("res://scripts/traetoppen/life/presenter_origin.gd").capture(self)
	if origin != null: _refresh_owned(origin)

func _refresh_owned(origin: RefCounted) -> void:
	if not origin.current(): return
	letter = {}
	if area == null or str(area.map.id) not in ["farm", "int_postkontoret"] or GameManager.total_day() <= 1 or GameManager.flag_int(&"post_read_day") == GameManager.total_day():
		queue_redraw()
		return
	var rows: Array = origin.call_owned(func(): return LifeFlow.offers("post"))
	# Pip's route is his own quest (postman_pip); merchant_pip is a different
	# everyday giver in the older six-giver configuration.
	if &"pips_runde" in origin.call_owned(func(): return QuestManager.offerable("postman_pip")):
		rows.push_front({"quest_id": &"pips_runde", "giver": &"postman_pip"})
	if not rows.is_empty():
		letter = rows[GameManager.total_day() % rows.size()]
		for row in rows:
			if str(row.quest_id) == "pips_runde":
				letter = row
				break
		if str(area.map.id) == "farm" and GameManager.flag_int(&"post_toast_day") != GameManager.total_day():
			GameManager.set_flag(&"post_toast_day", GameManager.total_day())
			if not origin.current(): return
			EventBus.whisper_requested.emit("LIFE_POST_TOAST")
	queue_redraw()

func _draw() -> void:
	# A paper pennant uses the UI's matte ink/parchment palette above the painted box.
	if not letter.is_empty():
		draw_line(Vector2(35, -50), Vector2(35, -125), Color("35263e"), 4)
		draw_colored_polygon(PackedVector2Array([Vector2(35, -125), Vector2(80, -112), Vector2(35, -96)]), Color("d6a84b"))

func interact(player: Node) -> void:
	var origin := _admit_operation(player)
	if origin == null: return
	_refresh_owned(origin)
	if not origin.current():
		_finish_operation(origin)
		return
	if GameManager.total_day() <= 1 or GameManager.flag_int(&"post_read_day") == GameManager.total_day():
		EventBus.whisper_requested.emit("LIFE_POST_EMPTY")
		_finish_operation(origin)
		return
	var row := letter.duplicate()
	GameManager.set_flag(&"post_read_day", GameManager.total_day())
	if not origin.current():
		_finish_operation(origin)
		return
	letter.clear()
	queue_redraw()
	origin.call_owned(func(): EventBus.game_event.emit(&"post_read", {"quest_id": str(row.get("quest_id", ""))}))
	if not origin.current():
		_finish_operation(origin)
		return
	if row.is_empty():
		EventBus.whisper_requested.emit("LIFE_POST_EMPTY")
	else:
		var offer := LifeFlow.offer_request_owned(self, row, origin)
		if offer != null: await offer.wait()
	_finish_operation(origin)
