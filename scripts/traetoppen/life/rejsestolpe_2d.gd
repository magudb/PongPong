class_name Rejsestolpe2D
extends Interactable2D
var stop := ""
var area: IsoArea
var _busy := false
var _busy_origin: Dictionary = {}
var _busy_ticket: RefCounted
static func create_marker(params: Dictionary, _pos: Vector2, _cell: Vector2i, target: IsoArea) -> Node:
	var signpost := Rejsestolpe2D.new()
	signpost.stop = str(params.get("id", "farm"))
	signpost.area = target
	signpost.prompt_key = "LIFE_TRAVEL_PROMPT"
	return signpost
func _process(_delta: float) -> void:
	if GameManager.flag_int(StringName("ft_" + stop)) != 0:
		set_process(false)
		return
	var player := PlayerRegistry.local_player(get_tree()) as Node2D
	if player != null and Iso.to_ground(player.global_position - global_position).length() < 200:
		GameManager.set_flag(StringName("ft_" + stop), 1)
func interact(player: Node) -> void:
	if (_busy and LifeFlow.current(_busy_origin, self)) or not is_enabled(): return
	var origin := LifeFlow.service_origin(self, player)
	if origin.is_empty(): return
	var ticket := RefCounted.new()
	_busy = true
	_busy_origin = origin
	_busy_ticket = ticket
	var choices: Array = []
	for row in LuaData.arr(GameManager.config_value("traetoppen.fast_travel.stops", [])):
		if str(row.id) != stop and GameManager.flag_int(StringName(str(row.flag))) > 0:
			choices.append({"text_key": "LIFE_STOP_" + str(row.id).to_upper(), "action": "travel", "spawn": str(row.spawn)})
	choices.append({"text_key": "LIFE_LATER", "action": "close"})
	var result := await LifeFlow.ask(self, "merchant_pip", [{"text_key": "LIFE_TRAVEL_INTRO"}], choices, origin)
	var choice := LuaData.dict(result.get("choice", {}))
	if _busy_ticket == ticket and LifeFlow.current(origin, self) and str(choice.get("action", "")) == "travel":
		EventBus.area_change_requested.emit(area.map.id, StringName(str(choice.spawn)))
	_finish(ticket)

func _finish(ticket: RefCounted) -> void:
	if _busy_ticket != ticket: return
	_busy_ticket = null
	_busy_origin = {}
	_busy = false
