extends Control
## Main menu: new game, continue, settings, quit.

@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var new_game_btn: Button = %NewGameButton
@onready var continue_btn: Button = %ContinueButton
@onready var settings_btn: Button = %SettingsButton
@onready var quit_btn: Button = %QuitButton
@onready var language_btn: Button = %LanguageButton


func _ready() -> void:
	title_label.text = tr("GAME_TITLE")
	subtitle_label.text = tr("GAME_SUBTITLE")
	new_game_btn.text = tr("MENU_NEW_GAME")
	continue_btn.text = tr("MENU_CONTINUE")
	settings_btn.text = tr("MENU_SETTINGS")
	quit_btn.text = tr("MENU_QUIT")
	language_btn.text = tr("MENU_LANGUAGE")

	new_game_btn.pressed.connect(_on_new_game)
	continue_btn.pressed.connect(_on_continue)
	settings_btn.pressed.connect(_on_settings)
	quit_btn.pressed.connect(_on_quit)
	language_btn.pressed.connect(_on_language)

	continue_btn.disabled = not SaveManager.has_save(0)


func _on_new_game() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/character_select.tscn")


func _on_continue() -> void:
	if SaveManager.load_game(0):
		get_tree().change_scene_to_file("res://scenes/main/world.tscn")


func _on_settings() -> void:
	EventBus.ui_panel_toggled.emit(&"settings", true)


func _on_quit() -> void:
	get_tree().quit()


func _on_language() -> void:
	if LocalizationManager.is_da():
		LocalizationManager.set_locale("en")
	else:
		LocalizationManager.set_locale("da")
	# Refresh labels
	_ready()
