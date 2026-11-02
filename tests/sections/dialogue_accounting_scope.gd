extends RefCounted
## Load from an actual p1 terminal observer, not an ambient-id stand-in.
const SECTION := "dialogue_accounting_scope"
const TIMEOUT_S := 90.0
func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SocialManager")
	var saves: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	saves.autosave_enabled = false
	saves.save_dir = "user://dialogue_accounting_scope"
	# A normal single-host social save deliberately has no by_player field.
	PlayerRegistry.for_player(&"p0", func(): sm.debug_set_hearts("smith_thorin", 2))
	t.check("saved_single_host_social_has_real_p0_points", sm.points("smith_thorin", &"p0") == 200 and not sm.to_dict().has("by_player"))
	t.check("real_single_host_save_before_p1_join", saves.save_game(0))
	var body: Node2D = t.world()._make_player()
	t.world()._register_player(body, 1, 2)
	t.world().add_child(body)
	var actor := Npc2D.create({"id": "smith_thorin", "wander": "0"})
	t.world().add_child(actor)
	var ui: Control = t.tree.get_first_node_in_group("dialogue_ui")
	PlayerRegistry.for_player(&"p0", func(): actor.interact(body))
	await t.page_to_choices(ui)
	t.check("real_p1_weekly_page_under_conflicting_p0_caller", actor.is_talking and actor._talk_player == body and PlayerRegistry.registered_id(body) == &"p1" and sm.points("smith_thorin", &"p1") == 0 and PlayerRegistry._acting_id == &"")
	var observed: Array = []
	var on_flag := func(flag, value):
		if flag != &"friend_last_smith_thorin" or int(value) <= 0 or not observed.is_empty(): return
		observed.append({"scope": str(PlayerRegistry._acting_id)})
		observed[0]["loaded"] = saves.load_game(0)
		observed[0]["p0"] = sm.points("smith_thorin", &"p0")
		observed[0]["p1"] = sm.points("smith_thorin", &"p1")
		observed[0]["return_scope"] = str(PlayerRegistry._acting_id)
	bus.flag_changed.connect(on_flag)
	for button in ui._buttons:
		if button.get_meta("choice").get("action") == "close":
			PlayerRegistry.for_player(&"p0", func():
				button.pressed.emit()
				t.check("synchronous_input_restores_conflicting_caller_scope", PlayerRegistry._acting_id == &"p0"))
			break
	bus.flag_changed.disconnect(on_flag)
	t.check("p1_observer_load_preserves_saved_slot_identity", observed == [{"scope": "p1", "loaded": true, "p0": 200, "p1": 0, "return_scope": "p1"}], str(observed))
	t.check("old_p1_accounting_cannot_change_loaded_rows", sm.points("smith_thorin", &"p0") == 200 and sm.points("smith_thorin", &"p1") == 0 and PlayerRegistry._acting_id == &"", str(sm.to_dict()))
	t.check("p1_load_leaves_no_page_or_hold", not ui.is_open() and not actor.is_talking and not actor._held)
	actor.free()
	if is_instance_valid(body): t.world()._unregister_player(body)
	gm.clear_config_overrides()
