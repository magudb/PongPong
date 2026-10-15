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
var selected_skin: StringName = &""

## The skins of the current selection, filled by _populate_skins from characters.lua (retired rows never offered).
var _skins: Array = []

const _RACE_KEYS := {
	CharacterType.ANIMAL: "animal",
	CharacterType.FAIRY: "fairy",
	CharacterType.HOBBIT: "hobbit",
	CharacterType.GHOST: "ghost",
}


## [{id, name_key}] of the live skins of a race, in characters.lua order (default_skin first when present).
static func _skins_of(type: CharacterType) -> Array:
	var race: String = _RACE_KEYS.get(type, "animal")
	var out: Array = []
	var wanted := CharacterCatalog.default_skin(race)
	var fallback_first: Array = []
	for id in CharacterCatalog.skin_ids():
		var row := CharacterCatalog.skin(id)
		if str(row.get("race", "")) != race or bool(row.get("retired", false)):
			continue
		var entry := {"id": StringName(id), "name_key": str(row.get("name_key", ""))}
		if id == wanted:
			fallback_first.push_front(entry)
		else:
			fallback_first.append(entry)
	out.append_array(fallback_first)
	return out


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


func _populate_skins() -> void:
	_skins = _skins_of(selected_type)
	skin_option.clear()
	for skin in _skins:
		var key: String = skin["name_key"]
		skin_option.add_item(tr(key) if key != "" else str(skin["id"]))
	skin_option.selected = 0
	selected_skin = _skins[0]["id"] if not _skins.is_empty() else &""


func _on_skin_selected(index: int) -> void:
	if index >= 0 and index < _skins.size():
		selected_skin = _skins[index]["id"]


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
