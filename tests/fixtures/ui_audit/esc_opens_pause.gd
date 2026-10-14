extends Node
## Planted defect of the Esc-does-nothing check (esc_depth 0, the title screen): a screen that opens a pause modal when Esc / Start is pressed.


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_node("/root/GameManager").push_modal(&"audit_pause")
