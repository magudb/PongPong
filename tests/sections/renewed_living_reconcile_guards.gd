extends RefCounted
## Pure diagnostic policy controls; seeded rows here are not physical evidence.
const SECTION := "renewed_living_reconcile_guards"
const ACTIONS := preload("res://scripts/social/living/living_actions.gd")
const DATA := preload("res://scripts/social/living/living_data.gd")
const GOALS := preload("res://scripts/social/living/living_goals.gd")

func run(t) -> void:
	for npc in ["baker_maja", "beekeeper_birk", "smith_thorin"]:
		var profile: Dictionary = DATA.profile(npc)
		var repair: Dictionary = {}
		for goal in profile.goals:
			if goal.id == "lc_" + npc + "_reconcile": repair = goal
		var prior := {"day": 2, "goal": "lc_" + npc + "_connect", "outcome": "connection", "target": repair.target, "closed_day": 2, "cooldowns": {"lc_" + npc + "_connect": 4}}
		var before := prior.duplicate(true)
		var available: Dictionary = ACTIONS.plan(npc, profile, 3, prior, [repair.target])
		t.check(npc + "_authored_followup_selected", available.get("goal") == repair.id)
		t.check(npc + "_planner_does_not_mutate_prior", prior == before)
		t.check(npc + "_missing_named_target_falls_back", ACTIONS.plan(npc, profile, 3, prior, []).get("executor") == "reflect")
		var wrong := prior.duplicate(true)
		wrong.target = npc
		t.check(npc + "_wrong_named_prior_cannot_clarify", ACTIONS.plan(npc, profile, 3, wrong, [repair.target]).get("executor") != "clarify")
		var cooled := prior.duplicate(true)
		cooled.cooldowns[repair.id] = 4
		t.check(npc + "_repair_cooldown_preserves_valid_fallback", ACTIONS.plan(npc, profile, 3, cooled, [repair.target]).get("executor") == "reflect")
		t.check(npc + "_repair_cooldown_boundary_reopens_phase", ACTIONS.plan(npc, profile, 4, cooled, [repair.target]).get("executor") == "clarify")
		for outcome in ["reflection", "clarification", "interrupted", "pending"]:
			var consumed := prior.duplicate(true)
			consumed.outcome = outcome
			t.check(npc + "_" + outcome + "_cannot_restart_followup", ACTIONS.plan(npc, profile, 3, consumed, [repair.target]).get("executor") != "clarify")
		var inputs := {"day": 3, "available": true, "free_time": true, "protected": {"essential_work": false, "story": false, "festival": false, "home": false}}
		var weighted: Dictionary = GOALS.select(npc, profile, inputs)
		t.check(npc + "_pure_weighted_selector_is_not_globally_reweighted", weighted.get("utility") == 6 and weighted.get("kind") == "connect", str(weighted))
		for goal in profile.goals: cooled.cooldowns[goal.id] = 4
		t.check(npc + "_all_cooldowns_can_refuse_without_forcing_repair", ACTIONS.plan(npc, profile, 3, cooled, [repair.target]).is_empty())
