extends Control
## Inventory panel: grid of item slots with tooltips.

signal item_used(item_id: StringName)
signal item_dropped(item_id: StringName)

@onready var grid: GridContainer = %ItemGrid
@onready var gold_label: Label = %GoldLabel
@onready var close_btn: Button = %CloseButton
@onready var tooltip: PanelContainer = %Tooltip

const SLOT_SIZE := 64
const SLOTS := 40

var _slots: Array[Dictionary] = []


func _ready() -> void:
	visible = false
	close_btn.pressed.connect(func(): visible = false; EventBus.ui_panel_toggled.emit(&"inventory", false))
	EventBus.ui_panel_toggled.connect(_on_panel_toggled)
	EventBus.player_inventory_changed.connect(_on_inventory_changed)
	EventBus.gold_changed.connect(_on_gold_changed)
	_build_grid()
	_refresh()


func _build_grid() -> void:
	grid.columns = 8
	for i in SLOTS:
		var slot := TextureButton.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.ignore_texture_size = true
		slot.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		slot.pressed.connect(func(): _on_slot_pressed(i))
		slot.mouse_entered.connect(func(): _on_slot_hover(i))
		slot.mouse_exited.connect(func(): tooltip.visible = false)
		grid.add_child(slot)
		_slots.append({"button": slot, "item_id": &"", "amount": 0})


func _refresh() -> void:
	var inv: Dictionary = EconomyManager.get_inventory_dict()
	var idx := 0
	for item_id in inv:
		if idx >= SLOTS:
			break
		_slots[idx]["item_id"] = item_id
		_slots[idx]["amount"] = inv[item_id]
		var btn: TextureButton = _slots[idx]["button"]
		btn.tooltip_text = "%s x%d" % [tr("ITEM_%s" % str(item_id).to_upper()), inv[item_id]]
		idx += 1

	for i in range(idx, SLOTS):
		_slots[i]["item_id"] = &""
		_slots[i]["amount"] = 0
		_slots[i]["button"].tooltip_text = ""

	_on_gold_changed(EconomyManager.gold, 0)


func _on_inventory_changed(_inv: Dictionary) -> void:
	_refresh()


func _on_gold_changed(amount: int, _delta: int) -> void:
	if gold_label:
		gold_label.text = "%s: %d" % [tr("UI_GOLD"), amount]


func _on_slot_pressed(index: int) -> void:
	var item_id: StringName = _slots[index]["item_id"]
	if item_id == &"":
		return
	item_used.emit(item_id)


func _on_slot_hover(index: int) -> void:
	var item_id: StringName = _slots[index]["item_id"]
	if item_id == &"":
		tooltip.visible = false
		return
	var def: Dictionary = LuaRuntime.get_item_def(str(item_id))
	tooltip.visible = true
	# Populate tooltip labels (best-effort)
	var title := tooltip.get_node_or_null("%TooltipTitle") as Label
	var desc := tooltip.get_node_or_null("%TooltipDesc") as Label
	if title:
		title.text = tr("ITEM_%s" % str(item_id).to_upper())
	if desc:
		desc.text = tr(def.get("description_key", ""))


func _on_panel_toggled(panel: StringName, is_open: bool) -> void:
	if panel == &"inventory":
		visible = is_open
		if is_open:
			_refresh()
