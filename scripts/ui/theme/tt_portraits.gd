extends RefCounted
## Dialogue / shop / journal portraits: NPC id -> visual id -> a portrait file.
##
## Who looks like whom is DATA (nothing here names a stand-in character):
##   1. lua/config/npcs.lua (P10, LuaRuntime.get_npc): `portrait` (when it differs) else `visual`, plus its `fallback`;
##   2. lua/config/characters.lua `fallbacks` (P05, CharacterCatalog.fallback_chain): the chain a missing art id follows;
##   3. per id of the chain the first file that exists:
##        res://assets/portraits/<id>.webp                     (256x256 BUST, P21; the 12 pack characters have one too)
##        res://assets/isometric_characters/<id>/portrait.webp (full-body crop of the pack / bust of the new characters)
## So when P21 bakes `fairy_mayor` and its bust, the mayor's portrait changes without touching a line of code.
## Preloaded by path (no class_name: preload works with a stale global class cache).

const PORTRAITS_DIR := "res://assets/portraits/"
const CHARACTERS_DIR := "res://assets/isometric_characters/"
## last resort for an unknown NPC id (the mayor's pack stand-in)
const DEFAULT_VISUAL := "fairy"


## Row of npcs.lua ({} for an unknown id or while there is no LuaRuntime).
static func npc(npc_id: StringName) -> Dictionary:
	var lr := Svc.node("LuaRuntime")
	if lr == null or not lr.has_method("get_npc"):
		return {}
	var row: Variant = lr.call("get_npc", String(npc_id))
	return row if typeof(row) == TYPE_DICTIONARY else {}


## Visual ids to try, best first: the NPC's portrait/visual with its fallback chain (characters.lua), then npcs.lua's own
## `fallback` chain, finally DEFAULT_VISUAL. An id that npcs.lua does not know is tried as a visual id itself first.
static func visual_candidates(npc_id: StringName) -> Array[String]:
	var out: Array[String] = []
	var row := npc(npc_id)
	var heads: Array[String] = []
	if row.is_empty():
		heads.append(String(npc_id))
	else:
		var p := str(row.get("portrait", ""))
		if p != "":
			heads.append(p)
		heads.append(str(row.get("visual", "")))
		heads.append(str(row.get("fallback", "")))
	for h in heads:
		if h == "":
			continue
		for c in CharacterCatalog.fallback_chain(h):
			if not out.has(c):
				out.append(c)
	if not out.has(DEFAULT_VISUAL):
		out.append(DEFAULT_VISUAL)
	return out


## The two files that can hold the portrait of one visual id, in lookup order.
static func portrait_paths(visual_id: String) -> Array[String]:
	return [PORTRAITS_DIR + visual_id + ".webp", CHARACTERS_DIR + visual_id + "/portrait.webp"]


## Ordered lookup of an NPC portrait path; "" when nothing exists. `exists` (Callable(path) -> bool) is a test seam,
## the default is ResourceLoader.exists (imported files are remapped in exports, a plain file test would fail there).
static func resolve_path(npc_id: StringName, exists: Callable = Callable()) -> String:
	return resolve_visual_path(visual_candidates(npc_id), exists)


static func resolve_visual_path(visuals: Array, exists: Callable = Callable()) -> String:
	for v in visuals:
		if not CharacterCatalog.is_safe_id(str(v)):
			continue
		for p in portrait_paths(str(v)):
			var found: bool = bool(exists.call(p)) if exists.is_valid() else ResourceLoader.exists(p)
			if found:
				return p
	return ""


## The art folder an animated face (tt_sprite_face) of this NPC should use: first id of the chain that has art.
static func sprite_for(npc_id: StringName) -> String:
	for c in visual_candidates(npc_id):
		if CharacterCatalog.exists(c):
			return c
	return DEFAULT_VISUAL


static func portrait(npc_id: StringName) -> Texture2D:
	var p := resolve_path(npc_id)
	return load(p) as Texture2D if p != "" else null


## Portrait of a visual id (shop keeper by sprite, character cards): same fallback chain and the same two folders.
static func portrait_by_sprite(visual_id: String) -> Texture2D:
	var chain: Array = CharacterCatalog.fallback_chain(visual_id)
	var p := resolve_visual_path(chain)
	return load(p) as Texture2D if p != "" else null
