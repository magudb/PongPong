extends Node
## Planted defect of the text-field audit: a screen that reads the `inventory` hotkey in _input (before the focused text field sees the key),
## so typing "i" into a name field also opens the backpack.


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		get_node("/root/GameManager").push_modal(&"audit_inventory")
