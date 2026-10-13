extends Control
## Shop UI: buy/sell tabs, item list, transaction feedback.

signal transaction_complete(shop_id: StringName, item_id: StringName, amount: int, is_buy: bool)

@onready var shop_name_label: Label = %ShopNameLabel
@onready var tab_container: TabContainer = %TabContainer
@onready var buy_list: ItemList = %BuyList
@onready var sell_list: ItemList = %SellList
@onready var quantity_spin: SpinBox = %QuantitySpin
@onready var buy_btn: Button = %BuyButton
@onready var sell_btn: Button = %SellButton
@onready var gold_label: Label = %GoldLabel
@onready var close_btn: Button = %CloseButton

var current_shop: StringName = &""


func _ready() -> void:
	visible = false
	buy_btn.pressed.connect(_on_buy)
	sell_btn.pressed.connect(_on_sell)
	close_btn.pressed.connect(_close)
	EventBus.shop_opened.connect(_on_shop_opened)
	EventBus.shop_closed.connect(_on_shop_closed)
	EventBus.gold_changed.connect(_on_gold_changed)


func _on_shop_opened(shop_id: StringName) -> void:
	current_shop = shop_id
	visible = true
	shop_name_label.text = tr("SHOP_%s" % str(shop_id).to_upper())
	_populate_buy()
	_populate_sell()
	_on_gold_changed(EconomyManager.gold, 0)
	GameManager.change_phase(GameManager.GamePhase.PAUSED)


func _on_shop_closed(_shop_id: StringName) -> void:
	visible = false
	GameManager.change_phase(GameManager.GamePhase.PLAYING)


func _populate_buy() -> void:
	buy_list.clear()
	var inventory: Array = ShopSystem.get_shop_inventory(current_shop)
	for entry in inventory:
		if entry["stock"] <= 0:
			continue
		var text := "%s — %d guld (x%d)" % [
			tr(entry["name_key"]),
			entry["price"],
			entry["stock"]
		]
		buy_list.add_item(text)
		buy_list.set_item_metadata(buy_list.item_count - 1, entry)


func _populate_sell() -> void:
	sell_list.clear()
	var inv: Dictionary = EconomyManager.get_inventory_dict()
	for item_id in inv:
		var price: int = ShopSystem.get_sell_price(current_shop, StringName(item_id))
		var text := "%s x%d — %d guld" % [
			tr("ITEM_%s" % str(item_id).to_upper()),
			inv[item_id],
			price
		]
		sell_list.add_item(text)
		sell_list.set_item_metadata(sell_list.item_count - 1, {
			"item_id": item_id,
			"price": price,
			"amount": inv[item_id],
		})


func _on_buy() -> void:
	var selected := buy_list.get_selected_items()
	if selected.is_empty():
		return
	var entry: Dictionary = buy_list.get_item_metadata(selected[0])
	var amount := int(quantity_spin.value)
	if ShopSystem.buy_item(current_shop, StringName(entry["item_id"]), amount):
		_populate_buy()
		_populate_sell()
		transaction_complete.emit(current_shop, StringName(entry["item_id"]), amount, true)


func _on_sell() -> void:
	var selected := sell_list.get_selected_items()
	if selected.is_empty():
		return
	var entry: Dictionary = sell_list.get_item_metadata(selected[0])
	var amount := int(quantity_spin.value)
	if ShopSystem.sell_item(current_shop, StringName(entry["item_id"]), amount):
		_populate_buy()
		_populate_sell()
		transaction_complete.emit(current_shop, StringName(entry["item_id"]), amount, false)


func _on_gold_changed(amount: int, _delta: int) -> void:
	if gold_label:
		gold_label.text = "%s: %d" % [tr("UI_GOLD"), amount]


func _close() -> void:
	ShopSystem.close_shop(current_shop)
