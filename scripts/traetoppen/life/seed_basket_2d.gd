class_name SeedBasket2D
extends Interactable2D
var _busy := false
static func create_marker(_params: Dictionary, _pos: Vector2, _cell: Vector2i, _area: IsoArea) -> Node:
	var basket := SeedBasket2D.new()
	basket.prompt_key = "LIFE_SWAP_PROMPT"
	return basket

func swap() -> Dictionary:
	if _busy:
		return {"ok": false, "reason": "busy"}
	if GameManager.flag_int(&"swap_day") == GameManager.total_day():
		return {"ok": false, "reason": "LIFE_SWAP_USED"}
	var needs := LuaData.dict(GameManager.config_value("traetoppen.swap.give", {"carrot": 2}))
	if not EconomyManager.has_items(needs):
		return {"ok": false, "reason": "LIFE_SWAP_NEED"}
	var weights := LuaData.dict(GameManager.config_value("traetoppen.swap.table", {"moonflower_seeds": 3, "glow_berry_seeds": 2}))
	var sum := 0
	for value in weights.values():
		sum += maxi(0, int(value))
	if sum <= 0:
		return {"ok": false, "reason": "LIFE_SWAP_NEED"}
	var roll := randi_range(1, sum)
	var item := &""
	for id in weights:
		roll -= maxi(0, int(weights[id]))
		if roll <= 0:
			item = StringName(str(id))
			break
	# Conservative fitting: never take the carrots on a full bag, even if that
	# deduction would open a slot. The reward must fit before the transaction.
	if item == &"" or not EconomyManager.can_add_item(item, 1):
		return {"ok": false, "reason": "LIFE_BAG_FULL"}
	_busy = true
	var ok := EconomyManager.consume_backpack_items(needs, func():
		GameManager.set_flag(&"swap_day", GameManager.total_day())
		EconomyManager.add_item(item, 1, true))
	_busy = false
	return {"ok": ok, "item": str(item), "reason": "" if ok else "LIFE_SWAP_NEED"}

func interact(_player: Node) -> void:
	if not is_enabled():
		return
	var result := swap()
	if bool(result.ok):
		EventBus.whisper_requested.emit(tr("LIFE_SWAP_DONE") % tr(str(EconomyManager.item_def(StringName(result.item)).get("name_key", result.item))))
	elif str(result.reason) != "busy":
		EventBus.whisper_requested.emit(str(result.reason))
