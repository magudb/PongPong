extends RefCounted
const SECTION := "event_camera_ownership"
const TIMEOUT_S := 180.0
const NPC := "gardener_hoppe"

func _relationship(n: Npc2D, out: Array) -> void:
	out.append(await RelationshipFlow.play_scene(NPC,{"relationship":1},weakref(n)))
func _play(r: SocialEventRunner,id: String,definition: Dictionary,out: Array) -> void:
	out.append(await r.play(id,definition))
func _citizen(t) -> Npc2D:
	var n := Npc2D.create({"id":NPC,"guest":true,"wander":"0"})
	n.area = t.world().area
	t.world().area.objects.add_child(n)
	n.global_position = t.player().global_position + Vector2(180,70)
	return n
func _definition(flag: String = "") -> Dictionary:
	var steps: Array = [{"act":"camera","target":NPC,"zoom":0.9,"seconds":0.01},{"act":"say","who":NPC,"text_key":"DLG_HOPPE_HELLO"}]
	if flag != "": steps.append({"act":"flag","key":flag})
	steps.append({"act":"end"})
	return {"meta":{"trigger":"automatic","npc":NPC},"steps":steps}
func _confirms(node: Node) -> Array:
	var out: Array = []
	if node is UiConfirm: out.append(node)
	for child in node.get_children(): out.append_array(_confirms(child))
	return out
func _clean(p: Player2D,zoom: Vector2) -> bool:
	return p.camera.offset.is_zero_approx() and p.camera.zoom.is_equal_approx(zoom)
func _setup(t) -> void:
	await t.start_world()
	t.autoload("SaveManager").autosave_enabled = false
	t.autoload("GameManager").set_config_override("time.minutes_per_real_second",0.0)

func run(t) -> void:
	await _setup(t)
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SocialManager")
	var r: SocialEventRunner = sm.get_node("EventDirector").runner
	var n := _citizen(t)
	var p: Player2D = t.player()
	var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
	var resolver := func(id):return p if id == "player" else n
	r.actor_resolver = resolver
	var zoom: Vector2 = p.camera.zoom
	var out: Array = []
	var finished: Array = []
	var ended := func(id,skipped):finished.append([id,skipped])
	r.finished.connect(ended)
	_relationship(n,out)
	await t.until(func():return ui.is_open(),5.0)
	t.check("relationship_real_authored_camera_before_page",r.active == "ev_relationship_gardener_hoppe_1" and ui.is_open() and not p.camera.offset.is_zero_approx() and not p.camera.zoom.is_equal_approx(zoom),str([p.camera.offset,p.camera.zoom,zoom]))
	await t.tap(&"ui_cancel")
	await t.frames(3)
	var confirms := _confirms(t.root)
	t.check("input_cancel_opens_skip_confirm_with_continue_focus",confirms.size() == 1 and confirms[0].get_node("%CancelButton").has_focus() and gm.top_modal() == &"confirm")
	t.tap_key(KEY_ENTER)
	await t.frames(3)
	t.check("input_continue_preserves_focused_scene",out.is_empty() and r.active != "" and ui.is_open() and not p.camera.offset.is_zero_approx())
	await t.tap(&"ui_cancel")
	await t.frames(3)
	confirms = _confirms(t.root)
	if confirms.size() == 1:
		confirms[0].get_node("%OkButton").grab_focus()
		t.tap_key(KEY_ENTER)
	await t.until(func():return not out.is_empty(),5.0)
	t.check("authored_input_skip_finishes_and_stamps_once",out == [true] and finished == [["ev_relationship_gardener_hoppe_1",true]] and sm.event_stamp("ev_relationship_gardener_hoppe_1") == 1,str([out,finished]))
	t.check("authored_skip_restores_nondefault_offset_and_zoom",_clean(p,zoom),str([p.camera.offset,p.camera.zoom,zoom]))
	t.check("authored_skip_cleans_holds_and_modals",not p._event_active and not n._event and not ui.is_open() and not gm.is_modal_open())
	t.check("relationship_exact_resolver_restored",r.actor_resolver == resolver)
	var again: bool = await RelationshipFlow.play_scene(NPC,{"relationship":1},weakref(n))
	t.check("authored_seen_refusal_has_no_second_effect",not again and finished.size() == 1 and r.actor_resolver == resolver)
	r.finished.disconnect(ended)
	r.actor_resolver = Callable()
	n.free()
	# Distinct normal close, explicit abort, authored skip and model invalidation.
	for mode in ["normal_close","owned_cancel","skip","model_abort","body_departure","runner_exit"]:
		await _setup(t)
		n = _citizen(t)
		p = t.player()
		ui = t.tree.get_first_node_in_group("dialogue_ui")
		r = SocialEventRunner.new()
		t.world().add_child(r)
		r.actor_resolver = func(id):return p if id == "player" else n
		zoom = p.camera.zoom
		out = []
		var flag: String = "camera_effect_"+mode
		var flag_count := [0]
		var flag_observer := func(key,_value):
			if str(key) == flag: flag_count[0] += 1
		t.autoload("EventBus").flag_changed.connect(flag_observer)
		_play(r,"camera_"+mode,_definition(flag),out)
		await t.until(func():return ui.is_open(),5.0)
		t.check(mode+"_real_focus_and_hold_before_cleanup",ui.is_open() and p._event_active and n._event and not p.camera.offset.is_zero_approx() and not p.camera.zoom.is_equal_approx(zoom))
		var body_parent: Node = p.get_parent()
		if mode == "normal_close": ui.close()
		elif mode == "owned_cancel": ui.close_owned(r._ticket)
		elif mode == "skip": r.skip()
		elif mode == "body_departure": p.get_parent().remove_child(p)
		elif mode == "model_abort":
			PlayerRegistry.reset_states()
			ui.close()
		else: t.world().remove_child(r)
		await t.until(func():return not out.is_empty(),5.0)
		t.autoload("EventBus").flag_changed.disconnect(flag_observer)
		var earned: bool = mode in ["normal_close","skip"]
		t.check(mode+"_camera_restored",_clean(p,zoom),str([p.camera.offset,p.camera.zoom,zoom]))
		t.check(mode+"_exact_effect_and_seen_multiplicity",out == [earned] and flag_count[0] == (1 if earned else 0) and sm.event_seen("camera_"+mode) == earned,str([out,flag_count]))
		t.check(mode+"_holds_and_modal_cleanup",not p._event_active and not n._event and not ui.is_open() and not gm.is_modal_open(&"event"))
		r.free()
		n.free()
		if not p.is_inside_tree(): body_parent.add_child(p)
	# Cancellation at the normal camera-return await must retain the full hold
	# set until it can be retired, even if the runner is destroyed immediately.
	await _setup(t)
	p = t.player()
	n = _citizen(t)
	ui = t.tree.get_first_node_in_group("dialogue_ui")
	r = SocialEventRunner.new()
	t.world().add_child(r)
	r.actor_resolver = func(id):return p if id == "player" else n
	zoom = p.camera.zoom
	out = []
	_play(r,"camera_release_exit",_definition(),out)
	await t.until(func():return ui.is_open(),5.0)
	ui.close()
	t.check("normal_return_await_is_active_before_exit",r.active != "" and p._event_active and n._event and p._camera_tween != null and p._camera_tween.is_running())
	r.free()
	await t.frames(3)
	t.check("normal_return_tree_exit_restores_camera",_clean(p,zoom))
	t.check("normal_return_tree_exit_retires_all_exact_holds",not p._event_active and not n._event and not gm.is_modal_open(&"event"))
	n.free()
	# A close observer installs a successor on the SAME runner/body/modal name.
	# Old camera cleanup must have happened before that callback can run.
	await _setup(t)
	p = t.player()
	n = _citizen(t)
	ui = t.tree.get_first_node_in_group("dialogue_ui")
	r = SocialEventRunner.new()
	t.world().add_child(r)
	r.actor_resolver = func(id):return p if id == "player" else n
	zoom = p.camera.zoom
	out = []
	_play(r,"camera_old",_definition("camera_old_effect"),out)
	await t.until(func():return ui.is_open(),5.0)
	var winner: Array = []
	var closed: Array = []
	ui.closed.connect(func():
		closed.append(_clean(p,zoom))
		r.cancel()
		_play(r,"camera_successor",_definition("camera_successor_effect"),winner),CONNECT_ONE_SHOT)
	r.skip()
	await t.until(func():return ui.is_open() and r.active == "camera_successor",5.0)
	t.check("old_camera_restored_before_close_observer",closed == [true],str(closed))
	t.check("old_skip_cannot_restore_or_end_successor_camera_hold",r.active == "camera_successor" and p._event_active and n._event and not p.camera.offset.is_zero_approx() and not p.camera.zoom.is_equal_approx(zoom))
	t.check("old_skip_preserves_successor_same_modal_page",ui.is_open() and gm.is_modal_open(&"event") and gm.top_modal() == &"dialogue" and winner.is_empty())
	t.check("stale_abort_cannot_release_successor",not r._abort(r._generation-1) and r.active == "camera_successor" and p._event_active and gm.is_modal_open(&"event"))
	r.skip()
	await t.until(func():return not winner.is_empty(),5.0)
	t.check("successor_can_finish_and_restore_own_camera",winner == [true] and _clean(p,zoom) and not p._event_active and not n._event and not gm.is_modal_open())
	t.check("successor_effect_seen_once",sm.event_seen("camera_successor") and bool(gm.get_flag(&"camera_successor_effect",false)))
	r.free()
	n.free()
	# Independent owners may replace actor holds and the event modal without
	# adopting this runner. Its stale cancel must not touch their camera.
	await _setup(t)
	p = t.player()
	n = _citizen(t)
	ui = t.tree.get_first_node_in_group("dialogue_ui")
	r = SocialEventRunner.new()
	t.world().add_child(r)
	r.actor_resolver = func(id):return p if id == "player" else n
	out = []
	_play(r,"camera_external_old",_definition(),out)
	await t.until(func():return ui.is_open(),5.0)
	var player_hold := RefCounted.new()
	var npc_hold := RefCounted.new()
	var modal := RefCounted.new()
	p.event_begin_owned(player_hold)
	n.event_begin_owned(npc_hold)
	gm.push_modal_owned(&"event",false,modal)
	await p.camera_focus(p.global_position+Vector2(90,35),0.6,0.01)
	var offset: Vector2 = p.camera.offset
	zoom = p.camera.zoom
	r.cancel()
	await t.frames(3)
	t.check("cancel_preserves_independent_actor_camera_owner",p.event_hold_current(player_hold) and n.event_hold_current(npc_hold) and p.camera.offset.is_equal_approx(offset) and p.camera.zoom.is_equal_approx(zoom))
	t.check("cancel_preserves_independent_same_name_modal",gm.is_modal_open(&"event"))
	p.camera_release(0.0)
	p.event_end_owned(player_hold)
	n.event_end_owned(npc_hold)
	gm.pop_modal_owned(&"event",modal)
	r.free()
	n.free()
