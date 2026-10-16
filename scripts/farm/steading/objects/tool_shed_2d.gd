class_name ToolShed2D
extends Interactable2D
var prop_node: Node2D
static func create_marker(params: Dictionary, _pos: Vector2, cell: Vector2i, area: IsoArea) -> Node:
	var shed := ToolShed2D.new()
	shed.prop_node = area.place_prop(str(params.get("prop", "tool_shed")), cell)
	shed.prompt_key = "FARMSITE_SHED_PROMPT"
	return shed

func interact(_player: Node) -> void:
	if not is_enabled():
		return
	if not bool(GameManager.get_flag(&"shed_explained", false)):
		GameManager.set_flag(&"shed_explained", 1)
		EventBus.whisper_requested.emit("FARMSITE_SHED_WHISPER")
	EventBus.game_event.emit(&"open_home_chest", {})
