class_name WhisperLine
extends Control
## The whisper (UI_NAVIGATION.md 5.1 S09 / S10): `EventBus.whisper_requested(text_key)` shows tr(text_key) in a `PanelWhisper` (night plate, teal border) at
## the left / bottom corner (40 px from both edges), at most 360 px wide, `Whisper` italic 18, for seconds_for(text): 3.5 s for a short line, longer for a long one (UX-12: a fixed 3.5 s was too
## short to read a two-line whisper), at most 8 s (0.15 s in, 0.4 s out). A second whisper replaces the first and restarts the timer. The farm HUD, the forest HUD and the title / select scenes instance it: every refusal of the world (the bed before
## 18:00, a locked warp, missing items, Indretning outside the home, a wrong-season seed) is a whisper, and without it none of them gives any feedback.
## Scene: scenes/ui/components/whisper_line.tscn. Not focusable, mouse_filter IGNORE. The text re-labels on a language switch while it is showing.

const SECONDS := 3.5
## the reading time a whisper stays up: 1.5 s plus this many characters per second, between SECONDS and MAX_SECONDS
const READ_CHARS_PER_SECOND := 14.0
const MAX_SECONDS := 8.0
const MAX_WIDTH := 360.0
const FADE_IN := 0.15
const FADE_OUT := 0.4

var _key := ""
var _connected := false
var _tween: Tween

@onready var _panel: PanelContainer = %Panel
@onready var _label: Label = %Text


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_panel.visible = false
	_connect()


func _enter_tree() -> void:
	if is_node_ready():
		_connect()


func _exit_tree() -> void:
	var bus := Svc.node("EventBus")
	if bus != null and _connected and bus.is_connected(&"whisper_requested", _on_whisper):
		bus.disconnect(&"whisper_requested", _on_whisper)
	_connected = false
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _connect() -> void:
	if _connected:
		return
	var bus := Svc.node("EventBus")
	if bus != null:
		_connected = true
		bus.connect(&"whisper_requested", _on_whisper)


func _on_whisper(text_key: String) -> void:
	show_whisper(text_key)


## Shows a whisper: a translation key (translated now and on a language switch) or a ready display string.
func show_whisper(text_key: String) -> void:
	if text_key == "":
		return
	_key = text_key
	_apply_text()
	_panel.visible = true
	_panel.modulate.a = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "modulate:a", 1.0, FADE_IN)
	_tween.tween_interval(seconds_for(_label.text))
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(_hide)


## How long a whisper with this display text stays fully visible.
static func seconds_for(text: String) -> float:
	return clampf(1.5 + text.length() / READ_CHARS_PER_SECOND, SECONDS, MAX_SECONDS)


func is_showing() -> bool:
	return _panel != null and _panel.visible


func shown_text() -> String:
	return _label.text if is_showing() else ""


func _hide() -> void:
	_panel.visible = false
	_key = ""


func _apply_text() -> void:
	var text: String = str(TranslationServer.translate(_key)) if UiHints.is_key(_key) else _key
	_label.text = text
	# at most MAX_WIDTH wide: a short whisper hugs its text, a long one wraps
	var font := _label.get_theme_font("font")
	var font_px := _label.get_theme_font_size("font_size")
	var margin := _panel.get_theme_stylebox("panel").get_minimum_size().x
	var inner := MAX_WIDTH - margin
	var wide := font != null and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x > inner
	_label.custom_minimum_size.x = inner if wide else 0.0
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wide else TextServer.AUTOWRAP_OFF


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready() and _key != "":
		_apply_text()
