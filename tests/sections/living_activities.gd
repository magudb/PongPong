extends RefCounted
## First vertical tracer: stock is granted by the existing delivery fixture;
## the real Npc2D meeting, not a fabricated LC receipt, commits the hand-in.
const SECTION := "living_activities"
const TIMEOUT_S := 180.0
const NPC := "smith_thorin"

func run(t) -> void:
	await load("res://tests/progression/living_delivery.gd").run(t)
	var sm: Node = t.autoload("SocialManager")
	var gm: Node = t.autoload("GameManager")
	t.check("committed_mining_has_private_receipt", sm.living_context(NPC, &"p1").get("memories", []).size() == 1)
	t.check("activity_snapshot_exists", sm.has_method("living_activity_snapshot"), "Actual receipt must drive a next-day LC1/LC3 decision and existing routine")
	if not sm.has_method("living_activity_snapshot"):
		return
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	var day: int = gm.total_day()
	var receipt: Dictionary = sm.to_dict()
	t.check("receipt_creates_shared_pending_not_player_payload", sm._living.world.get("pilot", {}).get("pending_day") == day and not JSON.stringify(sm.living_activity_snapshot()).contains("p1"))
	gm.set_config_override("time.weather_chances.foraar", {&"klart": 1.0})
	gm.set_clock(18, 0)
	await t.world().sleep()
	sm.flush()
	var snapshot: Dictionary = sm.living_activity_snapshot()
	var selected: Dictionary = snapshot.get("selected", {})
	t.check("actual_lc1_lc3_help_selected_next_day", selected.get("goal_id") == "lc_smith_thorin_personal" and selected.get("selected_day") == day + 1, str(snapshot))
	var ctx := Routines.now_ctx()
	ctx.hour = 19.5
	var helped := Routines.where_is(NPC, ctx)
	t.check("help_changes_existing_routine_post_and_act", helped.get("place") == "hyggebyen.torv_bench2" and helped.get("act") == "sit", str(helped))
	var helped_save: Dictionary = sm.to_dict()
	await _dialogue(t, helped_save)
	var no_help := receipt.duplicate(true)
	no_help.erase("living")
	sm.from_dict(no_help)
	sm.flush()
	var baseline := Routines.where_is(NPC, Routines.make_ctx(int(ctx.weekday), 19.5, str(ctx.weather), {"total_day": day + 1, "living_activity": sm.living_activity_snapshot()}))
	t.check("baseline_and_help_really_differ", baseline.get("place") == "hyggebyen.torv_fountain_e" and baseline.get("place") != helped.get("place"), str(baseline))
	gm.clear_config_overrides()

func _dialogue(t, saved: Dictionary) -> void:
	var sm: Node = t.autoload("SocialManager")
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("towns.curfew.enabled", false)
	gm.hour = 19
	gm.minute = 30
	await t.world().travel(&"hyggebyen", &"default")
	await t.until_game(func(): return NpcDirector.node_of(NPC) != null, 10.0)
	var actor: Npc2D = NpcDirector.node_of(NPC)
	if not t.expect(actor != null, "real director spawns Thorin for changed activity: area=%s error=%s hour=%s presence=%s directors=%s" % [t.world().area.map.id, t.world().last_travel_error, gm.hour, Routines.where_is(NPC, Routines.now_ctx()), NpcDirector._active.map(func(d): return {"area": d.area_id, "ready": d.ready_for_population, "live": d.live.keys()})]): return
	var director: TownDirector = actor.get_parent().get_parent().get_node_or_null("TownDirector")
	t.check("real_director_activity_body", actor.driven and actor._act == "sit", str(actor._act))
	var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
	actor.interact(t.player())
	await t.frames(3)
	t.check("real_npc_talking_and_held", actor.is_talking and actor._held and screen.is_open())
	# p0 still had the independently eligible mining objective in this fixture:
	# a physical meeting can commit it. Subsequent LC info/cancel cannot.
	var before: Dictionary = sm._living.duplicate(true)
	await t.page_to_choices(screen)
	var reached := false
	for page in 6:
		var wanted: Button
		for button in screen._buttons:
			if button.get_meta("choice", {}).get("action") == "living_activity": wanted = button; break
		if wanted != null:
			reached = true
			var forged: Dictionary = wanted.get_meta("choice").duplicate(true)
			forged.merge({"npc": "baker_maja", "player_id": "p3", "goal_id": "forged", "reward": 9999})
			var payload_before := forged.duplicate(true)
			var info := load("res://scripts/social/living/living_dialogue.gd")
			var offered := {"choices": [wanted.get_meta("choice")]}
			var reply: Dictionary = info.action(actor, t.player(), offered, {"completed": true, "choice": forged})
			t.check("choice_payload_not_authority_and_not_mutated", reply.get("speaker") == NPC and forged == payload_before and sm._living == before)
			t.check("missing_actual_npc_cannot_authorize_choice", info.action(null, t.player(), offered, {"completed": true, "choice": forged}).is_empty() and sm._living == before)
			_live_choice_guards(t, actor, offered, forged, before)
		else:
			for button in screen._buttons:
				if button.get_meta("choice", {}).get("action") == "social_more": wanted = button; break
		if wanted == null: break
		await t.until_game(func(): return screen._choice_grace <= 0.0, 1.0)
		wanted.grab_focus()
		t.tap_key(KEY_ENTER)
		# The pressed row is freed with its page: remember its id, never capture the Node in a lambda.
		var pressed := wanted.get_instance_id()
		if reached:
			# The contextual reply is a new page the game opens after the pick: wait for it, bounded by game time.
			await t.until_game(func(): return not screen._buttons.any(func(b): return b.get_instance_id() == pressed) and actor.is_talking and screen._lines.any(func(line): return line.get("text_key") == "LC_SMITH_THORIN_ACTIVITY"), 2.0)
			break
		# "More" replaces the page: wait until the pressed row is gone and the next page is open.
		await t.until_game(func(): return not screen._buttons.any(func(b): return b.get_instance_id() == pressed) and screen.is_open(), 2.0)
		await t.page_to_choices(screen)
	t.check("contextual_choice_reachable_real_npc_more_ui", reached)
	t.check("contextual_followup_on_actual_npc", reached and actor.is_talking and screen._lines.any(func(line): return line.get("text_key") == "LC_SMITH_THORIN_ACTIVITY"))
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	t.check("choice_cancel_do_not_mutate_living", sm._living == before and not actor.is_talking and not actor._held, "talk=%s held=%s open=%s diff=%s" % [actor.is_talking, actor._held, screen.is_open(), load("res://tests/progression/living_delivery.gd")._differences(before, sm._living)])

func _live_choice_guards(t, actor: Npc2D, page: Dictionary, picked: Dictionary, before: Dictionary) -> void:
	var info := load("res://scripts/social/living/living_dialogue.gd")
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SocialManager")
	var tm: Node = t.autoload("TimeManager")
	var lr: Node = t.autoload("LuaRuntime")
	var hm: Node = t.autoload("HomeManager")
	var festivals: Dictionary = lr._registries.festivals
	var visit: Dictionary = hm._visit
	var visit_day: int = hm._visit_day
	for condition in ["rain", "festival", "home", "unavailable", "absent", "post20"]:
		t.expect(not info.choice(NPC).is_empty(), "live choice positive before " + condition)
		if condition == "rain": tm.set_weather(&"regn")
		if condition == "festival": lr._registries.festivals = {"fix_festival": {"meta": {"season": str(gm.season), "day": gm.day, "from": 12, "to": 21}}}
		if condition == "home": hm._visit_day = gm.total_day(); hm._visit = {"npc": NPC}
		if condition in ["unavailable", "absent"]:
			var reg := Routines.registry().duplicate(true)
			if condition == "unavailable": reg[NPC].gate = {"done_quest": "fix_missing", "or_day": 999999}
			else: reg.erase(NPC)
			Routines.override_registry = reg
		if condition == "post20": gm.hour = 20; gm.minute = 0
		t.check("live_choice_hidden_" + condition, info.choice(NPC).is_empty() and sm._living == before)
		t.check("opened_choice_revalidates_" + condition, info.action(actor, t.player(), page, {"completed": true, "choice": picked}).is_empty() and sm._living == before)
		tm.set_weather(&"klart")
		lr._registries.festivals = festivals
		hm._visit = visit
		hm._visit_day = visit_day
		Routines.override_registry = {}
		Routines.clear_cache()
		gm.hour = 19
		gm.minute = 30
