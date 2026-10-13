extends Control
## Dev page: every guide section-03 building block ("guide" page) and the rarity row of the feature addendum ("rarity" page).
## Used for visual regression screenshots (shot_runner: `components`, `components_rarity`) and by the foundation smoke.
## All texts of the scenes are translation keys; strings that need arguments are filled here and follow the language.

const PAGES: Array[StringName] = [&"guide", &"rarity"]

@onready var slot_empty = %SlotTom
@onready var slot_filled = %SlotFyldt
@onready var slot_selected = %SlotValgt
@onready var slot_rare = %SlotSjælden
@onready var focused_button: Button = %FocusedButton
@onready var total_label: Label = %TotalLabel

@export var page: StringName = &"guide":
	set(v):
		page = v
		_apply_page()


func _ready() -> void:
	slot_empty.setup(&"", 0)
	slot_filled.setup(&"carrot", 12)
	slot_selected.setup(&"carrot", 12)
	slot_selected.button_pressed = true
	slot_rare.setup(&"moonstone", 1, "", true)
	# guide mock shows tiny mono names instead of art
	for s in [slot_filled, slot_selected, slot_rare]:
		s.item_icon.mode = 1
	# state sheet: the same buttons painted with their hover / pressed styleboxes (mouse can only be in one place)
	var row: HBoxContainer = %StatesRow
	for state in ["normal", "hover", "pressed"]:
		var b := Button.new()
		b.theme_type_variation = &"ButtonPrimary"
		b.text = {"normal": "GALLERY_STATE_NORMAL", "hover": "GALLERY_STATE_HOVER", "pressed": "GALLERY_STATE_PRESSED"}[state]
		b.focus_mode = Control.FOCUS_NONE
		row.add_child(b)                       # must be in the tree before the variation resolves
		b.add_theme_stylebox_override("normal", b.get_theme_stylebox(state))
		b.add_theme_font_size_override("font_size", 20)
	_setup_rarity_page()
	_translate()
	_apply_page()
	focused_button.grab_focus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_translate()


## strings with arguments and the ladder rows (they draw display strings, not keys)
func _translate() -> void:
	total_label.text = tr("SHOP_TOTAL") % "300"
	slot_filled.item_icon.display_name = tr("GALLERY_ITEM_CARROT")
	slot_selected.item_icon.display_name = tr("GALLERY_ITEM_CARROT")
	slot_rare.item_icon.display_name = tr("GALLERY_ITEM_MOONSTONE")
	for lr in find_children("Ladder*", "Control", true, false):
		if lr.has_meta("title_key"):
			lr.title = tr(str(lr.get_meta("title_key")))
			lr.chip = tr(str(lr.get_meta("chip_key")))


func _setup_rarity_page() -> void:
	for tile in find_children("Themed*", "Button", true, false):
		var sample: Array = tile.get_meta("sample")
		tile.setup(StringName(sample[1]), 3 if sample[0] == "normal" else 1, "", false, "", StringName(sample[0]))
		tile.button_pressed = tile.name.begins_with("ThemedSelected")


func show_page(p: StringName) -> void:
	page = p


func _apply_page() -> void:
	if not is_node_ready():
		return
	%Margin.visible = page == &"guide"
	%RarityMargin.visible = page == &"rarity"
