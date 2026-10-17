extends RefCounted
const SECTION := "social_events"
const TIMEOUT_S := 180.0
const NPC := "gardener_hoppe"
var runner: SocialEventRunner
var ui: Node
var director: SocialEventDirector
func run(t) -> void:
	await _run(t,false)
func run_windowed(t) -> void:
	await _run(t,true)
func _run(t,native: bool) -> void:
	await t.start_world()
	var world: WorldRoot2D = t.world()
	GameManager.set_flag(&"intro_pending",false)
	GameManager.set_config_override("time.minutes_per_real_second",0)
	GameManager.set_config_override("towns.curfew.enabled",false)
	SocialFixture.jump(3,12)
	SocialManager.flush()
	director = SocialManager.get_node("EventDirector")
	runner = director.runner
	ui = t.first(&"dialogue_ui")
	var records: Array = []
	var ended := func(id,skip): records.append([id,skip])
	runner.finished.connect(ended)
	var definitions := {
		"event_reward":{"meta":{"npc":NPC,"hearts":1,"trigger":"talk"},"steps":[
			{"act":"fade","to":"black","time":0.01},
			{"act":"stand","who":"player","facing":"NE"},
			{"act":"camera","focus":"player","time":0.01,"zoom":0.6},
			{"act":"fade","to":"clear","time":0.01},
			{"act":"say","who":NPC,"text_key":"SOC_GARDENER_HOPPE_FIRST_1_V"},
			{"act":"say","who":NPC,"text_key":"SOC_GARDENER_HOPPE_GREET_H0_1_V"},
			{"act":"choice","options":[{"id":"first","text_key":"SOC_EV_CONTINUE","points":20,"flag":"event_first_choice"},{"id":"second","text_key":"SOC_EV_SKIP","points":10,"flag":"event_second_choice"}]},
			{"act":"give","item":"moonflower_seeds","amount":2},
			{"act":"points","amount":30},
			{"act":"flag","key":"event_reward_flag"},
			{"act":"time","minutes":300},
			{"act":"wait","time":0.01},{"act":"sfx","id":"unavailable_test_cue"},{"act":"end"}],"rewards":{"points":40,"flag":"event_end_flag"}},
		"event_missing_actor":{"meta":{"npc":NPC,"hearts":1},"steps":[{"act":"walk","who":"missing_actor","mark":"missing"},{"act":"clip","who":"missing_actor","clip":"idle"},{"act":"emote","who":"missing_actor","kind":"heart"},{"act":"say","who":NPC,"text_key":"SOC_GARDENER_HOPPE_FIRST_1_V"}],"rewards":{"points":10}},
		"event_yearly":{"meta":{"trigger":"festival","once_per_year":true},"steps":[{"act":"say","who":NPC,"text_key":"SOC_GARDENER_HOPPE_FIRST_1_V"}],"rewards":{"items":{"wood":1}}},
		"event_cancel":{"meta":{"npc":NPC,"hearts":1},"steps":[{"act":"say","who":NPC,"text_key":"SOC_GARDENER_HOPPE_FIRST_1_V"},{"act":"flag","key":"event_cancelled_flag"}]},
	}
	SocialFixture.install({}, {"events":definitions,"festivals":{}})
	SocialManager.debug_set_hearts(NPC,1)
	await t.frames(3)
	t.check("heart_event_only_on_talk",runner.active == "" and not GameManager.is_modal_open(&"event") and "event_reward" in SocialManager.events_ready(NPC))
	t.check("automatic_events_never_appear_in_talk_choices",not "event_yearly" in SocialManager.events_ready(NPC))
	GameManager.push_modal(&"test_pause",true)
	t.check("queue_accepts_while_busy",director.request("event_reward"))
	t.check("deduplicates_queued_events",not director.request("event_reward"))
	await t.frames(3)
	t.check("waits_for_playing_and_no_modal",runner.active == "" and director.queue.size() == 1)
	GameManager.pop_modal(&"test_pause")
	await t.until(func(): return ui.is_open(),3.0)
	t.check("queued_talk_starts_after_modal_closes",runner.active == "event_reward" and GameManager.is_modal_open(&"event") and ui.is_open())
	t.check("event_modal_is_nonpausing_cutscene",not t.tree.paused and GameManager.current_phase == GameManager.GamePhase.CUTSCENE)
	var old_minutes := GameManager.hour*60+GameManager.minute
	await t.seconds(0.05)
	t.check("clock_frozen",GameManager.hour*60+GameManager.minute == old_minutes)
	t.check("no_save_during_event",not SaveManager.save_game(3) and str(SaveManager.last_error.code) == "event")
	var old_area := world.area
	await world.travel(&"traetoppen",&"default")
	await world.sleep()
	t.check("no_travel_or_sleep_during_event",world.area == old_area and not world.sleeping and SocialManager.today() == 3)
	t.check("rewards_deferred_until_scene_end",EconomyManager.count_item(&"moonflower_seeds") == 0 and not GameManager.get_flag(&"event_reward_flag",false))
	if native:
		ui._typing = false
		ui.get_node("%TextLabel").visible_characters = -1
		await t.capture("heart_event")
	var overlay: Node = world.game_ui.get_screen(&"event_overlay")
	t.check("overlay_follows_modal",overlay.visible and not world.game_ui.get_screen(&"social_hud").visible)
	UiAudit.expect(t,UiAudit.focusable_report(overlay,{"forbid_focus":true}),"overlay_focus_none")
	UiAudit.expect(t,UiAudit.rule_report(overlay),"overlay_rules")
	UiAudit.expect(t,await UiAudit.locale_flip_report(t,overlay),"overlay_i18n")
	await t.tap(&"ui_cancel")
	await t.frames(3)
	var confirms := _confirms(t.tree.root)
	t.check("escape_opens_one_confirm",confirms.size() == 1 and GameManager.top_modal() == &"confirm")
	if native: await t.capture("skip_confirm")
	t.check("continue_is_default",confirms.size() == 1 and confirms[0].get_node("%CancelButton").has_focus())
	if not confirms.is_empty(): confirms[0]._finish(false)
	await t.frames(2)
	t.check("declining_skip_keeps_scene",runner.active == "event_reward" and ui.is_open())
	await t.tap(&"ui_cancel")
	await t.frames(2)
	confirms = _confirms(t.tree.root)
	if not confirms.is_empty(): confirms[0]._finish(true)
	await t.until(func():return runner.active == "",3.0)
	t.check("skip_fast_forwards_effects",GameManager.get_flag(&"event_reward_flag",false) and GameManager.get_flag(&"event_end_flag",false) and EconomyManager.count_item(&"moonflower_seeds") == 2)
	t.check("choice_takes_option_one_on_skip",GameManager.get_flag(&"event_first_choice",false) and not GameManager.get_flag(&"event_second_choice",false))
	t.check("all_point_steps_commit_once",SocialManager.points(NPC) == 190)
	t.check("time_step_capped_at_two_hours",GameManager.hour*60+GameManager.minute == old_minutes+120)
	t.check("seen_once_and_skip_recorded",SocialManager.event_seen("event_reward") and records == [["event_reward",true]])
	t.check("say_runs_merge_per_speaker",runner.dialogue_runs == 1)
	t.check("actors_released_on_end",world.player.state == PlayerBody2D.S.FREE and not world.player._event_active and GameManager.current_phase == GameManager.GamePhase.PLAYING)
	t.check("camera_released_on_end",world.player.camera.offset.is_zero_approx())
	t.check("seen_event_refused",not director.request("event_reward"))
	t.check("save_after_commit",SaveManager.save_game(3))
	t.check("load_after_commit",SaveManager.load_game(3))
	await t.frames(3)
	t.check("rewards_paid_once_after_load",SocialManager.event_seen("event_reward") and EconomyManager.count_item(&"moonflower_seeds") == 2 and not director.request("event_reward"))
	var skipped_before := runner.skipped_directives
	t.check("missing_actor_scene_can_start",director.request("event_missing_actor"))
	await _finish_dialogue(t)
	t.check("missing_actor_api_is_skipped_not_fatal",runner.skipped_directives-skipped_before == 3 and SocialManager.event_seen("event_missing_actor"))
	t.check("ordinary_scene_points_paid",SocialManager.points(NPC) == 200)
	# A full backpack keeps the reward in the existing social save, then claims it once.
	EconomyManager.inventory.clear()
	for i in 24: EconomyManager.inventory.append({"id":&"stone","amount":99,"meta":{}})
	t.check("yearly_scene_starts",director.request("event_yearly",true))
	await _finish_dialogue(t)
	t.check("full_pack_reward_is_saved",SocialManager.to_dict().get("owed",{}).get("wood",0) == 1 and EconomyManager.count_item(&"wood") == 0)
	t.check("full_pack_save_valid",SaveManager.save_game(3))
	t.check("full_pack_reward_loads",SaveManager.load_game(3))
	await t.frames(2)
	t.check("owed_survives_load",SocialManager.to_dict().get("owed",{}).get("wood",0) == 1)
	EconomyManager.remove_item(&"stone",99)
	await t.frames(4)
	t.check("reward_claimed_when_space_opens",EconomyManager.count_item(&"wood") == 1 and not SocialManager.to_dict().has("owed"))
	SocialManager.claim_event_items()
	t.check("reward_claim_is_idempotent",EconomyManager.count_item(&"wood") == 1)
	t.check("yearly_refused_same_year",not director.request("event_yearly",true))
	GameManager.year += 1
	t.check("yearly_scene_repeats_next_year",director.request("event_yearly",true))
	await _finish_dialogue(t)
	t.check("yearly_reward_second_year",EconomyManager.count_item(&"wood") == 2 and SocialManager.event_stamp("event_yearly") == 2)
	GameManager.hour = GameManager.day_end_hour()-1
	GameManager.minute = 50
	definitions.event_cancel.steps.insert(0,{"act":"time","minutes":100})
	SocialFixture.uninstall()
	SocialFixture.install({}, {"events":definitions,"festivals":{}})
	t.check("cancel_scene_starts",director.request("event_cancel"))
	await t.until(func():return ui.is_open(),3.0)
	runner.cancel()
	await t.frames(3)
	t.check("cancel_does_not_commit",not SocialManager.event_seen("event_cancel") and not GameManager.get_flag(&"event_cancelled_flag",false))
	t.check("cancel_releases_modal_and_actors",not GameManager.is_modal_open() and not world.player._event_active)
	t.check("cancelled_scene_can_retry",director.request("event_cancel"))
	await _finish_dialogue(t)
	t.check("time_stops_before_the_live_day_roll",GameManager.hour == GameManager.day_end_hour()-1 and GameManager.minute == 59)
	GameManager.push_modal(&"test_pause",true)
	for i in 6:
		var id := "queued_%d" % i
		var ok := director.request(id,true,{"meta":{"trigger":"automatic"},"steps":[]})
		t.check("queue_bound_%d" % i,ok == (i < 4))
	SocialFixture.jump(SocialManager.today()+2,12)
	GameManager.pop_modal(&"test_pause")
	await t.frames(4)
	t.check("queue_drops_after_two_days",director.queue.is_empty() and runner.active == "" and not SocialManager.event_seen("queued_0"))
	runner.finished.disconnect(ended)
	SocialFixture.uninstall()
	director.reset()
	t.new_game()

func _finish_dialogue(t) -> void:
	for i in 400:
		await t.frames(1)
		if ui.is_open() and GameManager.top_modal() == &"dialogue":
			if ui._wants_focus(): ui._pick(ui._choices[0])
			else: ui._advance()
		if runner.active == "" and director.queue.is_empty(): return
	t.fail("event did not release after its dialogue")

func _confirms(node: Node) -> Array:
	var out: Array = []
	if node is UiConfirm and node.is_open(): out.append(node)
	for child in node.get_children(): out.append_array(_confirms(child))
	return out
