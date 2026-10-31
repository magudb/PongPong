extends RefCounted
const SECTION := "tutorial_producer_origins"
const TIMEOUT_S := 180.0
const Runner := preload("res://scripts/farm/steading/tutorial/tutorial_runner.gd")

func run(t) -> void:
	await _successor(t, "talk")
	await _successor(t, "hold")
	await _successor(t, "attachment")

func _successor(t, mode: String) -> void:
	if not await t.start_world(): return
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	var world: Node = t.world()
	var body: Node = t.player()
	body.set_physics_process(true)
	var ui: Node = t.first(&"dialogue_ui")
	var session := Runner.new()
	session.world = world
	session.origin = EventBus.interaction_origin(&"p0")
	var entered: Array = []
	var actor_ref: Array = []
	var requests: Array = []
	var next_parent := Node2D.new()
	world.area.objects.add_child(next_parent)
	var listener := func(id, _payload):
		if id != &"tutorial_finished" or not entered.is_empty(): return
		entered.append(true)
		var actor: Variant = session.actors.get("postman_pip")
		if not is_instance_valid(actor): return
		actor_ref.append(weakref(actor))
		if mode == "talk":
			actor.interact(body)
			requests.append(ui._request)
		elif mode == "hold":
			actor.event_begin()
		else:
			actor.reparent(next_parent)
			actor.event_begin()
	EventBus.game_event.connect(listener)
	var done: Array = []
	_launch(session, done)
	t.check(mode + "_authored_initial_page", ui.is_open() and ui._speaker.get("id") == "postman_pip")
	t.tap_key(KEY_ESCAPE)
	await t.frames(8)
	EventBus.game_event.disconnect(listener)
	t.check(mode + "_authored_skip_completes_earned_model", entered == [true] and done == [true] and bool(GameManager.get_flag(&"first_morning_done", false)) and bool(GameManager.get_flag(&"intro_letter_seen", false)) and QuestManager.is_active(&"intro_lottery") and QuestManager.is_active(&"forste_dage"))
	var actor: Variant = actor_ref[0].get_ref() if actor_ref.size() == 1 else null
	t.check(mode + "_new_same_actor_survives_old_cleanup", is_instance_valid(actor) and actor.is_inside_tree() and not actor.is_queued_for_deletion())
	var talking: bool = is_instance_valid(actor) and actor.is_talking and actor._held
	var held: bool = is_instance_valid(actor) and actor._event and actor._held
	t.check(mode + "_successor_exact_authority_preserved", (talking and requests.size() == 1 and requests[0] != null and ui._request == requests[0] and requests[0].result.is_empty()) if mode == "talk" else (held and (mode != "attachment" or actor.get_parent() == next_parent)))
	# Every predicate is emitted on baseline as well as candidate. No repair of
	# actor state/timers: finish the actual successor through its real UI API.
	if mode == "talk" and requests.size() == 1 and requests[0] != null:
		ui.close_request(requests[0])
	elif is_instance_valid(actor):
		actor.event_end()
	await t.physics(3)
	t.check(mode + "_successor_terminal_releases_body", body.state == PlayerBody2D.S.FREE and not GameManager.is_modal_open())
	var before: Vector2 = body.global_position
	t.hold(&"move_left")
	await t.physics(8)
	t.release(&"move_left")
	await t.physics(2)
	t.check(mode + "_enabled_natural_body_progress", body.is_physics_processing() and body.global_position.distance_to(before) > 1)
	if is_instance_valid(actor): actor.queue_free()
	await t.go_menu()

func _launch(session: RefCounted, done: Array) -> void:
	await session.play()
	done.append(true)
