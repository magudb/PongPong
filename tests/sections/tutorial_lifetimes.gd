extends RefCounted
const SECTION := "tutorial_lifetimes"
const TIMEOUT_S := 60.0
const Runner := preload("res://scripts/farm/steading/tutorial/tutorial_runner.gd")

func run(t) -> void:
	if not await t.start_world(): return
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	var session := Runner.new()
	session.world = t.world()
	session.origin = EventBus.interaction_origin(&"p0")
	session._area_ref = weakref(t.world().area)
	t.check("tutorial_attached_area_positive", session._good())
	var area: Node = t.world().area
	var parent: Node = area.get_parent()
	parent.remove_child(area)
	t.check("tutorial_retained_detached_area_refuses", not session._good())
	session._enter("postman_pip", "pip_mailbox")
	t.check("tutorial_detached_area_no_new_actor", session.actors.is_empty())
	parent.add_child(area)
	for actor in session.actors.values():
		if is_instance_valid(actor): actor.queue_free()
	session.actors.clear()
	await t.frames(2)
	t.check("tutorial_current_reattached_root_positive", session._good())
	# Actual dangling Dictionary reference reaches the production receiving local.
	var expired: Variant = Npc2D.create({"id":"postman_pip", "wander":"0", "guest":true})
	session.actors["postman_pip"] = expired
	expired.free()
	await session._leave("postman_pip", "warp")
	t.check("tutorial_freed_actor_receiving_refuses_without_dispatch", not is_instance_valid(session.actors.get("postman_pip")))
	session.actors.clear()
	session._enter("postman_pip", "pip_mailbox")
	var current: Variant = session.actors.get("postman_pip")
	t.check("tutorial_next_actual_actor_entry", is_instance_valid(current) and current.is_inside_tree() and current._event)
	if is_instance_valid(current): current.queue_free()
	session.actors.clear()
	await t.go_menu()
