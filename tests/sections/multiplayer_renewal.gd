extends RefCounted
## In-callee ownership regressions; actual authored content and public services.
const SECTION := "multiplayer_renewal"
const TIMEOUT_S := 90.0

class RejectOnce extends Node:
	var reject := false
	func reset() -> void: pass
	func to_dict() -> Dictionary: return {"value": 1}
	func from_dict(_data: Dictionary) -> bool:
		if reject:
			reject = false
			return false
		return true

func run(t) -> void:
	var saves: Node = t.autoload("SaveManager")
	var prior: String = saves.save_dir
	t.on_cleanup(func(): saves.save_dir = prior)
	if not await t.start_world(): return
	saves.save_dir = "user://mp4-renewal-social"
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	var selected := OS.get_environment("MP4_RENEWAL_CASE")
	if selected == "rollback":
		_rollback_control(t, saves)
		await t.go_menu()
		return
	if selected != "lua":
		_social_gift(t, saves)
		for mode: String in ["normal", "mirror_load", "points_load", "stage_load", "guest", "row", "failed_load"]:
			await t.go_menu()
			if not await t.start_world(): return
			saves.save_dir = "user://mp4-renewal-social-" + mode
			DirAccess.make_dir_recursive_absolute(saves.save_dir)
			_social_boundary(t, saves, mode)
	await t.go_menu()
	if selected == "social": return
	if not await t.start_world(): return
	saves.save_dir = "user://mp4-renewal-lua"
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	for nested: bool in [false, true]:
		if nested:
			await t.go_menu()
			if not await t.start_world(): return
			saves.save_dir = "user://mp4-renewal-lua-nested"
			DirAccess.make_dir_recursive_absolute(saves.save_dir)
		_lua_terminal(t, saves, nested)
	await t.go_menu()
	if not await t.start_world(): return
	saves.save_dir = "user://mp4-renewal-effects"
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	_lua_effects(t, saves)
	await t.go_menu()
	if not await t.start_world(): return
	_lua_guest_pure(t)
	await t.go_menu()
	if not await t.start_world(): return
	saves.save_dir = "user://mp4-renewal-rollback"
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	_rollback_control(t, saves)
	await t.go_menu()

func _complete(quests: Node, def: Dictionary) -> void:
	for objective: Dictionary in def.get("objectives", []):
		quests.update_objective(&"lost_cat", StringName(str(objective.id)), int(objective.target))

func _social_gift(t, saves: Node) -> void:
	var quests: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var social: Node = t.autoload("SocialManager")
	var loot: Node = t.autoload("LootService")
	var npc := &"pippin_boegeknop"
	var def: Dictionary = quests.get_quest_def(&"lost_cat")
	quests.active_quests.clear()
	quests.accept_quest(&"lost_cat")
	var old: RefCounted = PlayerRegistry.peek_state(&"p0")
	var other: RefCounted = PlayerRegistry.state(&"p1")
	PlayerRegistry.for_player(&"p1", func():
		eco.from_dict(eco.to_dict())
		quests.from_dict(quests.to_dict()))
	var other_before: Dictionary = other.to_dict().duplicate(true)
	var gold_before: int = eco.gold
	t.check("social_authored_gift_eligible", quests.is_active(&"lost_cat") and def.rewards.friendship == {"pippin_boegeknop": 2} and social.hearts(npc) == 0 and social.befriend_reason(npc) == "" and not loot.claimed.has("pippin_boegeknop:2") and eco.can_add_item(&"painting_porthole", 1), "genuine two-heart recipient with authored painting gift; reward=%s hearts=%s reason=%s claimed=%s fits=%s active=%s" % [def.rewards.friendship, social.hearts(npc), social.befriend_reason(npc), loot.claimed.has("pippin_boegeknop:2"), eco.can_add_item(&"painting_porthole", 1), quests.is_active(&"lost_cat")])
	var observed: Array = []
	var replacement_at_callback := {}
	var social_at_callback := {}
	var loot_at_callback := {}
	var old_at_callback := {}
	var callback := func(id: StringName, friend: StringName, hearts: int):
		if friend != npc: return
		observed.append([id, hearts, saves.save_game(0), saves.load_game(0)])
		replacement_at_callback.merge(PlayerRegistry.peek_state(&"p0").to_dict().duplicate(true))
		social_at_callback.merge(social.to_dict().duplicate(true))
		loot_at_callback.merge(loot.to_dict().duplicate(true))
		old_at_callback.merge(old.to_dict().duplicate(true))
	EventBus.friend_changed.connect(callback, CONNECT_ONE_SHOT)
	_complete(quests, def)
	t.check("social_actual_friend_callback_loaded", observed == [[&"p0", 2, true, true]] and PlayerRegistry.peek_state(&"p0") != old, "committed grant saved then successfully disk-loaded inside actual SocialManager signal")
	t.check("social_first_commit_accounted", old.gold == gold_before + 150 and old.flags.get("friend_pippin_boegeknop") == 2 and &"lost_cat" in old.quests.completed and old.to_dict() == old_at_callback, "original gold/points/mirror/completion/owed unchanged after revoke")
	t.check("social_loaded_row_and_gift_untouched", PlayerRegistry.peek_state(&"p0").to_dict() == replacement_at_callback and social.to_dict() == social_at_callback and loot.to_dict() == loot_at_callback and not loot.claimed.has("pippin_boegeknop:2") and eco.count_item(&"painting_porthole") == 0, "old add_points cannot claim or deliver painting on loaded run")
	t.check("social_unrelated_loaded_row_unchanged", other.to_dict() == other_before and PlayerRegistry.peek_state(&"p1").to_dict() == other_before, "unrelated old and loaded player")
	var progress: Dictionary = social.add_hearts(npc, 1)
	t.check("social_future_current_progress_not_stranded", progress.ok and social.hearts(npc) == 3 and eco.count_item(&"painting_porthole") == 1 and loot.claimed.has("pippin_boegeknop:2"), "new current-owner earned progress delivers previously unclaimed eligible gift")
	loot.check_friend_gifts(npc)
	social.add_points(npc, 1)
	t.check("social_future_gift_exactly_once", eco.count_item(&"painting_porthole") == 1 and PlayerRegistry.peek_state(&"p1").to_dict() == other_before, "idempotent eligible gift, unrelated loaded row preserved")

func _social_boundary(t, saves: Node, mode: String) -> void:
	var social: Node = t.autoload("SocialManager")
	var eco: Node = t.autoload("EconomyManager")
	var quests: Node = t.autoload("QuestManager")
	var loot: Node = t.autoload("LootService")
	var npc := &"pippin_boegeknop"
	quests.active_quests.clear()
	quests.accept_quest(&"lost_cat")
	var old: RefCounted = PlayerRegistry.peek_state(&"p0")
	var gold: int = eco.gold
	var snapshot := {}
	var social_snapshot := {}
	var loot_snapshot := {}
	var toasts: Array = []
	var fired: Array = []
	var events: Array = []
	var mutate := func():
		if not fired.is_empty(): return
		fired.append(true)
		if mode.ends_with("load") and mode != "failed_load":
			fired.append(saves.save_game(0))
			fired.append(saves.load_game(0))
		elif mode == "failed_load":
			fired.append(saves.load_game(2)) # real absent-slot refusal, same owner
		elif mode == "guest":
			PlayerRegistry.world(t.tree).free()
			var guest: Node = load("res://scripts/world2d/world_2d.gd").new()
			guest.name = "World"
			guest.guest_bootstrap = true
			t.tree.root.add_child(guest)
			t.tree.current_scene = guest
		elif mode == "row":
			var replacement := PlayerState.new(&"p0", 1)
			replacement.reset_profile("SocialReplacement", 0, &"animal_fox")
			PlayerRegistry._states[&"p0"] = replacement
		snapshot.merge(PlayerRegistry.peek_state(&"p0").to_dict().duplicate(true))
		social_snapshot.merge(social.to_dict().duplicate(true))
		loot_snapshot.merge(loot.to_dict().duplicate(true))
		toasts.append_array(social._toast_queue.duplicate(true))
	var flag := func(id: StringName, _value: Variant):
		if mode == "mirror_load" and id == &"friend_pippin_boegeknop": mutate.call()
	var event := func(id: StringName, data: Dictionary):
		if id == &"social_points" and data.get("npc") == String(npc):
			events.append("points")
			if mode == "points_load": mutate.call()
		elif id == &"relationship_changed" and data.get("npc") == String(npc):
			events.append("stage")
			if mode == "stage_load": mutate.call()
	var friend := func(_pid, id, _hearts):
		if id != npc: return
		events.append("friend")
		if mode in ["guest", "row", "failed_load"]: mutate.call()
	EventBus.flag_changed.connect(flag)
	EventBus.game_event.connect(event)
	EventBus.friend_changed.connect(friend)
	_complete(quests, quests.get_quest_def(&"lost_cat"))
	EventBus.flag_changed.disconnect(flag)
	EventBus.game_event.disconnect(event)
	EventBus.friend_changed.disconnect(friend)
	if mode in ["normal", "failed_load"]:
		t.check("social_" + mode + "_essential_progress", (fired == [true, false] if mode == "failed_load" else fired.is_empty()) and PlayerRegistry.peek_state(&"p0") == old and eco.gold == gold + 150 and social.hearts(npc) == 2 and eco.count_item(&"painting_porthole") == 1 and loot.claimed.has("pippin_boegeknop:2") and quests.pending_rewards.is_empty() and GameManager.get_flag(&"cat_location_hidden") == false and events == ["points", "friend", "stage"], "same-owner real quest completes all authored effects despite harmless failed load")
		quests.complete_quest(&"lost_cat")
		loot.check_friend_gifts(npc)
		t.check("social_" + mode + "_exactly_once", eco.gold == gold + 150 and eco.count_item(&"painting_porthole") == 1, "no duplicate completion or automatic gift")
	else:
		t.check("social_" + mode + "_boundary_exercised", fired == ([true, true, true] if mode.ends_with("load") else [true]) and (not NetAuthority.can_write() if mode == "guest" else PlayerRegistry.peek_state(&"p0") != old), "actual named callback replaced authority")
		t.check("social_" + mode + "_replacement_frozen", PlayerRegistry.peek_state(&"p0").to_dict() == snapshot and social.to_dict() == social_snapshot and loot.to_dict() == loot_snapshot and social._toast_queue == toasts, "no old grant/gift/stage/toast after callback")
		t.check("social_" + mode + "_event_continuation_refused", events == (["points", "friend", "stage"] if mode == "stage_load" else (["points", "friend"] if mode in ["guest", "row"] else (["points"] if mode == "points_load" else []))), "each producer checks before next public event")

func _lua_terminal(t, saves: Node, nested := false) -> void:
	var tag := "lua_nested_" if nested else "lua_"
	var quests: Node = t.autoload("QuestManager")
	var game: Node = t.autoload("GameManager")
	var eco: Node = t.autoload("EconomyManager")
	quests.active_quests.clear()
	quests.accept_quest(&"lost_cat")
	game.set_flag(&"mp4_unrelated_world", "retained")
	var other: RefCounted = PlayerRegistry.state(&"p1")
	PlayerRegistry.for_player(&"p1", func():
		game.set_flag(&"mp4_unrelated_player", "retained")
		eco.from_dict(eco.to_dict())
		quests.from_dict(quests.to_dict()))
	var other_before: Dictionary = other.to_dict().duplicate(true)
	var old: RefCounted = PlayerRegistry.peek_state(&"p0")
	t.check(tag + "genuine_earlier_save", quests.is_active(&"lost_cat") and game.get_flag(&"lost_cat_active") == true and game.get_flag(&"cat_location_hidden") == true and saves.save_game(0), "real authored on_accept and valid disk save before completion")
	var origin_flags: Dictionary = game.world_flags
	var observed: Array = []
	var replacement_at_callback := {}
	var flags_at_callback := {}
	var old_at_callback := {}
	var callback := func(flag: StringName, value: Variant):
		if flag != &"lost_cat_active" or value != false or not observed.is_empty(): return
		observed.append(saves.load_game(0))
		if nested:
			game.set_flag(&"cat_location_hidden", false)
			LuaRuntime.call_quest_event("lost_cat", "quest_accepted")
		replacement_at_callback.merge(PlayerRegistry.peek_state(&"p0").to_dict().duplicate(true))
		flags_at_callback.merge(game.world_flags.duplicate(true))
		old_at_callback.merge(old.to_dict().duplicate(true))
	EventBus.flag_changed.connect(callback)
	_complete(quests, quests.get_quest_def(&"lost_cat"))
	EventBus.flag_changed.disconnect(callback)
	t.check(tag + "actual_terminal_callback_loaded", observed == [true] and PlayerRegistry.peek_state(&"p0") != old, "load succeeds inside first real lost_cat.handle_event terminal flag")
	t.check(tag + "loaded_terminal_flags_untouched", game.get_flag(&"cat_location_hidden") == true and game.get_flag(&"lost_cat_active") == true and game.world_flags == flags_at_callback and PlayerRegistry.peek_state(&"p0").to_dict() == replacement_at_callback, "second old Lua statement must not write into loaded run")
	t.check(tag + "origin_first_commit_retained", origin_flags.get("lost_cat_active") == false and origin_flags.get("cat_location_hidden") == true and &"lost_cat" in old.quests.completed and old.to_dict() == old_at_callback, "committed terminal first write stays with completed original row")
	t.check(tag + "unrelated_old_and_loaded_rows_unchanged", other.to_dict() == other_before and PlayerRegistry.peek_state(&"p1").to_dict() == other_before and game.get_flag(&"mp4_unrelated_world") == "retained", "other rows and unrelated world flags preserved")
	var gold: int = eco.gold
	_complete(quests, quests.get_quest_def(&"lost_cat"))
	var completed: Dictionary = PlayerRegistry.peek_state(&"p0").to_dict().duplicate(true)
	t.check(tag + "future_current_terminal_completes", quests.is_completed(&"lost_cat") and eco.gold == gold + 150 and game.get_flag(&"lost_cat_active") == false and game.get_flag(&"cat_location_hidden") == false and _lua_context_restored(), "new run can finish actual authored script after stale outer and nested work unwind")
	quests.complete_quest(&"lost_cat")
	t.check(tag + "future_idempotent_context_restored", PlayerRegistry.peek_state(&"p0").to_dict() == completed and _lua_context_restored(), "no replay or leaked old execution context")

func _lua_context_restored() -> bool:
	var origin: Variant = LuaRuntime.get("_effect_origin")
	return origin == null or (origin is Dictionary and origin.is_empty())

func _effect_state() -> Dictionary:
	return {"row": PlayerRegistry.peek_state(&"p0").to_dict().duplicate(true), "flags": GameManager.world_flags.duplicate(true), "zones": GameManager.unlocked_zones.duplicate(), "social": SocialManager.to_dict().duplicate(true), "loot": LootService.to_dict().duplicate(true)}

func _lua_effects(t, saves: Node) -> void:
	var effects := {
		"flag": 'api.set_flag("mp4_effect_mutation", false)',
		"gold": 'api.add_gold(11)',
		"item": 'api.add_item("wood", 1)',
		"remove": 'api.remove_item("turnip_seeds", 1)',
		"notification": 'api.notification("mp4_effect_notice", "notice")',
		"zone": 'api.unlock_zone("mp4_effect_zone")',
		"emit": 'api.emit("mp4_effect_event", {})',
		"hearts": 'api.add_hearts("pippin_boegeknop", 1)',
		"offer": 'api.offer_quest("lost_cat")',
		"complete": 'api.complete_quest("lost_cat")',
		"expression": 'api.set_flag("mp4_effect_mutation", api.emit("mp4_expression_trigger", {}))',
	}
	var quests: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	for kind: String in effects:
		quests.active_quests.clear()
		quests.completed_quests.clear()
		quests.offered_quests.clear()
		if kind == "complete": quests.accept_quest(&"lost_cat")
		eco.add_item(&"turnip_seeds", 2)
		GameManager.set_flag(&"mp4_effect_trigger", false)
		GameManager.set_flag(&"mp4_effect_mutation", true)
		var file := FileAccess.open("user://mp4_effect_probe.lua", FileAccess.WRITE)
		file.store_string('kind = "dialogue"\nid = "mp4_effect_probe"\nfunction get_dialogue(context)\n  if context.trigger then\n    api.set_flag("mp4_effect_trigger", true)\n  end\n  ' + effects[kind] + '\n  return { ok = true }\nend\n')
		file.close()
		var sid: String = LuaRuntime.load_file("user://mp4_effect_probe.lua")
		t.check("lua_effect_" + kind + "_eligible", sid != "" and saves.save_game(0) and (quests.is_active(&"lost_cat") if kind == "complete" else eco.count_item(&"turnip_seeds") >= 1), "real runtime parsed fixture and valid disk save; normal positive follows stale control")
		var observed: Array = []
		var snapshot := {}
		var emissions: Array = []
		var revoke := func():
			if not observed.is_empty(): return
			observed.append(saves.load_game(0))
			snapshot.merge(_effect_state())
		var flag := func(id: StringName, value: Variant):
			if id == &"mp4_effect_trigger" and value == true: revoke.call()
		var event := func(id: StringName, _payload: Dictionary):
			if id == &"mp4_expression_trigger": revoke.call()
			elif id == &"mp4_effect_event": emissions.append(id)
		var notice := func(title, _message, _icon):
			if title == "mp4_effect_notice": emissions.append(title)
		EventBus.flag_changed.connect(flag)
		EventBus.lua_event.connect(event)
		EventBus.notification_posted.connect(notice)
		LuaRuntime.get_dialogue("mp4_effect_probe", {"trigger": kind != "expression"})
		t.check("lua_effect_" + kind + "_stale_dispatch_refused", observed == [true] and _effect_state() == snapshot and emissions.is_empty() and _lua_context_restored(), "old statement or enclosing call after argument callback cannot borrow loaded state")
		EventBus.flag_changed.disconnect(flag)
		# The same otherwise-eligible effect must make real progress on its current owner.
		var before: Dictionary = _effect_state()
		var result: Dictionary = LuaRuntime.get_dialogue("mp4_effect_probe", {"trigger": false})
		EventBus.lua_event.disconnect(event)
		EventBus.notification_posted.disconnect(notice)
		t.check("lua_effect_" + kind + "_current_owner_progress", result.get("ok") == true and (_effect_state() != before or not emissions.is_empty()) and _lua_context_restored(), "identical interpreter/effect succeeds for live owner; queries/side effects not globally disabled")
	LuaRuntime.reload_scripts()

func _rollback_control(t, saves: Node) -> void:
	var quests: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var reject := RejectOnce.new()
	t.tree.root.add_child(reject)
	saves.register_section("mp4_rollback_control", reject, 10000)
	quests.active_quests.clear()
	quests.accept_quest(&"lost_cat")
	t.check("rollback_real_save_eligible", saves.save_game(0) and quests.is_active(&"lost_cat"), "genuine valid pre-completion save including healthy late section")
	var old: RefCounted = PlayerRegistry.peek_state(&"p0")
	var observed: Array = []
	var callback := func(flag: StringName, value: Variant):
		if flag != &"lost_cat_active" or value != false or not observed.is_empty(): return
		observed.append("entered") # before load: rollback itself emits this flag
		reject.reject = true
		observed.append(saves.load_game(0))
		observed.append(saves.last_error.get("code"))
		observed.append(PlayerRegistry.peek_state(&"p0") == old)
		observed.append(quests.is_completed(&"lost_cat"))
	EventBus.flag_changed.connect(callback)
	_complete(quests, quests.get_quest_def(&"lost_cat"))
	EventBus.flag_changed.disconnect(callback)
	t.check("rollback_actual_late_refusal_and_restore", observed == ["entered", false, "apply", true, true] and quests.is_completed(&"lost_cat"), "failed load really applied then completely rolled back; original completed profile identity preserved")
	t.check("rollback_same_run_essential_terminal_finishes", GameManager.get_flag(&"lost_cat_active") == false and GameManager.get_flag(&"cat_location_hidden") == false and _lua_context_restored(), "legitimate failed-load rollback must not strand already-earned authored terminal effect")
	var gold: int = eco.gold
	var row_after_rollback: Dictionary = PlayerRegistry.peek_state(&"p0").to_dict().duplicate(true)
	LuaRuntime.call_quest_event("lost_cat", "quest_accepted")
	LuaRuntime.call_quest_event("lost_cat", "quest_completed")
	t.check("rollback_future_current_progress", quests.is_completed(&"lost_cat") and eco.gold == gold and PlayerRegistry.peek_state(&"p0").to_dict() == row_after_rollback and GameManager.get_flag(&"cat_location_hidden") == false and _lua_context_restored(), "independent current authored work still runs without compensating reward or guard reset; not closure of stranded old effect")
	saves.unregister_section("mp4_rollback_control")
	reject.free()

func _lua_guest_pure(t) -> void:
	var page: Dictionary = LuaRuntime.get_dialogue("baker_maja", {})
	t.check("lua_guest_pure_offline_control", not page.is_empty(), "actual authored pure dialogue")
	PlayerRegistry.world(t.tree).free()
	var guest: Node = load("res://scripts/world2d/world_2d.gd").new()
	guest.name = "World"
	guest.guest_bootstrap = true
	t.tree.root.add_child(guest)
	t.tree.current_scene = guest
	t.check("lua_guest_pure_dialogue_preserved", not NetAuthority.can_write() and LuaRuntime.get_dialogue("baker_maja", {}) == page, "pure interpreted queries must not acquire write permission")
