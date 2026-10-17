extends Interactable2D
var area: IsoArea
var item := &""
var cell := Vector2i.ZERO
var picture: Node2D
var _taking := false
func _init() -> void:
	prompt_key = "ANIMAL_DECOR_PICKUP"
func interact(_player: Node) -> void:
	if _taking: return
	var world := get_tree().get_first_node_in_group("world_2d")
	if world == null: return
	var index := -1
	for i in world.placed_items.size():
		var entry: Dictionary = world.placed_items[i]
		if str(entry.get("area", "farm")) == str(area.map.id) and str(entry.get("item","")) == str(item) and entry.get("cell") == [cell.x,cell.y]: index = i
	if index < 0: return
	_taking = true
	var received := EconomyManager.receive_backpack_item(item,1,func(): world.placed_items.remove_at(index))
	if received:
		area.remove_prop(picture)
	else:
		_taking = false
		EventBus.whisper_requested.emit("KISTE_FULL")
