class_name NoticeBoard2D
extends Interactable2D
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

static func create_marker(_params: Dictionary, _pos: Vector2, _cell: Vector2i, _area: IsoArea) -> Node:
	var board := NoticeBoard2D.new()
	board.prompt_key = "LIFE_BOARD_PROMPT"
	return board

func rows() -> Array[Dictionary]:
	return LifeFlow.offers("board").slice(0, maxi(0, int(GameManager.config_value("traetoppen.board.max", 5))))

func interact(player: Node) -> void:
	var origin := _admit_operation(player)
	if origin == null: return
	var offers: Array = origin.call_owned(rows)
	if offers.is_empty():
		EventBus.whisper_requested.emit("LIFE_BOARD_EMPTY")
		_finish_operation(origin)
		return
	var choices: Array = []
	for row in offers:
		choices.append({"text_key": "QUEST_%s_TITLE" % str(row.quest_id).to_upper(), "action": "offer", "quest_id": str(row.quest_id), "giver": str(row.giver)})
	choices.append({"text_key": "LIFE_LATER", "action": "close"})
	var next: Array = []
	var ticket := LifeFlow.request_owned(self, "mayor_lyra", [{"text_key": "LIFE_BOARD_INTRO"}], choices, origin,
		func(_ticket, result):
			var choice := LuaData.dict(result.get("choice", {}))
			if bool(result.get("completed", false)) and str(choice.get("action", "")) == "offer":
				next.append(LifeFlow.offer_request_owned(self, choice, origin)))
	if ticket != null: await ticket.wait()
	if not next.is_empty() and next[0] != null: await next[0].wait()
	_finish_operation(origin)
