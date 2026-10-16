extends TTScreen
## NPCs and event scenes await the same modal lifetime; text takes no keyboard focus.
signal session_finished(result: Dictionary)
signal choice_selected(action: String, data: Dictionary)
const Portraits := preload("res://scripts/ui/theme/tt_portraits.gd")
var _speaker: Dictionary = {}
var _lines: Array = []
var _choices: Array = []
var _buttons: Array[Button] = []
var _line := -1
var _shown := 0
var _typing := false
var _elapsed := 0.0
var _generation := 0
var _session := false
var _voice_key := ""
var _has_voice := false
var chars_per_second := 40.0

func _init() -> void:
	super._init()
	screen_id = &"dialogue_ui"
	modal_name = &"dialogue"
	pauses_tree = false

func _ready() -> void:
	super._ready()
	add_to_group("dialogue_ui")
	%NextButton.focus_mode = Control.FOCUS_NONE
	%NextButton.set_meta("tt_audit_ignore", "Mouse alternative to interact/ui_accept; dialogue text deliberately has no focus owner (S11)")
	%NextButton.pressed.connect(_advance)
	%TextLabel.focus_mode = Control.FOCUS_NONE
	%TextLabel.selection_enabled = false
	UiNav.watcher().device_changed.connect(func(_device):
		_refresh_hint()
		if _session:
			_refresh_texts())
	chars_per_second = float(LuaRuntime.get_config("ui.dialogue_chars_per_second", 40.0))
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("dialogue", Callable(get_script(), &"fixture_setup"))
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("intro", Callable(get_script(), &"fixture_intro"))
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("dialogue_guide", Callable(get_script(), &"fixture_guide"))

func _wants_focus() -> bool:
	return not _buttons.is_empty() and %ChoicesBox.visible

func _initial_focus() -> Control:
	return _buttons[0] if not _buttons.is_empty() else null

func show_lines(speaker: Dictionary, lines: Array, choices: Array = []) -> Dictionary:
	# Resolve the old await before starting the next one.
	if _session:
		_finish(false)
	_generation += 1
	_speaker = speaker.duplicate(true)
	_lines = lines.duplicate(true)
	_choices = choices.duplicate(true)
	_line = -1
	_shown = 0
	_session = true
	%TextLabel.text = ""
	_clear_choices()
	super.open()
	if not is_open():
		_session = false
		return {"completed": false, "lines_shown": 0, "choice": {}}
	# This frameless overlay dispatches advance in _input; the panel/choice buttons
	# own GUI clicks. World actions remain guarded by the dialogue modal/phase.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_next_line()
	return await session_finished

func start_dialogue(speaker: Dictionary, lines: Array, choices: Array = []) -> Dictionary:
	return await show_lines(speaker, lines, choices)

func _process(delta: float) -> void:
	super._process(delta)
	if _typing:
		_elapsed += delta
		%TextLabel.visible_characters = mini(int(_elapsed * maxf(chars_per_second, 1.0)), %TextLabel.get_total_character_count())
		_typing = %TextLabel.visible_characters < %TextLabel.get_total_character_count()
	%VoiceGroup.visible = _has_voice and AudioManager.is_voice_playing()

func _input(event: InputEvent) -> void:
	if is_open() and is_top() and not _wants_focus() and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		_advance()
		return
	if is_open() and is_top() and event.is_pressed() and not event.is_echo() and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"ui_accept")):
		get_viewport().set_input_as_handled()
		if _wants_focus():
			var focused := get_viewport().gui_get_focus_owner()
			if focused is Button and focused in _buttons:
				_pick(focused.get_meta("choice"))
		else:
			_advance()
		return
	super._input(event)

func _next_line() -> void:
	_clear_choices()
	_line += 1
	if _line >= _lines.size():
		if _choices.is_empty():
			_finish_empty.call_deferred(_generation)
		else:
			_show_choices()
		return
	var row: Dictionary = LuaData.dict(_lines[_line])
	var text := _line_text(row)
	%TextLabel.text = text
	%TextLabel.visible_characters = 0
	_elapsed = 0
	_typing = not text.is_empty()
	_shown += 1
	_voice_key = str(row.get("voice_key", ""))
	_has_voice = _voice_key != "" and AudioManager.voice_exists(_voice_key)
	AudioManager.stop_voice()
	if _has_voice:
		AudioManager.play_voice(_voice_key)
	%NextButton.visible = true
	_refresh_texts()
	EventBus.dialogue_line_shown.emit(%SpeakerLabel.text, text, _voice_key)
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()

func _finish_empty(generation: int) -> void:
	if _session and generation == _generation:
		_finish(true)

func _advance() -> void:
	if not _session or not is_top():
		return
	if _typing:
		_typing = false
		%TextLabel.visible_characters = -1
	else:
		if _wants_focus():
			var focused := get_viewport().gui_get_focus_owner()
			_pick(focused.get_meta("choice") if focused is Button and focused in _buttons else _choices[0])
		else:
			_next_line()

func _show_choices() -> void:
	_typing = false
	%TextLabel.visible_characters = -1
	%NextButton.visible = true
	%ChoicesBox.visible = true
	for choice in _choices:
		var button := Button.new()
		button.name = "Choice" + str(_buttons.size())
		button.theme_type_variation = &"ChoiceRow"
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = _choice_text(choice)
		button.icon = preload("res://assets/ui/icons/caret.svg")
		button.set_meta("choice", choice)
		%ChoicesBox.add_child(button)
		button.pressed.connect(_pick.bind(choice))
		_buttons.append(button)
	UiNav.wire_ring(_buttons)
	if not _buttons.is_empty():
		_buttons[0].grab_focus()

func _pick(choice: Dictionary) -> void:
	if not _session or not is_top():
		return
	_finish(true, choice)

func close() -> void:
	_finish(false)

func _finish(completed: bool, choice: Dictionary = {}) -> void:
	if not _session:
		return
	_session = false
	_generation += 1
	_typing = false
	_has_voice = false
	AudioManager.stop_voice()
	_clear_choices()
	super.close()
	if completed and not choice.is_empty():
		choice_selected.emit(str(choice.get("action", "close")), choice.duplicate(true))
	session_finished.emit({"completed": completed, "lines_shown": _shown, "choice": choice.duplicate(true)})

func _exit_tree() -> void:
	_finish(false)
	super._exit_tree()

func _clear_choices() -> void:
	_buttons.clear()
	if not is_node_ready():
		return
	for child in %ChoicesBox.get_children():
		%ChoicesBox.remove_child(child)
		child.queue_free()
	%ChoicesBox.visible = false

func _refresh_hint() -> void:
	if is_node_ready():
		%NextButton.text = UiHints.format("HINT_CONTINUE", &"interact")

func _refresh_texts() -> void:
	if not is_node_ready():
		return
	%SpeakerLabel.text = tr(str(_speaker.get("name_key", _speaker.get("speaker_name_key", ""))))
	%PortraitTexture.texture = _speaker.get("portrait", Portraits.portrait(StringName(str(_speaker.get("id", "")))))
	%VoiceIndicator.text = tr("DIALOGUE_VOICE_DA")
	_refresh_hint()
	var shown_line := mini(_line, _lines.size() - 1)
	if shown_line >= 0 and _lines[shown_line].has("text_key"):
		%TextLabel.text = _line_text(_lines[shown_line])
	for button in _buttons:
		button.text = _choice_text(button.get_meta("choice"))

func _choice_text(choice: Dictionary) -> String:
	var text := tr(str(choice.get("text_key", "")))
	if text.contains("%s") and choice.has("title_quest"):
		text = text % QuestManager.get_title(str(choice.title_quest))
	return text

static func fixture_setup(node: Node, _host: Node) -> void:
	node.show_lines({"id": "mayor_lyra", "name_key": "NPC_MAYOR_LYRA"}, [{"text_key": "DLG_LYRA_HELLO"}], [{"text_key": "REL_TALK_GOODBYE", "action": "close"}])
	node._typing = false
	node.get_node("%TextLabel").visible_characters = -1
	node._advance()

static func fixture_intro(node: Node, _host: Node) -> void:
	node.show_lines({"id": "fairy_king", "name_key": "NPC_FAIRY_KING"}, [{"text_key": "DLG_KING_LETTER"}], [])
	node._typing = false
	node.get_node("%TextLabel").visible_characters = -1

static func fixture_guide(node: Node, _host: Node) -> void:
	# Section 03 is a 660px component crop; production viewport captures retain 880px.
	var background := _host.get_node("Backdrop")
	background.color_a = Color("efede5")
	background.color_b = Color("efede5")
	background.queue_redraw()
	node.get_node("%Box").custom_minimum_size.x = 660
	node.show_lines({"id": "mayor_lyra", "name_key": "NPC_MAYOR_LYRA"}, [{"text_key": "GUIDE_DLG_1"}], [{"text_key": "GUIDE_CH_1", "action": "close"}, {"text_key": "GUIDE_CH_2", "action": "close"}])
	node._typing = false
	node.get_node("%TextLabel").visible_characters = -1
	node._advance()


func _line_text(row: Dictionary) -> String:
	return UiHints.format_line(row)
