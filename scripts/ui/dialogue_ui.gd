extends Control
## Dialogue UI: shows speaker, text with typewriter effect, choices.

signal choice_selected(action: String, data: Dictionary)

@onready var speaker_label: Label = %SpeakerLabel
@onready var text_label: RichTextLabel = %TextLabel
@onready var choices_box: VBoxContainer = %ChoicesBox
@onready var next_button: Button = %NextButton
@onready var voice_indicator: Label = %VoiceIndicator

var _full_text: String = ""
var _char_index: int = 0
var _typing_speed: float = 40.0  # chars per second
var _is_typing: bool = false
var _current_choices: Array = []


func _ready() -> void:
	visible = false
	next_button.pressed.connect(_on_next_pressed)
	EventBus.dialogue_line_shown.connect(_on_line_shown)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)
	_typing_speed = LuaRuntime.get_config("ui.dialogue_chars_per_second", 40.0)


func _on_line_shown(speaker: String, text: String, voice_key: String) -> void:
	visible = true
	speaker_label.text = speaker
	_full_text = text
	_char_index = 0
	text_label.text = ""
	_is_typing = true
	choices_box.visible = false
	next_button.visible = true

	if voice_key != "":
		voice_indicator.text = "♪"
		voice_indicator.visible = true
	else:
		voice_indicator.visible = false

	_start_typewriter()


func _start_typewriter() -> void:
	while _is_typing and _char_index < _full_text.length():
		_char_index += 1
		text_label.text = _full_text.substr(0, _char_index)
		await get_tree().create_timer(1.0 / _typing_speed).timeout
	_is_typing = false
	text_label.text = _full_text


func _on_next_pressed() -> void:
	if _is_typing:
		# Skip to end
		_is_typing = false
		text_label.text = _full_text
		return
	# Advance to next line or show choices
	# (Dialogue flow is managed by NPC script)
	pass


func show_choices(choices: Array) -> void:
	_current_choices = choices
	for child in choices_box.get_children():
		child.queue_free()

	for choice in choices:
		var btn := Button.new()
		btn.text = tr(choice.get("text_key", ""))
		btn.pressed.connect(func(): _on_choice_pressed(choice))
		choices_box.add_child(btn)

	choices_box.visible = true
	next_button.visible = false


func _on_choice_pressed(choice: Dictionary) -> void:
	var action: String = choice.get("action", "close")
	var data: Dictionary = choice.duplicate()
	choice_selected.emit(action, data)
	visible = false


func _on_dialogue_ended() -> void:
	visible = false
	_is_typing = false
