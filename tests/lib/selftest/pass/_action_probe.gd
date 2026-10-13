extends Node
## Helper (leading underscore: never discovered as a section). Counts presses of the `zoom_in` action.
var counter: Array = [0]

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"zoom_in"):
		counter[0] += 1
