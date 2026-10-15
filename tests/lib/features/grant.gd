class_name Grant
extends RefCounted
## Test helper (review RV-P11): gives the player everything the upgrade to home tier `n` asks for, ONLY through the public APIs of
## EconomyManager (gold, materials), QuestManager (quests), GameManager (friend_<npc> flags, home_tier) and FurnitureManager (hygge, through AutoFurnish).
## It is the only helper of the feature tests that writes state directly, and it never touches HomeManager: the upgrade itself (HomeManager.start_upgrade) is what the tests prove.
##
##   var report := Grant.requirements(5)            # {ok, tier, gold, materials, quests, hearts, hygge, missing[]}
##   Grant.requirements(8, {"dialogue_quests": ["snurresvampen"]})   # these quests are ACCEPTED through the real dialogue (see accept_via_dialogue), then completed
##
## Gate quests that are offered by dialogue (snurresvampen, moonstone_crown, bogtraeet, slotsdroemmen) are accepted through the dialogue of their giver by default: the helper reads the
## dialogue the player really sees (LuaRuntime.get_dialogue with the flag state of the offer) and accepts the `quest_accept` choice - what Npc2D.handle_choice does - so a quest that
## nobody offers fails the grant instead of being silently granted (RV-P1).  Every other quest is accepted and completed through QuestManager.
## Hearts: through SocialManager.debug_set_hearts when that autoload exists (S-core: the ONLY writer of friendship, raises only, mirrors the flag and emits friend_changed itself); until then (and in a tree
## without it) the flag friend_<npc> (cap 10) + EventBus.friend_changed(npc, hearts) when the signal exists.  Hygge: AutoFurnish.fill() up to the min_decor of the required level.

const DIALOGUE_QUESTS := ["snurresvampen", "moonstone_crown", "bogtraeet", "slotsdroemmen"]
## flag state in which the giver's dialogue offers the quest (the reference modules of data/features/pending/lua/dialogue)
const OFFER_FLAGS := {
	"snurresvampen": {},
	"moonstone_crown": {},
	"bogtraeet": {"math_bakery_done": true, "math_harvest_done": true, "math_quiz_done": true},
	"slotsdroemmen": {"home_tier": 10, "moonstone_crown_done": true},
}
const HEART_CAP := 10


static func tier_def(n: int) -> Dictionary:
	var tiers := LuaData.arr(Svc.lua_config("home.tiers", []))
	return LuaData.dict(tiers[n - 1]) if n >= 1 and n <= tiers.size() else {}


static func requirements(n: int, opts: Dictionary = {}) -> Dictionary:
	var report := {"ok": false, "tier": n, "gold": 0, "materials": {}, "quests": [], "hearts": {}, "hygge": {}, "missing": []}
	var missing: Array = report["missing"]
	var def := tier_def(n)
	if def.is_empty():
		missing.append("no tier %d in home.tiers" % n)
		return report
	var cost := LuaData.dict(def.get("cost", {}))
	var req := LuaData.dict(def.get("requires", {}))
	var eco := Svc.node("EconomyManager")
	var qm := Svc.node("QuestManager")
	var gm := Svc.node("GameManager")
	if eco == null or qm == null or gm == null:
		missing.append("EconomyManager, QuestManager and GameManager must exist")
		return report
	# --- gold (the knob economy.home_cost_scale of P10 scales every tier price)
	var scale := LuaData.num(Svc.lua_config("economy.home_cost_scale", 1.0), 1.0)
	var need_gold := int(round(LuaData.int_of(cost.get("gold", 0)) * scale))
	if int(eco.gold) < need_gold:
		eco.add_gold(need_gold - int(eco.gold))
	report["gold"] = need_gold
	# --- materials
	var mats := LuaData.int_map(cost.get("materials", {}))
	for id in mats:
		var short: int = int(mats[id]) - int(eco.count_item(StringName(id)))
		if short > 0 and not bool(eco.add_item(StringName(id), short, true)):
			missing.append("materials: no room for %d x %s" % [short, id])
	report["materials"] = mats
	# --- quests: dialogue-offered ones through the dialogue, the rest accepted + completed through QuestManager
	var via: Array = opts.get("dialogue_quests", DIALOGUE_QUESTS)
	var granted: Array = []
	for q in LuaData.arr(req.get("quests", [])):
		var qid := StringName(str(q))
		if qm.is_completed(qid):
			continue
		if str(q) in via:
			if not (qm.has_method("is_active") and bool(qm.is_active(qid))) and not accept_via_dialogue(str(q)):
				missing.append("quest %s is offered by nobody (no quest_accept choice in the dialogue of its giver)" % q)
				continue
		elif not (qm.has_method("is_active") and bool(qm.is_active(qid))) and not bool(qm.accept_quest(qid)):      # an already active quest (an intro accepted by the game) is only completed
			missing.append("quest %s cannot be accepted" % q)
			continue
		qm.complete_quest(qid)
		if not bool(qm.is_completed(qid)):
			missing.append("quest %s did not complete" % q)
		granted.append(str(q))
	report["quests"] = granted
	# --- hearts
	var hearts := LuaData.int_map(req.get("friendship", {}))
	for npc in hearts:
		set_hearts(str(npc), mini(int(hearts[npc]), HEART_CAP))
	report["hearts"] = hearts
	# --- hygge: a level INDEX of home.hygge_levels (CD7)
	if req.has("hygge"):
		var level := LuaData.int_of(req["hygge"])
		var levels := LuaData.arr(Svc.lua_config("home.hygge_levels", []))
		var target := LuaData.int_of(LuaData.dict(levels[level]).get("min_decor", 0)) if level >= 0 and level < levels.size() else 0
		var fm := Svc.node("FurnitureManager")
		if fm == null:
			missing.append("hygge level %d needs a FurnitureManager (none exists yet)" % level)
		elif AutoFurnish.hygge_score_of(fm) < 0:
			missing.append("hygge level %d needs FurnitureManager.hygge_score() (the binding accessor of PLAN_FEATURES.md section 3 task 4, RF16): the manager has no such method (hygge_total() is not accepted)" % level)
		else:
			var placed := AutoFurnish.fill(target)
			var score := AutoFurnish.hygge_score_of(fm)
			if score < target:
				missing.append("hygge: %d of %d points after placing %d pieces" % [score, target, placed])
			report["hygge"] = {"level": level, "target": target, "placed": placed, "score": score}
	report["ok"] = missing.is_empty()
	return report


## `hearts` whole hearts for `npc`, never lowering what is there.  Through SocialManager.debug_set_hearts when the autoload exists (it is the only writer of friendship: points, the derived flag mirror and
## friend_changed all stay consistent); the flag path below is the FALLBACK for a tree without the manager (wave 3: flag friend_<npc> + friend_changed).
static func set_hearts(npc: String, hearts: int) -> void:
	var sm := Svc.node("SocialManager")
	if sm != null and sm.has_method("debug_set_hearts"):
		sm.call("debug_set_hearts", npc, hearts)
		return
	var gm := Svc.node("GameManager")
	if gm == null:
		return
	var flag := StringName("friend_" + npc)
	var have := int(gm.flag_int(flag, 0)) if gm.has_method("flag_int") else 0
	if hearts > have:
		gm.set_flag(flag, hearts)
		var bus := Svc.node("EventBus")
		if bus != null and bus.has_signal("friend_changed"):
			bus.emit_signal("friend_changed", StringName(npc), hearts)


## the NPC that offers `quest` (config npcs.<id>.quests_offered), "" when nobody does
static func giver_of(quest: String) -> String:
	var npcs := LuaData.dict(Svc.lua_config("npcs", {}))
	for id in npcs:
		if quest in LuaData.strings(LuaData.dict(npcs[id]).get("quests_offered", [])):
			return str(id)
	return ""


## What Npc2D does when the player talks to the giver and picks the accept choice: the dialogue is evaluated with the flag state of the offer and the `quest_accept` choice of the quest
## is looked for; true only when it exists AND QuestManager accepts the quest.
static func accept_via_dialogue(quest: String, flags: Dictionary = {}) -> bool:
	var lr := Svc.node("LuaRuntime")
	var gm := Svc.node("GameManager")
	var qm := Svc.node("QuestManager")
	if lr == null or gm == null or qm == null:
		return false
	var giver := giver_of(quest)
	if giver == "":
		return false
	var want: Dictionary = flags if not flags.is_empty() else OFFER_FLAGS.get(quest, {})
	for k in want:
		gm.set_flag(StringName(k), want[k])
	var dialogue: Dictionary = lr.get_dialogue(giver, {})
	for ch in LuaData.arr(dialogue.get("choices", [])):
		var c := LuaData.dict(ch)
		if str(c.get("action", "")) == "quest_accept" and str(c.get("quest_id", "")) == quest:
			return bool(qm.accept_quest(StringName(quest)))
	return false
