extends VBoxContainer
## Data driven recipe list; the inventory screen owns its focus crossings.
signal navigation_changed
const Fmt := preload("res://scripts/ui/theme/tt_format.gd")
var recipe_buttons: Array[Button] = []
var _recipes: Array = []
var _recipe_id := ""
var _busy := false
@onready var craft_button: Button = %CraftButton

func _ready() -> void:
	craft_button.pressed.connect(_craft)
	refresh()

func refresh() -> void:
	if not is_node_ready() or _busy:
		return
	var previous := _recipes.map(func(recipe): return str(recipe.id))
	_recipes = CraftingSystem.get_recipes()
	if previous != _recipes.map(func(recipe): return str(recipe.id)):
		for child in %RecipeList.get_children():
			%RecipeList.remove_child(child)
			child.queue_free()
		recipe_buttons.clear()
		var group := ButtonGroup.new()
		group.set_meta("tt_value_selection", true)
		for recipe in _recipes:
			var button := Button.new()
			button.name = "Recipe_" + str(recipe.id)
			button.theme_type_variation = &"RecipeRow"
			button.toggle_mode = true
			button.button_group = group
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			%RecipeList.add_child(button)
			var margin := MarginContainer.new()
			margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for side in ["left", "top", "right", "bottom"]:
				margin.add_theme_constant_override("margin_" + side, 10)
			button.add_child(margin)
			var texts := VBoxContainer.new()
			texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
			margin.add_child(texts)
			for spec in [["Name", "Heavy18"], ["Status", "Muted17"]]:
				var label := Label.new()
				label.name = spec[0]
				label.theme_type_variation = StringName(spec[1])
				label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				texts.add_child(label)
			button.set_meta("name_label", texts.get_node("Name"))
			button.set_meta("status_label", texts.get_node("Status"))
			button.custom_minimum_size.y = 66
			button.pressed.connect(_activate.bind(str(recipe.id)))
			recipe_buttons.append(button)
	if not _recipes.any(func(recipe): return str(recipe.id) == _recipe_id):
		_recipe_id = str(_recipes[0].id) if not _recipes.is_empty() else ""
	for i in recipe_buttons.size():
		var recipe: Dictionary = _recipes[i]
		var available := CraftingSystem.can_craft(recipe.id)
		(recipe_buttons[i].get_meta("name_label") as Label).text = tr(str(recipe.get("name_key", "")))
		(recipe_buttons[i].get_meta("status_label") as Label).text = _status(available)
		recipe_buttons[i].set_pressed_no_signal(str(recipe.id) == _recipe_id)
	_show_recipe()
	navigation_changed.emit()

func _status(available: Dictionary) -> String:
	if bool(available.ok):
		return tr("WORKSHOP_CAN_CRAFT")
	var locked: Dictionary = available.get("locked", {})
	if not locked.is_empty():
		if str(locked.reason) == "flag":
			return tr("STORE_NEEDS_BLUEPRINT")
		var home := Svc.node("HomeManager")
		var key := "HOME_TIER_%d" % int(locked.get("need", 1))
		if home != null and home.has_method("tier_def"):
			key = str(home.call("tier_def", int(locked.need)).get("name_key", key))
		return tr("STORE_NEEDS_HOME_FMT") % tr(key)
	var missing: Array = available.get("missing", [])
	if not missing.is_empty():
		var row: Dictionary = missing[0]
		return tr("WORKSHOP_MISSING") % [int(row.need) - int(row.have), tr(str(ItemKinds.def(row.item).get("name_key", "")))]
	return tr("STORE_CANNOT_CRAFT")

func _select(id: String) -> void:
	_recipe_id = id
	for i in recipe_buttons.size():
		recipe_buttons[i].set_pressed_no_signal(str(_recipes[i].id) == id)
	_show_recipe()
	navigation_changed.emit()

func _activate(id: String) -> void:
	_select(id)
	if not craft_button.disabled:
		craft_button.grab_focus()

func _show_recipe() -> void:
	var recipe := CraftingSystem.get_recipe(_recipe_id)
	%RecipeName.text = tr(str(recipe.get("name_key", "")))
	for child in %IngredientRow.get_children():
		%IngredientRow.remove_child(child)
		child.queue_free()
	for id in recipe.get("ingredients", {}):
		var amount := int(recipe.ingredients[id])
		var have := EconomyManager.count_item(StringName(id))
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		%IngredientRow.add_child(column)
		var tile := RaritySlot.new()
		tile.slot_size = 40
		tile.item_id = StringName(id)
		tile.rarity = ItemKinds.rarity_of(id)
		tile.tooltip_text = tr(str(ItemKinds.def(id).get("name_key", "")))
		column.add_child(tile)
		var count := Label.new()
		count.theme_type_variation = &"CatalogHaveCount" if have >= amount else &"CatalogMissingCount"
		count.text = "%s / %s" % [Fmt.thousands(have), Fmt.thousands(amount)]
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(count)
	var available := CraftingSystem.can_craft(_recipe_id)
	%RecipeStatus.text = _status(available)
	UiNav.set_enabled(craft_button, bool(available.ok))

func _craft() -> void:
	var screen := get_owner() as TTScreen
	if _busy or craft_button.disabled or not is_visible_in_tree() or (screen != null and (not screen.is_open() or not screen.is_top())):
		return
	_busy = true
	var ok := CraftingSystem.craft(_recipe_id)
	_busy = false
	if ok:
		var recipe := CraftingSystem.get_recipe(_recipe_id)
		var output: Dictionary = recipe.get("output", {})
		EventBus.notification_posted.emit(tr("WORKSHOP_CRAFTED_TITLE"), tr(str(ItemKinds.def(output.get("item", "")).get("name_key", ""))), "info")
	refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()
