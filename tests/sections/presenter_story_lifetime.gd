extends RefCounted
const SECTION := "presenter_story_lifetime"
const TIMEOUT_S := 120.0
func run(t) -> void:
	for kind in ["mother", "garden"]:
		for mode in ["live", "depart", "free_marker", "cancel"]:
			await _case(t, kind, mode)
func _case(t, kind: String, mode: String) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	t.autoload("SaveManager").autosave_enabled = false
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.clear_flag(&"intro_pending")
	gm.set_flag(&"forest_mother_version", 1)
	var body: Node2D = t.world()._make_player()
	t.world()._register_player(body, 1, 2)
	t.world().add_child(body)
	PlayerRegistry.state(&"p1") # Intentional fixture admission, not a presentation read.
	var marker: Node
	if kind == "mother":
		marker = MotherEvidenceMarker.new()
		marker.evidence_id = "marked_lamp"
	else:
		marker = SecretGardenMarker.new()
		marker.kind = "gate"
	marker.area = t.world().area
	t.world().area.objects.add_child(marker)
	PlayerRegistry.for_player(&"p0", func(): marker.interact(body))
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	await t.page_to_choices(ui)
	t.check(kind + "_" + mode + "_real_page", ui.is_open() and not ui._buttons.is_empty())
	if mode == "depart":
		ui.choice_selected.connect(func(_action, _choice): t.world()._unregister_player(body), CONNECT_ONE_SHOT)
	elif mode == "free_marker":
		ui.choice_selected.connect(func(_action, _choice): marker.free(), CONNECT_ONE_SHOT)
	if mode == "cancel": ui.close()
	else: ui._pick({"action":"mother_record" if kind == "mother" else "garden_start"})
	await t.frames(2)
	var earned: bool = MotherStory.has("marked_lamp") if kind == "mother" else PlayerRegistry.for_player(&"p1", func(): return t.autoload("QuestManager").is_active(&"secret_garden"))
	t.check(kind + "_" + mode + "_earned_exactly_on_original_owner", earned == (mode != "cancel") and not PlayerRegistry.for_player(&"p0", func(): return t.autoload("QuestManager").is_active(&"secret_garden")))
	t.check(kind + "_" + mode + "_no_stale_hold_or_modal", not ui.is_open() and (not is_instance_valid(body) or body.state != PlayerBody2D.S.TALKING))
	if is_instance_valid(marker): marker.free()
	if is_instance_valid(body): t.world()._unregister_player(body)
	gm.clear_config_overrides()
