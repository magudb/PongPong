extends RefCounted
const SECTION := "renewed_hud_visual"
const TIMEOUT_S := 120.0
func run(t) -> void:
	await t.start_world()
	var hud: Control = load("res://scenes/ui/hud.tscn").instantiate()
	t.root.add_child(hud)
	var rows: Dictionary = PlayerRegistry._states
	var fallback: PlayerState = PlayerRegistry._fallback_state
	PlayerRegistry._states = {}
	# Deliberately no p0, no lazy manager normalisation. These APIs only paint
	# supplied data; they are not independent model-reading/event roots.
	hud._gold(3210, 0)
	hud._stats({"stamina":63, "max_stamina":100, "half_hearts":9, "max_half_hearts":10})
	hud.set_hotbar([{"id":"wood", "amount":4}], 0)
	t.check("model_less_explicit_pure_gold_stats_hotbar", hud.gold_label.text == "3.210" and hud.hearts.half_hearts == 9 and hud.stamina_bar.value == 63 and hud._entries == [{"id":"wood", "amount":4}])
	hud.get_script().fixture_setup(hud, t.root)
	t.check("model_less_original_visual_fixture_setup", hud.gold_label.text == "1.240" and hud.hearts.half_hearts == 7 and hud.stamina_bar.value == 72 and hud._entries.size() == 4 and hud._entries[3].amount == 12 and hud._day == 16 and hud._hour == 10 and hud._minute == 20 and not hud.quest_card.visible)
	var gold: String = hud.gold_label.text
	var entries: Array = hud._entries.duplicate(true)
	var event: Signal = EventBus.gold_changed
	for connection in event.get_connections():
		var callback: Callable = connection.callable
		if callback.get_object() == hud: callback.call(&"p0", 99999, 0)
	hud._refresh_all()
	hud._refresh_quests()
	t.check("model_less_independent_event_and_reader_roots_refuse", hud.gold_label.text == gold and hud._entries == entries and PlayerRegistry._states.is_empty())
	PlayerRegistry._states = rows
	PlayerRegistry._fallback_state = fallback
	hud._refresh_all()
	t.check("later_authentic_current_model_refresh_after_visual_fixture", hud.gold_label.text == hud.Fmt.thousands(rows[&"p0"].gold) and hud._entries == t.player().hotbar.entries())
	hud.free()
