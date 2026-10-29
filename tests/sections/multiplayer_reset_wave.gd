extends RefCounted
const SECTION := "multiplayer_reset_wave"
const TIMEOUT_S := 120.0
const Callback := preload("res://tests/sections/multiplayer_callback_ownership.gd")

func _snapshot(saves: Node) -> Dictionary:
	var out: Dictionary = Callback.new()._snapshot(saves)
	for name in ["TimeManager", "ShopSystem", "AnimalHusbandry", "HomeManager", "SocialManager"]:
		out[name] = Svc.node(name).to_dict().duplicate(true)
	var other := PlayerRegistry.peek_state(&"p1")
	out["other"] = other.to_dict().duplicate(true) if other != null else null
	return out

func run(t) -> void:
	var saves: Node = t.autoload("SaveManager")
	var prior: String = saves.save_dir
	t.on_cleanup(func(): saves.save_dir = prior)
	for kind: String in ["inventory", "gold", "weather", "husbandry", "home", "outfit", "owned", "furniture", "nested_newgame", "nested_reset", "nested_roster", "two_level", "raw_reentry", "full_failed", "incomplete", "normal", "deferred"]:
		if OS.get_environment("MP4_RESET_CASE") != "" and OS.get_environment("MP4_RESET_CASE") != kind: continue
		if not await t.start_world(): return
		saves.save_dir = "user://mp4-reset-wave-" + kind
		DirAccess.make_dir_recursive_absolute(saves.save_dir)
		if kind in ["normal", "deferred"]: await _ordinary(t, saves, kind)
		elif kind in ["full_failed", "incomplete"]: _failed(t, saves, kind)
		elif kind in ["nested_newgame", "nested_reset", "nested_roster", "two_level", "raw_reentry"]: _nested(t, saves, kind)
		else: await _load_winner(t, saves, kind)
		await t.go_menu()

func _load_winner(t, saves: Node, kind: String) -> void:
	PlayerRegistry.state(&"p1")
	PlayerRegistry.for_player(&"p1", func():
		EconomyManager.from_dict(EconomyManager.to_dict())
		QuestManager.from_dict(QuestManager.to_dict()))
	QuestManager.accept_quest(&"supply_run")
	for objective: Dictionary in QuestManager.get_quest_def(&"supply_run").get("objectives", []):
		QuestManager.update_objective(&"supply_run", StringName(str(objective.id)), int(objective.target))
	EconomyManager.add_item(&"stone", 17, true)
	EconomyManager.gold = 873
	QuestManager.accept_quest(&"lost_cat")
	SocialManager.add_hearts(&"fairy_lily", 6)
	QuestManager.pending_rewards = {"mp4_wave_loaded": {"wood": 3}}
	GameManager.play_time_seconds = 222
	var wood := EconomyManager.count_item(&"wood")
	t.check(kind + "_winner_saved", QuestManager.is_active(&"lost_cat") and QuestManager.is_completed(&"supply_run") and WardrobeManager.count_total(&"dress_sun_meadow") == 1 and FurnitureManager.count_total(&"sofa_leaf") == 1 and LootService.claimed.has("fairy_lily:6") and saves.save_game(1), "genuine distinct healthy progressed winner with queued owed reward")
	var entered: Array = []
	var winner: Dictionary = {}
	var replace := func():
		if not entered.is_empty(): return
		entered.append(kind) # arm before load also publishes inventory/gold
		entered.append(saves.load_game(1))
		winner.merge(_snapshot(saves))
		entered.append(EconomyManager.gold == 873 and EconomyManager.count_item(&"stone") == 17 and QuestManager.is_active(&"lost_cat") and not QuestManager.pending_rewards.is_empty() and saves.current_slot == 1)
	var inventory := func(_pid, _items):
		# Real first starter-item callback, not a pre-broadcast observer.
		if kind == "inventory" and GameManager.player_name == "OldWave": replace.call()
	var gold := func(_pid, _amount, _delta):
		if kind == "gold" and GameManager.player_name == "OldWave": replace.call()
	var weather := func(_value):
		if kind == "weather" and saves.current_slot == -1: replace.call()
	var husbandry := func():
		if kind == "husbandry" and saves.current_slot == -1: replace.call()
	var flag := func(key, _value):
		if kind == "home" and key == GameManager.FLAG_HOME_TIER and saves.current_slot == -1: replace.call()
	var outfit := func(_pid, _value):
		if kind == "outfit" and saves.current_slot == -1: replace.call()
	var owned := func():
		if kind == "owned" and saves.current_slot == -1: replace.call()
	var furniture := func(_reason):
		if kind == "furniture" and saves.current_slot == -1: replace.call()
	EventBus.weather_changed.connect(weather)
	AnimalHusbandry.state_changed.connect(husbandry)
	EventBus.flag_changed.connect(flag)
	EventBus.outfit_changed.connect(outfit)
	WardrobeManager.owned_changed.connect(owned)
	EventBus.furniture_changed.connect(furniture)
	EventBus.player_inventory_changed.connect(inventory)
	EventBus.gold_changed.connect(gold)
	GameManager.start_new_game("OldWave", GameManager.CharacterType.ANIMAL)
	EventBus.gold_changed.disconnect(gold)
	EventBus.player_inventory_changed.disconnect(inventory)
	EventBus.weather_changed.disconnect(weather)
	AnimalHusbandry.state_changed.disconnect(husbandry)
	EventBus.flag_changed.disconnect(flag)
	EventBus.outfit_changed.disconnect(outfit)
	WardrobeManager.owned_changed.disconnect(owned)
	EventBus.furniture_changed.disconnect(furniture)
	t.check(kind + "_successful_load_immediate", entered == [kind, true, true], "public synchronous successful nested load; %s" % [entered])
	t.check(kind + "_winner_after_whole_unwind", not winner.is_empty() and _snapshot(saves) == winner, "no remaining starter iteration or later reset listener may change loaded progress/stores/queues")
	await t.frames(4)
	t.check(kind + "_loaded_owed_automatic", EconomyManager.count_item(&"wood") == wood + 3 and QuestManager.pending_rewards.is_empty() and QuestManager.is_active(&"lost_cat") and QuestManager.is_completed(&"supply_run") and WardrobeManager.count_total(&"dress_sun_meadow") == 1 and FurnitureManager.count_total(&"sofa_leaf") == 1 and LootService.claimed.has("fairy_lily:6"), "automatic exactly-once loaded reward without extra event/manual claim")
	await t.frames(3)
	t.check(kind + "_future_live_once", EconomyManager.count_item(&"wood") == wood + 3 and SocialManager.add_points(&"fairy_lily", 1).ok and saves.save_game(2) and not saves.network_admission_blocked())


func _whole_normal(saves: Node) -> bool:
	var kits := true
	for entry in EconomyManager._starter_kit():
		kits = kits and EconomyManager.count_item(StringName(str(entry[0]))) == int(entry[1])
	return kits and EconomyManager.gold == int(GameManager.config_value("economy.starting_gold", 500)) and QuestManager.active_quests.is_empty() and QuestManager.pending_rewards.is_empty() and LootService.claimed.is_empty() and saves.current_slot == -1 and saves.pending_world.is_empty()

func _ordinary(t, saves: Node, kind: String) -> void:
	var public_notifications: Array = []
	var inventory_notifications: Array = []
	var public := func(): public_notifications.append(true)
	var inventory := func(_pid, items): inventory_notifications.append(items)
	EventBus.new_game_started.connect(public)
	EventBus.player_inventory_changed.connect(inventory)
	if kind == "normal":
		GameManager.start_new_game("NormalWave", GameManager.CharacterType.ANIMAL)
		t.check("normal_complete_wave", _whole_normal(saves) and GameManager.player_name == "NormalWave" and public_notifications.size() == 1)
		EconomyManager.gold = 12
		EventBus.new_game_started.emit() # supported no-argument legacy broadcast
		t.check("normal_legacy_raw_signal", _whole_normal(saves) and public_notifications.size() == 2)
		EconomyManager.gold = 19
		EconomyManager.reset() # supported independent direct callee
		t.check("normal_direct_reset", _whole_normal(saves) and public_notifications.size() == 2)
	else:
		# Notifications genuinely queue, then the first observer replaces the run
		# while the reset's remaining queued publications are being drained.
		t.check("deferred_winner_saved", saves.save_game(1))
		var entered: Array = []
		var callback := func(_pid, _items):
			if not entered.is_empty(): return
			entered.append(true)
			entered.append(saves.load_game(1))
		EventBus.player_inventory_changed.connect(callback)
		EconomyManager.defer_notifications(func(): GameManager.start_new_game("DeferredWave", GameManager.CharacterType.ANIMAL))
		EventBus.player_inventory_changed.disconnect(callback)
		t.check("deferred_real_success", entered == [true, true])
		# The genuine load has its own ordinary inventory notification. Old reset
		# notifications after the first must not run on the loaded incarnation.
		t.check("deferred_old_publications_cancelled", inventory_notifications.size() == 2 and saves.current_slot == 1, "one old committed notification + genuine loaded notification; %d" % inventory_notifications.size())
	EventBus.player_inventory_changed.disconnect(inventory)
	EventBus.new_game_started.disconnect(public)
	await t.frames(3)
	t.check(kind + "_independent_next_operation", saves.save_game(2) and saves.load_game(2) and not saves.network_admission_blocked())

func _nested(t, saves: Node, kind: String) -> void:
	var entered: Array = []
	var winner: Dictionary = {}
	var outer_profile: Array = []
	var callback := func(_pid, _items):
		var limit := 2 if kind == "two_level" else 1
		if entered.size() >= limit: return
		entered.append(GameManager.player_name)
		if kind == "nested_reset": saves.reset()
		elif kind == "nested_roster":
			var roster := PlayerRoster.new()
			roster.reset()
			roster.free()
		elif kind == "raw_reentry": EventBus.new_game_started.emit()
		else: GameManager.start_new_game("MiddleWave" if entered.size() < limit else "NewestWave", GameManager.CharacterType.GHOST)
		# Inner/newest callback alone commits distinct progress. Older test
		# observer does not compensate for stale production writes.
		if winner.is_empty():
			EconomyManager.gold = 991
			EconomyManager.add_item(&"stone", 23, true)
			QuestManager.accept_quest(&"lost_cat")
			winner.merge(_snapshot(saves))
	EventBus.player_inventory_changed.connect(callback)
	GameManager.start_new_game("OuterWave", GameManager.CharacterType.ANIMAL)
	EventBus.player_inventory_changed.disconnect(callback)
	t.check(kind + "_entered", entered == (["OuterWave", "MiddleWave"] if kind == "two_level" else ["OuterWave"]))
	t.check(kind + "_newest_survives", not winner.is_empty() and _snapshot(saves) == winner and EconomyManager.gold == 991 and QuestManager.is_active(&"lost_cat"), "newest synchronous reset/current-owner progress remains after every older subscriber returns")
	t.check(kind + "_next_save_load", saves.save_game(1) and saves.load_game(1) and not saves.network_admission_blocked())

func _failed(t, saves: Node, kind: String) -> void:
	var late := Callback.Rollback.LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("mp4_wave_late", late, 1000)
	t.check(kind + "_genuine_disk_saved", saves.save_game(1))
	var entered: Array = []
	var after: Dictionary = {}
	var callback := func(_pid, _items):
		if not entered.is_empty(): return
		entered.append(kind)
		if kind == "full_failed":
			# Canonical FULL rollback preimage, explicitly distinct from retained
			# raw sparse/incomplete controls (which MUST NOT revive authority).
			EconomyManager.from_dict(EconomyManager.to_dict())
			QuestManager.from_dict(QuestManager.to_dict())
			WardrobeManager.to_dict()
			HomeManager.from_dict(HomeManager.to_dict())
		var profile := PlayerRegistry.peek_state(&"p0")
		late.rejects = 1
		entered.append(saves.load_game(1))
		entered.append(late.calls)
		entered.append(PlayerRegistry.peek_state(&"p0") == profile)
		after.merge(_snapshot(saves))
	EventBus.player_inventory_changed.connect(callback)
	GameManager.start_new_game("FailedWave", GameManager.CharacterType.ANIMAL)
	EventBus.player_inventory_changed.disconnect(callback)
	if kind == "full_failed":
		t.check("full_failed_authenticated_restore", entered == [kind, false, 2, true] and not str(saves.last_error).contains("incomplete"), "%s %s" % [entered, saves.last_error])
		t.check("full_failed_whole_wave_progress", _whole_normal(saves), "same-owner starter remainder and all later resets complete after real restored refusal")
	else:
		t.check("incomplete_genuine_refusal", entered.size() == 4 and entered[1] == false and entered[2] == 2 and str(saves.last_error).contains("incomplete"), "%s %s" % [entered, saves.last_error])
		t.check("incomplete_cannot_revive_wave", not after.is_empty() and _snapshot(saves) == after, "incomplete rollback never licenses suspended older writes")
	t.check(kind + "_released_future", saves.save_game(2) and saves.load_game(2) and not saves.network_admission_blocked() and saves.ApplyGuard.alive == 0)
	saves.unregister_section("mp4_wave_late")
	late.free()
