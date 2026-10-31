class_name NoticeBoard2D
extends Interactable2D
var _busy := false
var _busy_origin: Dictionary = {}
var _busy_ticket: RefCounted
static func create_marker(_params: Dictionary, _pos: Vector2, _cell: Vector2i, _area: IsoArea) -> Node:
	var board := NoticeBoard2D.new()
	board.prompt_key = "LIFE_BOARD_PROMPT"
	return board

func rows(origin: Dictionary = {}) -> Array[Dictionary]:
	return LifeFlow.offers("board", origin).slice(0, maxi(0, int(GameManager.config_value("traetoppen.board.max", 5))))

func interact(player: Node) -> void:
	if (_busy and LifeFlow.current(_busy_origin, self)) or not is_enabled():
		return
	var origin := LifeFlow.service_origin(self, player)
	if origin.is_empty(): return
	var ticket := RefCounted.new()
	_busy = true
	_busy_origin = origin
	_busy_ticket = ticket
	var offers := rows(origin)
	if not LifeFlow.current(origin, self) or _busy_ticket != ticket:
		_finish(ticket)
		return
	if offers.is_empty():
		EventBus.whisper_requested.emit("LIFE_BOARD_EMPTY")
		_finish(ticket)
		return
	_busy = true
	var choices: Array = []
	for row in offers:
		choices.append({"text_key": "QUEST_%s_TITLE" % str(row.quest_id).to_upper(), "action": "offer", "quest_id": str(row.quest_id), "giver": str(row.giver)})
	choices.append({"text_key": "LIFE_LATER", "action": "close"})
	var result := await LifeFlow.ask(self, "mayor_lyra", [{"text_key": "LIFE_BOARD_INTRO"}], choices, origin)
	if LifeFlow.current(origin, self) and _busy_ticket == ticket:
		var choice := LuaData.dict(result.get("choice", {}))
		if str(choice.get("action", "")) == "offer":
			await LifeFlow.offer(self, choice, origin)
	_finish(ticket)

func _finish(ticket: RefCounted) -> void:
	if _busy_ticket != ticket: return
	_busy_ticket = null
	_busy_origin = {}
	_busy = false
