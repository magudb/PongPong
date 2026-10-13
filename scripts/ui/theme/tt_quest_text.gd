extends RefCounted
## Reads title / giver / steps / reward / tag of a quest from its Lua definition (QuestManager.get_quest_def), with
## translation-key fallbacks. This is the "Opgavebog reads the Lua fields, new quests need no new UI" contract (plan 5.3).
##
## Lua fields used (all optional; the first one that exists wins):
##   title | title_key        -> else tr("QUEST_<ID>_TITLE") -> else the quest id made readable ("lost_cat" -> "Lost Cat")
##   description | description_key -> else tr("QUEST_<ID>_DESC") -> else tr("QUEST_<ID>_OFFER")
##   meta.giver               -> NPC id, shown as tr("NPC_<GIVER>")
##   meta.location            -> a ZONE KEY ("ZONE_CITY", plan 3.12) shown translated ("Hyggebyen"), or plain text (optional).
##                               A string that looks like a key (A-Z 0-9 _) but has no translation is NOT shown: the book
##                               never prints a raw key.
##   meta.tag | meta.category -> tag chip. `tag` = FIND / HØST / BYG / SKOV / VENSKAB / LÆR (plan 3.12), `category` = the
##                               older help / errand / farm / adventure / friendship / intro / learning; see TAGS below
##   objectives[i]            -> { id, target, description_key | description }; text order = description_key ->
##                               OBJ_<QUEST>_<OBJ> -> OBJ_<OBJ> -> description -> the capitalised id (plan 3.12)
##   rewards                  -> { gold, items = { item_id = n }, friendship = { npc_id = n } }
##
## Every sub-table is read through LuaData: the Lua reader hands an EMPTY table `{}` over as an empty Dictionary or an empty
## Array (PLAN_FEATURES 3.8), so `meta = {}`, `rewards = {}`, `items = {}`, `objectives = {}` all render as "nothing" instead
## of raising script errors in the journal.

## tag id (see tag_id()) -> [QJ_TAG_ key suffix, chip colour]. Colours: plan 5.3 (FIND lavender, HØST light moss, BYG light honey,
## SKOV blue-grey) and the guide's pale chips for the rest.
const TAGS := {
	"FIND": ["FIND", "#e2d8f4"], "HOEST": ["HOEST", "#cde0a6"], "BYG": ["BYG", "#f0d49a"], "SKOV": ["SKOV", "#b9c3e3"],
	"VENSKAB": ["VENSKAB", "#e7b7c6"], "LAER": ["LAER", "#cfe6f2"],
	"HELP": ["HELP", "#e2d8f4"], "ERRAND": ["ERRAND", "#f0d49a"], "FARM": ["FARM", "#cde0a6"],
	"ADVENTURE": ["ADVENTURE", "#b9c3e3"], "FRIENDSHIP": ["FRIENDSHIP", "#e7b7c6"],
	"INTRO": ["INTRO", "#e8cfa6"], "LEARNING": ["LEARNING", "#cfe6f2"],
}
const DEFAULT_TAG := "HELP"

## Test seams (tests only): a Callable(quest_id) -> Dictionary for the definition and a Callable(quest_id) -> Dictionary for
## the runtime progress. Empty = QuestManager.
static var _def_provider: Callable = Callable()
static var _progress_provider: Callable = Callable()
static var _completed_provider: Callable = Callable()


static func set_providers(def_fn: Callable, progress_fn: Callable = Callable(), completed_fn: Callable = Callable()) -> void:
	_def_provider = def_fn
	_progress_provider = progress_fn
	_completed_provider = completed_fn


static func clear_providers() -> void:
	_def_provider = Callable()
	_progress_provider = Callable()
	_completed_provider = Callable()


static func _has_key(key: String) -> bool:
	return TranslationServer.translate(key) != key


static func def(quest_id: StringName) -> Dictionary:
	if _def_provider.is_valid():
		return LuaData.dict(_def_provider.call(quest_id))
	var qm := Svc.node("QuestManager")
	return LuaData.dict(qm.get_quest_def(quest_id)) if qm != null else {}


## A text field of a definition: the String / StringName value, "" for anything else (a number, an empty table).
static func _s(table: Dictionary, field: String) -> String:
	var v: Variant = table.get(field, "")
	return str(v) if typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME else ""


static func _meta(quest_id: StringName) -> Dictionary:
	return LuaData.dict(def(quest_id).get("meta", {}))


static func _progress(quest_id: StringName) -> Dictionary:
	if _progress_provider.is_valid():
		return LuaData.dict(_progress_provider.call(quest_id))
	var qm := Svc.node("QuestManager")
	return LuaData.dict(qm.get_quest_progress(quest_id)) if qm != null else {}


static func _is_completed(quest_id: StringName) -> bool:
	if _completed_provider.is_valid():
		return bool(_completed_provider.call(quest_id))
	var qm := Svc.node("QuestManager")
	return bool(qm.is_completed(quest_id)) if qm != null else false


## title -> title_key -> QUEST_<ID>_TITLE, each only when it exists / has a translation (like description() and step_text()), else
## the id made readable ("lost_cat" -> "Lost Cat", like giver_name() and step_text()): the book never prints a raw key.
static func title(quest_id: StringName) -> String:
	var d := def(quest_id)
	if _s(d, "title") != "":
		return _s(d, "title")
	var tk := _s(d, "title_key")
	if tk != "" and _has_key(tk):
		return TranslationServer.translate(tk)
	var k := "QUEST_%s_TITLE" % String(quest_id).to_upper()
	if _has_key(k):
		return TranslationServer.translate(k)
	return String(quest_id).capitalize()


static func description(quest_id: StringName) -> String:
	var d := def(quest_id)
	if _s(d, "description") != "":
		return _s(d, "description")
	if _s(d, "description_key") != "" and _has_key(_s(d, "description_key")):
		return TranslationServer.translate(_s(d, "description_key"))
	var up := String(quest_id).to_upper()
	for k in ["QUEST_%s_DESC" % up, "QUEST_%s_OFFER" % up]:
		if _has_key(k):
			return TranslationServer.translate(k)
	return ""


static func giver_id(quest_id: StringName) -> String:
	return _s(_meta(quest_id), "giver")


static func giver_name(quest_id: StringName) -> String:
	var g := giver_id(quest_id)
	if g == "":
		return ""
	var k := "NPC_%s" % g.to_upper()
	return TranslationServer.translate(k) if _has_key(k) else g.capitalize()


## True for a string shaped like a translation key (A-Z, 0-9, _ only), e.g. "ZONE_CITY".
static func _looks_like_key(text: String) -> bool:
	if text == "":
		return false
	for i in text.length():
		var c := text.unicode_at(i)
		if not ((c >= 65 and c <= 90) or (c >= 48 and c <= 57) or c == 95):
			return false
	return true


## meta.location for display: a zone key is translated ("ZONE_CITY" -> "Hyggebyen"), plain text is kept as it is, and a
## key-shaped string without a translation gives "" (a raw key is never printed).
static func location_text(quest_id: StringName) -> String:
	var loc := _s(_meta(quest_id), "location")
	if loc == "":
		return ""
	if _has_key(loc):
		return TranslationServer.translate(loc)
	return "" if _looks_like_key(loc) else loc


static func from_line(quest_id: StringName) -> String:
	var g := giver_name(quest_id)
	if g == "":
		return ""
	var s := TranslationServer.translate("QJ_FROM") % g
	var loc := location_text(quest_id)
	return s + (" · " + loc if loc != "" else "")


## "HØST" -> "HOEST", "LÆR" -> "LAER": the tag as an ASCII id (translation keys and the TAGS table are ASCII).
static func tag_id(tag: String) -> String:
	return tag.strip_edges().to_upper().replace("Ø", "OE").replace("Æ", "AE").replace("Å", "AA")


static func _tag_row(quest_id: StringName) -> Array:
	var m := _meta(quest_id)
	for field in ["tag", "category"]:
		var id := tag_id(_s(m, field))
		if id != "" and TAGS.has(id):
			return TAGS[id]
	return TAGS[DEFAULT_TAG]


static func tag_text(quest_id: StringName) -> String:
	return TranslationServer.translate("QJ_TAG_%s" % str(_tag_row(quest_id)[0]))


static func tag_color(quest_id: StringName) -> Color:
	return Color(str(_tag_row(quest_id)[1]))


## Text of one objective: description_key -> OBJ_<QUEST>_<OBJ> -> OBJ_<OBJ> -> description -> capitalised id.
static func step_text(obj_id: StringName, objective_def: Variant, quest_id: StringName = &"") -> String:
	var od := LuaData.dict(objective_def)
	var dk := _s(od, "description_key")
	if dk != "" and _has_key(dk):
		return TranslationServer.translate(dk)
	if quest_id != &"":
		var qk := "OBJ_%s_%s" % [String(quest_id).to_upper(), String(obj_id).to_upper()]
		if _has_key(qk):
			return TranslationServer.translate(qk)
	var k := "OBJ_%s" % String(obj_id).to_upper()
	if _has_key(k):
		return TranslationServer.translate(k)
	if _s(od, "description") != "":
		return _s(od, "description")
	return String(obj_id).capitalize()


## Steps as [{id, text, current, target, done}] in Lua order. For finished quests every step is done.
static func steps(quest_id: StringName) -> Array:
	var out: Array = []
	var d := def(quest_id)
	var rt: Dictionary = _progress(quest_id)
	var completed := _is_completed(quest_id)
	var runtime := LuaData.dict(rt.get("objectives", {}))
	for o in LuaData.arr(d.get("objectives", [])):
		var od := LuaData.dict(o)
		var oid := StringName(_s(od, "id"))
		var st := LuaData.dict(runtime.get(oid, {}))
		out.append({
			"id": oid, "text": step_text(oid, od, quest_id),
			"current": 1 if completed else LuaData.int_of(st.get("current", 0)),
			"target": LuaData.int_of(od.get("target", 1), 1),
			"done": completed or bool(st.get("done", false)),
		})
	return out


## Reward chips: [{kind: "gold"|"item"|"heart", text}]
static func rewards(quest_id: StringName) -> Array:
	var out: Array = []
	var r := LuaData.dict(def(quest_id).get("rewards", {}))
	if r.has("gold"):
		out.append({"kind": "gold", "text": "%s %s" % [preload("res://scripts/ui/theme/tt_format.gd").thousands(LuaData.int_of(r["gold"])), TranslationServer.translate("UI_CURRENCY")]})
	var items := LuaData.dict(r.get("items", {}))
	for id in items:
		out.append({"kind": "item", "text": "%s × %d" % [TranslationServer.translate("ITEM_%s" % String(id).to_upper()), LuaData.int_of(items[id])]})
	var fr := LuaData.dict(r.get("friendship", {}))
	for npc in fr:
		var k := "NPC_%s" % String(npc).to_upper()
		out.append({"kind": "heart", "text": "♥ " + (TranslationServer.translate(k) if _has_key(k) else String(npc))})
	return out


## Where the definition came from, for the small mono caption in the book ("quests/pippins_kat.lua").
static func source_path(quest_id: StringName) -> String:
	var p := _s(def(quest_id), "source_path")
	return p.replace("res://lua/", "") if p != "" else "quests/%s.lua" % quest_id
