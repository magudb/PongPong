extends TTScreen
## Backpack presentation is separate from the data-owned crafting panel.
const Fmt := preload("res://scripts/ui/theme/tt_format.gd")
const Slot := preload("res://scenes/ui/components/item_slot.tscn")
var farming_stats: Label
var _slots: Array[Button] = []
var _items: Array = []
var _selected := 0
var _selected_id: StringName = &""
var _busy := false
var _refresh_pending := false
var _picking := false
var _picker_buttons: Array[Button] = []
var _picker_opener: Control
var _picker_item: StringName = &""
@onready var workshop: Control = %WorkshopBody

func _init() -> void:
	super._init()
	screen_id = &"inventory_ui"
	modal_name = &"inventory"
	hotkey_action = &"inventory"

func _ready() -> void:
	super._ready()
	farming_stats = preload("res://scripts/ui/components/farming_details.gd").create(%DetailDesc)
	var slot_group := ButtonGroup.new()
	slot_group.set_meta("tt_value_selection", true)
	for index in EconomyManager.INVENTORY_SLOTS:
		var slot: Button = Slot.instantiate()
		slot.name = "BagSlot%d" % (index + 1)
		slot.button_group = slot_group
		slot.custom_minimum_size = Vector2(64, 64)
		%ItemGrid.add_child(slot)
		slot.item_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.item_icon.offset_left = 8
		slot.item_icon.offset_top = 8
		slot.item_icon.offset_right = -8
		slot.item_icon.offset_bottom = -8
		slot.pressed.connect(_activate_slot.bind(index))
		_slots.append(slot)
	%UseButton.pressed.connect(_use)
	%EquipButton.pressed.connect(_equip)
	%DropButton.pressed.connect(_discard)
	%AssignButton.pressed.connect(_open_picker)
	%CloseButton.pressed.connect(close)
	for index in 8:
		var button := Button.new()
		button.name = "HotbarSlot%d" % (index + 1)
		button.text = str(index + 1)
		button.theme_type_variation = &"ButtonTertiaryS"
		button.custom_minimum_size = Vector2(58, 48)
		%PickerRow.add_child(button)
		button.pressed.connect(_assign.bind(index))
		_picker_buttons.append(button)
	%PickerCancel.pressed.connect(_close_picker)
	workshop.navigation_changed.connect(_wire)
	EventBus.player_inventory_changed.connect(func(_inventory): _schedule_refresh())
	EventBus.home_upgraded.connect(func(_old, _new): _schedule_refresh())
	EventBus.flag_changed.connect(func(_flag, _value): _schedule_refresh())
	%HintBar.on_dark = true
	%HintBar.set_hints([{"pair": [&"ui_up", &"ui_down"], "key": "HINT_MOVE"}, {"action": &"ui_accept", "key": "HINT_OK"}, {"action": &"ui_cancel", "key": "HINT_BACK"}])
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("inventory", Callable(get_script(), &"fixture_setup"))

func _initial_focus() -> Control:
	return _picker_buttons[0] if _picking else _slots[clampi(_selected, 0, _slots.size() - 1)]

func close() -> void:
	_picking = false
	if is_node_ready():
		%HotbarPicker.visible = false
	super.close()

func _on_cancel() -> void:
	if _picking:
		_close_picker()
	else:
		close()

func _input(event: InputEvent) -> void:
	if is_open() and is_top() and event.is_pressed() and not event.is_echo():
		var focus := get_viewport().gui_get_focus_owner()
		if (focus is Button and focus in _slots) or _picking:
			for index in 8:
				if event.is_action_pressed(StringName("slot_%d" % (index + 1))):
					if focus is Button and focus in _slots:
						_select(_slots.find(focus))
					_assign(index)
					get_viewport().set_input_as_handled()
					return
	super._input(event)

func _schedule_refresh() -> void:
	if not is_open() or _busy or _refresh_pending:
		return
	_refresh_pending = true
	_flush.call_deferred()

func _flush() -> void:
	_refresh_pending = false
	if is_inside_tree() and is_open():
		_refresh()

func _refresh_texts() -> void:
	if not is_node_ready():
		return
	_refresh()

func _refresh() -> void:
	_items = EconomyManager.inventory.duplicate(true)
	_items = Rarity.sorted(_items, func(row): return ItemKinds.rarity_of(row.id), func(row): return str(row.id))
	# Retain the item selection across a sort after crafting/use; empty cells remain stops.
	if _selected_id != &"":
		for i in _items.size():
			if StringName(str(_items[i].id)) == _selected_id:
				_selected = i
				break
	for i in _slots.size():
		var entry: Dictionary = _items[i] if i < _items.size() else {}
		_slots[i].setup_item(StringName(str(entry.get("id", ""))), int(entry.get("amount", 0)))
		_slots[i].tooltip_text = tr(str(ItemKinds.def(entry.get("id", "")).get("name_key", "INV_EMPTY_SLOT")))
	%CapacityLabel.text = "%d / %d" % [EconomyManager.used_slots(), EconomyManager.INVENTORY_SLOTS]
	_select(_selected)
	workshop.refresh()
	_wire()

func _select(index: int) -> void:
	_selected = clampi(index, 0, _slots.size() - 1)
	_selected_id = _slots[_selected].item_id
	for i in _slots.size():
		_slots[i].set_pressed_no_signal(i == _selected)
	var def := ItemKinds.def(_selected_id)
	%DetailIcon.item_id = _selected_id
	%DetailIcon.rarity = ItemKinds.rarity_of(_selected_id)
	%DetailName.text = tr(str(def.get("name_key", "INV_EMPTY_SLOT")))
	%DetailRarity.theme_type_variation = StringName("CatalogRarity_" + str(ItemKinds.rarity_of(_selected_id)))
	%DetailRarity.text = tr("RARITY_" + str(ItemKinds.rarity_of(_selected_id)).to_upper()) if _selected_id != &"" else ""
	var description := tr(str(def.get("description_key", "")))
	var growing := preload("res://scripts/ui/components/farming_details.gd").text(_selected_id)
	var value := EconomyManager.sell_value(_selected_id)
	var sale := "\n" + tr("INV_SELLS_FOR") % Fmt.thousands(value) if value > 0 else ""
	%DetailDesc.text = description + sale
	%DetailDesc.visible = growing == ""
	farming_stats.text = growing + sale
	farming_stats.visible = growing != ""
	farming_stats.tooltip_text = description
	var use := str(def.get("category", "")) in ["animal","animal_care"] or (def.has("unlock_flag") and not bool(GameManager.get_flag(StringName(str(def.unlock_flag)), false))) or float(def.get("heal_half_hearts", 0)) > 0 or float(def.get("stamina", 0)) > 0 or float(def.get("oil_seconds", 0)) > 0 or str(def.get("placeable", "")) == "farm"
	UiNav.set_enabled(%UseButton, use)
	UiNav.set_enabled(%EquipButton, EconomyManager.equip_slot_of(_selected_id) != "")
	UiNav.set_enabled(%DropButton, _can_discard(_selected_id))
	UiNav.set_enabled(%AssignButton, _selected_id != &"")
	_wire()

func _activate_slot(index: int) -> void:
	_select(index)
	for button in [%UseButton, %EquipButton, %AssignButton, %DropButton]:
		if UiNav.is_stop(button):
			button.grab_focus()
			return

func _can_discard(id: StringName) -> bool:
	return _discardable(id) > 0

## How many of `id` may be thrown away (the last tool or weapon of a kind is kept).
func _discardable(id: StringName) -> int:
	if id == &"" or not EconomyManager.is_sellable(id) or QuestManager.item_in_use(id):
		return 0
	var count: int = EconomyManager.count_item(id)
	var category := str(ItemKinds.def(id).get("category", ""))
	return count - 1 if category in ["tool", "weapon"] else count

func _use() -> void:
	if _busy or not is_open() or not is_top() or %UseButton.disabled:
		return
	if str(ItemKinds.def(_selected_id).get("category","")) == "animal_care":
		var item := _selected_id
		close()
		EventBus.game_event.emit(&"animal_care_item_used",{"item":str(item)})
		return
	_busy = true
	var used := EconomyManager.use_item(_selected_id)
	_busy = false
	if not used:
		EventBus.whisper_requested.emit("STORE_CANNOT_USE")
	_refresh()

func _equip() -> void:
	if _busy or not is_open() or not is_top() or %EquipButton.disabled:
		return
	EconomyManager.equip(StringName(EconomyManager.equip_slot_of(_selected_id)), _selected_id)
	_refresh()

func _discard() -> void:
	var id := _selected_id
	if _busy or not is_open() or not is_top() or not _can_discard(id):
		return
	_busy = true
	var name := tr(str(ItemKinds.def(id).get("name_key", "")))
	var most := _discardable(id)
	# A stack gets a stepper that starts at the whole stack; a single item keeps the plain question.
	var amount := 0
	if most > 1:
		amount = await UiConfirm.ask_amount(self, "STORE_DISCARD", tr("STORE_DISCARD_AMOUNT_FMT") % name, "STORE_DISCARD", 1, most, most)
	else:
		var confirmed := await UiConfirm.ask(self, "STORE_DISCARD", tr("STORE_DISCARD_CONFIRM_FMT") % name, "STORE_DISCARD")
		amount = 1 if confirmed else 0
	if amount > 0 and is_inside_tree():
		amount = mini(amount, _discardable(id))
		if amount > 0:
			EconomyManager.remove_item(id, amount)
	_busy = false
	if is_inside_tree():
		_refresh()

func _open_picker() -> void:
	if _selected_id == &"" or _picking:
		return
	_picker_item = _selected_id
	_picker_opener = get_viewport().gui_get_focus_owner()
	_picking = true
	%HotbarPicker.visible = true
	_wire()
	_picker_buttons[0].grab_focus()

func _close_picker() -> void:
	_picking = false
	%HotbarPicker.visible = false
	_wire()
	if is_instance_valid(_picker_opener) and UiNav.is_stop(_picker_opener):
		_picker_opener.grab_focus()
	else:
		_slots[_selected].grab_focus()

func _assign(index: int) -> void:
	var item := _picker_item if _picking else _selected_id
	if item != &"" and EconomyManager.has_item(item):
		EventBus.hotbar_assign_requested.emit(index, item)
		EventBus.notification_posted.emit(tr("STORE_ASSIGNED_TITLE"), tr("STORE_ASSIGNED_FMT") % (index + 1), "info")
	if _picking:
		_close_picker()

func _wire() -> void:
	if not is_node_ready() or workshop == null:
		return
	if _picking:
		var pickers: Array = _picker_buttons.duplicate()
		pickers.append(%PickerCancel)
		UiNav.wire_ring(pickers, &"h")
		# Both axes stay within the picker, including Tab.
		UiNav.wire_groups([pickers], true, false)
		return
	var actions: Array = []
	for button in [%UseButton, %EquipButton, %AssignButton, %DropButton]:
		if UiNav.is_stop(button):
			actions.append(button)
	var recipes: Array = workshop.recipe_buttons
	var craft: Array = [workshop.craft_button] if UiNav.is_stop(workshop.craft_button) else []
	UiNav.wire_grid(_slots, 6)
	UiNav.wire_row([%CloseButton])
	UiNav.wire_row(actions)
	UiNav.wire_ring(recipes)
	UiNav.wire_row(craft)
	UiNav.wire_groups([[%CloseButton], _slots, actions, recipes, craft], true, false)
	if not recipes.is_empty():
		for index in _slots.size():
			if index % 6 == 5:
				UiNav.link(_slots[index], UiNav.RIGHT, recipes[0])
		for recipe in recipes:
			UiNav.link(recipe, UiNav.LEFT, _slots[5])

static func fixture_setup(node: Node, _host: Node) -> void:
	node.open()
