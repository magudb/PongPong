extends PanelContainer
## "−  5  +" quantity stepper (guide: shop footer). Scene: scenes/ui/components/quantity_stepper.tscn
## Emits value_changed. Clamp range with min_value / max_value (e.g. max = affordable or in stock).

signal value_changed(value: int)

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
	minus_button.pressed.connect(func(): value -= 1)
	plus_button.pressed.connect(func(): value += 1)
	_sync()


func set_range(lo: int, hi: int) -> void:
	min_value = lo
	max_value = maxi(lo, hi)
	value = value   # re-clamp
	_sync()


func _sync() -> void:
	if not is_node_ready():
		return
	value_label.text = str(value)
	minus_button.disabled = value <= min_value
	plus_button.disabled = value >= max_value


func _unhandled_key_input(event: InputEvent) -> void:
	# keyboard / gamepad: only when a child has focus
	if not (minus_button.has_focus() or plus_button.has_focus()):
		return
	if event.is_action_pressed("ui_left"):
		value -= 1
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		value += 1
		get_viewport().set_input_as_handled()
