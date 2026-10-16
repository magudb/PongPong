extends Button
## One focus stop with a rarity tile and localized catalog data.
const Fmt := preload("res://scripts/ui/theme/tt_format.gd")
var entry: Dictionary = {}
var item_id: StringName = &""
var price_label: Label
var tile: RaritySlot
var _price := 0
var _poor := false
var _name_label: Label
var _owned_label: Label

func _ready() -> void:
	theme_type_variation = &"RowButton"
	toggle_mode = true
	custom_minimum_size = Vector2(290, 78)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	margin.add_child(row)
	tile = RaritySlot.new()
	tile.slot_size = 44
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tile)
	var texts := VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	_name_label = Label.new()
	_name_label.theme_type_variation = &"Heavy18"
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.max_lines_visible = 2
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(_name_label)
	_owned_label = Label.new()
	_owned_label.theme_type_variation = &"Muted13"
	_owned_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.add_child(_owned_label)
	price_label = Label.new()
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(price_label)
	_render()

func setup(data: Dictionary, poor: bool) -> void:
	entry = data
	item_id = StringName(str(entry.item_id))
	_price = int(entry.price)
	_poor = poor
	if is_node_ready():
		_render()

func _render() -> void:
	tile.item_id = item_id
	tile.rarity = StringName(str(entry.get("rarity", "normal")))
	tile.display_name = tr(str(ItemKinds.def(item_id).get("name_key", "")))
	_name_label.text = tile.display_name
	_owned_label.text = tr("STORE_OWNED_FMT") % EconomyManager.count_item(item_id)
	price_label.theme_type_variation = &"CatalogTooDear" if _poor else &"Display20"
	price_label.text = Fmt.thousands(_price)
	tooltip_text = tile.display_name
