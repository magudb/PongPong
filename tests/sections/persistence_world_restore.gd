extends RefCounted
const SECTION := "persistence_world_restore"
const TIMEOUT_S := 180.0

func run(t) -> void:
	await t.start_world()
	var sm: Node = t.autoload("SaveManager")
	sm.autosave_enabled = false
	var bus: Node = t.autoload("EventBus")
	var w: Node = t.world()
	var applied := []
	var on_applied := func(): applied.append(true)
	w.state_applied.connect(on_applied)
	var data: Dictionary = w.to_dict()
	t.check("PB14_real_body_present_roundtrip_positive", w.try_from_dict(data).ok and applied == [true])
	applied.clear()
	var departed := []
	var on_hotbar := func(pid, _slots, _selected):
		if pid == &"p0" and departed.is_empty(): departed.append(w._unregister_player(w.player))
	bus.hotbar_changed.connect(on_hotbar)
	var result: Dictionary = w.try_from_dict(data)
	bus.hotbar_changed.disconnect(on_hotbar)
	w.state_applied.disconnect(on_applied)
	t.check("PB14_callback_departure_refuses_stale_restore_suffix", not result.ok and w.player == null and applied.is_empty() and departed == [&"p0"])
	await t.start_world()
	w = t.world()
	var old: Node2D = w.player
	var old_ref: WeakRef = weakref(old)
	var pos: Vector2 = old.global_position + Vector2(5, 2)
	var next: Node2D = w._make_player()
	var replacements := []
	var on_exit := func():
		w._register_player(next, 0, 1)
		w.add_child(next)
		replacements.append(next.get_instance_id())
	var notices := []
	var on_departure := func(pid): notices.append(pid)
	bus.player_despawned.connect(on_departure)
	old.tree_exiting.connect(on_exit, CONNECT_ONE_SHOT)
	w._unregister_player(old)
	next.enter_area(w.area, pos)
	next.set_physics_process(false)
	bus.player_despawned.disconnect(on_departure)
	t.check("PB06_real_tree_exit_reentry_preserves_new_attachment", replacements == [next.get_instance_id()] and w.player == next and w.player_by_peer_id(1) == next and notices.is_empty())
	await t.frames(3)
	t.check("PB06_old_body_actually_destroyed_successor_save_healthy", old_ref.get_ref() == null and w.persistence_ready() and sm.gather_payload().world.player_pos == [pos.x, pos.y])
	w._unregister_player(next)
	t.check("PB06_successor_later_departure_checkpoint_healthy", w.persistence_ready() and sm.gather_payload().world.player_pos == [pos.x, pos.y])
