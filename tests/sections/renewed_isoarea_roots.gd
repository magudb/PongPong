extends RefCounted
const SECTION := "renewed_isoarea_roots"
const TIMEOUT_S := 180.0
const GRAPH := preload("res://tests/sections/renewed_marker_refresh_model.gd")
const OLD := preload("res://tests/sections/persistence_marker_scope.gd")

class Reader extends Node2D:
	var observed: Array = []
	func set_enabled(on: bool) -> void:
		var qm: Node = Svc.node("QuestManager")
		observed.append([on, PlayerRegistry._acting_id, qm.is_active(&"zz_iso_roots")])

func run(t) -> void:
	for populated in [false,true]: await _roots(t,populated)
	await _calendar(t)

func _roots(t, populated: bool) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	gm.clear_flag(&"intro_pending")
	gm.set_config_override("time.minutes_per_real_second",0.0)
	t.autoload("SaveManager").autosave_enabled = false
	qm.register_quest_from_lua({"id":"zz_iso_roots","objectives":[{"id":"work","on":"manual","target":2}],"rewards":{},"meta":{}})
	t.check(_tag(populated)+"_genuine_p0_quest",qm.accept_quest(&"zz_iso_roots"))
	gm.set_flag(&"zz_iso_roots",true)
	var a := IsoArea.new()
	var reader := Reader.new()
	a.add_child(reader)
	t.root.add_child(a)
	a._track_when({"when":"quest:zz_iso_roots&flag:zz_iso_roots"},[reader])
	var other: PlayerState
	if populated:
		other = PlayerRegistry.state(&"p1")
		PlayerRegistry.for_player(&"p1",func():
			eco.from_dict(eco.to_dict())
			qm.to_dict()
			eco.add_item(&"wood",7,true))
		other.gold=713
		other.max_half_hearts=38
		other.max_stamina=137.0
		other.max_oil=211.0
	var registry: Dictionary=PlayerRegistry._states
	var before: Dictionary=other.to_dict().duplicate(true) if populated else {}
	var graph: Array=[]
	if populated: GRAPH.new()._retain(other,graph)
	t.check(_tag(populated)+"_complete_preimage",OLD.new()._unchanged(populated,other,before,graph,registry))
	for root in ["refresh","delegated","apply","track","quest","day","clock","flag","friend","game","enter","attachment"]:
		reader.observed.clear()
		var restored: Array=[]
		PlayerRegistry.for_player(&"p1",func():
			match root:
				"refresh":a.refresh_when()
				"delegated":a._refresh_delegated()
				"apply":a._apply_when(a._when_nodes[0])
				"track":a._track_when({"when":"quest:zz_iso_roots&flag:zz_iso_roots"},[reader])
				"quest":a._on_quest_event(&"p1",&"zz_iso_roots")
				"day":a._on_day_event(1,&"foraar")
				"clock":a._on_clock_event(24,0)
				"flag":a._on_flag_event(&"zz_iso_roots",true)
				"friend":a._on_friend_event(&"p1",&"baker_maja",4)
				"game":a._on_game_event(&"routine_changed",{})
				"enter":a.on_enter()
				"attachment":
					a.map=AreaMap.parse_text("@id zz_isoroots\n@ground\n.\n")
					t.root.remove_child(a)
					t.root.add_child(a)
			restored.append(PlayerRegistry._acting_id))
		t.check(_tag(populated)+"_"+root+"_actual_set_enabled_and_real_reader_p0",not reader.observed.is_empty() and reader.observed.all(func(v):return v==[true,&"p0",true]),str(reader.observed))
		t.check(_tag(populated)+"_"+root+"_whole_unrelated_values_and_aliases",OLD.new()._unchanged(populated,other,before,graph,registry))
		t.check(_tag(populated)+"_"+root+"_caller_restored",restored==[&"p1"] and PlayerRegistry._acting_id==&"")
	# Static API is intentionally NOT an environmental host reader.
	var ordinary: Array=[]
	PlayerRegistry.for_player(&"p1",func():ordinary.append(IsoArea.evaluate_when("quest:zz_iso_roots")))
	t.check(_tag(populated)+"_static_evaluator_retains_ordinary_caller",ordinary==[false])
	a.free()
	gm.clear_config_overrides()

func _calendar(t) -> void:
	await t.start_world()
	var gm: Node=t.autoload("GameManager")
	gm.clear_flag(&"intro_pending")
	gm.set_config_override("time.minutes_per_real_second",0.0)
	t.autoload("SaveManager").autosave_enabled=false
	var a:=IsoArea.new()
	t.root.add_child(a)
	var night:=Node2D.new()
	var flag:=Node2D.new()
	var hour:=Node2D.new()
	a.add_child(night);a.add_child(flag);a.add_child(hour)
	gm.hour=12;gm.minute=0
	a._track_when({"when":"night"},[night])
	a._track_when({"when":"flag:zz_iso_calendar"},[flag])
	a._track_when({"when":"hour:24-25"},[hour])
	t.check("calendar_day_and_old_kind_initial",not night.visible and not flag.visible and not hour.visible)
	gm.set_flag(&"zz_iso_calendar",true)
	t.check("calendar_real_flag_progress",flag.visible)
	gm.advance_time(12*60)
	t.check("calendar_real_clock26_midnight_progress",gm.hour==24 and night.visible and hour.visible)
	var day_before:int=gm.day
	gm.advance_time(120)
	t.check("calendar_real_day_roll_progress",gm.day==day_before+1 and gm.hour==2 and not hour.visible)
	# Off-tree/cache registration is a legitimate model projection, not body authority.
	t.root.remove_child(a)
	gm.set_flag(&"zz_iso_calendar",false)
	a.refresh_when()
	t.check("calendar_offtree_cache_old_kind_refresh",not flag.visible)
	t.root.add_child(a)
	a.on_enter()
	t.check("calendar_later_reattachment_progress",not flag.visible and a.is_inside_tree())
	a.free()
	gm.clear_config_overrides()

func _tag(populated:bool)->String:return "existing" if populated else "absent"
