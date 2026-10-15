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


## Esc is this panel's key: it opens the pause menu when nothing is modal and closes it when pause is the top modal
## (a modal stacked on top - the save/load screen - owns Esc then).
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel"):
		return
	var top := GameManager.top_modal()
	if visible and (top == &"" or top == &"pause"):
		_on_resume()
	elif not GameManager.is_modal_open():
		EventBus.ui_panel_toggled.emit(&"pause", true)
	else:
		return
	get_viewport().set_input_as_handled()


func _on_resume() -> void:
	visible = false
	GameManager.pop_modal(&"pause")
	EventBus.ui_panel_toggled.emit(&"pause", false)


func _on_save() -> void:
	EventBus.ui_panel_toggled.emit(&"save_menu", true)


func _on_load() -> void:
	EventBus.ui_panel_toggled.emit(&"load_menu", true)


func _on_settings() -> void:
	EventBus.ui_panel_toggled.emit(&"settings", true)


func _on_quit() -> void:
	GameManager.pop_all_modals()   # the menu would stay frozen otherwise (the tree is paused)
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")


func _on_panel_toggled(panel_name: StringName, is_open: bool) -> void:
	if panel_name == &"pause":
		visible = is_open
		if is_open:
			GameManager.push_modal(&"pause")
			resume_btn.text = tr("UI_RESUME")
			save_btn.text = tr("MENU_SAVE")
			load_btn.text = tr("MENU_LOAD_GAME")
			settings_btn.text = tr("MENU_SETTINGS")
			quit_btn.text = tr("MENU_QUIT")
		else:
			GameManager.pop_modal(&"pause")
