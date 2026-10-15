class_name NpcDirector
extends RefCounted
## The STATIC FACADE of the towns track for everybody who asks "where is he / is he here / is he in the game" (the social track's `when=at:<npc>` and hero-twin rule, the integration
## loop's TownProbe, the post office's "Hvor er ..?" list). No autoload, no node: pure functions over Routines + the TownDirector that is in the tree right now.
## Late-bound callers use  Svc.node("NpcDirector") (a test fake wins) and then Svc.static_call("res://scripts/towns/npc_director.gd", &"is_absent", [id], false).

static var _active: Array = []        # TownDirectors that are in the tree (normally one: the area the player is in)


static func register(d: Object) -> void:
	if not (d in _active):
		_active.append(d)


static func unregister(d: Object) -> void:
	_active.erase(d)


## Not part of the game for this player: the other hero's twin (rasmus, kiki, bertil, bodil, birk), or a gate that has not opened. Asleep / away / indoors is NOT absent.
static func is_absent(npc_id: String, ctx: Dictionary = {}) -> bool:
	return Routines.is_unavailable(npc_id, ctx if not ctx.is_empty() else Routines.now_ctx())


## The citizen is off stage on an errand of his plan (an `away:` block: Fru Ugle on her field days, Natteblik before dusk): not asleep, not a hero twin. The dungeon's hub marker uses it
## (`when=away:appraiser_fru_ugle`, a kind of the social track's eval_when): she stands in the hub only on the days she is not in Trætoppen.
static func is_away(npc_id: String, ctx: Dictionary = {}) -> bool:
	var w: Dictionary = where_is(npc_id, ctx)
	return str(w["state"]) == "absent" and str(w["act"]) == "away"


## The citizen is standing or walking in the area the player is in right now (a live node).
static func is_present(npc_id: String) -> bool:
	for d in _active:
		if is_instance_valid(d) and d.get("live") is Dictionary and (d.get("live") as Dictionary).has(npc_id):
			return true
	return false


## The live citizen NODE in the area the player is in (what a counter's `talk` host forwards to), or null (SE1).
static func node_of(npc_id: String) -> Node:
	for d in _active:
		if is_instance_valid(d) and d.has_method("node_of"):
			var v: Variant = d.call("node_of", npc_id)
			if v is Node and is_instance_valid(v):
				return v as Node
	return null


## {npc, state: stay|move|inside|absent, plan, place, act, area, leg?} at the live clock (or at `ctx`).
static func where_is(npc_id: String, ctx: Dictionary = {}) -> Dictionary:
	return Routines.where_is(npc_id, ctx if not ctx.is_empty() else Routines.now_ctx())


## Ids of the citizens whose body is in `area_id` right now (stay or walking), highest priority first. Works for any baked area, not only the one the player is in.
static func population(area_id: String, ctx: Dictionary = {}) -> Array:
	var out: Array = []
	for w in Routines.present_in(area_id, ctx if not ctx.is_empty() else Routines.now_ctx()):
		out.append(str((w as Dictionary)["npc"]))
	return out


## Re-places the citizens of the area the player is in after something changed that the schedule cannot see by itself (a scripted scene ended, a flag was set).
## With an id only that citizen is re-placed (the social track calls resync(npc) when a scene releases an actor).
static func resync(npc_id: String = "") -> void:
	for d in _active:
		if is_instance_valid(d):
			d.call("resync", true, npc_id)
