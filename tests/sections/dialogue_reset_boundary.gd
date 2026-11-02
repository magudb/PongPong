extends RefCounted
## Actual synchronous new-game mutation inside an earned SocialManager callback.
## This probes the approved narrow fence against the excluded manager's API.
const SECTION := "dialogue_reset_boundary"
const TIMEOUT_S := 90.0

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SocialManager")
	var bus: Node = t.autoload("EventBus")
	gm.start_new_game("Reset control", gm.character_type, "Control")
	t.check("ordinary_newgame_synchronous_clean_social", sm.points("smith_thorin", &"p0") == 0 and gm.player_name == "Reset control")
	var actor := Npc2D.create({"id": "smith_thorin", "wander": "0"})
	t.world().add_child(actor)
	var screen: Control = t.tree.get_first_node_in_group("dialogue_ui")
	actor.interact(t.player())
	await t.page_to_choices(screen)
	var close_button: Button
	for button in screen._buttons:
		if button.get_meta("choice").get("action") == "close": close_button = button
	t.check("actual_eligible_first_week_chat_before_reset", actor.is_talking and close_button != null and screen._shown > 0 and sm.points("smith_thorin", &"p0") == 0)
	var trace: Array = []
	var once: Array = []
	var observer := func(flag, value):
		if flag != &"friend_last_smith_thorin" or int(value) <= 0 or not once.is_empty(): return
		once.append(true)
		gm.start_new_game("Observer reset", gm.character_type, "New farm")
		trace.append({"points_after_newgame_return": sm.points("smith_thorin", &"p0"), "name": gm.player_name})
	bus.flag_changed.connect(observer)
	await t.until_game(func(): return screen._choice_grace <= 0.0, 1.0)
	close_button.grab_focus()
	t.tap_key(KEY_ENTER)
	await t.frames(3)
	bus.flag_changed.disconnect(observer)
	t.check("real_newgame_finished_inside_social_flag_observer", trace == [{"points_after_newgame_return": 0, "name": "Observer reset"}], str(trace))
	t.check("old_terminal_accounting_cannot_mutate_reset_state", sm.points("smith_thorin", &"p0") == 0, "points_after_old_completion=%s; observer=%s" % [sm.points("smith_thorin", &"p0"), trace])
	t.check("reset_no_stale_page_or_hold", not screen.is_open() and not actor.is_talking and not actor._held)
	actor.free()
