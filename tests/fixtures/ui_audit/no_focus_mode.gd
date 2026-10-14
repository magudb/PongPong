extends Control
## A fixture screen that holds no focus owner in one mode (like Indretning PLACE or a dialogue text line): `_wants_focus()` returns `wants`. Attached with set_script() on a
## built screen; the audit asks for no initial focus and does not walk it while `wants` is false.

var wants := false


func _wants_focus() -> bool:
	return wants
