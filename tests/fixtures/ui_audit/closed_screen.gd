extends Control
## Planted defect: a screen whose is_open() says false (it was never opened, or it has already closed) while the audit asks for its focus.


func is_open() -> bool:
	return false
