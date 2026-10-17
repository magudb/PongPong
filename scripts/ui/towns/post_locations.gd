class_name PostLocations
extends RefCounted
## A fresh schedule snapshot for each opening. No saved or inferred locations.
const GROUPS := ["traetoppen","hyggebyen","farm"]
static func rows(ctx: Dictionary = {}) -> Array[Dictionary]:
	var context := ctx if not ctx.is_empty() else Routines.now_ctx()
	var keepers := {}
	for building in Hours.registry().values():
		var id := str(building.get("keeper",""))
		if id != "": keepers[id] = true
	var result: Array[Dictionary] = []
	for id in SocialData.friend_ids():
		if Routines.is_unavailable(id,context) or (not keepers.has(id) and Routines.hearts_of(context,id) < 1): continue
		var state := Routines.where_is(id,context)
		var area := str(state.get("area",""))
		var building := area.trim_prefix("int_") if area.begins_with("int_") else ""
		var group := str(Hours.building(building).get("area",area)) if building != "" else area
		if group not in GROUPS: group = str(SocialData.npc_row(id).get("home_area","traetoppen"))
		if group not in GROUPS: group = "traetoppen"
		result.append({"id":id,"group":group,"state":state,"place":place_text(state),"act":act_text(state)})
	result.sort_custom(func(a,b):
		if GROUPS.find(str(a.group)) != GROUPS.find(str(b.group)): return GROUPS.find(str(a.group)) < GROUPS.find(str(b.group))
		return SocialLayout.npc_name(a.id).naturalnocasecmp_to(SocialLayout.npc_name(b.id)) < 0)
	return result
static func place_text(state: Dictionary) -> String:
	var place := str(state.get("place",""))
	if str(state.get("act","")) == "hide": return TranslationServer.translate("POST_HIDING")
	if str(state.get("state","")) == "absent":
		if str(state.get("act","")) == "sleep" or str(state.get("npc","")) == "mapseller_natteblik": return TranslationServer.translate("POST_NOT_AWAKE")
		return TranslationServer.translate("POST_FOREST" if str(state.get("act","")) == "away" else "POST_AWAY")
	if str(state.get("state","")) == "move": return TranslationServer.translate("POST_ON_WAY")
	if place.begins_with("int_"): return TranslationServer.translate("BLD_"+place.get_slice(".",0).trim_prefix("int_").to_upper())
	var post := place.get_slice(".",1)
	var key := "WHERE_POST_"+post.to_upper()
	if TranslationServer.translate(key) != key: return TranslationServer.translate(key)
	if post.begins_with("door_"): return TranslationServer.translate("BLD_"+post.trim_prefix("door_").to_upper())
	if post.begins_with("fest_"): return TranslationServer.translate("POST_AT_FESTIVAL")
	return TranslationServer.translate("POST_GROUP_"+str(state.get("area","traetoppen")).to_upper())
static func act_text(state: Dictionary) -> String:
	if str(state.get("state","")) == "absent" or str(state.get("act","")) == "hide": return ""
	var key := "ACT_"+str(state.get("act","stand")).to_upper()
	return TranslationServer.translate(key) if TranslationServer.translate(key) != key else ""
