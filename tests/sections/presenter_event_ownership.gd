extends RefCounted
const SECTION := "presenter_event_ownership"
const TIMEOUT_S := 120.0
func setup(t) -> void:
	await t.start_world()
	t.autoload("SaveManager").autosave_enabled = false
	t.autoload("GameManager").set_config_override("time.minutes_per_real_second", 0.0)
func runner(t) -> SocialEventRunner:
	var r := SocialEventRunner.new()
	t.world().add_child(r)
	return r
func citizen(t) -> Npc2D:
	var n := Npc2D.create({"id":"gardener_hoppe", "guest":true, "wander":"0"})
	n.area = t.world().area
	t.world().area.objects.add_child(n)
	return n
func run(t) -> void:
	await setup(t)
	var r := runner(t)
	var n := citizen(t)
	r.actor_resolver = func(id): return t.player() if id == "player" else n
	var bus: Node = t.autoload("EventBus")
	var gm: Node = t.autoload("GameManager")
	var changed: Array = []
	var replace := func(key, _value):
		if key == &"event_hold_abort" and changed.is_empty():
			changed.append(true)
			PlayerRegistry.reset_states()
	bus.flag_changed.connect(replace)
	await r.play("hold_abort", {"meta":{"npc":"gardener_hoppe"}, "steps":[{"act":"flag","key":"event_hold_abort"}]})
	bus.flag_changed.disconnect(replace)
	t.check("abort_releases_original_player_hold", changed.size() == 1 and not t.player()._event_active)
	t.check("abort_releases_original_npc_hold", not n._event)
	t.check("abort_releases_busy_modal", r.active == "" and not gm.is_modal_open(&"event"))
	r.free()
	n.free()
	await setup(t)
	r = runner(t)
	n = citizen(t)
	r.actor_resolver = func(id): return t.player() if id == "player" else n
	var newer: Array = []
	var acquire := func(key, _value):
		if key == &"event_hold_newer" and newer.is_empty():
			newer.append(true)
			t.player().event_begin()
			n.event_begin()
	bus.flag_changed.connect(acquire)
	await r.play("hold_newer", {"meta":{"npc":"gardener_hoppe"}, "steps":[{"act":"flag","key":"event_hold_newer"}]})
	bus.flag_changed.disconnect(acquire)
	t.check("old_release_preserves_newer_player_hold", newer.size() == 1 and t.player()._event_active)
	t.check("old_release_preserves_newer_npc_hold", n._event)
	t.player().event_end()
	n.event_end()
	r.free()
	n.free()
	await setup(t)
	r = runner(t)
	var swapped: Array = []
	var modal_replace := func(_stack):
		if gm.is_modal_open(&"event") and swapped.is_empty():
			swapped.append(true)
			PlayerRegistry.reset_states()
			gm.pop_modal(&"event")
			gm.push_modal(&"event", false)
	bus.modal_changed.connect(modal_replace)
	await r.play("modal_replace", {"steps":[{"act":"end"}]})
	bus.modal_changed.disconnect(modal_replace)
	t.check("abort_does_not_pop_same_name_replacement_modal", swapped.size() == 1 and gm.is_modal_open(&"event"))
	gm.pop_modal(&"event")
	r.free()
	await setup(t)
	r = runner(t)
	n = citizen(t)
	r.actor_resolver = func(id): return t.player() if id == "player" else n
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	r.play("old_skip", {"meta":{"npc":"gardener_hoppe"}, "steps":[{"act":"say","who":"gardener_hoppe","text_key":"DLG_HOPPE_HELLO"}]})
	await t.frames(2)
	t.check("skip_reentry_real_old_page", ui.is_open() and r.active == "old_skip")
	ui.closed.connect(func():
		r.cancel()
		r.play("new_after_close", {"meta":{"npc":"gardener_hoppe"}, "steps":[{"act":"wait","seconds":1.0}]}), CONNECT_ONE_SHOT)
	r.skip()
	await t.frames(2)
	t.check("old_skip_preserves_reentrant_new_runner_holds", r.active == "new_after_close" and n._event and t.player()._event_active)
	t.check("old_skip_preserves_reentrant_new_modal", gm.is_modal_open(&"event"))
	r.cancel()
	r.free()
	n.free()
