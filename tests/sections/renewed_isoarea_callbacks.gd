extends RefCounted
const SECTION := "renewed_isoarea_callbacks"
const TIMEOUT_S := 180.0

class Enabled extends Node2D:
	var calls: Array=[]
	var action: Callable
	func set_enabled(on:bool)->void:
		calls.append([on,PlayerRegistry._acting_id])
		if action.is_valid(): action.call()

func run(t)->void:
	for kind in ["replace","fresh","detach","roundtrip","transfer","queued","destroyed"]:
		await _boundary(t,kind)
	await _enabled_boundary(t)
	await _publication(t)
	await _staged(t)

func _enabled_boundary(t)->void:
	await t.start_world()
	var gm:Node=t.autoload("GameManager")
	gm.clear_flag(&"intro_pending")
	gm.set_config_override("time.minutes_per_real_second",0.0)
	t.autoload("SaveManager").autosave_enabled=false
	var a:=IsoArea.new()
	t.root.add_child(a)
	var first:=Enabled.new()
	var tail:=Enabled.new()
	var glow:=Node2D.new()
	a.add_child(first);a.add_child(tail);a.add_child(glow)
	a._glows.append({"node":glow,"base":1.0})
	a._track_when({"when":"flag:zz_iso_enabled"},[first,tail])
	first.calls.clear();tail.calls.clear()
	var fired:Array=[]
	first.action=func():
		if not fired.is_empty():return
		fired.append(PlayerRegistry._acting_id)
		PlayerRegistry.reset_states()
	PlayerRegistry.for_player(&"p1",func():a.on_enter())
	t.check("enabled_real_set_enabled_callback_reached",fired==[&"p0"])
	t.check("enabled_old_loop_tail_refused_after_replacement",first.calls==[[false,&"p0"]] and tail.calls.is_empty())
	t.check("enabled_on_enter_trailing_night_keeps_exact_origin",glow.visible and glow.modulate.a==1.0)
	first.action=Callable()
	a.on_enter()
	t.check("enabled_independent_successor_root_progress",tail.calls==[[false,&"p0"]] and not glow.visible and PlayerRegistry._acting_id==&"")
	a.free()
	gm.clear_config_overrides()

func _boundary(t,kind:String)->void:
	await t.start_world()
	var gm:Node=t.autoload("GameManager")
	gm.clear_flag(&"intro_pending")
	gm.set_config_override("time.minutes_per_real_second",0.0)
	t.autoload("SaveManager").autosave_enabled=false
	gm.set_flag(&"zz_iso_boundary",true)
	var a:=IsoArea.new()
	t.root.add_child(a)
	var first:=StaticBody2D.new()
	var tail:=Enabled.new()
	var elsewhere:=Node2D.new()
	t.root.add_child(elsewhere)
	a.add_child(first);a.add_child(tail)
	a._track_when({"when":"flag:zz_iso_boundary"},[first,tail])
	first.collision_layer=31
	first.process_mode=Node.PROCESS_MODE_ALWAYS
	tail.calls.clear()
	var old:PlayerState=PlayerRegistry._states[&"p0"]
	var fired:Array=[]
	var victim_ref:WeakRef=weakref(tail)
	var callback:=func():
		if first.visible or not fired.is_empty():return
		fired.append([PlayerRegistry._acting_id,kind])
		match kind:
			"replace":PlayerRegistry.reset_states()
			"fresh":gm.set_flag(&"zz_iso_boundary",true)
			"detach":t.root.remove_child(a)
			"roundtrip":
				t.root.remove_child(a)
				t.root.add_child(a)
			"transfer":
				a.remove_child(tail)
				elsewhere.add_child(tail)
			"queued":tail.queue_free()
			"destroyed":tail.free() # a different idle sibling, not the executing/emitting node
	first.visibility_changed.connect(callback)
	var restored:Array=[]
	PlayerRegistry.for_player(&"p1",func():
		gm.set_flag(&"zz_iso_boundary",false)
		restored.append(PlayerRegistry._acting_id))
	t.check(kind+"_real_visibility_callback_reached",fired==[[&"p0",kind]],str(fired))
	t.check(kind+"_conflicting_caller_restored",restored==[&"p1"] and PlayerRegistry._acting_id==&"")
	match kind:
		"replace":
			t.check(kind+"_exact_new_model_not_old_body",PlayerRegistry._states[&"p0"]!=old and t.world()._host_profile==old and not t.world()._host_live())
			t.check(kind+"_old_visibility_suffix_and_tail_refused",first.process_mode==Node.PROCESS_MODE_ALWAYS and first.collision_layer==31 and tail.calls.is_empty())
			t.check(kind+"_successor_quest_containers_not_lazily_created",PlayerRegistry._states[&"p0"].quests.is_empty())
		"fresh":
			t.check(kind+"_new_root_wins_entire_suffix",first.visible and first.process_mode==Node.PROCESS_MODE_INHERIT and first.collision_layer==31 and tail.calls==[[true,&"p0"]],str(tail.calls))
		"detach":
			t.check(kind+"_detached_stack_cannot_mutate_suffix_or_tail",not a.is_inside_tree() and first.process_mode==Node.PROCESS_MODE_ALWAYS and first.collision_layer==31 and tail.calls.is_empty())
		"roundtrip":
			t.check(kind+"_reattached_old_stack_stays_revoked",a.is_inside_tree() and first.process_mode==Node.PROCESS_MODE_ALWAYS and first.collision_layer==31 and tail.calls.is_empty())
		"transfer":
			t.check(kind+"_exact_old_target_attachment_retained",tail.get_parent()==elsewhere and tail.calls.is_empty())
		"queued":
			t.check(kind+"_queued_lifetime_refused_before_real_free",tail.is_queued_for_deletion() and tail.calls.is_empty())
		"destroyed":t.check(kind+"_actual_idle_sibling_destruction",victim_ref.get_ref()==null)
	first.visibility_changed.disconnect(callback)
	if kind=="detach":t.root.add_child(a)
	# An independently admitted current operation still works after the refusal.
	if kind not in ["queued","destroyed","transfer"]:
		tail.calls.clear()
		gm.set_flag(&"zz_iso_boundary",true)
		a.refresh_when()
		t.check(kind+"_independent_current_root_progress",first.visible and first.collision_layer==31 and not tail.calls.is_empty() and tail.calls.all(func(v):return v==[true,&"p0"]))
	await t.frames(2)
	if kind=="queued":t.check(kind+"_natural_destruction_settled",victim_ref.get_ref()==null)
	a.free();elsewhere.free()
	gm.clear_config_overrides()

func _publication(t)->void:
	await t.start_world()
	var gm:Node=t.autoload("GameManager")
	gm.clear_flag(&"intro_pending")
	gm.set_config_override("time.minutes_per_real_second",0.0)
	t.autoload("SaveManager").autosave_enabled=false
	gm.set_flag(&"zz_iso_publication",true)
	var w:Node=t.world()
	var a:IsoArea=w.area
	var first:=StaticBody2D.new()
	var tail:=Enabled.new()
	a.objects.add_child(first);a.objects.add_child(tail)
	a._track_when({"when":"flag:zz_iso_publication"},[first,tail])
	first.process_mode=Node.PROCESS_MODE_ALWAYS
	first.collision_layer=29
	tail.calls.clear()
	var seen:Array=[]
	var callback:=func():
		if not first.visible:
			seen.append(PlayerRegistry._acting_id)
			w.area=null
	first.visibility_changed.connect(callback)
	PlayerRegistry.for_player(&"p1",func():gm.set_flag(&"zz_iso_publication",false))
	t.check("publication_actual_visibility_boundary",seen==[&"p0"] and w.area==null)
	t.check("publication_old_model_still_current_but_attachment_revoked",PlayerRegistry._states[&"p0"]==w._host_profile and first.process_mode==Node.PROCESS_MODE_ALWAYS and first.collision_layer==29 and tail.calls.is_empty())
	first.visibility_changed.disconnect(callback)
	w.area=a
	gm.set_flag(&"zz_iso_publication",true)
	t.check("publication_independent_exact_reattached_root_progress",first.visible and not tail.calls.is_empty() and tail.calls.all(func(v):return v==[true,&"p0"]))
	first.free();tail.free()
	gm.clear_config_overrides()

func _staged(t)->void:
	await t.start_world()
	var gm:Node=t.autoload("GameManager")
	gm.clear_flag(&"intro_pending")
	gm.set_config_override("time.minutes_per_real_second",0.0)
	t.autoload("SaveManager").autosave_enabled=false
	var w:Node=t.world()
	var previous:IsoArea=w.area
	var staged:=IsoArea.new()
	w.area=null
	w.holder.add_child(staged)
	var reader:=Enabled.new()
	staged.add_child(reader)
	gm.set_flag(&"zz_iso_staged",true)
	var restored:Array=[]
	PlayerRegistry.for_player(&"p1",func():
		staged._track_when({"when":"flag:zz_iso_staged"},[reader])
		staged.on_enter()
		restored.append(PlayerRegistry._acting_id))
	t.check("staged_actual_set_enabled_before_area_publication",reader.calls==[[true,&"p0"],[true,&"p0"]] and restored==[&"p1"] and not PlayerRegistry._states.has(&"p1"))
	w.area=previous
	staged.free()
	# A real production cache departure/re-entry, no manual physical rebinding.
	t.check("staged_real_world_enter_hyggebyen",w._enter(&"hyggebyen",&"default"))
	t.check("staged_real_world_cached_farm_return",w.is_parked(&"farm") and w._enter(&"farm",&"default") and w.area==previous and w._host_live())
	gm.clear_config_overrides()
