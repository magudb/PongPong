extends RefCounted
const SECTION := "renewed_isoarea_model"
const TIMEOUT_S := 180.0
const GRAPH := preload("res://tests/sections/renewed_marker_refresh_model.gd")
const OLD := preload("res://tests/sections/persistence_marker_scope.gd")

func run(t) -> void:
	for populated in [false, true]:
		await _case(t, populated)
		await _loaded(t, populated)

func _loaded(t, populated: bool) -> void:
	await t.start_world()
	var gm: Node=t.autoload("GameManager")
	var qm: Node=t.autoload("QuestManager")
	var sm: Node=t.autoload("SaveManager")
	var eco: Node=t.autoload("EconomyManager")
	gm.clear_flag(&"intro_pending")
	gm.set_config_override("time.minutes_per_real_second",0.0)
	sm.autosave_enabled=false
	sm.save_dir="user://renewed_isoarea_loaded"
	var title: String=("existing" if populated else "absent")+"_loaded"
	qm.register_quest_from_lua({"id":"zz_isoarea_loaded","objectives":[{"id":"work","on":"manual","target":1}],"rewards":{},"meta":{}})
	t.check(title+"_real_p0_quest",qm.accept_quest(&"zz_isoarea_loaded"))
	if populated:
		PlayerRegistry.for_player(&"p1",func():
			eco.from_dict(eco.to_dict())
			qm.to_dict()
			eco.add_item(&"wood",7,true))
		PlayerRegistry._states[&"p1"].gold=713
	var oldworld: Node=t.world()
	var oldmodel: PlayerState=PlayerRegistry._states[&"p0"]
	var area: IsoArea=oldworld.area
	var quest:=Node2D.new()
	area.objects.add_child(quest)
	area._track_when({"when":"quest:zz_isoarea_loaded"},[quest])
	t.check(title+"_real_whole_disk_save",sm.save_game(0))
	var result: Array=[]
	PlayerRegistry.for_player(&"p1",func():
		result.append(sm.load_game(0))
		result.append(PlayerRegistry._acting_id))
	t.check(title+"_new_logical_model_without_physical_rebind",result==[true,&"p1"] and PlayerRegistry._acting_id==&"" and PlayerRegistry._states[&"p0"]!=oldmodel and oldworld._host_profile==oldmodel and not oldworld._host_live())
	var other: PlayerState=PlayerRegistry._states.get(&"p1") if populated else null
	if populated:
		other.max_half_hearts=38
		other.max_stamina=137.0
		other.max_oil=211.0
	var registry: Dictionary=PlayerRegistry._states
	var values: Dictionary=other.to_dict().duplicate(true) if populated else {}
	var graph: Array=[]
	if populated:GRAPH.new()._retain(other,graph)
	t.check(title+"_independent_complete_decoded_preimage",OLD.new()._unchanged(populated,other,values,graph,registry))
	quest.visible=false
	PlayerRegistry.for_player(&"p1",func():EventBus.quest_accepted.emit(&"p0",&"zz_isoarea_loaded"))
	t.check(title+"_raw_full_fanout_new_model_view",quest.visible and not oldworld._host_live())
	t.check(title+"_raw_full_fanout_entire_unrelated_values_and_aliases",OLD.new()._unchanged(populated,other,values,graph,registry))
	qm.update_objective(&"zz_isoarea_loaded",&"work",1)
	t.check(title+"_real_current_logical_quest_completion",qm.is_completed(&"zz_isoarea_loaded") and not quest.visible and not oldworld._host_live())
	await t.frames(3)
	t.check(title+"_later_complete_unrelated_graph_preserved",OLD.new()._unchanged(populated,other,values,graph,registry))
	quest.free()
	gm.clear_config_overrides()

func _case(t, populated: bool) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	gm.clear_flag(&"intro_pending")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	t.autoload("SaveManager").autosave_enabled = false
	var area: IsoArea = t.world().area
	var title := "existing" if populated else "absent"
	qm.register_quest_from_lua({"id":"zz_isoarea_model", "title_key":"HUD_SAVED", "objectives":[{"id":"work", "on":"manual", "target":2, "text_key":"HUD_SAVED"}], "rewards":{}, "meta":{}})
	t.check(title+"_real_p0_quest_admitted", qm.accept_quest(&"zz_isoarea_model"))
	var quest := Node2D.new()
	area.objects.add_child(quest)
	area._track_when({"when":"quest:zz_isoarea_model"}, [quest])
	var done := Node2D.new()
	area.objects.add_child(done)
	area._track_when({"when":"done:zz_isoarea_model"}, [done])
	var other: PlayerState
	if populated:
		other = PlayerRegistry.state(&"p1")
		PlayerRegistry.for_player(&"p1", func():
			eco.from_dict(eco.to_dict())
			qm.to_dict()
			eco.add_item(&"wood", 7, true))
		other.name = "Independent complete IsoArea caller"
		other.gold = 713
		other.max_half_hearts = 38
		other.max_stamina = 137.0
		other.max_oil = 211.0
	var registry: Dictionary = PlayerRegistry._states
	var values: Dictionary = other.to_dict().duplicate(true) if populated else {}
	var graph: Array = []
	if populated: GRAPH.new()._retain(other, graph)
	t.check(title+"_authenticated_whole_unrelated_preimage", OLD.new()._unchanged(populated, other, values, graph, registry))
	var restored: Array = []
	# The real signal, every registered consumer, no filtering/disconnection,
	# no producer/reader substitute and no pre-created absent caller.
	PlayerRegistry.for_player(&"p1", func():
		EventBus.quest_accepted.emit(&"p0", &"zz_isoarea_model")
		restored.append(PlayerRegistry._acting_id))
	t.check(title+"_raw_public_complete_fanout_whole_profile_and_aliases", OLD.new()._unchanged(populated, other, values, graph, registry))
	t.check(title+"_raw_public_complete_fanout_p0_scenery", quest.visible and not done.visible)
	t.check(title+"_raw_public_complete_fanout_caller_restored", restored == [&"p1"] and PlayerRegistry._acting_id == &"")
	await t.frames(3)
	t.check(title+"_raw_public_later_whole_profile_and_aliases", OLD.new()._unchanged(populated, other, values, graph, registry))
	qm.update_objective(&"zz_isoarea_model", &"work", 1)
	t.check(title+"_ordinary_p0_objective_progress", qm.get_objective_progress(&"zz_isoarea_model", &"work").get("current") == 1)
	qm.update_objective(&"zz_isoarea_model", &"work", 1)
	t.check(title+"_ordinary_p0_completion_and_scenery", qm.is_completed(&"zz_isoarea_model") and not quest.visible and done.visible)
	quest.free()
	done.free()
	gm.clear_config_overrides()
