extends RefCounted
## A small interpreter of the JSON-schema subset data/interiors/schema.json uses (package T-towns-core): type, enum, required, properties, additionalProperties, items, minimum, maximum,
## minItems, maxItems, pattern, $ref. The Python validator (tools/towns/interiors/validate.py) implements the same subset; the section towns_interiors runs both on the same files.


static func problems(value: Variant, schema: Dictionary, root: Dictionary = {}, path: String = "$") -> Array[String]:
	var top: Dictionary = root if not root.is_empty() else schema
	var out: Array[String] = []
	if schema.has("$ref"):
		var node: Variant = top
		for part in str(schema["$ref"]).trim_prefix("#/").split("/"):
			node = (node as Dictionary).get(part, {})
		return problems(value, node as Dictionary, top, path)
	if schema.has("enum"):
		var found: bool = false
		for e in (schema["enum"] as Array):
			if _same(e, value):
				found = true
		if not found:
			return ["%s: %s is not one of %s" % [path, str(value), str(schema["enum"])]]
	if schema.has("type") and not _type_ok(value, str(schema["type"])):
		return ["%s: expected %s, got type %d" % [path, schema["type"], typeof(value)]]
	if (value is int or value is float):
		if schema.has("minimum") and float(value) < float(schema["minimum"]):
			out.append("%s: %s is below %s" % [path, str(value), str(schema["minimum"])])
		if schema.has("maximum") and float(value) > float(schema["maximum"]):
			out.append("%s: %s is above %s" % [path, str(value), str(schema["maximum"])])
	if value is String and schema.has("pattern"):
		var rx := RegEx.new()
		rx.compile(str(schema["pattern"]))
		if rx.search(value) == null:
			out.append("%s: %s does not match %s" % [path, str(value), str(schema["pattern"])])
	if value is Array:
		var arr: Array = value
		if schema.has("minItems") and arr.size() < int(schema["minItems"]):
			out.append("%s: needs at least %s entries" % [path, str(schema["minItems"])])
		if schema.has("maxItems") and arr.size() > int(schema["maxItems"]):
			out.append("%s: allows at most %s entries" % [path, str(schema["maxItems"])])
		if schema.has("items"):
			for i in arr.size():
				out.append_array(problems(arr[i], schema["items"] as Dictionary, top, "%s[%d]" % [path, i]))
	if value is Dictionary:
		var d: Dictionary = value
		for k in (schema.get("required", []) as Array):
			if not d.has(str(k)):
				out.append("%s: missing `%s`" % [path, k])
		var props: Dictionary = schema.get("properties", {}) as Dictionary
		for k in d:
			if props.has(k):
				out.append_array(problems(d[k], props[k] as Dictionary, top, "%s.%s" % [path, k]))
			elif schema.get("additionalProperties", true) == false:
				out.append("%s: unknown key `%s`" % [path, k])
	return out


static func _type_ok(v: Variant, t: String) -> bool:
	match t:
		"object":
			return v is Dictionary
		"array":
			return v is Array
		"string":
			return v is String
		"integer":
			return (v is int) or (v is float and is_equal_approx(float(v), roundf(float(v))))      # JSON numbers parse as floats in Godot
		"number":
			return v is int or v is float
		"boolean":
			return v is bool
	return false


static func _same(a: Variant, b: Variant) -> bool:
	return str(a) == str(b)
