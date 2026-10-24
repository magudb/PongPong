extends RefCounted
## Pure selector tracer; actual runtime LC1 catalogue, never a gameplay engine claim.
const SECTION := "living_goals"
const SELECTOR_PATH := "res://scripts/social/living/living_goals.gd"


func _inputs(day: int = 10) -> Dictionary:
	return {"day": day, "available": true, "free_time": true,
		"protected": {"essential_work": false, "story": false, "festival": false, "home": false}}


func run(t) -> void:
	var catalogue: Dictionary = t.autoload("LuaRuntime").call("get_config", "living_citizens", {})
	var thorin: Dictionary = catalogue.get("smith_thorin", {})
	t.check("real_thorin_profile", thorin.get("id") == "smith_thorin" and thorin.get("goals", []).size() == 4)
	t.check("selector_exists", FileAccess.file_exists(SELECTOR_PATH), "Thorin baseline vs confirmed help requires new pure selector")
	if not FileAccess.file_exists(SELECTOR_PATH):
		return
	var selector: Script = load(SELECTOR_PATH)
	var baseline: Dictionary = selector.call("select", "smith_thorin", thorin, _inputs())
	t.check("thorin_baseline_without_help", baseline.get("kind") != "personal" and not baseline.is_empty())
	var confirmed := _inputs(11)
	confirmed.triggers = {"future_committed_mining_help": true}
	var helped: Dictionary = selector.call("select", "smith_thorin", thorin, confirmed, baseline)
	t.check("thorin_help_next_safe_day", helped.get("goal_id") == "lc_smith_thorin_personal", str(helped))
	t.check("actual_thorin_baseline_exact_contributions", baseline.get("goal_id") == "lc_smith_thorin_connect"
		and baseline.get("utility") == 6 and baseline.get("reasons") == {"value": "quiet", "value_weight": 3,
		"goal_weight": 2, "weighted_value": 6, "trigger_bonus": 0})
	t.check("actual_thorin_help_exact_contributions", helped.get("goal_id") == "lc_smith_thorin_personal"
		and helped.get("utility") == 7 and helped.get("reasons") == {"value": "craft", "value_weight": 2,
		"goal_weight": 3, "weighted_value": 6, "trigger_bonus": 1})
	var named_kind := thorin.duplicate(true)
	named_kind.goals[2].kind = &"connect"
	var named_selected: Dictionary = selector.call("select", "smith_thorin", named_kind, _inputs())
	var named_replay: Dictionary = selector.call("select", "smith_thorin", named_kind, _inputs(), named_selected)
	t.check("stringname_kind_rejected_before_selection", named_selected.is_empty(),
		"kind type=%d; selected=%s; same-day=%s" % [typeof(named_selected.get("kind")), str(named_selected), str(named_replay)])
	_scoring(t, selector, thorin)
	_guards(t, selector, thorin, baseline)
	_lifecycle(t, selector, thorin, baseline)
	_invalid(t, selector, thorin, baseline)
	_malformed_types(t, selector, thorin, baseline)
	_string_contract(t, selector, thorin, baseline)
	_boundaries(t, selector, thorin, baseline, catalogue)
	_roster_and_purity(t, selector, catalogue)


func _scoring(t, selector: Script, thorin: Dictionary) -> void:
	var p := thorin.duplicate(true)
	p.goals = [p.goals[0], p.goals[1]]
	p.goals[1].trigger = "none"
	p.values = {"quiet": 5, "craft": 1}
	var a: Dictionary = selector.call("select", "smith_thorin", p, _inputs())
	t.check("values_drive_role", a.get("kind") == "role")
	p.values = {"craft": 5, "quiet": 1}
	var b: Dictionary = selector.call("select", "smith_thorin", p, _inputs())
	t.check("values_drive_personal", b.get("kind") == "personal")
	p.values = {"quiet": 2, "craft": 2}
	p.goals[0].weight = 5
	t.check("goal_weights_drive_role", selector.call("select", "smith_thorin", p, _inputs()).get("kind") == "role")
	p.goals[0].weight = 3
	var tied: Dictionary = selector.call("select", "smith_thorin", p, _inputs())
	t.check("stable_id_tie", tied.get("kind") == "personal")
	p.goals.reverse()
	p.values = {"craft": 2, "quiet": 2}
	t.check("goal_and_dictionary_permutation", selector.call("select", "smith_thorin", p, _inputs()) == tied)
	t.check("explicit_integer_contributions", tied.get("reasons") == {"value": "craft", "value_weight": 2,
		"goal_weight": 3, "weighted_value": 6, "trigger_bonus": 0} and typeof(tied.get("utility")) == TYPE_INT)
	t.check("trigger_contribution", selector.call("select", "smith_thorin", thorin,
		{"day": 10, "available": true, "free_time": true, "protected": _inputs().protected,
		"triggers": {"future_committed_mining_help": true}}).get("reasons", {}).get("trigger_bonus") == 1)


func _guards(t, selector: Script, p: Dictionary, previous: Dictionary) -> void:
	for field in ["available", "free_time"]:
		for value in [false, null, 1, "true"]:
			var i := _inputs()
			i[field] = value
			t.check("guard_%s_%s" % [field, str(value)], selector.call("select", "smith_thorin", p, i, previous).is_empty())
		var missing := _inputs()
		missing.erase(field)
		t.check("missing_" + field, selector.call("select", "smith_thorin", p, missing).is_empty())
	for field in ["essential_work", "story", "festival", "home"]:
		for value in [true, null, 0]:
			var i := _inputs()
			i.protected[field] = value
			t.check("protected_%s_%s" % [field, str(value)], selector.call("select", "smith_thorin", p, i, previous).is_empty())
		var missing := _inputs()
		missing.protected.erase(field)
		t.check("missing_protection_" + field, selector.call("select", "smith_thorin", p, missing).is_empty())
	for day in [0, -1, 1.5, INF, NAN, true, "10", 1000001]:
		var i := _inputs()
		i.day = day
		t.check("invalid_day_" + str(day), selector.call("select", "smith_thorin", p, i).is_empty())
	var missing_day := _inputs()
	missing_day.erase("day")
	t.check("missing_clock", selector.call("select", "smith_thorin", p, missing_day).is_empty())
	var no_trigger := _inputs()
	no_trigger["private_player_rows"] = {"p0": {"helped": true}}
	no_trigger["future_committed_mining_help"] = true
	t.check("no_private_or_public_event_inference", selector.call("select", "smith_thorin", p, no_trigger).get("kind") != "personal")


func _lifecycle(t, selector: Script, p: Dictionary, baseline: Dictionary) -> void:
	var midday := _inputs()
	midday.triggers = {"future_committed_mining_help": true}
	t.check("same_day_latch_before_trigger", selector.call("select", "smith_thorin", p, midday, baseline) == baseline)
	var altered := p.duplicate(true)
	altered.values.quiet = 1
	altered.goals.reverse()
	t.check("same_day_latch_before_weights", selector.call("select", "smith_thorin", altered, midday, baseline) == baseline)
	altered.goals[0].weight = 5
	midday.cooldowns = {baseline.goal_id: 15}
	t.check("same_day_latch_before_goal_weights_and_cooldowns", selector.call("select", "smith_thorin", altered, midday, baseline) == baseline)
	var personal: Dictionary = selector.call("select", "smith_thorin", p, midday)
	t.check("same_day_latch_after_trigger_removed", selector.call("select", "smith_thorin", p, _inputs(), personal) == personal)
	var next := _inputs(11)
	next.triggers = midday.triggers
	t.check("next_day_reevaluates", selector.call("select", "smith_thorin", p, next, baseline).get("kind") == "personal")
	t.check("prior_selection_cooldown", selector.call("select", "smith_thorin", p, next, personal).get("kind") != "personal")
	next.day = personal.cooldown_until_day
	t.check("cooldown_exact_boundary", selector.call("select", "smith_thorin", p, next, personal).get("kind") == "personal")
	var all_cooled := _inputs(11)
	all_cooled.cooldowns = {}
	for g in p.goals:
		all_cooled.cooldowns[g.id] = 12
	t.check("all_goals_cooling_empty", selector.call("select", "smith_thorin", p, all_cooled).is_empty())
	all_cooled.day = 12
	t.check("input_cooldown_boundary", not selector.call("select", "smith_thorin", p, all_cooled).is_empty())
	var expired := _inputs(int(baseline.expiry_day))
	var after_expiry: Dictionary = selector.call("select", "smith_thorin", p, expired, baseline)
	t.check("expiry_reevaluated_not_replayed", after_expiry.get("selected_day") == expired.day)
	var future := baseline.duplicate(true)
	future.selected_day = 11
	t.check("future_previous_fails_closed", selector.call("select", "smith_thorin", p, _inputs(), future).is_empty())
	var unknown := baseline.duplicate(true)
	unknown.goal_id = "lc_smith_thorin_retired"
	t.check("retired_previous_no_reroll", selector.call("select", "smith_thorin", p, _inputs(), unknown).is_empty())
	var injected := baseline.duplicate(true)
	injected["runtime_object"] = self
	injected.reasons["unknown"] = self
	var sanitized: Dictionary = selector.call("select", "smith_thorin", p, _inputs(), injected)
	t.check("previous_allowlist_only", sanitized == baseline and not sanitized.has("runtime_object"))
	t.check("record_dates_and_target", baseline.selected_day == 10 and baseline.expiry_day == 13
		and baseline.cooldown_until_day == 12 and baseline.get("target") == "baker_maja")
	t.check("immutable_record_and_reasons", baseline.is_read_only() and baseline.reasons.is_read_only())


func _invalid(t, selector: Script, thorin: Dictionary, baseline: Dictionary) -> void:
	var mutations := {
		"wrong_identity": func(p): p.id = "baker_maja",
		"retired": func(p): p.retired = true,
		"untrusted_authorship": func(p): p.authorship = "derived",
		"value_nan": func(p): p.values.quiet = NAN,
		"value_fraction": func(p): p.values.quiet = 2.5,
		"weight_infinity": func(p): p.goals[0].weight = INF,
		"weight_bool": func(p): p.goals[0].weight = true,
		"weight_bounds": func(p): p.goals[0].weight = 6,
		"cooldown_zero": func(p): p.goals[0].cooldown_days = 0,
		"expiry_bounds": func(p): p.goals[0].expires_days = 8,
		"unknown_value": func(p): p.goals[0].value = "inferred",
		"duplicate_goal": func(p): p.goals[1].id = p.goals[0].id,
		"unknown_kind": func(p): p.goals[0].kind = "loot",
		"unknown_trigger": func(p): p.goals[0].trigger = "public_help_event",
		"nonpersonal_trigger": func(p): p.goals[0].trigger = "future_committed_mining_help",
		"eligibility_not_optional": func(p): p.goals[0].eligible.free_time = false,
		"eligibility_truthy": func(p): p.goals[0].eligible.existing_availability = 1,
		"unknown_target": func(p): p.goals[2].target = "story:iva",
		"untied_target": func(p): p.goals[2].target = "mayor_lyra",
		"currency_grant": func(p): p.goals[0].currency = 1,
		"resolution_kind": func(p): p.goals[0].resolutions[0].kind = "reward",
		"fallback": func(p): p.goals[0].fallback = "missing",
		"reconciliation": func(p): p.goals[0].reconciliation = "alone",
		"missing_copy": func(p): p.erase("purpose_key"),
		"identity_override": func(p): p.role = "invented",
	}
	for label in mutations:
		var p := thorin.duplicate(true)
		mutations[label].call(p)
		t.check("invalid_profile_" + label, selector.call("select", "smith_thorin", p, _inputs()).is_empty())
	t.check("absent_profile", selector.call("select", "smith_thorin", {}, _inputs()).is_empty())
	t.check("unknown_npc", selector.call("select", "retired_npc", thorin, _inputs()).is_empty())
	var input_mutations := {
		"trigger_truthy": func(i): i.triggers = {"future_committed_mining_help": 1},
		"trigger_unknown": func(i): i.triggers = {"public_help_event": true},
		"cooldown_nan": func(i): i.cooldowns = {"lc_smith_thorin_role": NAN},
		"cooldown_fraction": func(i): i.cooldowns = {"lc_smith_thorin_role": 11.5},
		"cooldown_unknown": func(i): i.cooldowns = {"unknown": 11},
	}
	for label in input_mutations:
		var i := _inputs()
		input_mutations[label].call(i)
		t.check("invalid_inputs_" + label, selector.call("select", "smith_thorin", thorin, i).is_empty())
	for field in ["selected_day", "expiry_day", "cooldown_until_day", "utility"]:
		var previous := baseline.duplicate(true)
		previous[field] = NAN
		t.check("invalid_previous_" + field, selector.call("select", "smith_thorin", thorin, _inputs(), previous).is_empty())


func _malformed_types(t, selector: Script, thorin: Dictionary, baseline: Dictionary) -> void:
	var bad := [null, true, 1.5, INF, NAN, "", &"role", {}, [], self, Callable(self, "_inputs")]
	var checks := 0
	var failures: Array[String] = []
	for field in ["id", "authorship", "values", "ties", "goals", "purpose_key", "identity_source", "retired"]:
		for value in bad:
			var p := thorin.duplicate(true)
			p[field] = value
			checks += 1
			if not selector.call("select", "smith_thorin", p, _inputs()).is_empty():
				failures.append("profile:" + field + ":" + str(typeof(value)))
	for field in ["id", "kind", "value", "weight", "eligible", "trigger", "currency", "resources", "resolutions", "fallback", "reconciliation"]:
		for value in bad:
			# Empty resources and numeric zero are valid; neither is part of this fixture set except {}.
			if field == "resources" and typeof(value) == TYPE_DICTIONARY:
				continue
			var p := thorin.duplicate(true)
			p.goals[0][field] = value
			checks += 1
			if not selector.call("select", "smith_thorin", p, _inputs()).is_empty():
				failures.append("goal:" + field + ":" + str(typeof(value)))
	for field in ["protected", "triggers", "cooldowns"]:
		for value in bad:
			if typeof(value) == TYPE_DICTIONARY:
				continue
			var i := _inputs()
			i[field] = value
			checks += 1
			if not selector.call("select", "smith_thorin", thorin, i).is_empty():
				failures.append("inputs:" + field + ":" + str(typeof(value)))
	for field in ["npc", "goal_id", "kind", "target", "reasons", "selected_day", "expiry_day", "cooldown_until_day", "utility"]:
		for value in bad:
			var previous := baseline.duplicate(true)
			previous[field] = value
			checks += 1
			if not selector.call("select", "smith_thorin", thorin, _inputs(), previous).is_empty():
				failures.append("previous:" + field + ":" + str(typeof(value)))
	for field in ["value", "value_weight", "goal_weight", "weighted_value", "trigger_bonus"]:
		for value in bad:
			var previous := baseline.duplicate(true)
			previous.reasons[field] = value
			checks += 1
			if not selector.call("select", "smith_thorin", thorin, _inputs(), previous).is_empty():
				failures.append("reason:" + field + ":" + str(typeof(value)))
	for field in ["target", "provenance", "source", "reason_key"]:
		for value in bad:
			var p := thorin.duplicate(true)
			p.ties[0][field] = value
			checks += 1
			if not selector.call("select", "smith_thorin", p, _inputs()).is_empty():
				failures.append("tie:" + field + ":" + str(typeof(value)))
	for field in ["id", "kind", "text_key"]:
		for value in bad:
			var p := thorin.duplicate(true)
			p.goals[0].resolutions[0][field] = value
			checks += 1
			if not selector.call("select", "smith_thorin", p, _inputs()).is_empty():
				failures.append("resolution:" + field + ":" + str(typeof(value)))
	t.check("malformed_types_fail_closed", failures.is_empty(), "%d cases; failures: %s" % [checks, str(failures)])


func _string_contract(t, selector: Script, thorin: Dictionary, baseline: Dictionary) -> void:
	# Matching StringNames are not Lua strings, including consumed enums not copied to output.
	var mutations := {
		"id": func(p): p.id = StringName(p.id),
		"authorship": func(p): p.authorship = StringName(p.authorship),
		"purpose_key": func(p): p.purpose_key = StringName(p.purpose_key),
		"identity_source": func(p): p.identity_source = StringName(p.identity_source),
		"value_key": func(p): p.values = {&"quiet": 3, "craft": 2},
		"goal_id": func(p): p.goals[2].id = StringName(p.goals[2].id),
		"goal_kind": func(p): p.goals[2].kind = &"connect",
		"goal_value": func(p): p.goals[2].value = StringName(p.goals[2].value),
		"goal_target": func(p): p.goals[2].target = StringName(p.goals[2].target),
		"goal_trigger": func(p): p.goals[0].trigger = &"none",
		"help_trigger": func(p): p.goals[1].trigger = &"future_committed_mining_help",
		"goal_text": func(p): p.goals[0].text_key = StringName(p.goals[0].text_key),
		"fallback": func(p): p.goals[0].fallback = StringName(p.goals[0].fallback),
		"reconciliation": func(p): p.goals[0].reconciliation = StringName(p.goals[0].reconciliation),
		"tie_target": func(p): p.ties[0].target = StringName(p.ties[0].target),
		"tie_provenance": func(p): p.ties[0].provenance = StringName(p.ties[0].provenance),
		"tie_source": func(p): p.ties[0].source = StringName(p.ties[0].source),
		"tie_reason": func(p): p.ties[0].reason_key = StringName(p.ties[0].reason_key),
		"resolution_id": func(p): p.goals[0].resolutions[0].id = StringName(p.goals[0].resolutions[0].id),
		"resolution_kind": func(p): p.goals[0].resolutions[0].kind = StringName(p.goals[0].resolutions[0].kind),
		"resolution_text": func(p): p.goals[0].resolutions[0].text_key = StringName(p.goals[0].resolutions[0].text_key),
	}
	for label in mutations:
		var p := thorin.duplicate(true)
		mutations[label].call(p)
		t.check("stringname_profile_" + label, selector.call("select", "smith_thorin", p, _inputs()).is_empty())
	for field in ["npc", "goal_id", "kind", "target"]:
		var previous := baseline.duplicate(true)
		previous[field] = StringName(previous[field])
		t.check("stringname_previous_" + field, selector.call("select", "smith_thorin", thorin, _inputs(), previous).is_empty())
	var previous := baseline.duplicate(true)
	previous.reasons.value = &"quiet"
	t.check("stringname_previous_reason_value", selector.call("select", "smith_thorin", thorin, _inputs(), previous).is_empty())
	for field in ["target", "reason_value"]:
		for index in 8:
			var value: Variant = [null, true, 1, &"baker_maja", &"quiet", {}, [], self][index]
			var record := baseline.duplicate(true)
			if field == "target":
				record["target"] = value
			else:
				record.reasons["value"] = value
			record.reasons.make_read_only()
			record.make_read_only()
			t.check("safe_record_scalar_%s_%d" % [field, index], not _safe_record(record))
	t.check("safe_record_actual_string_scalars", _safe_record(baseline)
		and typeof(baseline.target) == TYPE_STRING and typeof(baseline.reasons.value) == TYPE_STRING)


func _boundaries(t, selector: Script, thorin: Dictionary, baseline: Dictionary, catalogue: Dictionary) -> void:
	var other: Dictionary = catalogue.baker_maja.duplicate(true)
	other.goals[1].trigger = "future_committed_mining_help"
	var trusted := _inputs()
	trusted.triggers = {"future_committed_mining_help": true}
	t.check("help_trigger_smith_personal_only", selector.call("select", "baker_maja", other, trusted).is_empty())
	trusted.triggers.future_committed_mining_help = false
	t.check("explicit_false_trigger_ineligible", selector.call("select", "smith_thorin", thorin, trusted) == baseline)
	var values := thorin.duplicate(true)
	values.values["extra_a"] = 1
	values.values["extra_b"] = 1
	t.check("maximum_four_values_valid_references", selector.call("select", "smith_thorin", values, _inputs()) == baseline)
	values.values["extra_c"] = 1
	t.check("oversized_values_five_valid_references", values.values.size() == 5
		and selector.call("select", "smith_thorin", values, _inputs()).is_empty())
	var ties := thorin.duplicate(true)
	var targets := {}
	for tie in ties.ties:
		targets[tie.target] = true
	var ids := catalogue.keys()
	ids.sort()
	for id in ids:
		if id == "smith_thorin" or targets.has(id):
			continue
		if ties.ties.size() == 8:
			break
		var tie: Dictionary = thorin.ties[0].duplicate(true)
		tie.target = id
		ties.ties.append(tie)
		targets[id] = true
	t.check("maximum_eight_distinct_ties_valid_references", ties.ties.size() == 8
		and selector.call("select", "smith_thorin", ties, _inputs()) == baseline)
	for id in ids:
		if id != "smith_thorin" and not targets.has(id):
			var tie: Dictionary = thorin.ties[0].duplicate(true)
			tie.target = id
			ties.ties.append(tie)
			targets[id] = true
			break
	t.check("oversized_ties_nine_distinct_valid_references", ties.ties.size() == 9 and targets.size() == 9
		and selector.call("select", "smith_thorin", ties, _inputs()).is_empty())
	var goals := thorin.duplicate(true)
	t.check("maximum_four_unique_goals_valid", selector.call("select", "smith_thorin", goals, _inputs()) == baseline)
	var extra: Dictionary = goals.goals[0].duplicate(true)
	extra.id = "lc_smith_thorin_extra"
	goals.goals.append(extra)
	var goal_ids := {}
	for goal in goals.goals:
		goal_ids[goal.id] = true
	t.check("oversized_goals_five_unique_valid_references", goal_ids.size() == 5
		and selector.call("select", "smith_thorin", goals, _inputs()).is_empty())
	var long_id := thorin.duplicate(true)
	long_id.goals[0].id = "lc_smith_thorin_" + "a".repeat(129)
	t.check("bounded_goal_token", selector.call("select", "smith_thorin", long_id, _inputs()).is_empty())
	var min_day := _inputs(1)
	t.check("minimum_day", selector.call("select", "smith_thorin", thorin, min_day).get("selected_day") == 1)
	var json_input: Dictionary = JSON.parse_string(JSON.stringify(_inputs()))
	var json_profile: Dictionary = JSON.parse_string(JSON.stringify(thorin))
	var json_previous: Dictionary = JSON.parse_string(JSON.stringify(baseline))
	t.check("whole_json_numbers_accepted", selector.call("select", "smith_thorin", json_profile, json_input, json_previous) == baseline)
	var expired_cooling := thorin.duplicate(true)
	expired_cooling.goals = [expired_cooling.goals[0]]
	expired_cooling.goals[0].expires_days = 1
	expired_cooling.goals[0].cooldown_days = 14
	var first: Dictionary = selector.call("select", "smith_thorin", expired_cooling, _inputs())
	t.check("expired_selection_still_cools", selector.call("select", "smith_thorin", expired_cooling, _inputs(11), first).is_empty())
	t.check("expired_cooldown_exact_boundary", selector.call("select", "smith_thorin", expired_cooling, _inputs(24), first).get("selected_day") == 24)
	var input := _inputs()
	input.cooldowns = {baseline.goal_id: 1000015}
	t.check("cooldown_upper_bound", selector.call("select", "smith_thorin", thorin, input).is_empty())
	var forged := baseline.duplicate(true)
	forged.reasons.weighted_value += 1
	t.check("inconsistent_previous_reason", selector.call("select", "smith_thorin", thorin, _inputs(), forged).is_empty())
	var safe := _inputs(11)
	safe.triggers = {"future_committed_mining_help": true}
	safe.protected.story = true
	t.check("next_day_help_cannot_override_story", selector.call("select", "smith_thorin", thorin, safe, baseline).is_empty())


func _roster_and_purity(t, selector: Script, catalogue: Dictionary) -> void:
	var before := catalogue.duplicate(true)
	var canonical: Dictionary = t.autoload("LuaRuntime").call("get_config", "npcs", {})
	var ids := catalogue.keys()
	ids.sort()
	var expected := canonical.keys()
	expected.sort()
	t.check("actual_full_34_roster", ids.size() == 34 and ids == expected)
	var counts := {"profiles": 0, "goals": 0, "permutations": 0}
	for npc in ids:
		var p: Dictionary = catalogue[npc]
		counts.profiles += 1
		counts.goals += p.goals.size()
		var i := _inputs()
		i["ignored_object"] = self
		i["private_player_rows"] = {"p3": {"future_committed_mining_help": true}}
		var before_input := i.duplicate(true)
		var selected: Dictionary = selector.call("select", npc, p, i)
		t.check("roster_selected_" + npc, not selected.is_empty() and selected.npc == npc)
		t.check("bounded_output_" + npc, _safe_record(selected))
		var latched := selected.duplicate(true)
		latched["ignored_object"] = self
		var before_previous := latched.duplicate(true)
		var replay: Dictionary = selector.call("select", npc, p, i, latched)
		t.check("purity_" + npc, i == before_input and latched == before_previous and replay == selected)
		var permutations := _permutations(p.goals)
		var invariant := true
		for goals in permutations:
			var permuted: Dictionary = _reverse_tree(p)
			permuted.goals = _reverse_tree(goals)
			counts.permutations += 1
			invariant = invariant and selector.call("select", npc, permuted, _reverse_tree(i)) == selected
		t.check("all_permutations_" + npc, invariant, str(permutations.size()))
		# Every authored goal can be eligible alone; this is a decision, never an activity or resource grant.
		for goal in p.goals:
			var single := p.duplicate(true)
			single.goals = [goal.duplicate(true)]
			var explicit := _inputs(1000000)
			explicit.triggers = {"future_committed_mining_help": true}
			var result: Dictionary = selector.call("select", npc, single, explicit)
			t.check("authored_goal_" + goal.id, result.get("goal_id") == goal.id and result.get("selected_day") == 1000000
				and _safe_record(result))
	t.check("runtime_catalogue_not_mutated", before == catalogue)
	t.check("full_roster_counts", counts.profiles == 34 and counts.goals == 74, str(counts))
	var dump_path := OS.get_environment("LC3_SELECTOR_DUMP")
	if dump_path != "":
		var file := FileAccess.open(dump_path, FileAccess.WRITE)
		t.check("evidence_dump_open", file != null)
		if file != null:
			file.store_string(JSON.stringify({"counts": counts, "catalogue": catalogue,
				"baseline": selector.call("select", "smith_thorin", catalogue.smith_thorin, _inputs()),
				"confirmed": selector.call("select", "smith_thorin", catalogue.smith_thorin,
				{"day": 11, "available": true, "free_time": true, "protected": _inputs().protected,
				"triggers": {"future_committed_mining_help": true}})}, "  "))


func _safe_record(record: Dictionary) -> bool:
	var keys := record.keys()
	keys.sort()
	var expected := ["npc", "goal_id", "kind", "selected_day", "expiry_day", "cooldown_until_day", "utility", "reasons"]
	if record.get("kind") in ["connect", "reconcile"]:
		expected.append("target")
	expected.sort()
	if keys != expected or not record.is_read_only() or typeof(record.get("reasons")) != TYPE_DICTIONARY:
		return false
	var reason_keys: Array = record.reasons.keys()
	reason_keys.sort()
	if reason_keys != ["goal_weight", "trigger_bonus", "value", "value_weight", "weighted_value"] or not record.reasons.is_read_only():
		return false
	for field in ["npc", "goal_id", "kind"]:
		if typeof(record[field]) != TYPE_STRING or record[field].length() > 128:
			return false
	if record.has("target") and (typeof(record.target) != TYPE_STRING or record.target.length() < 1 or record.target.length() > 128):
		return false
	if typeof(record.reasons.value) != TYPE_STRING or record.reasons.value.length() < 1 or record.reasons.value.length() > 128:
		return false
	for field in ["selected_day", "expiry_day", "cooldown_until_day", "utility"]:
		if typeof(record[field]) != TYPE_INT:
			return false
	for field in ["goal_weight", "trigger_bonus", "value_weight", "weighted_value"]:
		if typeof(record.reasons[field]) != TYPE_INT:
			return false
	return record.utility >= 1 and record.utility <= 26


func _reverse_tree(source: Variant) -> Variant:
	if typeof(source) == TYPE_DICTIONARY:
		var keys: Array = source.keys()
		keys.reverse()
		var result := {}
		for key in keys:
			result[key] = _reverse_tree(source[key])
		return result
	if typeof(source) == TYPE_ARRAY:
		var result := []
		for item in source:
			result.append(_reverse_tree(item))
		return result
	return source


func _permutations(goals: Array) -> Array:
	if goals.is_empty():
		return [[]]
	var result := []
	for index in goals.size():
		var rest := goals.duplicate()
		var first: Variant = rest.pop_at(index)
		for tail in _permutations(rest):
			result.append([first] + tail)
	return result
