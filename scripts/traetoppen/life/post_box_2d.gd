class_name PostBox2D
extends Interactable2D
var area: IsoArea
var prop_node: Node2D
var letter: Dictionary = {}
var _busy := false

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
	letter = {}
	if area == null or str(area.map.id) != "farm" or GameManager.total_day() <= 1 or GameManager.flag_int(&"post_read_day") == GameManager.total_day():
		queue_redraw()
		return
	var rows := LifeFlow.offers("post")
	# Pip's route is his own quest (postman_pip); merchant_pip is a different
	# everyday giver in the older six-giver configuration.
	if &"pips_runde" in QuestManager.offerable("postman_pip"):
		rows.push_front({"quest_id": &"pips_runde", "giver": &"postman_pip"})
	if not rows.is_empty():
		letter = rows[GameManager.total_day() % rows.size()]
		for row in rows:
			if str(row.quest_id) == "pips_runde":
				letter = row
				break
		if GameManager.flag_int(&"post_toast_day") != GameManager.total_day():
			GameManager.set_flag(&"post_toast_day", GameManager.total_day())
			EventBus.whisper_requested.emit("LIFE_POST_TOAST")
	queue_redraw()

func _draw() -> void:
	# A paper pennant uses the UI's matte ink/parchment palette above the painted box.
	if not letter.is_empty():
		draw_line(Vector2(35, -50), Vector2(35, -125), Color("35263e"), 4)
		draw_colored_polygon(PackedVector2Array([Vector2(35, -125), Vector2(80, -112), Vector2(35, -96)]), Color("d6a84b"))

func interact(_player: Node) -> void:
	if _busy or not is_enabled():
		return
	if str(area.map.id) != "farm":
		EventBus.whisper_requested.emit("LIFE_POST_OFFICE")
		return
	refresh()
	if GameManager.total_day() <= 1 or GameManager.flag_int(&"post_read_day") == GameManager.total_day():
		EventBus.whisper_requested.emit("LIFE_POST_EMPTY")
		return
	_busy = true
	var row := letter.duplicate()
	GameManager.set_flag(&"post_read_day", GameManager.total_day())
	letter.clear()
	queue_redraw()
	EventBus.game_event.emit(&"post_read", {"quest_id": str(row.get("quest_id", ""))})
	if row.is_empty():
		EventBus.whisper_requested.emit("LIFE_POST_EMPTY")
	else:
		await LifeFlow.offer(self, row)
	_busy = false
