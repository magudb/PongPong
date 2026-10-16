class_name NoticeBoard2D
extends Interactable2D
var _busy := false
static func create_marker(_params: Dictionary, _pos: Vector2, _cell: Vector2i, _area: IsoArea) -> Node:
	var board := NoticeBoard2D.new()
	board.prompt_key = "LIFE_BOARD_PROMPT"
	return board

func rows() -> Array[Dictionary]:
	return LifeFlow.offers("board").slice(0, maxi(0, int(GameManager.config_value("traetoppen.board.max", 5))))

func interact(_player: Node) -> void:
	if _busy or not is_enabled():
		return
	var offers := rows()
	if offers.is_empty():
		EventBus.whisper_requested.emit("LIFE_BOARD_EMPTY")
		return
	_busy = true
	var choices: Array = []
	for row in offers:
		choices.append({"text_key": "QUEST_%s_TITLE" % str(row.quest_id).to_upper(), "action": "offer", "quest_id": str(row.quest_id), "giver": str(row.giver)})
	choices.append({"text_key": "LIFE_LATER", "action": "close"})
	var result := await LifeFlow.ask(self, "mayor_lyra", [{"text_key": "LIFE_BOARD_INTRO"}], choices)
	if is_inside_tree():
		var choice := LuaData.dict(result.get("choice", {}))
		if str(choice.get("action", "")) == "offer":
			await LifeFlow.offer(self, choice)
	_busy = false
