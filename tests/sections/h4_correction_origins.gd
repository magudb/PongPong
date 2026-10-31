extends RefCounted
const SECTION := "h4_correction_origins"
const TIMEOUT_S := 180.0
const H1 := preload("res://tests/sections/boss_terminal_origins.gd")

func run(t) -> void:
	var selected := OS.get_environment("H4C_CASE")
	if selected in ["","r1"]:
		for pid in [&"p0",&"p1"]:
			for mode in ["normal","replacement","failed"]: await _nested(t,pid,mode)
	if selected in ["","r2"]:
		for kind in ["acorn_purse","firefly_swarm","cocoa_thermos"]:
			for seam in ["loot","cap","surprise","normal","departure"]: await _tail(t,seam,kind)
	if selected in ["","r3"]: await _spawn_generation(t)
	if selected == "":
		var original: Dictionary = SaveManager.gather_payload()
		var altered := original.duplicate(true)
		altered.meta.timestamp = str(original.meta.timestamp)+"-actual-negative"
		t.check("timestamp_actual_mutation_still_refused",not preload("res://tests/sections/ghostfam_origins.gd").new()._same_payload(original,altered))
	# Explicitly rejected engine-locked diagnostic, never accepted coverage.
	if selected == "r4": await _pending_victim(t)

func _pending_victim(t) -> void:
	if await H1.new()._start(t) == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var parent := Node2D.new()
	t.world().area.objects.add_child(parent)
	var at := Vector2(12000,12000)
	var orbs: Array = []
	for i in 50: orbs.append(LootDrop2D.spawn(parent,at+Vector2(i,0),"wood",1))
	var victim: WeakRef = weakref(orbs[0])
	var queue := LootDrop2D.queue_for(parent)
	queue.set_process(false)
	var row := {"id":"stone","amount":2,"position":at}
	queue.rows.append(row)
	var wood := EconomyManager.count_item(&"wood")
	var seen: Array = []
	var gained := func(_pid,id,_amount):
		if id!=&"wood" or not seen.is_empty(): return
		seen.append(true)
		var node: Variant = victim.get_ref()
		node.free()
		seen.append(victim.get_ref()==null)
	EventBus.item_gained.connect(gained)
	queue._process(.6)
	EventBus.item_gained.disconnect(gained)
	t.check("r4_eventbus_observer_actually_destroyed_only_victim",seen==[true,true] and victim.get_ref()==null and is_instance_valid(queue) and is_instance_valid(parent))
	t.check("r4_collection_earned_prefix_once",EconomyManager.count_item(&"wood")==wood+1)
	t.check("r4_exact_pending_row_lossless_spawn_after_destroyed_victim",queue.rows.is_empty() and parent.get_children().filter(func(n): return n is LootDrop2D and n.item_id==&"stone" and n.amount==2 and n.global_position==at).size()==1)
	t.check("r4_sibling_order_and_cap_preserved",parent.get_children().filter(func(n): return n is LootDrop2D).size()==50 and orbs.slice(1).all(func(n): return is_instance_valid(n) and not n.collected))
	parent.queue_free()
	await t.go_menu()

func _spawn_generation(t) -> void:
	if await H1.new()._start(t) == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var parent := Node2D.new()
	t.world().area.objects.add_child(parent)
	var at := Vector2(12000,12000)
	var successor := at+Vector2(100,200)
	var seen: Array = []
	var entered := func(node):
		if node is LootDrop2D:
			seen.append(node)
			node.setup(&"stone",3)
			node.global_position = successor
	parent.child_entered_tree.connect(entered)
	var result := LootDrop2D.spawn(parent,at,"wood",1)
	parent.child_entered_tree.disconnect(entered)
	t.check("r3_legal_child_entered_setup_successor",seen.size()==1 and seen[0].item_id==&"stone" and seen[0].amount==3)
	t.check("r3_old_spawn_cannot_place_or_return_successor",result==null and seen[0].global_position==successor,str([result,seen[0].global_position]))
	var normal := LootDrop2D.spawn(parent,at,"wood",2)
	t.check("r3_healthy_spawn_returns_own_generation_at_original_position",is_instance_valid(normal) and normal.item_id==&"wood" and normal.amount==2 and normal.global_position==at)
	parent.queue_free()
	await t.go_menu()

func _tail(t, seam: String = "loot", kind: String = "acorn_purse") -> void:
	if await H1.new()._start(t) == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var loot: Node = t.autoload("LootService")
	var saves: Node = t.autoload("SaveManager")
	var rules: Dictionary = LuaRuntime.get_config("dungeon_loot")
	var prior_surprises: Variant = rules.surprises
	rules.surprises = [{"id":kind,"bp":10000,"gold":[25,25],"oil_s":30,"heal_half_hearts":2}]
	var cfg: Dictionary = loot.loot_cfg().duplicate(true)
	var container: Dictionary = cfg.containers.trae
	container.rolls = {"min":1,"max":1}
	container.find_chance = 1.0
	container.wander_bp = 0
	container.kinds = {"material":100}
	container.odds = {"normal":10000}
	loot.set_loot_config(cfg)
	loot.dungeon["day"] = {"day":GameManager.total_day(),"value":999999,"capped":true}
	loot._cap_told_day = 0
	var body: Node2D = t.player()
	body.oil=40
	body.half_hearts=3
	var gold: int = EconomyManager.gold
	var guest: Node2D
	if seam=="departure":
		guest=t.world()._make_player()
		t.world()._register_player(guest,1,2)
		t.world().add_child(guest)
		guest.enter_area(t.world().area,body.global_position)
		guest.set_physics_process(false)
		guest.is_local=true
		guest.oil=41
		guest.half_hearts=4
	var seen: Array = []
	var notices: Array = []
	var whispers: Array = []
	var earned: Array = []
	var origin := EventBus.interaction_origin()
	var replace := func():
		if not seen.is_empty() or seam=="normal": return
		seen.append(true)
		if seam=="departure":
			t.world()._unregister_player(body)
			seen.append(PlayerRegistry.local_player()==guest and EventBus.interaction_current(origin))
		else: seen.append(saves._apply_payload(saves.gather_payload()).ok and not EventBus.interaction_current(origin))
		seen.append(PlayerRegistry.peek_state(&"p0").to_dict().duplicate(true))
		seen.append([body.oil,body.half_hearts])
	var rolled := func(_source,rows):
		earned.append(rows.duplicate(true))
		if seam in ["loot","departure"]: replace.call()
	var event := func(name,_payload):
		if name in [&"dungeon_surprise",&"loot_day_capped"]: notices.append(name)
		if (name==&"loot_day_capped" and seam=="cap") or (name==&"dungeon_surprise" and seam=="surprise"): replace.call()
	var whisper := func(key): whispers.append(key)
	var watch: Node = t.world().get_node("RunWatch")
	# Prove inside-public fanout with the actual consumer ordered after the
	# replacement observer, not only a producer check after emit returns.
	EventBus.game_event.disconnect(watch._event)
	EventBus.loot_rolled.connect(rolled)
	EventBus.game_event.connect(event)
	EventBus.game_event.connect(watch._event)
	EventBus.whisper_requested.connect(whisper)
	var result: Dictionary = loot.open_container("skovkant","trae","dg:h4c:tail",{"rng":RandomNumberGenerator.new()})
	EventBus.loot_rolled.disconnect(rolled)
	EventBus.game_event.disconnect(event)
	EventBus.whisper_requested.disconnect(whisper)
	var tag := "r2_"+seam+"_"+kind
	t.check(tag+"_actual_container_earned_result_once",result.ok and not result.results.is_empty() and earned==[result.results])
	if seam in ["normal","departure"]:
		t.check(tag+"_ordinary_model_surprise_economics",PlayerRegistry.peek_state(&"p0").gold==gold+(25 if kind=="acorn_purse" else 0) and loot._cap_told_day==GameManager.total_day())
		t.check(tag+"_optional_physical_original_only",[body.oil,body.half_hearts]==([40.0,3] if seam=="departure" else [70.0 if kind=="firefly_swarm" else 40.0,5 if kind=="cocoa_thermos" else 3]) and (seam!="departure" or [guest.oil,guest.half_hearts]==[41.0,4]))
		t.check(tag+"_public_phases_once",notices==[&"loot_day_capped",&"dungeon_surprise"] and whispers.size()==2)
		if seam=="departure": t.check(tag+"_body_loss_keeps_model_prefix",seen.size()==4 and seen[1])
	else:
		t.check(tag+"_public_callback_actually_replaced",seen.size()==4 and seen[1])
		t.check(tag+"_winner_profile_cap_and_body_untouched",seen.size()==4 and PlayerRegistry.peek_state(&"p0").to_dict()==seen[2] and loot._cap_told_day==0 and [body.oil,body.half_hearts]==seen[3])
		var expected: Array = [] if seam=="loot" else ([&"loot_day_capped"] if seam=="cap" else [&"loot_day_capped",&"dungeon_surprise"])
		t.check(tag+"_no_old_optional_suffix",notices==expected and whispers.size()==(1 if seam=="surprise" else 0),str([notices,whispers]))
	# Raw notification never grants a fresh operation to the consequence consumer.
	var raw_gold: int = EconomyManager.gold
	EventBus.game_event.emit(&"dungeon_surprise",{"id":"acorn_purse","gold":7})
	t.check(tag+"_raw_notification_no_mutation",EconomyManager.gold==raw_gold)
	rules.surprises = prior_surprises
	loot.set_loot_config()
	await t.go_menu()

func _nested(t, pid: StringName = &"p1", mode: String = "normal") -> void:
	if await H1.new()._start(t) == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var body: Node2D = t.world()._make_player()
	t.world()._register_player(body,1,2)
	t.world().add_child(body)
	body.enter_area(t.world().area,t.player().global_position)
	body.set_physics_process(false)
	# Match the established complete-rollback fixture: initialize guest codec containers.
	PlayerRegistry.for_player(&"p1",func():
		EconomyManager.from_dict(EconomyManager.to_dict())
		QuestManager.from_dict(QuestManager.to_dict()))
	var loot: Node = t.autoload("LootService")
	var saves: Node = t.autoload("SaveManager")
	var prior: String = loot.delegate_path
	var directory: String = saves.save_dir
	loot.delegate_path = "res://tests/fixtures/h4_correction_delegate.gd"
	var tag := "r1_"+str(pid)+"_"+mode
	var quest := StringName("h4c_"+tag)
	QuestManager.register_quest_from_lua({"id":quest,"objectives":[{"id":"wood","on":"item_gained","item":"wood","target":100}],"rewards":{},"meta":{}})
	PlayerRegistry.for_player(pid,func():
		EconomyManager.add_item(&"stone",3)
		EconomyManager.add_gold(100)
		QuestManager.accept_quest(quest))
	var late := preload("res://tests/sections/multiplayer_rollback.gd").LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("h4c_late",late,1000)
	saves.save_dir = "user://"+tag
	var old_origin := EventBus.interaction_origin()
	var profile := PlayerRegistry.peek_state(&"p0")
	var barriers: Array = []
	var final_barriers: Array = []
	late.callback = func(): barriers.append(not EventBus.interaction_current(old_origin))
	var failed := func(title,_message,kind):
		if kind=="save" and title==TranslationServer.translate("NOTIF_LOAD_FAILED_TITLE"):
			final_barriers.append(PlayerRegistry.peek_state(&"p0")==profile and not saves.continuation_available(profile))
	if mode=="failed":
		t.check(tag+"_real_primary_no_backup",saves.save_game(0) and not FileAccess.file_exists(saves.backup_path(0)))
	EventBus.notification_posted.connect(failed)
	var entered: Array = []
	var notices: Array = []
	var item := func(owner,id,n):
		if id==&"wood": notices.append(["item",owner,n])
	var money := func(owner,_balance,delta):
		if delta == -3: notices.append(["gold",owner,delta])
	var inventory := func(owner,_pack): notices.append(["inventory",owner])
	EventBus.item_gained.connect(item)
	EventBus.gold_changed.connect(money)
	EventBus.player_inventory_changed.connect(inventory)
	var hook := func(at):
		if at != "commit" or not entered.is_empty(): return
		entered.append(true)
		if mode=="replacement":
			entered.append(saves._apply_payload(saves.gather_payload()).ok and not EventBus.interaction_current(old_origin))
		elif mode=="failed":
			late.rejects=1
			entered.append(not saves.load_game(0) and EventBus.interaction_current(old_origin) and barriers==[true,true] and final_barriers==[true])
		else: entered.append(EventBus.interaction_current(old_origin))
		var unrelated := PlayerRegistry.peek_state(&"p0").to_dict().duplicate(true)
		var before: Dictionary = PlayerRegistry.for_player(pid,func(): return {"gold":EconomyManager.gold,"wood":EconomyManager.count_item(&"wood"),"stone":EconomyManager.count_item(&"stone")})
		var result: Dictionary = PlayerRegistry.for_player(pid,func(): return loot.open_container("skovkant","trae","dg:h4c:inner",{"consume":{"stone":1},"fee":3}))
		entered.append(result.ok and PlayerRegistry.for_player(pid,func(): return EconomyManager.gold==before.gold-3 and EconomyManager.count_item(&"wood")==before.wood+2 and EconomyManager.count_item(&"stone")==before.stone-1))
		entered.append((pid==&"p0" or PlayerRegistry.peek_state(&"p0").to_dict()==unrelated) and PlayerRegistry.acting_id()==&"p0")
	Engine.set_meta("h4_delegate_hook",hook)
	var outer: Dictionary = loot.open_container("skovkant","trae","dg:h4c:outer")
	Engine.remove_meta("h4_delegate_hook")
	EventBus.item_gained.disconnect(item)
	EventBus.gold_changed.disconnect(money)
	EventBus.player_inventory_changed.disconnect(inventory)
	EventBus.notification_posted.disconnect(failed)
	var count := 2 if pid==&"p0" and mode!="replacement" else 1
	t.check(tag+"_registered_nested_commit_and_lifecycle",entered==[true,true,true,true],str(entered))
	t.check(tag+"_exact_once_labelled_item",notices.filter(func(row): return row[0]=="item" and row[1]==pid).size()==count,str(notices))
	t.check(tag+"_exact_once_gold_inventory",notices.filter(func(row): return row[0]=="gold" and row[1]==pid).size()==1 and notices.filter(func(row): return row[0]=="inventory" and row[1]==pid).size()==count+1+(1 if mode=="replacement" else (2 if mode=="failed" else 0)),str(notices))
	t.check(tag+"_real_quest_item_consumer",PlayerRegistry.for_player(pid,func(): return int(QuestManager.active_quests[quest].objectives.wood.current)==count*2))
	t.check(tag+"_caller_restored_and_old_model_refused",PlayerRegistry.acting_id()==&"p0" and (str(outer.reason)=="superseded" if mode=="replacement" else outer.ok))
	saves.unregister_section("h4c_late")
	late.free()
	saves.save_dir=directory
	loot.delegate_path=prior
	QuestManager.quest_defs.erase(quest)
	await t.go_menu()
