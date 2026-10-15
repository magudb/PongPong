extends Control
## Character selection screen: Animal, Fairy, Hobbit or Ghost (P16 replaces this legacy screen by the four-card page).

signal character_chosen(type: int, skin: StringName, player_name: String)

const CharacterType = preload("res://scripts/autoload/game_manager.gd").CharacterType

@onready var name_input: LineEdit = %NameInput
@onready var farm_input: LineEdit = %FarmNameInput
@onready var animal_btn: Button = %AnimalButton
@onready var fairy_btn: Button = %FairyButton
@onready var hobbit_btn: Button = %HobbitButton
@onready var ghost_btn: Button = %GhostButton
@onready var preview_label: Label = %PreviewLabel
@onready var preview_desc: Label = %PreviewDescription
@onready var skin_option: OptionButton = %SkinOption
@onready var confirm_btn: Button = %ConfirmButton
@onready var back_btn: Button = %BackButton

var selected_type: CharacterType = CharacterType.ANIMAL
var selected_skin: StringName = &"animal_rabbit"

const SKINS := {
	CharacterType.ANIMAL: [
		{"id": &"animal_rabbit", "name_key": "SKIN_ANIMAL_RABBIT"},
		{"id": &"animal_fox", "name_key": "SKIN_ANIMAL_FOX"},
		{"id": &"animal_bear", "name_key": "SKIN_ANIMAL_BEAR"},
		{"id": &"animal_owl", "name_key": "SKIN_ANIMAL_OWL"},
	],
	CharacterType.FAIRY: [
		{"id": &"fairy_meadow", "name_key": "SKIN_FAIRY_MEADOW"},
		{"id": &"fairy_stardust", "name_key": "SKIN_FAIRY_STARDUST"},
		{"id": &"fairy_dusk", "name_key": "SKIN_FAIRY_DUSK"},
	],
	CharacterType.HOBBIT: [
		{"id": &"hobbit_pip", "name_key": "SKIN_HOBBIT_PIP"},
		{"id": &"hobbit_moss", "name_key": "SKIN_HOBBIT_MOSS"},
		{"id": &"hobbit_bramble", "name_key": "SKIN_HOBBIT_BRAMBLE"},
	],
	CharacterType.GHOST: [
		{"id": &"ghost_bu", "name_key": "SKIN_GHOST_BU"},
		{"id": &"ghost_hviske", "name_key": "SKIN_GHOST_HVISKE"},
	],
}


func _ready() -> void:
	animal_btn.pressed.connect(func(): _select_type(CharacterType.ANIMAL))
	fairy_btn.pressed.connect(func(): _select_type(CharacterType.FAIRY))
	hobbit_btn.pressed.connect(func(): _select_type(CharacterType.HOBBIT))
	ghost_btn.pressed.connect(func(): _select_type(CharacterType.GHOST))
	ghost_btn.text = tr("CHAR_GHOST_NAME")
	skin_option.item_selected.connect(_on_skin_selected)
	confirm_btn.pressed.connect(_on_confirm)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn"))

	if name_input.text == "":
		name_input.text = ""
	if farm_input.text == "":
		farm_input.text = tr("DEFAULT_FARM_NAME")

	_select_type(CharacterType.ANIMAL)


func _select_type(type: CharacterType) -> void:
	selected_type = type
	animal_btn.disabled = type == CharacterType.ANIMAL
	fairy_btn.disabled = type == CharacterType.FAIRY
	hobbit_btn.disabled = type == CharacterType.HOBBIT
	ghost_btn.disabled = type == CharacterType.GHOST

	match type:
		CharacterType.ANIMAL:
			preview_label.text = tr("CHAR_ANIMAL_NAME")
			preview_desc.text = tr("CHAR_ANIMAL_DESC")
		CharacterType.FAIRY:
			preview_label.text = tr("CHAR_FAIRY_NAME")
			preview_desc.text = tr("CHAR_FAIRY_DESC")
		CharacterType.HOBBIT:
			preview_label.text = tr("CHAR_HOBBIT_NAME")
			preview_desc.text = tr("CHAR_HOBBIT_DESC")
		CharacterType.GHOST:
			preview_label.text = tr("CHAR_GHOST_NAME")
			preview_desc.text = tr("CHAR_GHOST_PERK")

	_populate_skins()
	selected_skin = SKINS[type][0]["id"]


func _populate_skins() -> void:
	skin_option.clear()
	for skin in SKINS[selected_type]:
		skin_option.add_item(tr(skin["name_key"]))
	skin_option.selected = 0


func _on_skin_selected(index: int) -> void:
	var skins: Array = SKINS[selected_type]
	if index >= 0 and index < skins.size():
		selected_skin = skins[index]["id"]


func _on_confirm() -> void:
	var p_name := name_input.text.strip_edges()
	if p_name.is_empty():
		p_name = tr("DEFAULT_PLAYER_NAME")
	var farm_name := farm_input.text.strip_edges()
	if farm_name.is_empty():
		farm_name = tr("DEFAULT_FARM_NAME")

	character_chosen.emit(selected_type, selected_skin, p_name)
	# Hand off to game manager and load world
	GameManager.start_new_game(p_name, selected_type, farm_name, selected_skin)
	get_tree().change_scene_to_file("res://scenes/main/world.tscn")
