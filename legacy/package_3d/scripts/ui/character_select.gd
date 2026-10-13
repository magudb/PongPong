extends Control
## Character selection screen: Animal, Fairy, or Hobbit.

signal character_chosen(type: int, skin: StringName, player_name: String)

const CharacterType = preload("res://scripts/autoload/game_manager.gd").CharacterType

@onready var name_input: LineEdit = %NameInput
@onready var farm_input: LineEdit = %FarmNameInput
@onready var animal_btn: Button = %AnimalButton
@onready var fairy_btn: Button = %FairyButton
@onready var hobbit_btn: Button = %HobbitButton
@onready var preview_label: Label = %PreviewLabel
@onready var preview_desc: Label = %PreviewDescription
@onready var skin_option: OptionButton = %SkinOption
@onready var confirm_btn: Button = %ConfirmButton
@onready var back_btn: Button = %BackButton

var _preview_stage: Node3D
var _preview_actor: Node3D

var selected_type: CharacterType = CharacterType.ANIMAL
var selected_skin: StringName = &"animal_rabbit"

const SKINS := {
	CharacterType.ANIMAL: [
		{"id": &"animal_rabbit", "name_key": "SKIN_ANIMAL_RABBIT"},
		{"id": &"animal_fox", "name_key": "SKIN_ANIMAL_FOX"},
		{"id": &"animal_bear", "name_key": "SKIN_ANIMAL_BEAR"},
		{"id": &"animal_cat", "name_key": "SKIN_ANIMAL_CAT"},
		{"id": &"animal_bat", "name_key": "SKIN_ANIMAL_BAT"},
		{"id": &"animal_monkey", "name_key": "SKIN_ANIMAL_MONKEY"},
		{"id": &"animal_capybara", "name_key": "SKIN_ANIMAL_CAPYBARA"},
		{"id": &"animal_raccoon", "name_key": "SKIN_ANIMAL_RACCOON"},
		{"id": &"animal_penguin", "name_key": "SKIN_ANIMAL_PENGUIN"},
		{"id": &"animal_hedgehog", "name_key": "SKIN_ANIMAL_HEDGEHOG"},
		{"id": &"animal_frog", "name_key": "SKIN_ANIMAL_FROG"},
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
}


func _ready() -> void:
	animal_btn.pressed.connect(func(): _select_type(CharacterType.ANIMAL))
	fairy_btn.pressed.connect(func(): _select_type(CharacterType.FAIRY))
	hobbit_btn.pressed.connect(func(): _select_type(CharacterType.HOBBIT))
	skin_option.item_selected.connect(_on_skin_selected)
	confirm_btn.pressed.connect(_on_confirm)
	back_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn"))

	if name_input.text == "":
		name_input.text = ""
	if farm_input.text == "":
		farm_input.text = tr("DEFAULT_FARM_NAME")

	_setup_3d_preview()
	_select_type(CharacterType.ANIMAL)


func _select_type(type: CharacterType) -> void:
	selected_type = type
	animal_btn.disabled = type == CharacterType.ANIMAL
	fairy_btn.disabled = type == CharacterType.FAIRY
	hobbit_btn.disabled = type == CharacterType.HOBBIT

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

	_populate_skins()
	selected_skin = SKINS[type][0]["id"]
	_show_3d_preview()


func _populate_skins() -> void:
	skin_option.clear()
	for skin in SKINS[selected_type]:
		skin_option.add_item(tr(skin["name_key"]))
	skin_option.selected = 0


func _on_skin_selected(index: int) -> void:
	var skins: Array = SKINS[selected_type]
	if index >= 0 and index < skins.size():
		selected_skin = skins[index]["id"]
		_show_3d_preview()


func _on_confirm() -> void:
	var p_name := name_input.text.strip_edges()
	if p_name.is_empty():
		p_name = tr("DEFAULT_PLAYER_NAME")
	var farm_name := farm_input.text.strip_edges()
	if farm_name.is_empty():
		farm_name = tr("DEFAULT_FARM_NAME")

	character_chosen.emit(selected_type, selected_skin, p_name)
	# Hand off to game manager and load world
	GameManager.start_new_game(p_name, selected_type, farm_name)
	GameManager.character_skin = selected_skin
	get_tree().change_scene_to_file("res://scenes/main/world.tscn")


func _setup_3d_preview() -> void:
	var panel: Control = $HBoxContainer/RightPanel
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	_preview_stage = Node3D.new()
	viewport.add_child(_preview_stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.19, 0.16, 0.24)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.94, 0.93, 1.0)
	environment.environment.ambient_light_energy = 0.65
	_preview_stage.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -145, 0)
	key.light_energy = 1.1
	_preview_stage.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 35, 0)
	fill.light_energy = 0.5
	_preview_stage.add_child(fill)
	var camera := Camera3D.new()
	_preview_stage.add_child(camera)
	camera.position = Vector3(2.5, 2.3, -5.6)
	camera.look_at(Vector3(0, 1.0, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.2
	camera.current = true

func _show_3d_preview() -> void:
	if _preview_stage == null:
		return
	if is_instance_valid(_preview_actor):
		_preview_stage.remove_child(_preview_actor)
		_preview_actor.queue_free()
	_preview_actor = null
	var path := "res://scenes/player/skins/%s.tscn" % selected_skin
	if ResourceLoader.exists(path):
		var packed := load(path) as PackedScene
		_preview_actor = packed.instantiate() as Node3D
	else:
		# Owl and hobbit art were not requested; retain the original placeholder choices.
		_preview_actor = Node3D.new()
		var mesh := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.height = 1.6
		capsule.radius = 0.4
		mesh.mesh = capsule
		mesh.position.y = 0.8
		_preview_actor.add_child(mesh)
		var label := Label3D.new()
		label.text = tr("CHAR_ART_PLACEHOLDER")
		label.position.y = 2.0
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_preview_actor.add_child(label)
	_preview_stage.add_child(_preview_actor)
