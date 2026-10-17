extends TTScreen
const L := preload("res://scripts/ui/social/social_layout.gd")
const BUILDING_ORDER := ["coop","house","barn","greenhouse"]
var _selected_building := &"coop"
var building_list: VBoxContainer
var name_label: Label
var cost_label: Label
var capacity_label: Label
var build_btn: Button
var close_btn: Button
var preview: TextureRect
var hint_label: Label
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
	var title := L.label(header,"FARMSITE_UPGRADES_TITLE","Display34")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn = _named(L.button(header,"HINT_CLOSE","ButtonTertiaryS"),"CloseButton") as Button
	close_btn.pressed.connect(close)
	var upgrades := L.box(body, false, 12)
	var house := L.button(upgrades, "FARMSITE_HOUSE_UPGRADES", "ButtonSecondaryS22")
	house.name = "HouseUpgrades"
	house.pressed.connect(func():
		close()
		EventBus.game_event.emit(&"open_home_builder", {}))
	var field := L.button(upgrades, "FARMSITE_FIELD_UPGRADE", "ButtonSecondaryS22")
	field.name = "FieldExpansion"
	field.pressed.connect(func():
		close()
		var world := get_tree().get_first_node_in_group("world_2d")
		for marker in world.area.find_markers("field_expansion"):
			if marker.node != null and marker.node.is_enabled():
				marker.node.interact(world.player)
				return
		EventBus.whisper_requested.emit("FARMSITE_FIELD_OWNED"))
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
	hint_label = L.label(detail,"ANIMAL_BUILD_HINT","Body",true)
	build_btn = _named(L.button(detail,"ANIMAL_BUILD","ButtonPrimary"),"BuildButton") as Button
	build_btn.pressed.connect(_on_build)
	AnimalHusbandry.state_changed.connect(func():
		if is_open(): _refresh_texts.call_deferred())
	EventBus.game_event.connect(func(event, _data):
		if event == &"greenhouse_changed" and is_open(): _refresh_texts.call_deferred())
	EventBus.day_started.connect(func(_day, _season):
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
func _building_row(kind: String) -> Dictionary:
	return GameData.dict_of(GameData.cfg("greenhouse", {})) if kind == "greenhouse" else AnimalHusbandry.buildings_data[kind]
func _refresh_texts() -> void:
	if building_list == null: return
	L.clear(building_list)
	for kind in BUILDING_ORDER:
		var button := L.button(building_list,tr(str(_building_row(kind).name_key)),"ButtonSecondaryS22")
		button.toggle_mode = true
		button.button_pressed = kind == str(_selected_building)
		button.pressed.connect(func(): _selected_building = StringName(kind); _refresh_texts())
	var row := _building_row(str(_selected_building))
	hint_label.visible = _selected_building != &"greenhouse"
	if _selected_building == &"greenhouse":
		_refresh_greenhouse(row)
		return
	var building = AnimalHusbandry.building_of(_selected_building)
	var upgrade: Dictionary = AnimalHusbandry.building_upgrade(_selected_building)
	var owned: bool = building != null
	name_label.text = tr(str(row.name_key))
	capacity_label.text = tr("ANIMAL_CAPACITY_FMT") % AnimalHusbandry.get_building_capacity(_selected_building) if owned else tr("ANIMAL_CAPACITY_FMT") % int(row.capacity)
	if owned and not upgrade.is_empty():
		capacity_label.text = tr("FARMSITE_CAPACITY_UPGRADE_FMT") % [AnimalHusbandry.building_capacity(building), int(upgrade.capacity)]
	var costs: Array[String] = []
	var enough := true
	var price: Dictionary = LuaData.dict(upgrade.get("cost", {})) if owned else LuaData.dict(row.build_cost)
	for id in price:
		var need := int(price[id])
		var have := EconomyManager.gold if id == "gold" else EconomyManager.count_item(StringName(id))
		enough = enough and have >= need
		costs.append("%s %d / %d" % [tr("ANIMAL_GOLD") if id == "gold" else L.item_name(str(id)),have,need])
	if owned and not upgrade.is_empty():
		costs.append(tr("FARMSITE_BUILD_DAYS_FMT") % int(upgrade.days))
	cost_label.text = "\n".join(costs)
	var busy: bool = owned and building.upgrade_ready_day > 0
	build_btn.text = tr("FARMSITE_UPGRADE_FMT") % (building.tier + 1) if owned and not upgrade.is_empty() else tr("ANIMAL_BUILT") if owned else tr("ANIMAL_BUILD")
	if busy:
		build_btn.text = tr("FARMSITE_UPGRADING_FMT") % maxi(0, building.upgrade_ready_day - GameManager.total_day())
	build_btn.disabled = (owned and upgrade.is_empty()) or busy or not enough or _asking
	build_btn.focus_mode = Control.FOCUS_NONE if build_btn.disabled else Control.FOCUS_ALL
	preview.texture = ArtCatalog.prop(StringName(PlacementService.PROPS[str(_selected_building)])).get("texture")
func _refresh_greenhouse(row: Dictionary) -> void:
	name_label.text = tr(str(row.name_key))
	capacity_label.text = tr("FARMSITE_GREENHOUSE_HINT")
	var costs: Array[String] = []
	var enough := HomeManager.tier >= int(row.min_home_tier)
	if not enough: costs.append(tr("FARMSITE_GREENHOUSE_TIER_FMT") % int(row.min_home_tier))
	for id in row.build_cost:
		var have := EconomyManager.gold if id == "gold" else EconomyManager.count_item(StringName(id))
		var need := int(row.build_cost[id])
		enough = enough and have >= need
		costs.append("%s %d / %d" % [tr("ANIMAL_GOLD") if id == "gold" else L.item_name(str(id)), have, need])
	var built := FarmEquipment.greenhouse_built()
	var busy := FarmEquipment.greenhouse_building()
	costs.append(tr("FARMSITE_CONSTRUCTION_DAYS_FMT") % int(row.build_days))
	cost_label.text = "" if built else "\n".join(costs)
	build_btn.text = tr("FARMSITE_GREENHOUSE_ENTER") if built else tr("FARMSITE_UPGRADING_FMT") % FarmEquipment.greenhouse_days_left() if busy else tr("ANIMAL_BUILD")
	build_btn.disabled = not built and (busy or not enough or _asking)
	build_btn.focus_mode = Control.FOCUS_NONE if build_btn.disabled else Control.FOCUS_ALL
	preview.texture = ArtCatalog.prop(&"greenhouse").get("texture")
func _on_build() -> void:
	if build_btn.disabled or _asking: return
	_asking = true
	var kind := _selected_building
	if kind == &"greenhouse":
		if FarmEquipment.greenhouse_built():
			_asking = false
			close()
			var world := FarmEquipment.current_world()
			if world != null: world.travel(&"greenhouse", &"default")
			return
		var row := _building_row("greenhouse")
		var accepted := await UiConfirm.ask(self,"FARMSITE_GREENHOUSE","FARMSITE_GREENHOUSE_BUILD_FMT","ANIMAL_BUILD","NAV_CANCEL",&"cancel",[int(row.build_days)])
		_asking = false
		if accepted: FarmEquipment.build_greenhouse()
		_refresh_texts()
		return
	var is_upgrade := AnimalHusbandry.has_building(kind)
	var accepted := await UiConfirm.ask(self,"ANIMAL_BUILD_TITLE","FARMSITE_UPGRADE_CONFIRM_FMT" if is_upgrade else "ANIMAL_BUILD_CONFIRM_FMT","ANIMAL_BUILD","NAV_CANCEL",&"cancel",[tr(str(AnimalHusbandry.buildings_data[str(kind)].name_key))])
	_asking = false
	if accepted:
		if AnimalHusbandry.has_building(kind):
			AnimalHusbandry.upgrade_building(kind)
		else:
			AnimalHusbandry.build_building(kind)
	_refresh_texts()
