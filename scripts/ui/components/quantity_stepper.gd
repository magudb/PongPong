extends PanelContainer
## "−  5  +" quantity stepper (guide: shop footer; also the home chest). Scene: scenes/ui/components/quantity_stepper.tscn
## Emits value_changed. Clamp range with min_value / max_value (e.g. max = affordable or in stock).
##
## Keyboard / gamepad (UI_NAVIGATION.md 4.6 item 3d, amended by P28): the stepper is ONE focus stop. The ROOT takes focus, the two buttons are FOCUS_NONE (mouse
## only, so a disabled "-" is never a stop either) and the keys are read in the focused root's `_gui_input`: Left / Right -1 / +1 (a held key repeats: echo
## events; a fresh press at the end of the range goes on to focus navigation, see _step_or_pass), PageUp / PageDown +5 / -5, accept (Enter, Space, pad A)
## COMMITS (`committed(value)`: the shop's Køb). A focused Button would hand Left / Right to
## focus navigation before an `_unhandled_key_input` ever saw them, which is why the keys are not read there. The focus ring is painted by the root itself
## (the theme's `PanelField/focus` style, declared with the meta `tt_focus_style` like TTSlider does).

signal value_changed(value: int)
## accept pressed on the focused stepper
signal committed(value: int)

const STEP := 1
const PAGE_STEP := 5

@export var min_value: int = 1
@export var max_value: int = 99
@export var value: int = 1:
	set(v):
		var nv := clampi(v, min_value, maxi(min_value, max_value))
		var changed := nv != value
		value = nv
		_sync()
		if changed:
			value_changed.emit(value)

@onready var minus_button: Button = %MinusButton
@onready var plus_button: Button = %PlusButton
@onready var value_label: Label = %ValueLabel


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	for b in [minus_button, plus_button]:
		(b as Button).focus_mode = Control.FOCUS_NONE
		(b as Button).set_meta(&"tt_audit_ignore", "mouse-only: the stepper root is its ONE focus stop (UI_NAVIGATION.md 4.6 item 3d)")
	minus_button.pressed.connect(func(): step_by(-STEP))
	plus_button.pressed.connect(func(): step_by(STEP))
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	_declare_style()
	_sync()


func set_range(lo: int, hi: int) -> void:
	min_value = lo
	max_value = maxi(lo, hi)
	value = value   # re-clamp
	_sync()


## value += n (clamped). The keys and the buttons both go through here.
func step_by(n: int) -> void:
	value += n


func _sync() -> void:
	if not is_node_ready():
		return
	value_label.text = str(value)
	minus_button.disabled = value <= min_value
	plus_button.disabled = value >= max_value


func _gui_input(event: InputEvent) -> void:
	if not has_focus():
		return
	if event.is_action_pressed(&"ui_left", true):
		if not _step_or_pass(-STEP, event):
			return
	elif event.is_action_pressed(&"ui_right", true):
		if not _step_or_pass(STEP, event):
			return
	elif event.is_action_pressed(&"ui_page_up", true):
		step_by(PAGE_STEP)
	elif event.is_action_pressed(&"ui_page_down", true):
		step_by(-PAGE_STEP)
	elif event.is_action_pressed(&"ui_accept"):
		committed.emit(value)
	else:
		return
	accept_event()


## Left / Right while the value can still move: step and consume. At the end of the range a FRESH press is not consumed (focus navigation takes it, so a
## stepper in a row is never a dead end); a held key (echo) is swallowed there, so holding Right up to the maximum does not throw the focus out.
## Returns false when the event is left to focus navigation.
func _step_or_pass(n: int, event: InputEvent) -> bool:
	var at_limit := value + n < min_value or value + n > maxi(min_value, max_value)
	if at_limit and not event.is_echo():
		return false
	step_by(n)
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_declare_style()
		queue_redraw()


func _declare_style() -> void:
	var sb := get_theme_stylebox(&"focus")
	if sb != null and not (sb is StyleBoxEmpty):
		set_meta(&"tt_focus_style", sb)


## The gold ring around the whole field while it has focus.
func _draw() -> void:
	if has_focus():
		var sb := get_theme_stylebox(&"focus")
		if sb != null and not (sb is StyleBoxEmpty):
			draw_style_box(sb, Rect2(Vector2.ZERO, size))
