extends RefCounted
const SECTION := "multiplayer_callback_ownership"
const TIMEOUT_S := 120.0
const Rollback := preload("res://tests/sections/multiplayer_rollback.gd")

func _lily_failed(t, saves: Node, kind: String) -> void:
	var late := Rollback.LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("mp4_callback_late", late, 1000)
	t.check(kind + "_eligible", SocialManager.befriend_reason(&"fairy_lily") == "" and SocialManager.hearts(&"fairy_lily") == 0 and EconomyManager.can_add_item(&"dress_sun_meadow") and EconomyManager.can_add_item(&"sofa_leaf") and saves.save_game(0))
	var origin := PlayerRegistry.peek_state(&"p0")
	var entered: Array = []
	var gains: Array = []
	var replace := func():
		if not entered.is_empty() or WardrobeManager.count_total(&"dress_sun_meadow") == 0: return
		entered.append(kind)
		late.rejects = 1
		entered.append(saves.load_game(0))
		entered.append(late.calls)
		entered.append(PlayerRegistry.peek_state(&"p0") == origin)
	var owned := func():
		if kind == "lily_failed_store": replace.call()
	var gained := func(_pid, id, n):
		gains.append([id, n])
		if kind == "lily_failed_item" and id == &"dress_sun_meadow": replace.call()
	WardrobeManager.owned_changed.connect(owned)
	EventBus.item_gained.connect(gained)
	SocialManager.add_hearts(&"fairy_lily", 6)
	EventBus.item_gained.disconnect(gained)
	WardrobeManager.owned_changed.disconnect(owned)
	t.check(kind + "_complete_rollback", entered == [kind, false, 2, true] and not str(saves.last_error).contains("incomplete"), "genuine late rejection and complete origin identity restoration; %s" % [entered])
	t.check(kind + "_earned_pair_continues", SocialManager.hearts(&"fairy_lily") == 6 and WardrobeManager.count_total(&"dress_sun_meadow") == 1 and FurnitureManager.count_total(&"sofa_leaf") == 1 and LootService.claimed.has("fairy_lily:3") and LootService.claimed.has("fairy_lily:6") and gains == [[&"dress_sun_meadow", 1], [&"sofa_leaf", 1]], "actual post-rollback remaining gift progresses automatically once")
	var gold := EconomyManager.gold
	LootService.check_friend_gifts("fairy_lily")
	t.check(kind + "_next_progress_once", EconomyManager.gold == gold and SocialManager.add_points(&"fairy_lily", 1).ok and SocialManager.points(&"fairy_lily") == 6 * SocialManager.points_per_heart() + 1 and saves.save_game(1) and not saves.network_admission_blocked(), "no duplicate gift sale; future current operation is live")
	saves.unregister_section("mp4_callback_late")
	late.free()


func run(t) -> void:
	var saves: Node = t.autoload("SaveManager")
	var prior: String = saves.save_dir
	t.on_cleanup(func(): saves.save_dir = prior)
	for kind: String in ["lily_item", "lily_store", "lily_failed_item", "lily_failed_store"]:
		if OS.get_environment("MP4_CALLBACK_CASE") != "" and OS.get_environment("MP4_CALLBACK_CASE") != kind: continue
		if not await t.start_world(): return
		saves.save_dir = "user://mp4-callback-" + kind
		DirAccess.make_dir_recursive_absolute(saves.save_dir)
		if kind == "lily_item": _lily_item(t, saves)
		elif kind == "lily_store": _lily_store(t, saves)
		else: _lily_failed(t, saves, kind)
		await t.go_menu()

func _snapshot(saves: Node) -> Dictionary:
	return {"game": GameManager.to_dict().duplicate(true), "profile": PlayerRegistry.peek_state(&"p0"), "row": PlayerRegistry.peek_state(&"p0").to_dict().duplicate(true), "loot": LootService.to_dict().duplicate(true), "furniture": FurnitureManager.to_dict().duplicate(true), "pending": saves.pending_world.duplicate(true), "run": saves.run_id, "slot": saves.current_slot}

func _matches(saves: Node, snap: Dictionary) -> bool:
	return _snapshot(saves) == snap

func _lily_item(t, saves: Node) -> void:
	var other := PlayerRegistry.state(&"p1")
	PlayerRegistry.for_player(&"p1", func():
		EconomyManager.from_dict(EconomyManager.to_dict())
		QuestManager.from_dict(QuestManager.to_dict()))
	var unrelated := other.to_dict().duplicate(true)
	var old := PlayerRegistry.peek_state(&"p0")
	var first_claims := LootService.claimed
	t.check("lily_item_eligible", SocialManager.befriend_reason(&"fairy_lily") == "" and SocialManager.hearts(&"fairy_lily") == 0 and not LootService.claimed.has("fairy_lily:3") and not LootService.claimed.has("fairy_lily:6") and EconomyManager.can_add_item(&"dress_sun_meadow") and EconomyManager.can_add_item(&"sofa_leaf") and saves.save_game(0), "actual authored Lily pair fits; real lower-heart winner disk save")
	var entered: Array = []
	var winner: Dictionary = {}
	var callback := func(pid: StringName, id: StringName, n: int):
		if id != &"dress_sun_meadow" or not entered.is_empty(): return
		entered.append([pid, id, n, LootService.claimed.has("fairy_lily:3"), WardrobeManager.count_total(id)])
		entered.append(saves.load_game(0))
		winner.merge(_snapshot(saves))
		entered.append(SocialManager.hearts(&"fairy_lily") == 0 and FurnitureManager.count_total(&"sofa_leaf") == 0 and not LootService.claimed.has("fairy_lily:6"))
	EventBus.item_gained.connect(callback)
	var result: Dictionary = SocialManager.add_hearts(&"fairy_lily", 6)
	EventBus.item_gained.disconnect(callback)
	t.check("lily_item_committed_boundary", result.ok and entered == [[&"p0", &"dress_sun_meadow", 1, true, 1], true, true], "first gift and its claim committed before actual successful winner load; %s" % [entered])
	t.check("lily_item_no_stale_second", not winner.is_empty() and _matches(saves, winner) and FurnitureManager.count_total(&"sofa_leaf") == 0 and not LootService.claimed.has("fairy_lily:6"), "winner immediately and after old gift loop unwind must be identical")
	t.check("lily_item_origin_accounted", old.wardrobe.owned.get("dress_sun_meadow", 0) == 1 and first_claims.has("fairy_lily:3") and not first_claims.has("fairy_lily:6") and PlayerRegistry.peek_state(&"p1").to_dict() == unrelated, "one committed first-origin gift/claim; no unrelated row loss")
	SocialManager.add_hearts(&"fairy_lily", 6)
	LootService.check_friend_gifts("fairy_lily")
	t.check("lily_item_next_owner_gifts_once", WardrobeManager.count_total(&"dress_sun_meadow") == 1 and FurnitureManager.count_total(&"sofa_leaf") == 1 and LootService.claimed.has("fairy_lily:3") and LootService.claimed.has("fairy_lily:6") and not saves.network_admission_blocked(), "loaded owner can earn both actual gifts once without borrowed cached eligibility")

func _lily_store(t, saves: Node) -> void:
	t.check("lily_store_eligible", SocialManager.befriend_reason(&"fairy_lily") == "" and SocialManager.hearts(&"fairy_lily") == 0 and EconomyManager.can_add_item(&"dress_sun_meadow") and saves.save_game(0), "real wardrobe and actual lower-heart winner save")
	var entered: Array = []
	var winner: Dictionary = {}
	var gained: Array = []
	var origin := PlayerRegistry.peek_state(&"p0")
	var callback := func():
		if not entered.is_empty() or WardrobeManager.count_total(&"dress_sun_meadow") == 0: return
		entered.append(not LootService.claimed.has("fairy_lily:3"))
		entered.append(saves.load_game(0))
		winner.merge(_snapshot(saves))
	var item := func(_pid, id, _n): gained.append(id)
	WardrobeManager.owned_changed.connect(callback)
	EventBus.item_gained.connect(item)
	SocialManager.add_hearts(&"fairy_lily", 6)
	EventBus.item_gained.disconnect(item)
	WardrobeManager.owned_changed.disconnect(callback)
	t.check("lily_store_precommit_boundary", entered == [true, true] and origin.wardrobe.owned.get("dress_sun_meadow", 0) == 1, "real owned_changed before loot accounting successfully replaces origin")
	t.check("lily_store_no_stale_accounting", not winner.is_empty() and _matches(saves, winner) and gained.is_empty() and not LootService.claimed.has("fairy_lily:3") and not LootService.claimed.has("fairy_lily:6"), "old store return cannot announce gains or commit claims/keepsakes on replacement; %s" % [gained])
	SocialManager.add_hearts(&"fairy_lily", 6)
	t.check("lily_store_future_earned", WardrobeManager.count_total(&"dress_sun_meadow") == 1 and FurnitureManager.count_total(&"sofa_leaf") == 1 and LootService.claimed.has("fairy_lily:3") and LootService.claimed.has("fairy_lily:6"), "replacement genuinely earns the authored pair via normal automatic Social route")
