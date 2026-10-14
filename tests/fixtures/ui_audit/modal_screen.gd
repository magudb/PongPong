extends "res://tests/fixtures/ui_audit/modals.gd"
## A screen that opens its own modal layer when it is instantiated (the way a registry row's scene does): the escape check of a spec row (esc_depth N, no driver)
## runs in pre_opened mode against it. `layers` is how many nested layers it opens (default 1).

var layers := 1


func _ready() -> void:
	super._ready()
	for level in layers:
		open_level(level)
