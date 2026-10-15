extends RefCounted
## The MUTATION helper of the towns tests (package T-towns-core): one broken copy of a buildings registry per rule, so a validator is proven to catch what it claims to catch.
## mutants(registry) -> [{name, registry}]: every mutant violates exactly one rule of tests/lib/towns/consistency.gd (hours.consistency, the row schema, the shop ids, the service rule).
## `registry` is deep-copied, never changed. A later package (T-routes: TownsValidate; T-ext-content) feeds ITS validator with these copies and expects every one to be reported.


static func mutants(registry: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var shop: String = _first(registry, "shop")
	var service: String = _first(registry, "service")
	var stall: String = _first(registry, "stall")
	var home: String = _first(registry, "home")
	if shop != "":
		out.append(_m("shop_without_hours", registry, func(r: Dictionary) -> void: (r[shop] as Dictionary).erase("hours")))
		out.append(_m("close_after_the_end_of_the_day", registry, func(r: Dictionary) -> void: ((r[shop] as Dictionary)["hours"] as Dictionary)["close"] = 27))
		out.append(_m("open_equals_close", registry, func(r: Dictionary) -> void: ((r[shop] as Dictionary)["hours"] as Dictionary)["close"] = ((r[shop] as Dictionary)["hours"] as Dictionary)["open"]))
		out.append(_m("closed_on_every_weekday", registry, func(r: Dictionary) -> void: ((r[shop] as Dictionary)["hours"] as Dictionary)["closed"] = [0, 1, 2, 3, 4, 5, 6]))
		out.append(_m("closed_weekday_out_of_range", registry, func(r: Dictionary) -> void: ((r[shop] as Dictionary)["hours"] as Dictionary)["closed"] = [7]))
		out.append(_m("shop_id_unknown", registry, func(r: Dictionary) -> void: (r[shop] as Dictionary)["shop"] = "no_such_shop_anywhere"))
		out.append(_m("keeper_is_no_citizen", registry, func(r: Dictionary) -> void: (r[shop] as Dictionary)["keeper"] = "nobody_at_all"))
		out.append(_m("name_key_is_not_BLD_id", registry, func(r: Dictionary) -> void: (r[shop] as Dictionary)["name_key"] = "BLD_WRONG"))
		out.append(_m("interior_without_size", registry, func(r: Dictionary) -> void: (r[shop] as Dictionary).erase("size")))
		out.append(_m("unknown_field", registry, func(r: Dictionary) -> void: (r[shop] as Dictionary)["stand_in"] = "table_stump"))
		out.append(_m("override_weekday_out_of_range", registry, func(r: Dictionary) -> void: ((r[shop] as Dictionary)["hours"] as Dictionary)["overrides"] = [{"weekday": [9], "open": 9, "close": 15}]))
		out.append(_m("hours_not_numeric", registry, func(r: Dictionary) -> void: ((r[shop] as Dictionary)["hours"] as Dictionary)["open"] = "morning"))
	if service != "":
		out.append(_m("service_with_a_shop_id", registry, func(r: Dictionary) -> void: (r[service] as Dictionary)["shop"] = "fx_bread"))
		out.append(_m("service_without_keeper", registry, func(r: Dictionary) -> void: (r[service] as Dictionary).erase("keeper")))
	if stall != "":
		out.append(_m("stall_with_an_interior", registry, func(r: Dictionary) -> void:
			(r[stall] as Dictionary)["interior"] = "int_%s" % stall
			(r[stall] as Dictionary)["size"] = "S"))
		out.append(_m("short_night_row_without_short_ok", registry, func(r: Dictionary) -> void:
			var hd: Dictionary = (r[stall] as Dictionary)["hours"] as Dictionary
			hd["open"] = 20
			hd["close"] = 23
			hd.erase("short_ok")))
	if home != "":
		out.append(_m("home_without_owner", registry, func(r: Dictionary) -> void: (r[home] as Dictionary).erase("owner")))
	return out


static func _m(name: String, registry: Dictionary, edit: Callable) -> Dictionary:
	var copy: Dictionary = registry.duplicate(true)
	edit.call(copy)
	return {"name": name, "registry": copy}


## The first row of a kind that carries hours / owner (shops and stalls: one with a shop id).
static func _first(registry: Dictionary, kind: String) -> String:
	for id in registry:
		var row: Variant = registry[id]
		if row is Dictionary and str((row as Dictionary).get("kind", "")) == kind:
			if kind in ["shop", "service"] and not (row as Dictionary).has("hours"):
				continue
			if kind == "shop" and not (row as Dictionary).has("interior"):
				continue
			return str(id)
	return ""
