class_name Rejsestolpe2D
extends Interactable2D
var stop := ""
var area: IsoArea
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
	var origin := _admit_operation(player)
	if origin == null: return
	var choices: Array = []
	for row in LuaData.arr(GameManager.config_value("traetoppen.fast_travel.stops", [])):
		if str(row.id) != stop and GameManager.flag_int(StringName(str(row.flag))) > 0:
			choices.append({"text_key": "LIFE_STOP_" + str(row.id).to_upper(), "action": "travel", "spawn": str(row.spawn)})
	choices.append({"text_key": "LIFE_LATER", "action": "close"})
	var destination := area.map.id
	var ticket := LifeFlow.request_owned(self, "merchant_pip", [{"text_key": "LIFE_TRAVEL_INTRO"}], choices, origin,
		func(_ticket, result):
			var choice := LuaData.dict(result.get("choice", {}))
			if origin.current() and bool(result.get("completed", false)) and str(choice.get("action", "")) == "travel":
				EventBus.area_change_requested.emit(destination, StringName(str(choice.spawn))))
	if ticket != null: await ticket.wait()
	_finish_operation(origin)
