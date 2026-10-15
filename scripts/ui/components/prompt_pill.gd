class_name PromptPill
extends Control
## The interaction prompt (UI_NAVIGATION.md 5.1 S23): an ink pill with the guide's gold border, centred 160 px above the bottom edge (above the tool name),
## shown while `EventBus.interaction_prompt_changed(text)` is non-empty. A prompt that carries its key in the text ("E: Sov", "E · Tal med Pippin") has that
## leading key token replaced by a KeyCap with the glyph of `interact` on the CURRENT device ("E" on the keyboard, "A" on a pad); the verb keeps its text
## ("a prompt never bakes a key into the translation": new prompts are written as the verb only and get the cap as well). Scene:
## scenes/ui/components/prompt_pill.tscn. Not focusable, mouse_filter IGNORE.
##
## The text may be a translation key (UPPER_CASE with an underscore): it is translated and follows a language switch; a ready display string (what
## the emitters send today) is shown as it is. The cap follows the device through UiNav.watcher().device_changed.

const BOTTOM_OFFSET := 160.0

var _text := ""
var _connected := false
var _watcher_connected := false

@onready var _pill: PanelContainer = %Pill
@onready var _cap: Label = %KeyCap
@onready var _verb: Label = %Verb


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	# the pill is the "PromptPill" look of the theme (ink fill, 2 px gold border, radius 999) on a container that holds the cap and the verb
	var look := get_theme_stylebox("normal", "PromptPill")
	if look != null:
		_pill.add_theme_stylebox_override("panel", look)
	_connect()
	_render()


func _enter_tree() -> void:
	if is_node_ready():
		_connect()


func _exit_tree() -> void:
	var bus := Svc.node("EventBus")
	if bus != null and _connected and bus.is_connected(&"interaction_prompt_changed", _on_prompt):
		bus.disconnect(&"interaction_prompt_changed", _on_prompt)
	_connected = false
	var w := UiNav.watcher()
	if w != null and _watcher_connected and w.device_changed.is_connected(_on_device_changed):
		w.device_changed.disconnect(_on_device_changed)
	_watcher_connected = false


func _connect() -> void:
	if not _connected:
		var bus := Svc.node("EventBus")
		if bus != null:
			_connected = true
			bus.connect(&"interaction_prompt_changed", _on_prompt)
	if not _watcher_connected:
		var w := UiNav.watcher()
		if w != null:
			_watcher_connected = true
			w.device_changed.connect(_on_device_changed)


func _on_prompt(text: String) -> void:
	set_prompt(text)


func _on_device_changed(_dev: StringName) -> void:
	_render()


## Shows the prompt ("" hides it).
func set_prompt(text: String) -> void:
	_text = text
	if is_node_ready():
		_render()


func prompt_text() -> String:
	return _text


## What the pill shows as plain data: {visible, key: bool, cap, verb}.
func shown() -> Dictionary:
	return {"visible": _pill.visible, "key": _cap.visible, "cap": _cap.text, "verb": _verb.text}


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_render()


func _render() -> void:
	var shown_text: String = str(TranslationServer.translate(_text)) if UiHints.is_key(_text) else _text
	_pill.visible = shown_text != ""
	if shown_text == "":
		return
	var parts := UiHints.split_prompt(shown_text)
	var cap := UiHints.glyph(&"interact")
	if bool(parts["key"]):
		_cap.text = cap
		_cap.visible = cap != ""
		_verb.text = str(parts["rest"])
	else:
		# a verb-only prompt gets the cap of `interact` as well
		_cap.text = cap
		_cap.visible = cap != ""
		_verb.text = shown_text
