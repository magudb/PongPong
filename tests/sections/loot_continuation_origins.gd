extends RefCounted
const SECTION := "loot_continuation_origins"
const TIMEOUT_S := 180.0
const H1 := preload("res://tests/sections/boss_terminal_origins.gd")
const H2 := preload("res://tests/sections/boss_inner_origins.gd")
const Compare := preload("res://tests/sections/ghostfam_origins.gd")

func run(t) -> void:
	var selected := OS.get_environment("H4_CASE")
	if selected == "collect":
		for mode in ["transfer","reuse","heal","visible"]: await _collect(t,mode)
		return
	if selected == "ready":
		await _ready_cap(t)
		return
	if selected == "pending":
		await _pending(t)
		return
	if selected == "cap":
		await _cap(t)
		return
	if selected == "nested":
		await _nested_current(t)
		return
	for seam in ([selected] if selected != "" else ["plan","fit","commit"]):
		await _delegate(t,seam,"direct")
		await _delegate(t,seam,"normal")
	if selected != "": return
	await _nested_current(t)
	await _cap(t)
	await _ready_cap(t)
	await _pending(t)
	for mode in ["transfer","reuse","heal","visible"]: await _collect(t,mode)

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

func _pending(t) -> void:
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
		queue.rows.clear()
		queue.rows.append(replacement)
	EventBus.item_gained.connect(record)
	queue._process(.6)
	EventBus.item_gained.disconnect(record)
	t.check("pending_actual_oldest_collection_callback",seen == [true])
	t.check("pending_exact_front_row_not_replacement_popped",queue.rows.size()==1 and is_same(queue.rows[0],replacement))
	t.check("pending_no_stale_row_spawn",parent.get_children().filter(func(n): return n is LootDrop2D).size()==50)
	queue._process(.6)
	t.check("pending_independent_replacement_row_progresses_next_tick",queue.rows.is_empty() and parent.get_children().filter(func(n): return n is LootDrop2D and not n.collected).size()==50)
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
		else:
			orb.reparent(other)
	var inventory := func(_pid,id,_amount):
		if id == &"wood" and mode in ["transfer","reuse"]: act.call()
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
	else:
		t.check("collect_"+mode+"_transferred_resource_not_retired",orb.get_parent()==other and orb.is_processing() and not orb.is_queued_for_deletion() and (mode == "visible" or orb.visible))
	parent.queue_free()
	other.queue_free()
	await t.go_menu()
