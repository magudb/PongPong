extends TTScreen
const L := preload("res://scripts/ui/social/social_layout.gd")
const BUILDING_ORDER := ["coop","house","barn"]
var _selected_building := &"coop"
var building_list: VBoxContainer
var name_label: Label
var cost_label: Label
var capacity_label: Label
var build_btn: Button
var close_btn: Button
var preview: TextureRect
var _asking := false
func _init() -> void:
	super._init()
	screen_id = &"build_menu_ui"
	modal_name = &"build_menu"
	hotkey_action = &"build_menu"
func _named(node: Control, id: String) -> Control:
	node.name = id
	node.owner = self
	node.unique_name_in_owner = true
	return node
func _ready() -> void:
	super._ready()
	L.scrim(self)
	var book := L.panel(self,"PanelBook",Rect2(110,90,1060,540))
	var body := L.box(L.margin(book,20),true,16)
	var header := L.box(body,false)
	var title := L.label(header,"ANIMAL_BUILD_TITLE","Display34")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn = _named(L.button(header,"HINT_CLOSE","ButtonTertiaryS"),"CloseButton") as Button
	close_btn.pressed.connect(close)
	var columns := L.box(body,false,24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	building_list = _named(L.box(columns,true,8),"BuildingList") as VBoxContainer
	building_list.custom_minimum_size.x = 210
	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(330,360)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	columns.add_child(preview)
	var detail := L.box(columns,true,14)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label = L.label(detail,"","Heading22")
	capacity_label = _named(L.label(detail,"","Body",true),"CapacityLabel") as Label
	cost_label = _named(L.label(detail,"","Body",true),"CostLabel") as Label
	L.label(detail,"ANIMAL_BUILD_HINT","Muted14",true)
	build_btn = _named(L.button(detail,"ANIMAL_BUILD","ButtonPrimary"),"BuildButton") as Button
	build_btn.pressed.connect(_on_build)
	AnimalHusbandry.state_changed.connect(func():
		if is_open(): _refresh_texts.call_deferred())
func _hotkey_open_allowed() -> bool:
	var world := get_tree().get_first_node_in_group("world_2d")
	if world == null or world.area == null or world.area.map.id != &"farm":
		EventBus.whisper_requested.emit("ANIMAL_BUILD_ONLY_FARM")
		return false
	return true
func open(opener: Control = null) -> void:
	if _hotkey_open_allowed(): super.open(opener)
func _initial_focus() -> Control:
	return close_btn if build_btn.disabled else build_btn
func _refresh_texts() -> void:
	if building_list == null: return
	L.clear(building_list)
	for kind in BUILDING_ORDER:
		var button := L.button(building_list,tr(str(AnimalHusbandry.buildings_data[kind].name_key)))
		button.toggle_mode = true
		button.button_pressed = kind == str(_selected_building)
		button.pressed.connect(func(): _selected_building = StringName(kind); _refresh_texts())
	var row: Dictionary = AnimalHusbandry.buildings_data[str(_selected_building)]
	name_label.text = tr(str(row.name_key))
	capacity_label.text = tr("ANIMAL_CAPACITY_FMT") % int(row.capacity)
	var costs: Array[String] = []
	var enough := true
	for id in row.build_cost:
		var need := int(row.build_cost[id])
		var have := EconomyManager.gold if id == "gold" else EconomyManager.count_item(StringName(id))
		enough = enough and have >= need
		costs.append("%s %d / %d" % [tr("ANIMAL_GOLD") if id == "gold" else L.item_name(str(id)),have,need])
	cost_label.text = "\n".join(costs)
	var owned := AnimalHusbandry.has_building(_selected_building)
	build_btn.text = tr("ANIMAL_BUILT") if owned else tr("ANIMAL_BUILD")
	build_btn.disabled = owned or not enough or _asking
	preview.texture = ArtCatalog.prop(StringName(PlacementService.PROPS[str(_selected_building)])).get("texture")
func _on_build() -> void:
	if build_btn.disabled or _asking: return
	_asking = true
	var kind := _selected_building
	var accepted := await UiConfirm.ask(self,"ANIMAL_BUILD_TITLE","ANIMAL_BUILD_CONFIRM_FMT","ANIMAL_BUILD","NAV_CANCEL",&"cancel",[tr(str(AnimalHusbandry.buildings_data[str(kind)].name_key))])
	_asking = false
	if accepted: AnimalHusbandry.build_building(kind)
	_refresh_texts()
