class_name TextureRefs
extends RefCounted
## Shared lookup tables retain metadata, while the scene owns texture residency.
static func store(value: Variant) -> Variant:
	if value is Texture2D:
		return weakref(value)
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = store(value[key])
		return result
	return value

static func fetch(value: Variant) -> Variant:
	if value is WeakRef:
		return value.get_ref()
	if value is Dictionary:
		var result := {}
		for key in value:
			var item: Variant = fetch(value[key])
			if item == null and (value[key] is WeakRef or value[key] is Dictionary):
				return null
			result[key] = item
		return result
	return value
