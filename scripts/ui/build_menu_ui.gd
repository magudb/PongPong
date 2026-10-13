extends Control
## Building construction UI: select building, see costs, build.

@onready var building_list: ItemList = %BuildingList
@onready var detail_panel: VBoxContainer = %DetailPanel
@onready var name_label: Label = %NameLabel
@onready var desc_label: Label = %DescLabel
@onready var cost_label: Label = %CostLabel
@onready var capacity_label: Label = %CapacityLabel
@onready var build_btn: Button = %BuildButton
@onready var close_btn: Button = %CloseButton

var _selected_building: StringName = &""
var _husbandry: Node = null

const BUILDING_ORDER := ["coop", "house", "barn"]


func _ready() -> void:
	visible = false
	_husbandry = get_node_or_null("/root/AnimalHusbandry")

	build_btn.pressed.connect(_on_build)
	close_btn.pressed.connect(_close)
	building_list.item_selected.connect(_on_building_selected)
	EventBus.ui_panel_toggled.connect(_on_panel_toggled)


func _on_panel_toggled(panel: StringName, is_open: bool) -> void:
	if panel == &"build_menu":
		visible = is_open
		if is_open:
			_populate_list()


func _populate_list() -> void:
	building_list.clear()
	if _husbandry == null:
		return

	for btype in BUILDING_ORDER:
		var spec: Dictionary = _husbandry.BUILDINGS[btype]
		var has_it: bool = _husbandry.has_building(StringName(btype))
		var text := "%s %s" % ["✓" if has_it else "☐", tr(spec["name_key"])]
		building_list.add_item(text)
		building_list.set_item_metadata(building_list.item_count - 1, btype)

	if building_list.item_count > 0:
		building_list.selected = 0
		_on_building_selected(0)


func _on_building_selected(index: int) -> void:
	_selected_building = StringName(building_list.get_item_metadata(index))
	_refresh_details()


func _refresh_details() -> void:
	if _husbandry == null or _selected_building == &"":
		return

	var spec: Dictionary = _husbandry.BUILDINGS[str(_selected_building)]
	name_label.text = tr(spec["name_key"])
	capacity_label.text = tr("UI_CAPACITY") % spec["capacity"]

	# Cost
	var costs: Array = []
	for item_id in spec["build_cost"]:
		if item_id == "gold":
			costs.append("%d %s" % [spec["build_cost"][item_id], tr("UI_GOLD")])
		else:
			costs.append("%s x%d" % [tr("ITEM_%s" % item_id.to_upper()), spec["build_cost"][item_id]])
	cost_label.text = tr("UI_COST") % ", ".join(costs)

	var has_it: bool = _husbandry.has_building(_selected_building)
	build_btn.disabled = has_it
	build_btn.text = tr("UI_ALREADY_BUILT") if has_it else tr("UI_BUILD")


func _on_build() -> void:
	if _husbandry == null:
		return
	if _husbandry.build_building(_selected_building):
		_populate_list()
		_refresh_details()


func _close() -> void:
	visible = false
