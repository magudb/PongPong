extends RefCounted
## Transient completion data, never save state or physical delivery authority.
signal finished
var resolved := false
var _result: Dictionary = {}

func resolve(value: Dictionary) -> void:
	if resolved: return
	_result = freeze(value.duplicate(true))
	resolved = true
	finished.emit()

func wait() -> Dictionary:
	if not resolved: await finished
	return _result

static func freeze(value: Variant) -> Variant:
	if value is Dictionary:
		for key in value: value[key] = freeze(value[key])
		value.make_read_only()
	elif value is Array:
		for i in value.size(): value[i] = freeze(value[i])
		value.make_read_only()
	return value
