extends TTScreen
## The shop owns presentation; ShopSystem owns stock, prices and transactions.
signal transaction_complete(shop_id: StringName, item_id: StringName, amount: int, is_buy: bool)
const Fmt := preload("res://scripts/ui/theme/tt_format.gd")
const Portraits := preload("res://scripts/ui/theme/tt_portraits.gd")
const Row := preload("res://scripts/ui/components/shop_item_row.gd")
const HoursText := preload("res://scripts/towns/hours.gd")
const Prices := preload("res://scripts/economy/price_curve.gd")
const Talk := "res://scripts/social/talk/social_talk.gd"
@onready var stepper: Control = %Stepper
@onready var item_grid: GridContainer = %ItemGrid
@onready var buy_btn: Button = %BuyButton
@onready var total_label: Label = %TotalLabel
@onready var gold_label: Label = %GoldLabel
@onready var close_btn: Button = %CloseButton
@onready var keeper_speech: Label = %KeeperSpeech
var current_shop: StringName = &"seed_shop"
var farming_stats: Label
var equipment_stats: Label
var _tabs: Array = []
var _tab_buttons: Array[Button] = []
var _rows: Array[Button] = []
var _row_cache: Dictionary = {}
var _row_group := ButtonGroup.new()
var _tab := 0
var _selected_id: StringName = &""
var _selected: Dictionary = {}
var _info: Dictionary = {}
var _greeting_key := ""
var _busy := false
var _refresh_pending := false
var _closing := false
var _displayed_unit := 0

func _init() -> void:
	super._init()
	screen_id = &"shop_ui"
	modal_name = &"shop"

func _ready() -> void:
	super._ready()
	farming_stats = preload("res://scripts/ui/components/farming_details.gd").create(%DetailDesc)
	_row_group.set_meta("tt_value_selection", true)
	equipment_stats = Label.new()
	equipment_stats.name = "EquipmentStats"
	equipment_stats.theme_type_variation = &"Small14"
	equipment_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equipment_stats.hide()
	var details := %DetailState.get_parent()
	details.add_child(equipment_stats)
	details.move_child(equipment_stats,%DetailState.get_index())
	close_btn.pressed.connect(close)
	buy_btn.pressed.connect(_confirm)
	stepper.value_changed.connect(func(_value): _footer())
	stepper.committed.connect(func(_value): _confirm())
	EventBus.shop_opened.connect(_shop_opened)
	EventBus.shop_closed.connect(_shop_closed)
	EventBus.gold_changed.connect(func(_gold, _delta): _schedule_refresh())
	EventBus.player_inventory_changed.connect(func(_inventory): _schedule_refresh())
	EventBus.friend_changed.connect(func(_npc, _hearts): _schedule_refresh())
	EventBus.outfit_changed.connect(func(_outfit): _schedule_refresh())
	%HintBar.on_dark = true
	%HintBar.set_hints([{"pair": [&"ui_up", &"ui_down"], "key": "HINT_MOVE"}, {"action": &"ui_accept", "key": "HINT_OK"}, {"action": &"ui_cancel", "key": "HINT_BACK"}])
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("shop", Callable(get_script(), &"fixture_setup"))

func _shop_opened(id: StringName) -> void:
	if is_open():
		close()
	current_shop = id
	_tab = 0
	_selected_id = &""
	_greeting_key = ""
	super.open()
	if not is_open():
		ShopSystem.close_shop(id)

func open(opener: Control = null) -> void:
	_greeting_key = ""
	super.open(opener)

func close() -> void:
	if not is_open() or _closing:
		return
	_closing = true
	super.close()
	ShopSystem.close_shop(current_shop)
	_clear_rows()
	_closing = false

func _force_closed() -> void:
	ShopSystem.close_shop(current_shop)
	_clear_rows()

func _shop_closed(id: StringName) -> void:
	if id == current_shop and is_open() and not _closing:
		super.close()
		_clear_rows()

func _exit_tree() -> void:
	var was_open := is_open()
	super._exit_tree()
	var shop := Svc.node("ShopSystem")
	if was_open and shop != null:
		shop.call("close_shop", current_shop)

func _initial_focus() -> Control:
	return _rows[0] if not _rows.is_empty() else close_btn

func _input(event: InputEvent) -> void:
	# The focused stepper owns PageUp/Down (+/-5), before TTScreen changes tabs.
	if is_open() and is_top() and stepper.has_focus() and (event.is_action_pressed(&"ui_page_up", true) or event.is_action_pressed(&"ui_page_down", true)):
		return
	super._input(event)

func _on_page(direction: int) -> void:
	if not _tabs.is_empty():
		_set_tab(posmod(_tab + direction, _tabs.size()))
		if not _rows.is_empty():
			_rows[0].grab_focus()

func _schedule_refresh() -> void:
	if not is_open() or _busy or _refresh_pending:
		return
	_refresh_pending = true
	_flush_refresh.call_deferred()

func _flush_refresh() -> void:
	_refresh_pending = false
	if is_inside_tree() and is_open():
		_refresh()

func _refresh_texts() -> void:
	if not is_node_ready():
		return
	_info = ShopSystem.get_shop_info(current_shop)
	%ShopNameLabel.text = tr(str(_info.get("name_key", "SHOP_SEED_SHOP")))
	var npc := StringName(str(_info.get("npc_id", "")))
	%KeeperName.text = tr(str(Portraits.npc(npc).get("name_key", "")))
	%KeeperFace.texture = Portraits.portrait(npc)
	if _greeting_key == "":
		var greeting: Dictionary = Svc.static_call(Talk, &"greeting_for_shop", [str(current_shop)], {})
		_greeting_key = str(greeting.get("text_key", _info.get("greeting_key", "SHOP_GREETING_DEFAULT")))
	keeper_speech.text = tr(_greeting_key)
	%EmptyLabel.text = tr("STORE_EMPTY")
	close_btn.tooltip_text = tr("UI_CLOSE")
	_tabs = ShopSystem.get_shop_tabs(current_shop)
	_tab = clampi(_tab, 0, maxi(0, _tabs.size() - 1))
	_clear(%TabRow)
	_tab_buttons.clear()
	var group := ButtonGroup.new()
	group.set_meta(UiNav.TAB_ROW_META, true)
	for index in _tabs.size():
		var tab := Button.new()
		tab.name = "Tab_" + str(_tabs[index].id)
		tab.text = tr(str(_tabs[index].name_key))
		tab.theme_type_variation = &"PillTab"
		tab.toggle_mode = true
		tab.button_group = group
		tab.set_pressed_no_signal(index == _tab)
		%TabRow.add_child(tab)
		tab.pressed.connect(_set_tab.bind(index))
		tab.focus_entered.connect(_set_tab.bind(index))
		_tab_buttons.append(tab)
	_refresh()

func _set_tab(index: int) -> void:
	if index == _tab:
		return
	_tab = index
	_selected_id = &""
	for i in _tab_buttons.size():
		_tab_buttons[i].set_pressed_no_signal(i == index)
	_refresh()

func _selling() -> bool:
	return not _tabs.is_empty() and bool(_tabs[_tab].get("sell", false))

func _refresh() -> void:
	_info = ShopSystem.get_shop_info(current_shop)
	gold_label.text = Fmt.thousands(EconomyManager.gold)
	var previous_id := _selected_id
	var previous_focus := get_viewport().gui_get_focus_owner()
	var focus_item := StringName(str(previous_focus.get("item_id"))) if previous_focus is Button and previous_focus in _rows else &""
	for row in _row_cache.values():
		row.visible = false
		row.focus_mode = Control.FOCUS_NONE
	_rows.clear()
	var entries: Array = ShopSystem.get_sell_list(current_shop) if _selling() else ShopSystem.get_shop_inventory(current_shop)
	if not _selling() and not _tabs.is_empty():
		entries = entries.filter(func(entry): return ShopSystem.item_in_tab(_tabs[_tab], entry.item_id))
	entries = Rarity.sorted(entries, func(entry): return entry.get("rarity", "normal"), func(entry): return str(entry.item_id))
	_selected = {}
	for entry in entries:
		var cache_key := ("sell_" if _selling() else "buy_") + str(entry.item_id)
		var row: Button = _row_cache.get(cache_key)
		if row == null:
			row = Row.new()
			row.name = "Item_" + cache_key
			row.button_group = _row_group
			row.setup(entry, not _selling() and EconomyManager.gold < int(entry.price))
			item_grid.add_child(row)
			row.pressed.connect(func(): _activate_row(row.entry))
			_row_cache[cache_key] = row
		else:
			row.setup(entry, not _selling() and EconomyManager.gold < int(entry.price))
		row.visible = true
		row.focus_mode = Control.FOCUS_ALL
		item_grid.move_child(row, _rows.size())
		_rows.append(row)
		if StringName(str(entry.item_id)) == _selected_id:
			_selected = entry
	if _selected.is_empty() and not entries.is_empty():
		_selected = entries[0]
	_selected_id = StringName(str(_selected.get("item_id", "")))
	if _selected_id != previous_id:
		stepper.value = 1
	%EmptyLabel.visible = entries.is_empty()
	for row in _rows:
		row.set_pressed_no_signal(row.item_id == _selected_id)
		if row.item_id == focus_item:
			row.grab_focus()
	%ClosedLabel.visible = bool(_info.get("closed", false))
	%ClosedLabel.text = _closed_text()
	_detail()
	_footer()
	_wire()

func _select(entry: Dictionary) -> void:
	var changed_item := _selected_id != StringName(str(entry.item_id))
	_selected = entry
	_selected_id = StringName(str(entry.item_id))
	if changed_item:
		stepper.value = 1
	for row in _rows:
		row.set_pressed_no_signal(row.item_id == _selected_id)
	_detail()
	_footer()
	_wire()

func _activate_row(entry: Dictionary) -> void:
	_select(entry)
	if stepper.focus_mode == Control.FOCUS_ALL:
		stepper.grab_focus()
	else:
		close_btn.grab_focus()

func _closed_text() -> String:
	var state := _info.duplicate()
	state["reason"] = state.get("closed_reason", "")
	state["next_weekday"] = state.get("next_open_weekday", 0)
	var message := HoursText.closed_text(state)
	return message if message != "" else tr("SHOP_UI_CLOSED_TODAY")

func _detail() -> void:
	var def := ItemKinds.def(_selected_id)
	%DetailName.text = tr(str(def.get("name_key", "")))
	%DetailDesc.text = tr(str(def.get("description_key", "")))
	farming_stats.text = preload("res://scripts/ui/components/farming_details.gd").text(_selected_id)
	farming_stats.visible = farming_stats.text != ""
	equipment_stats.text = preload("res://scripts/ui/components/equipment_details.gd").text(str(_selected_id))
	equipment_stats.visible = equipment_stats.text!=""
	%DetailIcon.item_id = _selected_id
	%DetailIcon.rarity = ItemKinds.rarity_of(_selected_id)
	%DetailPreview.texture = null
	var preview := "res://assets/iso_props/furniture/%s_r0.webp" % _selected_id
	if str(def.get("category", "")) == "furniture" and ResourceLoader.exists(preview):
		%DetailPreview.texture = load(preview)
	%DetailIcon.visible = %DetailPreview.texture == null
	%DetailPreview.visible = %DetailPreview.texture != null
	var details: Array[String] = []
	if not _selected.is_empty():
		details.append(tr("STORE_OWNED_FMT") % EconomyManager.count_item(_selected_id))
		if not _selling():
			var breakdown := Prices.breakdown(str(current_shop), str(_selected_id), int(_selected.get("base_price", _selected.get("price", 0))))
			if float(breakdown.get("sale", 0.0)) > 0:
				details.append(tr("SHOP_UI_SALE_FMT") % str(roundi(float(breakdown.sale) * 100)))
			if float(breakdown.get("surcharge", 0.0)) > 0:
				details.append(tr("STORE_REPEAT_FMT") % roundi(float(breakdown.surcharge) * 100))
			if bool(_selected.get("already_owned", false)):
				details.append(tr("SHOP_UI_ALREADY_OWNED"))
	%DetailState.text = " · ".join(details)

func _footer() -> void:
	var closed_shop := bool(_info.get("closed", false))
	var owned := bool(_selected.get("already_owned", false)) and not _selling()
	var unit := int(_selected.get("price", 0))
	_displayed_unit = unit
	var available := int(_selected.get("amount", 0) if _selling() else _selected.get("stock", 0))
	var limit := mini(99, available)
	if not _selling() and unit > 0:
		limit = mini(limit, int(EconomyManager.gold / unit))
	stepper.set_range(1, maxi(1, limit))
	var enabled := not closed_shop and not owned and not _selected.is_empty() and available > 0 and unit > 0 and (_selling() or EconomyManager.gold >= unit)
	stepper.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	stepper.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
	stepper.visible = not owned
	buy_btn.visible = not owned
	buy_btn.disabled = not enabled
	buy_btn.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	buy_btn.text = tr("UI_SELL" if _selling() else "UI_BUY")
	var total := EconomyManager.total_of(unit, stepper.value) if _selling() else ShopSystem.get_buy_total(current_shop, _selected_id, stepper.value)
	total_label.text = (tr("SHOP_TOTAL") % Fmt.thousands(total)) if not _selected.is_empty() else ""
	if available <= 0 and not _selected.is_empty():
		total_label.text = tr("SHOP_UI_SOLD_OUT")

func _wire() -> void:
	var header: Array = _tab_buttons.duplicate()
	header.append(close_btn)
	var footer: Array = []
	if stepper.focus_mode == Control.FOCUS_ALL:
		footer.append(stepper)
	if buy_btn.visible and not buy_btn.disabled:
		footer.append(buy_btn)
	UiNav.wire_row(header)
	UiNav.wire_grid(_rows, 2)
	if footer.size() == 2:
		UiNav.wire_row([stepper])
		UiNav.wire_row([buy_btn])
		UiNav.wire_groups([header, _rows, [stepper], [buy_btn]], true, false)
	else:
		UiNav.wire_groups([header, _rows], true, false)
	UiNav.hover_focus(_rows)

func _confirm() -> void:
	if not is_open() or not is_top() or _busy or buy_btn.disabled or _selected_id == &"":
		return
	var current_unit := ShopSystem.get_sell_price(current_shop, _selected_id) if _selling() else ShopSystem.get_buy_price(current_shop, _selected_id)
	if current_unit != _displayed_unit:
		_refresh()
		EventBus.whisper_requested.emit("STORE_PRICE_CHANGED")
		return
	_busy = true
	var id := _selected_id
	var amount: int = stepper.value
	var selling := _selling()
	var success := ShopSystem.sell_item(current_shop, id, amount) if selling else ShopSystem.buy_item(current_shop, id, amount)
	_busy = false
	_greeting_key = _keeper_key("THANKS" if success else ("CANNOT_PAY" if ShopSystem.last_refusal == &"no_gold" else "SOLD_OUT"))
	keeper_speech.text = tr(_greeting_key)
	_refresh()
	if success:
		transaction_complete.emit(current_shop, id, amount, not selling)
		var wardrobe := Svc.node("WardrobeManager")
		if str(ItemKinds.def(id).get("category", "")) == "clothing" and wardrobe != null and wardrobe.has_method("equip"):
			var equip_now := await UiConfirm.ask(self, "STORE_EQUIP_TITLE", tr("STORE_EQUIP_NOW"), "STORE_EQUIP")
			if equip_now and is_instance_valid(wardrobe):
				wardrobe.call("equip", id)

func _keeper_key(kind: String) -> String:
	var variants: Array = Svc.static_call(Talk, &"variants", ["KEEP_ANY_" + kind], [])
	return str(variants[0]) if not variants.is_empty() else str(_info.get("greeting_key", "SHOP_GREETING_DEFAULT"))

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _clear_rows() -> void:
	_clear(item_grid)
	_row_cache.clear()
	_rows.clear()

static func fixture_setup(node: Node, _host: Node) -> void:
	var gm := Svc.node("GameManager")
	var eco := Svc.node("EconomyManager")
	var previous_gold: int = eco.gold
	eco.gold = 1250
	var previous := {"day": gm.day, "season": gm.season, "year": gm.year, "hour": gm.hour, "minute": gm.minute}
	gm.day = 1
	gm.year = 1
	gm.season = &"foraar"
	gm.hour = 12
	gm.minute = 0
	node.closed.connect(func():
		eco.gold = previous_gold
		for key in previous:
			gm.set(key, previous[key]), CONNECT_ONE_SHOT)
	node.current_shop = &"seed_shop"
	node.open()
