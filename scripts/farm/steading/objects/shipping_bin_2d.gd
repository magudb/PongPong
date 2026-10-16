class_name ShippingBin2D
extends Interactable2D
var world: Node
var prop_node: Node2D
var _busy := false

static func create_marker(params: Dictionary, _pos: Vector2, cell: Vector2i, area: IsoArea) -> Node:
	var bin := ShippingBin2D.new()
	bin.prop_node = area.place_prop(str(params.get("prop", "shipping_bin")), cell)
	bin.prompt_key = "FARMSITE_BIN_PROMPT"
	bin.world = area.get_tree().get_first_node_in_group("world_2d")
	return bin

func interact(player: Node) -> void:
	if _busy or not is_enabled() or not is_instance_valid(world) or player.get("hotbar") == null:
		return
	var id: StringName = player.hotbar.current()
	var amount := EconomyManager.count_item(id)
	if amount <= 0:
		EventBus.whisper_requested.emit("FARMSITE_BIN_EMPTY")
		return
	var categories: Array = GameManager.config_value("farm_site.bin.categories", ["crop", "product", "forage"])
	if str(ItemKinds.def(id).get("category", "")) not in categories or not EconomyManager.is_sellable(id):
		EventBus.whisper_requested.emit("FARMSITE_BIN_REFUSE")
		return
	_busy = true
	EconomyManager.consume_backpack_items({id: amount}, func():
		world.set_area_flag(&"farm", "bin_" + str(id), int(world.get_area_flag(&"farm", "bin_" + str(id), 0)) + amount)
		EconomyManager.after_transaction(func():
			EventBus.game_event.emit(&"bin_shipped", {"item": str(id), "amount": amount})
			EventBus.whisper_requested.emit(tr("FARMSITE_BIN_PUT") % amount)))
	_busy = false
