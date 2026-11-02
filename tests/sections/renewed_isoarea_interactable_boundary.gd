extends RefCounted
const SECTION := "renewed_isoarea_interactable_boundary"
const TIMEOUT_S := 120.0
# The actual built-in callee, not the fixture Enabled/Reader presentation stub.
# A failing suffix here requests the exact excluded production dependency.
func run(t)->void:
	await t.start_world()
	var gm:Node=t.autoload("GameManager")
	gm.clear_flag(&"intro_pending")
	gm.set_config_override("time.minutes_per_real_second",0.0)
	t.autoload("SaveManager").autosave_enabled=false
	gm.set_flag(&"zz_iso_real_callee",true)
	var a:=IsoArea.new()
	t.root.add_child(a)
	var target:=Interactable2D.new()
	a.add_child(target)
	a._track_when({"when":"flag:zz_iso_real_callee"},[target])
	await t.frames(2)
	var actual_area:Area2D=target._area
	var before_layer:int=actual_area.collision_layer
	var before_monitorable:bool=actual_area.monitorable
	var old:PlayerState=PlayerRegistry._states[&"p0"]
	t.check("real_interactable_ordinary_enabled_precondition",target.is_enabled() and target.visible and before_layer==Iso.LAYER_INTERACTABLE and before_monitorable)
	var seen:Array=[]
	var observer:=func():
		if target.visible:return
		seen.append([PlayerRegistry._acting_id,actual_area.collision_layer,actual_area.monitorable])
		PlayerRegistry.reset_states()
	target.visibility_changed.connect(observer)
	var restored:Array=[]
	PlayerRegistry.for_player(&"p1",func():
		gm.set_flag(&"zz_iso_real_callee",false)
		restored.append(PlayerRegistry._acting_id))
	target.visibility_changed.disconnect(observer)
	t.check("real_interactable_actual_visibility_callback_and_new_model",seen.size()==1 and seen[0].slice(1)==[before_layer,before_monitorable] and PlayerRegistry._states[&"p0"]!=old)
	t.check("real_interactable_old_callee_collision_suffix_refused",actual_area.collision_layer==before_layer,str({"callback":seen,"after_layer":actual_area.collision_layer,"expected":before_layer}))
	t.check("real_interactable_conflicting_caller_restored",restored==[&"p1"] and PlayerRegistry._acting_id==&"")
	await t.frames(2)
	t.check("real_interactable_old_callee_deferred_monitorable_suffix_refused",actual_area.monitorable==before_monitorable,str({"after_monitorable":actual_area.monitorable,"expected":before_monitorable}))
	a.free()
	gm.clear_config_overrides()
