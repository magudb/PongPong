extends RefCounted
const SECTION := "presenter_callee_ownership"
const TIMEOUT_S := 150.0
func setup(t) -> void:
	await t.start_world()
	t.autoload("SaveManager").autosave_enabled = false
	t.autoload("GameManager").set_config_override("time.minutes_per_real_second", 0.0)
func run(t) -> void:
	await setup(t)
	var gm: Node = t.autoload("GameManager")
	var bus: Node = t.autoload("EventBus")
	var qm: Node = t.autoload("QuestManager")
	gm.set_flag(&"forest_mother_version", 1)
	var work := MotherEvidenceMarker.new()
	work.evidence_id = "memory_lamp"
	work.area = t.world().area
	t.world().area.objects.add_child(work)
	work.interact(t.player())
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	await t.page_to_choices(ui)
	t.check("real_mother_work_choice", ui.is_open() and ui._choices.any(func(c): return c.action == "stitch_0"))
	var events: Array = []
	var observe := func(id, _payload):
		if id == &"forest_mother_work": events.append(true)
	var changed: Array = []
	var replace := func(key, _value):
		if key == &"forest_mother_v1_work_memory_lamp" and changed.is_empty():
			changed.append(true)
			PlayerRegistry.reset_states()
	bus.game_event.connect(observe)
	bus.flag_changed.connect(replace)
	ui._pick({"action":"stitch_0"})
	bus.flag_changed.disconnect(replace)
	bus.game_event.disconnect(observe)
	t.check("work_first_earned_write_retained", changed.size() == 1 and MotherMemoryWork.state("memory_lamp") == 1)
	t.check("work_callee_stops_replacement_event_suffix", events.is_empty())
	work.free()
	await setup(t)
	ui = t.tree.get_first_node_in_group("dialogue_ui")
	gm.set_flag(&"forest_mother_version", 1)
	var marker: Node = MotherEvidenceMarker.new()
	marker.evidence_id = "marked_lamp"
	marker.area = t.world().area
	t.world().area.objects.add_child(marker)
	marker.interact(t.player())
	await t.page_to_choices(ui)
	t.check("real_mother_record_choice", ui.is_open() and ui._choices.any(func(c): return c.action == "mother_record"))
	changed.clear()
	var replace_record := func(key, _value):
		if key == &"forest_mother_v1_marked_lamp" and changed.is_empty():
			changed.append(true)
			PlayerRegistry.reset_states()
	bus.flag_changed.connect(replace_record)
	ui._pick({"action":"mother_record"})
	bus.flag_changed.disconnect(replace_record)
	t.check("record_first_earned_evidence_retained", changed.size() == 1 and MotherStory.has("marked_lamp"))
	t.check("record_callee_does_not_accept_replacement_quest", not qm.is_active(&"forest_mother_s03"))
	marker.free()
	await setup(t)
	ui = t.tree.get_first_node_in_group("dialogue_ui")
	gm.clear_flag(&"intro_pending")
	t.check("real_reward_garden_accepted", qm.accept_quest(&"secret_garden"))
	for i in 11: qm.complete_manual(&"secret_garden", StringName(SecretGardenStory.STEPS[i].id))
	t.check("real_final_garden_precondition", SecretGardenStory.step() == 11)
	marker = SecretGardenMarker.new()
	marker.kind = "bench"
	marker.area = t.world().area
	t.world().area.objects.add_child(marker)
	marker.interact(t.player())
	await t.page_to_choices(ui)
	t.check("real_final_garden_page", ui.is_open() and ui._choices.any(func(c): return c.action == "garden_work"))
	changed.clear()
	var replace_gold := func(_pid, _gold, _delta):
		if changed.is_empty():
			changed.append(true)
			PlayerRegistry.reset_states()
	bus.gold_changed.connect(replace_gold, CONNECT_ONE_SHOT)
	ui._pick({"action":"garden_work"})
	t.check("real_reward_first_gold_callback_reached", changed.size() == 1)
	t.check("quest_reward_suffix_does_not_grant_replacement_friendship", t.autoload("SocialManager").hearts("gardener_hoppe") == 0 and t.autoload("SocialManager").hearts("carpenter_brumme") == 0)
	marker.free()
