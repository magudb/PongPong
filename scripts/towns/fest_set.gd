class_name FestSet
extends RefCounted
## The STANDARD FESTIVAL POST SET of one spot (the post NAMES are the contract with the social track: S-core override_for, S-events FestivalStage, S-fest-content `social_fest_content.fest_posts_exist`).
## ONE marker per spot authors all 28 of them: `@marker F post set=fest spot=torvet` expands to
##   fest_<spot>_host, _judge, _stall_1.._stall_4, _table_1.._table_2, _gather_1.._gather_20
## on fixed cell offsets around the marker (a 9 x 8 cell block: stalls and tables on the sides, the 20 gather posts as a 4 x 4 block in front of the host).
## A post whose cell is blocked is moved to the nearest free cell not taken by another post (TownMarks.resolve_cells); the validator `towns.fest_sets_complete` checks the result.
## In the route table only `fest_<spot>_host` is an anchor: every other member is "host + a local walk" (LOCAL_SECONDS), so a spot costs one row, not twenty.

const LOCAL_SECONDS := 4.0

static func roles() -> Array:
	var r: Array = [["host", Vector2i(0, 0)], ["judge", Vector2i(2, 0)],
		["stall_1", Vector2i(-4, -2)], ["stall_2", Vector2i(-2, -2)], ["stall_3", Vector2i(2, -2)], ["stall_4", Vector2i(4, -2)],
		["table_1", Vector2i(-3, 1)], ["table_2", Vector2i(3, 1)]]
	for k in 20:
		r.append(["gather_%d" % (k + 1), Vector2i(k % 4 - 1, 2 + k / 4)])
	return r


static func post_names(spot: String) -> Array[String]:
	var out: Array[String] = []
	for r in roles():
		out.append("fest_%s_%s" % [spot, r[0]])
	return out


## true when `name` is a satellite of a spot (everything but the host)
static func is_satellite(post_name: String) -> bool:
	return post_name.begins_with("fest_") and not post_name.ends_with("_host") and _spot_of(post_name) != ""


static func host_of(post_name: String) -> String:
	var s: String = _spot_of(post_name)
	return "fest_%s_host" % s if s != "" else post_name


static func _spot_of(post_name: String) -> String:
	if not post_name.begins_with("fest_"):
		return ""
	for suffix in ["_judge", "_host"]:
		if post_name.ends_with(suffix):
			return post_name.trim_prefix("fest_").trim_suffix(suffix)
	for kind in ["_stall_", "_table_", "_gather_"]:
		var i: int = post_name.rfind(kind)
		if i > 5:
			return post_name.substr(5, i - 5)
	return ""
