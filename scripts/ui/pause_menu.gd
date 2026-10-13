extends Control
## Pause menu: resume, save, load, settings, quit to main.

@onready var resume_btn: Button = %ResumeButton
@onready var save_btn: Button = %SaveButton
@onready var load_btn: Button = %LoadButton
@onready var settings_btn: Button = %SettingsButton
@onready var quit_btn: Button = %QuitButton
@onready var panel: PanelContainer = %PanelContainer


func _ready() -> void:
	visible = false
	resume_btn.pressed.connect(_on_resume)
	save_btn.pressed.connect(_on_save)
	load_btn.pressed.connect(_on_load)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	EventBus.ui_panel_toggled.connect(_on_panel_toggled)


func _on_resume() -> void:
	visible = false
	GameManager.change_phase(GameManager.GamePhase.PLAYING)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	EventBus.ui_panel_toggled.emit(&"pause", false)


func _on_save() -> void:
	EventBus.ui_panel_toggled.emit(&"save_menu", true)


func _on_load() -> void:
	EventBus.ui_panel_toggled.emit(&"load_menu", true)


func _on_settings() -> void:
	EventBus.ui_panel_toggled.emit(&"settings", true)


func _on_quit() -> void:
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")


func _on_panel_toggled(panel_name: StringName, is_open: bool) -> void:
	if panel_name == &"pause":
		visible = is_open
		if is_open:
			resume_btn.text = tr("UI_RESUME")
			save_btn.text = tr("MENU_SAVE")
			load_btn.text = tr("MENU_LOAD_GAME")
			settings_btn.text = tr("MENU_SETTINGS")
			quit_btn.text = tr("MENU_QUIT")
