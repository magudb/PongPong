extends RefCounted
const SECTION := "new_game_issuer_occupancy"
const TIMEOUT_S := 150.0

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var saves: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	saves.autosave_enabled = false
	for boundary in ["reset_close", "flag", "character", "broadcast"]:
		var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
		var counts := {"flag":0, "character":0, "broadcast":0}
		var flags := func(key, _value):
			if key == &"mayor_welcome_pending" or key == gm.FLAG_INTRO_PENDING: counts.flag += 1
		var character := func(_pid, _skin): counts.character += 1
		var broadcast := func(): counts.broadcast += 1
		bus.flag_changed.connect(flags)
		bus.player_character_changed.connect(character)
		bus.new_game_started.connect(broadcast)
		var results: Array = []
		var armed := [true]
		var observer := func(_a = null, _b = null):
			if not armed[0]: return
			armed[0] = false
			results.append(_attempt(t, gm, saves, ui))
		if boundary == "reset_close":
			ui.request_page(t.player(), {"id":"player"}, [{"text_key":"DLG_HOPPE_HELLO"}], [], {"body":t.player()})
			t.check(boundary+"_real_page_open", ui.is_open())
			ui.closed.connect(observer, CONNECT_ONE_SHOT)
		elif boundary == "flag": bus.flag_changed.connect(observer, CONNECT_ONE_SHOT)
		elif boundary == "character": bus.player_character_changed.connect(observer, CONNECT_ONE_SHOT)
		else: bus.new_game_started.connect(observer, CONNECT_ONE_SHOT)
		var before_run: String = saves.run_id
		var accepted: Dictionary = gm.try_start_new_game("Parent "+boundary, gm.character_type, "Parent farm")
		bus.flag_changed.disconnect(flags)
		bus.player_character_changed.disconnect(character)
		bus.new_game_started.disconnect(broadcast)
		t.check(boundary+"_exact_current_helper_no_effect", results.size() == 1 and results[0].unchanged, str(results))
		t.check(boundary+"_public_busy_no_queue", results.size() == 1 and results[0].busy, str(results))
		t.check(boundary+"_one_reset_wave_and_metadata", accepted.ok and counts == {"flag":2,"character":1,"broadcast":1} and saves.run_id != before_run and gm.player_name == "Parent "+boundary, str(counts))
		t.check(boundary+"_reset_fence_balanced", not ui._resetting and ui._barrier == 0 and not ui.is_open() and not gm.lifecycle_busy(), str([ui._resetting,ui._barrier]))
		t.check(boundary+"_next_idle_root_progresses", gm.try_start_new_game("Next "+boundary,gm.character_type).ok and gm.player_name == "Next "+boundary and not gm.lifecycle_busy())
	# The admission callback runs before any reset mutation. It must not adopt
	# its parent's exact token and execute the entire body ahead of the issuer.
	var admitted: Array = []
	var counts := [0,0]
	var character := func(_pid,_skin): counts[0] += 1
	var broadcast := func(): counts[1] += 1
	bus.player_character_changed.connect(character)
	bus.new_game_started.connect(broadcast)
	var entry: Dictionary = gm.try_start_new_game_and_enter("Entry parent",gm.character_type,"Entry farm",&"",false,func():
		admitted.append(_attempt(t,gm,saves,t.tree.get_first_node_in_group("dialogue_ui")))
		t.go_to_neutral())
	bus.player_character_changed.disconnect(character)
	bus.new_game_started.disconnect(broadcast)
	t.check("admitted_exact_token_refused_before_first_reset", admitted.size() == 1 and admitted[0].unchanged and admitted[0].busy, str(admitted))
	t.check("entry_reset_wave_once", entry.ok and counts == [1,1] and gm.player_name == "Entry parent",str(counts))
	t.check("scene_request_holds_busy_after_return",gm.lifecycle_busy())
	await t.until(func(): return t.world() != null and t.world().ready_for_play,20.0)
	await t.frames(3)
	t.check("real_scene_ready_releases_issuer",t.world() != null and t.world().ready_for_play and t.player() != null and not gm.lifecycle_busy())
	# Attached-world adapter is another issuer of the same whole body.
	var attached_attempt: Array = []
	var attached: Dictionary = gm.try_start_new_game_attached(t.root,"Attached parent",gm.character_type,"Attached farm",&"",false,func(): attached_attempt.append(_attempt(t,gm,saves,t.tree.get_first_node_in_group("dialogue_ui"))))
	t.check("attached_tail_cannot_borrow_whole_body",attached.ok and attached_attempt.size() == 1 and attached_attempt[0].unchanged and attached_attempt[0].busy,str(attached_attempt))
	if attached.ok:
		var world: Node = attached.world
		await t.until(func():return world.ready_for_play and not gm.lifecycle_busy(),20.0)
		t.check("attached_genuine_bootstrap_and_release",world.ready_for_play and not gm.lifecycle_busy())
		world.free()
	await t.start_world()
	t.check("final_next_root_actual_healthy_world",t.world() != null and t.world().ready_for_play and t.player() != null and not gm.lifecycle_busy())

func _attempt(t,gm: Node,saves: Node,ui: Node) -> Dictionary:
	var token: RefCounted = gm.get("_lifecycle_token")
	var before := _state(gm,saves,ui)
	if gm.has_method("_start_new_game_owned"):
		gm._start_new_game_owned(token,"Nested exact token",gm.character_type,"Nested",gm.character_skin)
	var unchanged := before == _state(gm,saves,ui)
	var roots := [gm.try_start_new_game("Nested public",gm.character_type),gm.try_start_new_game_and_enter("Nested enter",gm.character_type),gm.try_start_new_game_attached(t.root,"Nested attached",gm.character_type)]
	return {"unchanged":unchanged and before == _state(gm,saves,ui),"busy":roots.all(func(r):return not r.ok and r.code == "busy"),"resetting_before":before.resetting,"resetting_after":ui._resetting if is_instance_valid(ui) else false}

func _state(gm: Node,saves: Node,ui: Node) -> Dictionary:
	return {"game":gm.to_dict(),"profile":PlayerRegistry.state(&"p0"),"run":saves.run_id,"slot":saves.current_slot,"pending":saves.pending_world.duplicate(true),"resetting":ui._resetting if is_instance_valid(ui) else false,"barrier":ui._barrier if is_instance_valid(ui) else 0}
