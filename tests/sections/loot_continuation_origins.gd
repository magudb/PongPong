extends RefCounted
const SECTION := "loot_continuation_origins"
const TIMEOUT_S := 180.0
const H1 := preload("res://tests/sections/boss_terminal_origins.gd")
const H2 := preload("res://tests/sections/boss_inner_origins.gd")
const Compare := preload("res://tests/sections/ghostfam_origins.gd")

func run(t) -> void:
	var selected := OS.get_environment("H4_CASE")
	if selected == "recipient":
		await _recipient(t)
		return
	if selected == "disk":
		for mode in ["primary","backup"]: await _delegate_disk(t,mode)
		return
	if selected == "full":
		await _full_pack(t)
		return
	if selected == "rollback":
		for seam in ["plan","fit","commit"]: await _delegate_rollback(t,seam)
		return
	if selected == "extra":
		await _stale_process(t)
		await _queue_admission(t)
		await _reentrant_collect(t)
		return
	if selected == "bind":
		await _delegate(t,"bind","direct")
		await _delegate(t,"plan","normal")
		return
	if selected == "collect":
		for mode in ["transfer","reuse","heal","visible","tree"]: await _collect(t,mode)
		return
	if selected == "ready":
		await _ready_cap(t)
		return
	if selected == "pending":
		await _pending(t)
		await _pending(t,true)
		return
	if selected == "cap":
		await _cap(t)
		return
	if selected == "nested":
		await _nested_current(t)
		return
	if selected == "": await _delegate(t,"bind","direct")
	for seam in ([selected] if selected != "" else ["plan","fit","commit"]):
		await _delegate(t,seam,"direct")
		await _delegate(t,seam,"normal")
	if selected != "": return
	await _nested_current(t)
	await _cap(t)
	await _ready_cap(t)
	await _pending(t)
	await _pending(t,true)
	for mode in ["transfer","reuse","heal","visible","tree"]: await _collect(t,mode)
	await _stale_process(t)
	await _queue_admission(t)
	await _reentrant_collect(t)
	await _full_pack(t)
	for seam in ["plan","fit","commit"]: await _delegate_rollback(t,seam)
	await _recipient(t)
	for mode in ["primary","backup"]: await _delegate_disk(t,mode)

func _delegate(t, seam: String, mode: String) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var saves: Node = t.autoload("SaveManager")
	var loot: Node = t.autoload("LootService")
	var prior: String = loot.delegate_path
	loot.delegate_path = "res://tests/fixtures/h4_loot_delegate.gd"
	var tag := "delegate_"+seam+"_"+mode
	var origin := EventBus.interaction_origin()
	var seen: Array = []
	var calls: Array = []
	EconomyManager.add_item(&"stone",3)
	EconomyManager.add_gold(100)
	var baseline := EconomyManager.count_item(&"wood")
	var stone_before := EconomyManager.count_item(&"stone")
	var gold_before: int = EconomyManager.gold
	var rng_before: int = loot.rng.state
	var files := H1.new()._files(saves)
	var callback := func(at):
		calls.append(at)
		if at != seam or mode != "direct" or not seen.is_empty(): return
		seen.append(true)
		var payload: Dictionary = saves.gather_payload()
		seen.append(saves.validate_payload(payload).ok and saves._apply_payload(payload).ok)
		seen.append(saves.gather_payload())
		seen.append(t.player()._last_stats.duplicate(true))
		H2.new()._journal(tag,"callback",{"payload":seen[2],"files":H1.new()._files(saves),"body_cache":seen[3]})
	Engine.set_meta("h4_delegate_hook",callback)
	var result: Dictionary = loot.open_container("skovkant","trae","dg:h4:"+tag,{"consume":{"stone":1},"fee":3})
	Engine.remove_meta("h4_delegate_hook")
	t.check(tag+"_real_supported_delegate_entered",seam in calls)
	if mode == "direct":
		t.check(tag+"_same_valued_success_revokes",seen.size()==4 and seen[1] and not EventBus.interaction_current(origin))
		var after: Dictionary = saves.gather_payload()
		H2.new()._journal(tag,"unwind",{"payload":after,"files":H1.new()._files(saves),"body_cache":t.player()._last_stats})
		t.check(tag+"_full_winner_exact_unwind",Compare.new()._same_payload(seen[2],after),str(Compare.new()._changed(seen[2],after)))
		t.check(tag+"_old_commit_refused",not loot.dungeon.has("h4_commits") and str(result.reason)=="superseded")
		await t.frames(3)
		var queued: Dictionary = saves.gather_payload()
		H2.new()._journal(tag,"three_frames",{"payload":queued,"files":H1.new()._files(saves),"body_cache":t.player()._last_stats})
		t.check(tag+"_full_winner_exact_three_frames",Compare.new()._same_payload(seen[2],queued) and t.player()._last_stats==seen[3])
	else:
		t.check(tag+"_ordinary_economics_commit_once",result.ok and calls==["plan","fit","commit"] and EconomyManager.count_item(&"wood")==baseline+2 and EconomyManager.count_item(&"stone")==stone_before-1 and EconomyManager.gold==gold_before-3 and loot.rng.state==rng_before and loot.dungeon.h4_commits==1)
	t.check(tag+"_files_exact",H1.new()._files(saves)==files)
	loot.delegate_path = prior
	await t.go_menu()

func _nested_current(t) -> void:
	if await H1.new()._start(t) == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var loot: Node = t.autoload("LootService")
	var saves: Node = t.autoload("SaveManager")
	var prior: String = loot.delegate_path
	loot.delegate_path = "res://tests/fixtures/h4_loot_delegate.gd"
	var entered: Array = []
	var notices: Array = []
	var record := func(pid, _balance, delta):
		if delta == 7: notices.append(pid)
	EventBus.gold_changed.connect(record)
	var callback := func(at):
		if at != "commit" or not entered.is_empty(): return
		entered.append(true)
		entered.append(saves._apply_payload(saves.gather_payload()).ok)
		var before: int = EconomyManager.gold
		EconomyManager.add_gold(7)
		entered.append(EconomyManager.gold == before+7)
	Engine.set_meta("h4_delegate_hook",callback)
	loot.open_container("skovkant","trae","dg:h4:nested")
	Engine.remove_meta("h4_delegate_hook")
	t.check("nested_current_actual_delegate_apply_and_economy",entered == [true,true,true])
	t.check("nested_current_independent_notification_owed",notices == [&"p0"],str(notices))
	EconomyManager.add_gold(7)
	t.check("nested_current_future_root_notifications",notices == [&"p0",&"p0"])
	EventBus.gold_changed.disconnect(record)
	loot.delegate_path = prior
	await t.go_menu()

func _cap(t) -> void:
	if await H1.new()._start(t) == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var parent := Node2D.new()
	t.world().area.objects.add_child(parent)
	var at: Vector2 = t.player().global_position+Vector2(2000,0)
	for i in 50: LootDrop2D.spawn(parent,at+Vector2(i,0),"wood",1)
	var saves: Node = t.autoload("SaveManager")
	var seen: Array = []
	var origin := EventBus.interaction_origin()
	var record := func(_pid,id,_n):
		if id != &"wood" or not seen.is_empty(): return
		seen.append(true)
		seen.append(saves._apply_payload(saves.gather_payload()).ok)
		seen.append(saves.gather_payload())
	EventBus.item_gained.connect(record)
	var result := LootDrop2D.spawn_owned(parent,at,"stone",2,EventBus.interaction_current.bind(origin))
	EventBus.item_gained.disconnect(record)
	t.check("cap_real_collection_replaces_model",seen.size()==3 and seen[1])
	t.check("cap_old_producer_does_not_allocate_after_collection",result == null and parent.get_children().filter(func(n): return n is LootDrop2D).size()==50)
	var after: Dictionary = saves.gather_payload()
	t.check("cap_whole_winner_exact",Compare.new()._same_payload(seen[2],after))
	await t.frames(3)
	var delayed: Dictionary = saves.gather_payload()
	t.check("cap_queued_winner_exact",Compare.new()._same_payload(seen[2],delayed))
	parent.queue_free()
	await t.go_menu()

func _ready_cap(t) -> void:
	if await H1.new()._start(t) == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var parent := Node2D.new()
	t.world().area.objects.add_child(parent)
	var at: Vector2 = t.player().global_position+Vector2(2000,0)
	for i in 50: LootDrop2D.spawn(parent,at+Vector2(i,0),"wood",1)
	var saves: Node = t.autoload("SaveManager")
	var seen: Array = []
	var record := func(_pid,id,_n):
		if id != &"wood" or not seen.is_empty(): return
		seen.append(true)
		seen.append(saves._apply_payload(saves.gather_payload()).ok)
	EventBus.item_gained.connect(record)
	var orb := LootDrop2D.create({"id":"stone","amount":2})
	parent.add_child(orb)
	EventBus.item_gained.disconnect(record)
	t.check("ready_cap_actual_collection_replaces_model",seen == [true,true])
	t.check("ready_cap_no_stale_collision_or_collector_suffix",orb.get_child_count()==0 and orb._player==null)
	parent.queue_free()
	await t.go_menu()

func _pending(t, mutate: bool = false) -> void:
	if await H1.new()._start(t) == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var parent := Node2D.new()
	t.world().area.objects.add_child(parent)
	var at: Vector2 = t.player().global_position+Vector2(2000,0)
	for i in 50: LootDrop2D.spawn(parent,at+Vector2(i,0),"wood",1)
	var queue := LootDrop2D.queue_for(parent)
	var original := {"id":"stone","amount":2,"position":at}
	var replacement := {"id":"wood","amount":3,"position":at+Vector2(60,0)}
	queue.rows.append(original)
	var seen: Array = []
	var record := func(_pid,id,_n):
		if id != &"wood" or not seen.is_empty(): return
		seen.append(true)
		if mutate:
			original.amount = 3
		else:
			queue.rows.clear()
			queue.rows.append(replacement)
	EventBus.item_gained.connect(record)
	queue._process(.6)
	EventBus.item_gained.disconnect(record)
	var suffix := "_mutated" if mutate else ""
	t.check("pending_actual_oldest_collection_callback"+suffix,seen == [true])
	t.check("pending_exact_front_row_not_replacement_popped"+suffix,queue.rows.size()==1 and is_same(queue.rows[0],original if mutate else replacement))
	t.check("pending_no_stale_row_spawn"+suffix,parent.get_children().filter(func(n): return n is LootDrop2D).size()==50)
	queue._process(.6)
	t.check("pending_independent_replacement_row_progresses_next_tick"+suffix,queue.rows.is_empty() and parent.get_children().filter(func(n): return n is LootDrop2D and not n.collected).size()==50)
	parent.queue_free()
	await t.go_menu()

func _collect(t, mode: String) -> void:
	if await H1.new()._start(t) == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var parent := Node2D.new()
	var other := Node2D.new()
	t.world().area.objects.add_child(parent)
	t.world().area.objects.add_child(other)
	var at: Vector2 = t.player().global_position+Vector2(2000,0)
	if mode == "heal":
		t.player().half_hearts = t.player().max_half_hearts-2
		t.player()._emit_stats_on_bus()
	var orb := LootDrop2D.spawn(parent,at,"tornebaer" if mode == "heal" else "wood",1)
	var saves: Node = t.autoload("SaveManager")
	var seen: Array = []
	var act := func():
		if not seen.is_empty(): return
		seen.append(true)
		if mode == "heal":
			seen.append(saves._apply_payload(saves.gather_payload()).ok)
			seen.append(saves.gather_payload())
			seen.append(t.player()._last_stats.duplicate(true))
		elif mode == "reuse":
			orb.setup(&"stone",3)
		elif mode == "tree":
			parent.reparent(other)
		else:
			orb.reparent(other)
	var inventory := func(_pid,id,_amount):
		if id == &"wood" and mode in ["transfer","reuse","tree"]: act.call()
	var health := func(_pid,_hearts,_maximum):
		if mode == "heal": act.call()
	var visibility := func():
		if mode == "visible" and not orb.visible: act.call()
	EventBus.item_gained.connect(inventory)
	EventBus.player_health_changed.connect(health)
	orb.visibility_changed.connect(visibility)
	var result := orb.collect()
	EventBus.item_gained.disconnect(inventory)
	EventBus.player_health_changed.disconnect(health)
	orb.visibility_changed.disconnect(visibility)
	t.check("collect_"+mode+"_actual_callback",not seen.is_empty() and result)
	if mode == "heal":
		var after: Dictionary = saves.gather_payload()
		t.check("collect_heal_winner_body_cache_exact",seen[1] and Compare.new()._same_payload(seen[2],after) and t.player()._last_stats==seen[3])
		t.check("collect_heal_no_stale_optional_spark",parent.get_node_or_null("SparkPool")==null)
	elif mode == "reuse":
		t.check("collect_reuse_new_request_survives",orb.item_id==&"stone" and not orb.collected and orb.visible and orb.is_processing() and not orb.is_queued_for_deletion())
	elif mode == "tree":
		t.check("collect_tree_transferred_parent_not_retired",parent.get_parent()==other and orb.get_parent()==parent and orb.is_processing() and not orb.is_queued_for_deletion() and orb.visible)
		var age := orb.age
		orb._process(.1)
		t.check("collect_tree_later_tick_cannot_adopt_attachment",orb.age==age)
	else:
		t.check("collect_"+mode+"_transferred_resource_not_retired",orb.get_parent()==other and orb.is_processing() and not orb.is_queued_for_deletion() and (mode == "visible" or orb.visible))
	parent.queue_free()
	other.queue_free()
	await t.go_menu()

func _stale_process(t) -> void:
	if await H1.new()._start(t) == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var parent := Node2D.new()
	t.world().area.objects.add_child(parent)
	var at: Vector2 = t.player().global_position+Vector2(150,0)
	var orb := LootDrop2D.spawn(parent,at,"wood",1)
	orb.age = .6
	var age := orb.age
	var saves: Node = t.autoload("SaveManager")
	t.check("drop_same_value_apply_succeeds",saves._apply_payload(saves.gather_payload()).ok)
	var balance := EconomyManager.count_item(&"wood")
	orb._process(.1)
	t.check("drop_old_process_cannot_move_or_age_in_winner",orb.age==age and orb.global_position==at)
	t.check("drop_old_future_collect_cannot_rebind_winner",not orb.collect() and EconomyManager.count_item(&"wood")==balance)
	parent.queue_free()
	await t.go_menu()

func _queue_admission(t) -> void:
	if await H1.new()._start(t) == null: return
	var parent := Node2D.new()
	var other := Node2D.new()
	t.world().area.objects.add_child(parent)
	t.world().area.objects.add_child(other)
	var entered: Array = []
	var hook := func(child):
		if child.name != "PendingDrops": return
		entered.append(true)
		# child_entered_tree is engine-locked for immediate reparent; queueing
		# deletion is legal here and must revoke the admission result.
		child.queue_free()
	parent.child_entered_tree.connect(hook)
	var queue := LootDrop2D.queue_for(parent)
	parent.child_entered_tree.disconnect(hook)
	t.check("queue_admission_real_queued_child_callback",entered == [true])
	t.check("queue_admission_refuses_queued_resource",queue==null)
	parent.queue_free()
	other.queue_free()
	await t.go_menu()

func _reentrant_collect(t) -> void:
	if await H1.new()._start(t) == null: return
	var parent := Node2D.new()
	t.world().area.objects.add_child(parent)
	var at: Vector2 = t.player().global_position+Vector2(2000,0)
	var orb := LootDrop2D.spawn(parent,at,"wood",1)
	var before := EconomyManager.count_item(&"wood")
	var entered: Array = []
	var hook := func(_pid,id,_amount):
		if id != &"wood" or not entered.is_empty(): return
		entered.append(true)
		entered.append(orb.collect())
	EventBus.item_gained.connect(hook)
	var result := orb.collect()
	EventBus.item_gained.disconnect(hook)
	t.check("collect_nested_same_request_once",result and entered == [true,false] and EconomyManager.count_item(&"wood")==before+1)
	parent.queue_free()
	await t.go_menu()

func _delegate_rollback(t, seam: String) -> void:
	if await H1.new()._start(t) == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var saves: Node = t.autoload("SaveManager")
	var loot: Node = t.autoload("LootService")
	var prior: String = loot.delegate_path
	var directory: String = saves.save_dir
	loot.delegate_path = "res://tests/fixtures/h4_loot_delegate.gd"
	saves.save_dir = "user://h4-failed-"+seam
	var late := preload("res://tests/sections/multiplayer_rollback.gd").LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("h4_late",late,1000)
	EconomyManager.add_item(&"stone",3)
	EconomyManager.add_gold(100)
	var stone := EconomyManager.count_item(&"stone")
	var wood := EconomyManager.count_item(&"wood")
	var gold: int = EconomyManager.gold
	t.check("rollback_"+seam+"_real_primary_without_backup",saves.save_game(0) and not FileAccess.file_exists(saves.backup_path(0)))
	var files := H1.new()._files(saves)
	var origin := EventBus.interaction_origin()
	var profile := PlayerRegistry.peek_state(&"p0")
	var seen: Array = []
	var barriers: Array = []
	var final_barriers: Array = []
	late.callback = func(): barriers.append(not EventBus.interaction_current(origin))
	var final := func(title,_message,kind):
		if kind == "save" and title == TranslationServer.translate("NOTIF_LOAD_FAILED_TITLE"):
			final_barriers.append(PlayerRegistry.peek_state(&"p0")==profile and not EventBus.interaction_current(origin) and not saves.continuation_available(profile))
	EventBus.notification_posted.connect(final)
	var hook := func(at):
		if at != seam or not seen.is_empty(): return
		seen.append(true)
		late.rejects = 1
		seen.append(saves.load_game(0))
		seen.append(EventBus.interaction_current(origin) and PlayerRegistry.peek_state(&"p0")==profile)
	Engine.set_meta("h4_delegate_hook",hook)
	var result: Dictionary = loot.open_container("skovkant","trae","dg:h4:rollback:"+seam,{"consume":{"stone":1},"fee":3})
	Engine.remove_meta("h4_delegate_hook")
	EventBus.notification_posted.disconnect(final)
	t.check("rollback_"+seam+"_complete_graph_resumes_after_final_barrier",seen==[true,false,true] and barriers==[true,true] and final_barriers==[true])
	t.check("rollback_"+seam+"_normal_economics_once",result.ok and EconomyManager.count_item(&"wood")==wood+2 and EconomyManager.count_item(&"stone")==stone-1 and EconomyManager.gold==gold-3 and loot.dungeon.h4_commits==1)
	t.check("rollback_"+seam+"_files_exact",H1.new()._files(saves)==files)
	await t.frames(3)
	t.check("rollback_"+seam+"_future_root_works",loot.open_container("skovkant","trae","dg:h4:next:"+seam).ok and loot.dungeon.h4_commits==2)
	saves.unregister_section("h4_late")
	late.free()
	saves.save_dir = directory
	loot.delegate_path = prior
	await t.go_menu()

func _full_pack(t) -> void:
	if await H1.new()._start(t) == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var parent := Node2D.new()
	t.world().area.objects.add_child(parent)
	var at: Vector2 = t.player().global_position+Vector2(2000,0)
	var slots: Array = []
	for i in 24: slots.append({"id":"stone","amount":99})
	EconomyManager.from_dict({"v":1,"gold":1000,"inventory":slots})
	for i in 50: LootDrop2D.spawn(parent,at+Vector2(i,0),"wood",1)
	var queue := LootDrop2D.queue_for(parent)
	var warnings: Array = []
	var hook := func(key):
		if key == "DEXP_BACKPACK_FULL": warnings.append(key)
	EventBus.whisper_requested.connect(hook)
	LootDrop2D.spawn(parent,at,"wood",2)
	queue._process(.6)
	t.check("full_real_pack_queued_and_one_warning",EconomyManager.free_slots()==0 and queue.rows.size()==1 and warnings.size()==1 and EconomyManager.count_item(&"wood")==0)
	EconomyManager.remove_item(&"stone",99)
	queue._process(.6)
	t.check("full_retry_once_lossless",queue.rows.is_empty() and EconomyManager.count_item(&"wood")==1 and parent.get_children().filter(func(n): return n is LootDrop2D and not n.collected).size()==50 and warnings.size()==1)
	EconomyManager.from_dict({"v":1,"gold":1000,"inventory":slots})
	LootDrop2D.spawn(parent,at,"wood",2)
	var old: Dictionary = queue.rows[0]
	var saves: Node = t.autoload("SaveManager")
	t.check("full_same_model_values_successfully_replaced",saves._apply_payload(saves.gather_payload()).ok)
	var fresh := {"id":"wood","amount":3,"position":at}
	queue.rows.append(fresh)
	queue._process(.6)
	t.check("full_obsolete_original_row_retires_not_successor",queue.rows.size()==1 and is_same(queue.rows[0],fresh) and not is_same(queue.rows[0],old) and EconomyManager.count_item(&"wood")==0)
	EconomyManager.remove_item(&"stone",99)
	queue._process(.6)
	t.check("full_new_current_row_not_blocked_by_old_orbs",queue.rows.is_empty() and parent.get_children().any(func(n): return n is LootDrop2D and n.amount==3 and not n.collected))
	EventBus.whisper_requested.disconnect(hook)
	parent.queue_free()
	await t.go_menu()

func _recipient(t) -> void:
	if await H1.new()._start(t) == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var body: Node2D = t.world()._make_player()
	t.world()._register_player(body,1,2)
	t.world().add_child(body)
	body.enter_area(t.world().area,t.player().global_position)
	body.set_physics_process(false)
	var loot: Node = t.autoload("LootService")
	var prior: String = loot.delegate_path
	loot.delegate_path = "res://tests/fixtures/h4_loot_delegate.gd"
	var p0 := PlayerRegistry.peek_state(&"p0")
	var p1 := PlayerRegistry.peek_state(&"p1")
	var p0_before := p0.to_dict().duplicate(true)
	var before: int = PlayerRegistry.for_player(&"p1",func(): return EconomyManager.count_item(&"wood"))
	var result: Dictionary = PlayerRegistry.for_player(&"p1",func(): return loot.open_container("skovkant","trae","dg:h4:p1"))
	t.check("recipient_delegate_p1_labels_and_scope",result.ok and PlayerRegistry.acting_id()==&"p0" and PlayerRegistry.for_player(&"p1",func(): return EconomyManager.count_item(&"wood"))==before+2)
	t.check("recipient_delegate_unrelated_profile_exact",p0.to_dict()==p0_before)
	var parent := Node2D.new()
	t.world().area.objects.add_child(parent)
	var at: Vector2 = t.player().global_position+Vector2(2000,0)
	var origin := EventBus.interaction_origin(&"p1")
	var orb := LootDrop2D.spawn_owned(parent,at,"wood",1,EventBus.interaction_current.bind(origin))
	t.check("recipient_spawn_keeps_existing_local_collector",orb._player==t.player())
	t.world()._unregister_player(body)
	var p1_before := p1.to_dict().duplicate(true)
	var wood := EconomyManager.count_item(&"wood")
	t.check("recipient_body_departure_preserves_earned_model_future_pickup",orb.collect() and EconomyManager.count_item(&"wood")==wood+1 and p1.to_dict()==p1_before)
	body.queue_free()
	parent.queue_free()
	loot.delegate_path = prior
	await t.go_menu()

func _delegate_disk(t, mode: String) -> void:
	if await H1.new()._start(t) == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var saves: Node = t.autoload("SaveManager")
	var loot: Node = t.autoload("LootService")
	var prior: String = loot.delegate_path
	var directory: String = saves.save_dir
	loot.delegate_path = "res://tests/fixtures/h4_loot_delegate.gd"
	saves.save_dir = "user://h4-disk-"+mode
	var saved: bool = saves.save_game(0)
	if mode == "backup":
		saved = saved and saves.save_game(0) and FileAccess.file_exists(saves.backup_path(0))
		var file := FileAccess.open(saves.slot_path(0),FileAccess.WRITE)
		file.store_string("{invalid-primary")
		file.close()
	t.check("disk_"+mode+"_real_slot_ready",saved)
	var origin := EventBus.interaction_origin()
	var seen: Array = []
	var hook := func(at):
		if at != "commit" or not seen.is_empty(): return
		seen.append(true)
		seen.append(saves.load_game(0))
		seen.append(saves.gather_payload())
		seen.append(H1.new()._files(saves))
		seen.append(t.player()._last_stats.duplicate(true))
		H2.new()._journal("disk_"+mode,"callback",{"payload":seen[2],"files":seen[3],"body_cache":seen[4]})
	Engine.set_meta("h4_delegate_hook",hook)
	var result: Dictionary = loot.open_container("skovkant","trae","dg:h4:disk:"+mode)
	Engine.remove_meta("h4_delegate_hook")
	var after: Dictionary = saves.gather_payload()
	t.check("disk_"+mode+"_actual_load_revokes_original",seen.size()==5 and seen[1] and not EventBus.interaction_current(origin) and str(result.reason)=="superseded")
	H2.new()._journal("disk_"+mode,"unwind",{"payload":after,"files":H1.new()._files(saves),"body_cache":t.player()._last_stats})
	t.check("disk_"+mode+"_winner_whole_unwind_exact",Compare.new()._same_payload(seen[2],after) and H1.new()._files(saves)==seen[3] and t.player()._last_stats==seen[4])
	await t.frames(3)
	var delayed: Dictionary = saves.gather_payload()
	H2.new()._journal("disk_"+mode,"three_frames",{"payload":delayed,"files":H1.new()._files(saves),"body_cache":t.player()._last_stats})
	t.check("disk_"+mode+"_winner_three_frames_exact",Compare.new()._same_payload(seen[2],delayed) and H1.new()._files(saves)==seen[3] and t.player()._last_stats==seen[4])
	saves.save_dir = directory
	loot.delegate_path = prior
	await t.go_menu()
