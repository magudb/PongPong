extends Control
## Animal care UI: list animals, feed, brush, play, collect products.

@onready var animal_list: ItemList = %AnimalList
@onready var detail_panel: VBoxContainer = %DetailPanel
@onready var name_label: Label = %NameLabel
@onready var species_label: Label = %SpeciesLabel
@onready var happiness_bar: ProgressBar = %HappinessBar
@onready var hunger_bar: ProgressBar = %HungerBar
@onready var bond_label: Label = %BondLabel
@onready var age_label: Label = %AgeLabel
@onready var status_label: Label = %StatusLabel
@onready var product_label: Label = %ProductLabel

@onready var feed_btn: Button = %FeedButton
@onready var brush_btn: Button = %BrushButton
@onready var play_btn: Button = %PlayButton
@onready var collect_btn: Button = %CollectButton
@onready var rename_btn: Button = %RenameButton

@onready var food_option: OptionButton = %FoodOption
@onready var close_btn: Button = %CloseButton

var _selected_animal: StringName = &""
var _husbandry: Node = null


func _ready() -> void:
	visible = false
	_husbandry = get_node_or_null("/root/AnimalHusbandry")

	feed_btn.pressed.connect(_on_feed)
	brush_btn.pressed.connect(_on_brush)
	play_btn.pressed.connect(_on_play)
	collect_btn.pressed.connect(_on_collect)
	rename_btn.pressed.connect(_on_rename)
	close_btn.pressed.connect(_close)

	animal_list.item_selected.connect(_on_animal_selected)
	EventBus.ui_panel_toggled.connect(_on_panel_toggled)

	if _husbandry:
		_husbandry.animal_happy.connect(func(_id, _h): _refresh_details())
		_husbandry.animal_fed.connect(func(_id, _f): _refresh_details())
		_husbandry.animal_product_collected.connect(func(_id, _p, _a): _refresh_details())


## Esc closes the care screen while it is the top modal.
func _unhandled_input(event: InputEvent) -> void:
	if visible and GameManager.top_modal() == &"animal_care" and event.is_action_pressed(&"ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _on_panel_toggled(panel: StringName, is_open: bool) -> void:
	if panel == &"animal_care":
		visible = is_open
		if is_open:
			GameManager.push_modal(&"animal_care")
			_populate_list()
			_populate_food_options()
		else:
			GameManager.pop_modal(&"animal_care")


func _populate_list() -> void:
	animal_list.clear()
	if _husbandry == null:
		return

	for animal in _husbandry.get_all_animals():
		var happiness_icon := ""
		if animal.happiness >= 80: happiness_icon = "❤"
		elif animal.happiness >= 60: happiness_icon = "☺"
		elif animal.happiness >= 40: happiness_icon = "😐"
		else: happiness_icon = "☹"

		var text := "%s %s (%s)" % [
			happiness_icon,
			animal.name,
			tr("ITEM_%s" % str(animal.species).to_upper()),
		]
		animal_list.add_item(text)
		animal_list.set_item_metadata(animal_list.item_count - 1, animal.id)


func _populate_food_options() -> void:
	food_option.clear()
	var foods := ["animal_treats", "chicken_feed", "carrot", "turnip", "cookie", "glow_berry", "rare_mushroom"]
	for food in foods:
		if EconomyManager.has_item(StringName(food), 1):
			food_option.add_item(tr("ITEM_%s" % food.to_upper()))


func _on_animal_selected(index: int) -> void:
	_selected_animal = animal_list.get_item_metadata(index)
	_refresh_details()


func _refresh_details() -> void:
	if _husbandry == null or _selected_animal == &"":
		return

	var animal = _husbandry.get_animal(_selected_animal)
	if animal == null:
		return

	name_label.text = animal.name
	species_label.text = tr("ITEM_%s" % str(animal.species).to_upper())
	happiness_bar.value = animal.happiness
	hunger_bar.value = animal.hunger
	bond_label.text = tr("UI_BOND_LEVEL") % animal.bond_level
	age_label.text = tr("UI_AGE_DAYS") % animal.age_days

	var happy_level: String = _husbandry.get_happiness_level(animal)
	status_label.text = tr("HAPPY_%s" % happy_level.to_upper())

	var spec: Dictionary = _husbandry.SPECIES_DATA[str(animal.species)]
	var product_id: String = spec["product"]
	product_label.text = tr("UI_PRODUCT_READY") % [tr("ITEM_%s" % product_id.to_upper()), animal.products_ready]

	collect_btn.disabled = animal.products_ready <= 0
	collect_btn.text = tr("UI_COLLECT_PRODUCT")


func _on_feed() -> void:
	if _selected_animal == &"" or food_option.selected < 0:
		return
	var food_name := food_option.get_item_text(food_option.selected)
	# Find food id from name (reverse lookup)
	for food in ["animal_treats", "chicken_feed", "carrot", "turnip", "cookie", "glow_berry", "rare_mushroom"]:
		if tr("ITEM_%s" % food.to_upper()) == food_name:
			_husbandry.feed_animal(_selected_animal, StringName(food))
			break
	_populate_food_options()
	_populate_list()
	_refresh_details()


func _on_brush() -> void:
	if _selected_animal == &"":
		return
	_husbandry.brush_animal(_selected_animal)
	_refresh_details()


func _on_play() -> void:
	if _selected_animal == &"":
		return
	_husbandry.play_with_animal(_selected_animal)
	_refresh_details()


func _on_collect() -> void:
	if _selected_animal == &"":
		return
	_husbandry.collect_product(_selected_animal)
	_refresh_details()


func _on_rename() -> void:
	# Simplified rename — use a dialog
	var dialog := AcceptDialog.new()
	dialog.title = tr("UI_RENAME_ANIMAL")
	var input := LineEdit.new()
	input.text = name_label.text
	dialog.add_child(input)
	dialog.dialog_text = tr("UI_ENTER_NAME")
	dialog.confirmed.connect(func():
		var new_name := input.text.strip_edges()
		if new_name != "" and _husbandry and _husbandry.has_method("get_animal"):
			var animal = _husbandry.get_animal(_selected_animal)
			if animal:
				animal.name = new_name
				_refresh_details()
				_populate_list()
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()


func _close() -> void:
	visible = false
	GameManager.pop_modal(&"animal_care")
	EventBus.ui_panel_toggled.emit(&"animal_care", false)
