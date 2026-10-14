extends Control
## Planted defect: hard-coded copy assigned in code (the static copy scan must find it).


func _ready() -> void:
	var l := Label.new()
	l.text = "Hard coded welcome sentence"
	add_child(l)
	var b := Button.new()
	b.text = "MENU_CONTINUE"
	b.position = Vector2(0, 60)
	add_child(b)
