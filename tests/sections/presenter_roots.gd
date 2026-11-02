extends RefCounted
const SECTION := "presenter_roots"
const TIMEOUT_S := 150.0
func run(t) -> void:
	await _post(t)
	await _intro(t)
	await _tutorial(t)
	await _tutorial_intro_skip(t)
	await _mother(t)
	await _garden(t)
	await _event(t)
	await _gift(t)
func _setup(t) -> void:
	await t.start_world()
	t.autoload("SaveManager").autosave_enabled = false
	t.autoload("GameManager").set_config_override("time.minutes_per_real_second", 0.0)
func _post(t) -> void:
	await _setup(t)
	var gm: Node = t.autoload("GameManager")
	var bus: Node = t.autoload("EventBus")
	gm.day = 2
	var box: PostBox2D = t.world().area.find_markers("mailbox")[0].node
	box.refresh()
	gm.clear_flag(&"post_toast_day")
	var seen: Array = []
	var observe := func(id, _payload):
		if id == &"post_read": seen.append(true)
	var replace := func(key, _value):
		if key == &"post_toast_day": PlayerRegistry.reset_states()
	bus.game_event.connect(observe)
	bus.flag_changed.connect(replace)
	box.interact(t.player())
	bus.flag_changed.disconnect(replace)
	t.check("post_refresh_callback_cannot_read_replacement", gm.flag_int(&"post_read_day") == 0 and seen.is_empty())
	bus.game_event.disconnect(observe)
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	if ui.is_open(): ui.close()
func _intro(t) -> void:
	await _setup(t)
	var gm: Node = t.autoload("GameManager")
	var bus: Node = t.autoload("EventBus")
	gm.clear_flag(&"intro_letter_seen")
	gm.set_config_override("farm_tutorial.first_morning.enabled", false)
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	preload("res://scripts/world2d/intro_sequence.gd").run(t.world())
	await t.frames(2)
	t.check("intro_actual_claim_open", ui.is_open())
	bus.dialogue_ended.connect(func(): PlayerRegistry.reset_states(), CONNECT_ONE_SHOT)
	for i in 30:
		if not ui.is_open(): break
		ui._typing = false
		ui._advance()
		await t.frames(1)
	await t.frames(2)
	t.check("intro_old_root_cannot_accept_replacement", not t.autoload("QuestManager").is_active(&"intro_lottery") and not bool(gm.get_flag(&"intro_letter_seen", false)))
	gm.clear_config_overrides()
func _tutorial(t) -> void:
	await _setup(t)
	var gm: Node = t.autoload("GameManager")
	var bus: Node = t.autoload("EventBus")
	gm.clear_flag(&"first_morning_done")
	gm.set_config_override("farm_tutorial.first_morning.steps", [{"kind":"hint","id":"tools"},{"kind":"quest_accept","quest":"intro_lottery"}])
	var changed: Array = []
	var replace := func(id, _payload):
		if id == &"tutorial_step" and changed.is_empty():
			changed.append(true)
			PlayerRegistry.reset_states()
	bus.game_event.connect(replace)
	await TutorialRunner.run(t.world())
	bus.game_event.disconnect(replace)
	t.check("tutorial_root_revoked_between_authored_steps", changed.size() == 1 and not t.autoload("QuestManager").is_active(&"intro_lottery") and not bool(gm.get_flag(&"first_morning_done", false)))
	gm.clear_config_overrides()
func _tutorial_intro_skip(t) -> void:
	await _setup(t)
	var gm: Node = t.autoload("GameManager")
	gm.clear_flag(&"first_morning_done")
	gm.clear_flag(&"intro_letter_seen")
	gm.set_config_override("farm_tutorial.first_morning.steps", [{"kind":"dialogue", "context":"intro"}, {"kind":"quest_accept", "quest":"intro_lottery"}])
	var session := TutorialRunner.new()
	session.world = t.world()
	session.origin = preload("res://scripts/traetoppen/life/presenter_origin.gd").capture(t.world())
	session.play()
	await t.frames(2)
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	t.check("tutorial_intro_real_page_before_skip", session.active and ui.is_open())
	session.skip()
	await t.frames(3)
	t.check("tutorial_intro_skip_exact_page_and_authored_completion", not session.active and not ui.is_open() and bool(gm.get_flag(&"first_morning_done", false)) and t.autoload("QuestManager").is_active(&"intro_lottery"))
	if ui.is_open(): ui.close()
	await t.frames(2)
	gm.clear_config_overrides()

func _mother(t) -> void:
	await _setup(t)
	var gm: Node = t.autoload("GameManager")
	gm.set_flag(&"forest_mother_version", 1)
	var marker := MotherEvidenceMarker.new()
	marker.evidence_id = "marked_lamp"
	marker.area = t.world().area
	t.world().area.objects.add_child(marker)
	marker.interact(t.player())
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	await t.page_to_choices(ui)
	t.check("mother_actual_record_choice", ui.is_open() and ui._choices.any(func(c): return c.action == "mother_record"))
	ui.choice_selected.connect(func(_action, _choice): PlayerRegistry.reset_states(), CONNECT_ONE_SHOT)
	ui._pick({"action":"mother_record"})
	await t.frames(2)
	t.check("mother_no_record_after_profile_replacement", not MotherStory.has("marked_lamp"))
	marker.free()
func _garden(t) -> void:
	await _setup(t)
	var gm: Node = t.autoload("GameManager")
	gm.clear_flag(&"intro_pending")
	var marker := SecretGardenMarker.new()
	marker.kind = "gate"
	marker.area = t.world().area
	t.world().area.objects.add_child(marker)
	marker.interact(t.player())
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	await t.page_to_choices(ui)
	t.check("garden_actual_start_choice", ui.is_open() and ui._choices.any(func(c): return c.action == "garden_start"))
	ui.choice_selected.connect(func(_action, _choice): PlayerRegistry.reset_states(), CONNECT_ONE_SHOT)
	ui._pick({"action":"garden_start"})
	await t.frames(2)
	t.check("garden_no_accept_after_profile_replacement", not t.autoload("QuestManager").is_active(&"secret_garden"))
	marker.free()
func _event(t) -> void:
	await _setup(t)
	var bus: Node = t.autoload("EventBus")
	var gm: Node = t.autoload("GameManager")
	var runner := SocialEventRunner.new()
	t.world().add_child(runner)
	var reset: Array = []
	var replace := func(key, _value):
		if key == &"presenter_event_first" and reset.is_empty():
			reset.append(true)
			PlayerRegistry.reset_states()
	bus.flag_changed.connect(replace)
	var before: int = t.autoload("SocialManager").points("baker_maja")
	await runner.play("presenter_test", {"meta":{"npc":"baker_maja"},"steps":[{"act":"flag","key":"presenter_event_first"},{"act":"points","npc":"baker_maja","amount":15}]})
	bus.flag_changed.disconnect(replace)
	t.check("event_no_points_suffix_after_profile_replacement", reset.size() == 1 and t.autoload("SocialManager").points("baker_maja") == before)
	t.check("event_unwinds_modal_and_busy", runner.active == "" and not gm.is_modal_open(&"event"))
	runner.free()

func _gift(t) -> void:
	await _setup(t)
	var bus: Node = t.autoload("EventBus")
	var eco: Node = t.autoload("EconomyManager")
	eco.add_item(&"carrot", 1, true)
	var result := GiftFlow.give_gift("gardener_hoppe", "carrot")
	t.check("gift_actual_committed_result", bool(result.get("ok", false)), str(result))
	if not bool(result.get("ok", false)): return
	var citizen := Npc2D.create({"id":"gardener_hoppe", "guest":true, "wander":"0"})
	citizen.area = t.world().area
	t.world().area.objects.add_child(citizen)
	var replacements: Array = []
	var replace := func(_title, _text, kind):
		if kind == "social" and replacements.is_empty():
			replacements.append(true)
			PlayerRegistry.reset_states()
	bus.notification_posted.connect(replace)
	preload("res://scripts/ui/social/gift_reaction.gd").run("gardener_hoppe", result, weakref(citizen))
	await t.frames(2)
	bus.notification_posted.disconnect(replace)
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	t.check("gift_toast_cannot_present_into_replacement", replacements.size() == 1 and not ui.is_open() and t.player().state != PlayerBody2D.S.TALKING)
	if ui.is_open(): ui.close()
	citizen.free()
