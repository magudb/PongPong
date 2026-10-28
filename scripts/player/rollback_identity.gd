extends RefCounted
## Operation-local runtime preimage, used only after SaveManager verifies a whole
## failed apply was restored. Keep collection references held by suspended grants;
## codec roundtrips alone rebuild them. No callbacks, serialization or authority.

var _fields: Array = []
var _collections: Array = []

func keep_fields(object: Object, fields: Array) -> void:
	for field in fields:
		var value: Variant = object.get(field)
		_fields.append([object, field, value])
		keep_value(value)

func keep_script_fields(object: RefCounted) -> void:
	var fields: Array = []
	for property in object.get_script().get_script_property_list():
		if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			fields.append(property.name)
	keep_fields(object, fields)

func keep_value(value: Variant) -> void:
	if not value is Dictionary and not value is Array: return
	if value.is_read_only(): return
	for entry: Array in _collections:
		if is_same(value, entry[0]): return
	_collections.append([value, value.duplicate()])
	for child in (value.values() if value is Dictionary else value):
		keep_value(child)

func restore() -> void:
	for entry: Array in _fields:
		entry[0].set(entry[1], entry[2])
	for entry: Array in _collections:
		if entry[0] is Dictionary:
			entry[0].clear()
			entry[0].merge(entry[1])
		else:
			entry[0].assign(entry[1])
