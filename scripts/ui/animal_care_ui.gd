extends TTScreen
## Care uses stable item IDs and the real husbandry owner. No food is consumed
## until Feed commits; rename is an in-canvas dialog shared with other screens.
const L := preload("res://scripts/ui/social/social_layout.gd")
var animal_list: VBoxContainer
var name_label: Label
var species_label: Label
var bond_label: Label
var happiness_bar: ProgressBar
var hunger_bar: ProgressBar
var food_option: Button
var feed_btn: Button
var brush_btn: Button
var play_btn: Button
var collect_btn: Button
var rename_btn: Button
var close_btn: Button
var product_label: Label
var status_label: Label
var _selected_animal: StringName
var _foods: Array[String] = []
var _food := ""
var _renaming := false
var _preview: IsoChibiSprite2D
var _preview_well: Control
var _preview_id := ""
func _init() -> void:
	super._init()
	screen_id = &"animal_care_ui"
	modal_name = &"animal_care"
func _named(node: Control, id: String) -> Control:
	node.name = id
	node.owner = self
	node.unique_name_in_owner = true
	return node
func _ready() -> void:
	super._ready()
	L.scrim(self)
	var book := L.panel(self,"PanelBook",Rect2(90,45,1100,630))
	var body := L.box(L.margin(book,20),true,12)
	var header := L.box(body,false)
	var title := L.label(header,"ANIMAL_CARE_TITLE","Display34")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn = _named(L.button(header,"HINT_CLOSE","ButtonTertiaryS"),"CloseButton") as Button
	close_btn.pressed.connect(close)
	var columns := L.box(body,false,24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.x = 240
	columns.add_child(scroll)
	animal_list = _named(L.box(scroll,true,6),"AnimalList") as VBoxContainer
	animal_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var center := L.box(columns,true,10)
	center.custom_minimum_size.x = 290
	_preview_well = L.panel(center,"PanelCard")
	_preview_well.custom_minimum_size = Vector2(290,300)
	name_label = _named(L.label(center,"","Heading22"),"NameLabel") as Label
	species_label = _named(L.label(center,"","Body"),"SpeciesLabel") as Label
	bond_label = _named(L.label(center,"","Body"),"BondLabel") as Label
	var right := L.box(columns,true,10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	L.label(right,"ANIMAL_HAPPINESS","Body")
	happiness_bar = _named(_meter(right),"HappinessBar") as ProgressBar
	L.label(right,"ANIMAL_FULLNESS","Body")
	hunger_bar = _named(_meter(right),"HungerBar") as ProgressBar
	food_option = _named(L.button(right,"ANIMAL_NO_FOOD","ButtonSecondaryS"),"FoodOption") as Button
	food_option.pressed.connect(_cycle_food)
	feed_btn = _named(L.button(right,"ANIMAL_FEED","ButtonPrimaryS"),"FeedButton") as Button
	feed_btn.pressed.connect(_on_feed)
	var care := L.box(right,false,8)
	brush_btn = _named(L.button(care,"ANIMAL_BRUSH","ButtonSecondaryS"),"BrushButton") as Button
	brush_btn.pressed.connect(func(): AnimalHusbandry.brush_animal(_selected_animal); _refresh_texts())
	play_btn = _named(L.button(care,"ANIMAL_PLAY","ButtonSecondaryS"),"PlayButton") as Button
	play_btn.pressed.connect(func(): AnimalHusbandry.play_with_animal(_selected_animal); _refresh_texts())
	product_label = L.label(right,"","Body",true)
	collect_btn = _named(L.button(right,"ANIMAL_COLLECT","ButtonPrimaryS"),"CollectButton") as Button
	collect_btn.pressed.connect(func(): AnimalHusbandry.collect_product(_selected_animal); _refresh_texts())
	rename_btn = _named(L.button(right,"ANIMAL_RENAME","ButtonTertiaryS"),"RenameButton") as Button
	rename_btn.pressed.connect(_on_rename)
	status_label = L.label(right,"","Muted14",true)
	EventBus.game_event.connect(func(event,payload):
		if event == &"open_animal_care":
			_selected_animal = StringName(str(payload.get("animal","")))
			open()
		elif event == &"animal_care_item_used":
			_food = str(payload.get("item",""))
			open())
	AnimalHusbandry.state_changed.connect(func():
		if is_open(): _refresh_texts.call_deferred())
func _meter(parent: Node) -> ProgressBar:
	var meter := ProgressBar.new()
	meter.show_percentage = false
	meter.custom_minimum_size.y = 16
	parent.add_child(meter)
	return meter
func _initial_focus() -> Control:
	return feed_btn if not feed_btn.disabled else close_btn
func _refresh_texts() -> void:
	if animal_list == null: return
	L.clear(animal_list)
	var animals: Array = AnimalHusbandry.get_all_animals()
	if AnimalHusbandry.get_animal(_selected_animal) == null:
		_selected_animal = animals[0].id if not animals.is_empty() else &""
	for animal in animals:
		var button := L.button(animal_list,animal.name)
		button.toggle_mode = true
		button.button_pressed = animal.id == _selected_animal
		button.pressed.connect(func(): _selected_animal = animal.id; _refresh_texts())
	var animal = AnimalHusbandry.get_animal(_selected_animal)
	if animal == null:
		name_label.text = tr("ANIMAL_EMPTY")
		for button in [feed_btn,brush_btn,play_btn,collect_btn,rename_btn,food_option]: button.disabled = true
		return
	var spec: Dictionary = AnimalHusbandry.species_data[str(animal.species)]
	name_label.text = animal.name
	species_label.text = tr("ANIMAL_SPECIES_" + str(animal.species).to_upper()) + " · " + (tr("ANIMAL_BABY") if animal.is_baby else tr("ANIMAL_ADULT"))
	bond_label.text = tr("ANIMAL_BOND_FMT") % [animal.bond_level,animal.age_days]
	happiness_bar.value = animal.happiness
	hunger_bar.value = animal.hunger
	_foods.clear()
	for food in LuaData.strings(spec.feed_types):
		if EconomyManager.has_item(StringName(food)): _foods.append(food)
	if _food not in _foods: _food = _foods[0] if not _foods.is_empty() else ""
	food_option.text = tr("ANIMAL_NO_FOOD") if _food == "" else tr("ANIMAL_FOOD_FMT") % [L.item_name(_food),EconomyManager.count_item(StringName(_food))]
	food_option.disabled = _foods.size() < 2
	feed_btn.disabled = _food == "" or animal.hunger >= 100
	brush_btn.disabled = not EconomyManager.has_item(&"brush") or animal.last_brushed_day == GameManager.total_day()
	play_btn.disabled = animal.last_played_day == GameManager.total_day()
	collect_btn.disabled = animal.products_ready <= 0
	rename_btn.disabled = _renaming
	product_label.text = tr("ANIMAL_PRODUCT_FMT") % [L.item_name(str(spec.product)),animal.products_ready]
	status_label.text = tr("ANIMAL_CARE_DAILY_HINT")
	var options: Array = Animal2D.VISUALS[str(animal.species)]
	var id: String = options[0 if animal.is_baby else 1]
	if id != _preview_id:
		_preview_id = id
		if is_instance_valid(_preview): _preview.queue_free()
		_preview = IsoChibiSprite2D.create(id)
		_preview.position = Vector2(145,280)
		_preview.scale = Vector2.ONE * 1.2
		_preview_well.add_child(_preview)
func _cycle_food() -> void:
	if _foods.is_empty(): return
	_food = _foods[posmod(_foods.find(_food)+1,_foods.size())]
	_refresh_texts()
func _on_feed() -> void:
	if _food != "": AnimalHusbandry.feed_animal(_selected_animal,StringName(_food))
	_refresh_texts()
func _on_rename() -> void:
	var animal = AnimalHusbandry.get_animal(_selected_animal)
	if animal == null or _renaming: return
	_renaming = true
	var id := _selected_animal
	var value := await UiConfirm.ask_text(self,"ANIMAL_RENAME",animal.name,24)
	_renaming = false
	animal = AnimalHusbandry.get_animal(id)
	if value != "" and animal != null:
		animal.name = value
		AnimalHusbandry.state_changed.emit()
	_refresh_texts()
