extends RefCounted
## Cross-system regressions from the code review: real menus, save recovery, run resets, reward delivery and calendars.
const SECTION := "review_regressions"
const TIMEOUT_S := 120.0

class ShortWriteManager extends "res://scripts/autoload/save_manager.gd":
	func _store_text(file: FileAccess, text: String) -> void:
		file.store_string(text.substr(0, int(text.length() / 2.0)))

var t
var gm: Node
var qm: Node
var ah: Node
var eco: Node
var sm: Node
var bus: Node
var scratch: String


func run(p_t) -> void:
	t = p_t
	gm = t.autoload("GameManager")
	qm = t.autoload("QuestManager")
	ah = t.autoload("AnimalHusbandry")
	eco = t.autoload("EconomyManager")
	sm = t.autoload("SaveManager")
	bus = t.autoload("EventBus")
	var keep_dir: String = sm.save_dir
	var keep_auto: bool = sm.autosave_enabled
	var keep_clock: float = sm.clock_override
	var keep_locale: String = TranslationServer.get_locale()
	scratch = "user://review_regressions_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(scratch)
	sm.save_dir = scratch
	sm.autosave_enabled = false
	await t.go_menu()
	await _menus()
	await _new_game()
	_quest_batch()
	await _quest_rewards()
	await _repeatable_quests()
	_availability_gate()
	_animal_products()
	_animal_calendar()
	_animal_validation()
	_backup_recovery()
	await t.go_menu()
	t.autoload("LuaRuntime").reload_scripts()
	_fresh()
	for key in qm.quest_flags.keys():
		if str(key).begins_with("def_review_"):
			qm.quest_flags.erase(key)
	sm.save_dir = keep_dir
	sm.clock_override = keep_clock
	sm.autosave_enabled = keep_auto
	t.autoload("LocalizationManager").set_locale(keep_locale)
	for file_name in DirAccess.get_files_at(scratch):
		DirAccess.remove_absolute(scratch.path_join(file_name))
	DirAccess.remove_absolute(scratch)
	await t.frames(2)


func _fresh() -> void:
	gm.start_new_game("Review", gm.CharacterType.ANIMAL, "Review farm")
	gm.change_phase(gm.GamePhase.MENU)


func _quest(id: String, objective: String = "x", rewards: Dictionary = {}, meta: Dictionary = {}) -> void:
	qm.register_quest_from_lua({
		"id": id, "objectives": [{"id": objective, "target": 1}], "rewards": rewards, "meta": meta,
	})


func _full_backpack() -> void:
	eco.inventory.clear()
	for i in eco.INVENTORY_SLOTS:
		eco.inventory.append({"id": &"wood", "amount": 99, "meta": {}})


func _animal(species: String = "chicken", extra: Dictionary = {}) -> Dictionary:
	var d := {"id": "animal_1", "species": species, "is_baby": false, "age_days": 10, "happiness": 60.0, "hunger": 100.0}
	d.merge(extra, true)
	return {"v": 2, "animals": {"animal_1": d}, "buildings": {}, "counter": 1}


func _wipe_slots() -> void:
	for slot in sm.all_slots():
		sm.delete_save(slot)


func _menus() -> void:
	_fresh()
	_wipe_slots()
	sm.clock_override = 100.0
	gm.player_name = "Autosave hero"
	t.check("autosave_created", sm.autosave(), "")
	await t.go_menu()
	var menu: Node = t.tree.current_scene
	t.check("continue_enabled_for_autosave", not menu.get_node("%ContinueButton").disabled, "the only save is the auto slot")
	var mark: int = t.log_mark()
	var locale: String = TranslationServer.get_locale()
	menu.get_node("%LanguageButton").pressed.emit()
	t.check("language_changed", TranslationServer.get_locale() != locale, "")
	menu.get_node("%LanguageButton").pressed.emit()
	t.check("language_changed_back", TranslationServer.get_locale() == locale, "")
	var counts_ok := true
	for button_name in ["NewGameButton", "ContinueButton", "SettingsButton", "QuitButton", "LanguageButton"]:
		counts_ok = counts_ok and menu.get_node("%" + button_name).pressed.get_connections().size() == 1
	t.check("language_keeps_single_connections", counts_ok, "")
	t.expect_clean_since(mark, "language changes never reconnect initialized controls")
	menu.get_node("%ContinueButton").pressed.emit()
	var entered: bool = await t.until(func() -> bool: return t.in_world())
	t.check("continue_enters_autosave_world", entered and gm.player_name == "Autosave hero", "")
	await t.frames(2)
	await t.go_menu()

	_fresh()
	_wipe_slots()
	gm.player_name = "Older hero"
	sm.clock_override = 200.0
	t.check("older_manual_created", sm.save_game(0), "")
	gm.player_name = "Newest hero"
	sm.clock_override = 300.0
	t.check("newer_manual_created", sm.save_game(4), "")
	await t.go_menu()
	t.tree.current_scene.get_node("%ContinueButton").pressed.emit()
	entered = await t.until(func() -> bool: return t.in_world())
	t.check("continue_uses_latest_manual_slot", entered and gm.player_name == "Newest hero" and sm.current_slot == 4, "")
	await t.frames(2)
	await t.go_menu()

	await t.change_scene("res://scenes/ui/character_select.tscn")
	var select: Node = t.tree.current_scene
	select.get_node("%FairyButton").pressed.emit()
	select.get_node("%SkinOption").select(2)
	select.get_node("%SkinOption").item_selected.emit(2)
	var announced: Array = []
	var reset_skins: Array = []
	var on_character := func(skin: StringName) -> void: announced.append(skin)
	var on_new := func() -> void: reset_skins.append(gm.character_skin)
	bus.player_character_changed.connect(on_character)
	bus.new_game_started.connect(on_new)
	select.get_node("%ConfirmButton").pressed.emit()
	bus.player_character_changed.disconnect(on_character)
	bus.new_game_started.disconnect(on_new)
	t.check("selected_skin_announced_before_reset", announced == [&"fairy_dusk"] and reset_skins == [&"fairy_dusk"], str(announced))
	entered = await t.until(func() -> bool: return t.in_world())
	await t.frames(2)
	t.check("selected_skin_reaches_world", entered and gm.character_skin == &"fairy_dusk", "")
	await t.go_menu()


func _new_game() -> void:
	_fresh()
	_full_backpack()
	_quest("review_pending_reset", "x", {"items": {"turnip": 3}})
	qm.accept_quest(&"review_pending_reset")
	qm.complete_quest(&"review_pending_reset")
	_quest("review_active")
	_quest("review_offered")
	qm.accept_quest(&"review_active")
	qm.offer_quest(&"review_offered")
	qm.quest_flags["review_flag"] = true
	var d := _animal()
	d["buildings"] = {"coop_1": {"id": "coop_1", "building_type": "coop", "is_built": true}}
	ah.from_dict(d)
	t.check("dirty_run_has_state", not qm.active_quests.is_empty() and not ah.animals.is_empty(), "")
	gm.start_new_game("Fresh hero", gm.CharacterType.HOBBIT, "Fresh farm")
	gm.change_phase(gm.GamePhase.MENU)
	await t.frames(2)
	var quests: Dictionary = qm.to_dict()
	t.check("new_game_clears_quest_progress", quests["active"].is_empty() and quests["completed"].is_empty() and quests["offered"].is_empty() and not qm.quest_flags.has("review_flag"), "")
	t.check("new_game_clears_pending_rewards", quests.get("pending_rewards", {}).is_empty() and eco.count_item(&"turnip") == 0, "a queued claim from the old run must not feed the new backpack")
	t.check("new_game_preserves_quest_definitions", not qm.get_quest_def(&"intro_lottery").is_empty() and not qm.get_quest_def(&"review_active").is_empty(), "")
	var husbandry: Dictionary = ah.to_dict()
	t.check("new_game_clears_husbandry", husbandry["animals"].is_empty() and husbandry["buildings"].is_empty() and husbandry["counter"] == 0, "")
	var payload: Dictionary = sm.gather_payload()
	payload.erase("husbandry")
	ah.from_dict(d)
	t.check("save_without_husbandry_resets_live_animals", sm._apply_payload(payload)["ok"] and ah.animals.is_empty() and ah.buildings.is_empty(), "")


func _quest_batch() -> void:
	_fresh()
	for id in ["review_harvest_a", "review_harvest_b", "review_harvest_c"]:
		_quest(id, "harvest_any")
		qm.accept_quest(StringName(id))
	bus.crop_harvested.emit(&"plot_1", &"turnip", 1)
	t.check("one_harvest_updates_every_eligible_quest", qm.active_quests.is_empty() and qm.completed_quests.size() == 3, str(qm.completed_quests))
	_fresh()
	for id in ["review_ore_a", "review_ore_b", "review_ore_c"]:
		_quest(id, "collect_iron_ore")
		qm.accept_quest(StringName(id))
	bus.resource_node_depleted.emit(&"ore_1", [{"id": &"iron_ore", "amount": 1}])
	t.check("one_resource_updates_every_eligible_quest", qm.active_quests.is_empty() and qm.completed_quests.size() == 3, str(qm.completed_quests))
	_fresh()
	for id in ["review_daily_a", "review_daily_b", "review_daily_c"]:
		var path := "user://%s.lua" % id
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string('kind = "quest"\nid = "%s"\nobjectives = { { id = "x", target = 1 } }\nfunction on_day_started(context)\n api.complete_quest("%s")\nend\n' % [id, id])
		file.close()
		t.check("%s_loaded" % id, t.autoload("LuaRuntime").load_file(path) != "", "")
		DirAccess.remove_absolute(path)
		qm.accept_quest(StringName(id))
	bus.day_started.emit(gm.day, gm.season)
	t.check("one_day_updates_every_eligible_quest", qm.active_quests.is_empty() and qm.completed_quests.size() == 3, str(qm.completed_quests))


func _quest_rewards() -> void:
	_fresh()
	_full_backpack()
	_quest("review_rewards", "x", {"gold": 17, "items": {"turnip": 3, "carrot": 2}})
	var gold_before: int = eco.gold
	qm.accept_quest(&"review_rewards")
	qm.update_objective(&"review_rewards", &"x")
	var pending: Dictionary = qm.to_dict().get("pending_rewards", {})
	t.check("full_backpack_retains_quest_rewards", qm.is_completed(&"review_rewards") and pending.get("review_rewards", {}) == {"turnip": 3, "carrot": 2} and eco.count_item(&"turnip") == 0, str(pending))
	t.check("quest_gold_delivered_once", eco.gold == gold_before + 17, "")
	t.check("pending_rewards_saved", sm.save_game(2), "")
	_fresh()
	t.check("pending_rewards_load", sm.load_game(2), "")
	await t.frames(2)
	t.check("full_backpack_still_owes_rewards_after_load", qm.to_dict().get("pending_rewards", {}) == pending, "")
	eco.remove_item(&"wood", 99)
	await t.frames(2)
	var owed: Dictionary = qm.to_dict().get("pending_rewards", {}).get("review_rewards", {})
	var turnips_first: bool = eco.count_item(&"turnip") == 3 and eco.count_item(&"carrot") == 0 and owed == {"carrot": 2}
	var carrots_first: bool = eco.count_item(&"carrot") == 2 and eco.count_item(&"turnip") == 0 and owed == {"turnip": 3}
	t.check("one_free_slot_claims_only_what_fits", turnips_first or carrots_first, str(owed))
	# A synchronous item-gained listener must not re-enter the same outstanding grant.
	var reenter := func(_id: StringName, _amount: int) -> void: qm.claim_rewards()
	bus.item_gained.connect(reenter)
	eco.remove_item(&"wood", 99)
	await t.frames(2)
	bus.item_gained.disconnect(reenter)
	qm.claim_rewards()
	qm.complete_quest(&"review_rewards")
	t.check("remaining_rewards_claimed_without_duplicates", eco.count_item(&"turnip") == 3 and eco.count_item(&"carrot") == 2 and qm.to_dict().get("pending_rewards", {}).is_empty() and eco.gold == gold_before + 17, "")
	t.check("delivered_rewards_saved", sm.save_game(2), "")
	_fresh()
	t.check("delivered_rewards_load", sm.load_game(2), "")
	await t.frames(2)
	t.check("delivered_rewards_do_not_reappear", eco.count_item(&"turnip") == 3 and eco.count_item(&"carrot") == 2 and qm.to_dict().get("pending_rewards", {}).is_empty(), "")

	_fresh()
	_full_backpack()
	_quest("review_save_during_grant", "x", {"items": {"turnip": 3}})
	qm.accept_quest(&"review_save_during_grant")
	qm.complete_quest(&"review_save_during_grant")
	var saved_during_grant: Array = []
	var on_gain := func(_id: StringName, _amount: int) -> void: saved_during_grant.append(sm.save_game(2))
	bus.item_gained.connect(on_gain)
	eco.remove_item(&"wood", 99)
	await t.frames(2)
	bus.item_gained.disconnect(on_gain)
	t.check("save_inside_reward_callback_succeeds", saved_during_grant == [true], "")
	t.check("save_inside_reward_callback_loads", sm.load_game(2), "")
	await t.frames(2)
	t.check("save_inside_reward_callback_never_duplicates_items", eco.count_item(&"turnip") == 3 and qm.to_dict().get("pending_rewards", {}).get("review_save_during_grant", {}).is_empty(), "")
	var before: Dictionary = qm.to_dict()
	var invalid: Dictionary = before.duplicate(true)
	invalid["pending_rewards"] = {"review_save_during_grant": {"turnip": "bad"}}
	t.check("invalid_pending_rewards_rejected_without_mutation", not qm.from_dict(invalid) and qm.to_dict() == before, "")


func _repeatable_quests() -> void:
	_fresh()
	gm.day = 28
	_quest("review_repeat", "x", {}, {"repeatable": true, "cooldown_days": 3})
	_quest("review_once")
	qm.accept_quest(&"review_once")
	qm.complete_quest(&"review_once")
	qm.accept_quest(&"review_repeat")
	qm.complete_quest(&"review_repeat")
	qm.offer_quest(&"review_repeat")
	t.check("repeatable_waits_for_cooldown", not qm.accept_quest(&"review_repeat") and &"review_repeat" not in qm.offered_quests, "")
	gm.end_day()
	t.check("repeatable_counts_across_seasons", gm.day == 1 and not qm.accept_quest(&"review_repeat"), "")
	t.check("repeatable_timestamp_saved", sm.save_game(3), "")
	_fresh()
	t.check("repeatable_timestamp_load", sm.load_game(3), "")
	await t.frames(2)
	gm.end_day()
	t.check("repeatable_waits_until_exact_day", not qm.accept_quest(&"review_repeat"), "")
	gm.end_day()
	qm.offer_quest(&"review_repeat")
	t.check("repeatable_offered_after_cooldown", &"review_repeat" in qm.offered_quests and qm.accept_quest(&"review_repeat"), "")
	qm.complete_quest(&"review_repeat")
	t.check("repeatable_history_has_no_duplicates", qm.completed_quests.count(&"review_repeat") == 1 and not qm.accept_quest(&"review_repeat"), "")
	t.check("nonrepeatable_stays_completed", not qm.accept_quest(&"review_once"), "")
	# Saves from before completion dates existed remain loadable and start their cooldown at the loaded date.
	var old: Dictionary = qm.to_dict()
	old.erase("completed_days")
	qm.from_dict(old)
	t.check("old_quest_save_preserves_definitions_and_starts_cooldown", not qm.accept_quest(&"review_repeat") and not qm.get_quest_def(&"intro_lottery").is_empty(), "")


## The Lua is_available(context) hook gates offer AND accept (it was never invoked before the review): a closed gate
## refuses the quest, opening the flag lets it through, and context.home_tier reaches the hook (slotsdroemmen reads it).
func _availability_gate() -> void:
	_fresh()
	var path := "user://review_available.lua"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('kind = "quest"\nid = "review_available"\nobjectives = { { id = "x", target = 1 } }\nfunction is_available(context)\n  return api.has_flag("review_gate_open")\nend\n')
	file.close()
	t.check("gate_quest_loaded", t.autoload("LuaRuntime").load_file(path) != "", "")
	DirAccess.remove_absolute(path)
	qm.offer_quest(&"review_available")
	t.check("closed_gate_blocks_offer_and_accept", &"review_available" not in qm.offered_quests and not qm.accept_quest(&"review_available"), "")
	gm.set_flag(&"review_gate_open", true)
	qm.offer_quest(&"review_available")
	t.check("open_gate_allows_offer_and_accept", &"review_available" in qm.offered_quests and qm.accept_quest(&"review_available"), "")
	_quest("review_no_hook")
	qm.offer_quest(&"review_no_hook")
	t.check("missing_hook_stays_available", &"review_no_hook" in qm.offered_quests, "")
	qm.offer_quest(&"review_nonexistent")
	t.check("unknown_quest_never_offerable", &"review_nonexistent" not in qm.offered_quests, "")
	var tier_path := "user://review_tier.lua"
	var tf := FileAccess.open(tier_path, FileAccess.WRITE)
	tf.store_string('kind = "quest"\nid = "review_tier"\nobjectives = { { id = "x", target = 1 } }\nfunction is_available(context)\n  local tier = context.home_tier or 1\n  return tier >= 3\nend\n')
	tf.close()
	t.check("tier_quest_loaded", t.autoload("LuaRuntime").load_file(tier_path) != "", "")
	DirAccess.remove_absolute(tier_path)
	qm.offer_quest(&"review_tier")
	t.check("context_tier_gates_offer", &"review_tier" not in qm.offered_quests, "")
	gm.set_flag(&"home_tier", 3)
	qm.offer_quest(&"review_tier")
	t.check("context_tier_opens_gate", &"review_tier" in qm.offered_quests and qm.accept_quest(&"review_tier"), "")


func _animal_products() -> void:
	_fresh()
	ah.from_dict(_animal("chicken", {"products_ready": 2}))
	_full_backpack()
	var collected: Array = []
	var on_product := func(_id: StringName, _product: StringName, n: int) -> void: collected.append(n)
	ah.animal_product_collected.connect(on_product)
	t.check("full_backpack_keeps_animal_products", ah.collect_product(&"animal_1") == 0 and ah.get_animal(&"animal_1").products_ready == 2 and collected.is_empty(), "")
	t.check("unclaimed_animal_products_saved", sm.save_game(5), "")
	_fresh()
	t.check("unclaimed_animal_products_load", sm.load_game(5), "")
	eco.remove_item(&"wood", 99)
	t.check("animal_products_delivered_on_retry", ah.collect_product(&"animal_1") == 2 and eco.count_item(&"egg") == 2 and ah.get_animal(&"animal_1").products_ready == 0 and collected == [2], "")
	t.check("animal_products_cannot_be_collected_twice", ah.collect_product(&"animal_1") == 0 and eco.count_item(&"egg") == 2, "")
	ah.animal_product_collected.disconnect(on_product)


func _animal_calendar() -> void:
	for row in [["chicken", 1], ["rabbit", 2], ["sheep", 3]]:
		_fresh()
		gm.day = 28
		var start: int = gm.total_day()
		ah.from_dict(_animal(str(row[0]), {"last_product_day": start}))
		var animal = ah.get_animal(&"animal_1")
		for elapsed in range(1, int(row[1]) + 1):
			gm.end_day()
			t.check("%s_production_day_%d" % [row[0], elapsed], (animal.products_ready > 0) == (elapsed == int(row[1])), "the interval crosses the season boundary")
		var ready: int = animal.products_ready
		var produced_day: int = animal.last_product_day
		gm.end_day()
		t.check("%s_uncollected_product_is_preserved" % row[0], animal.products_ready == ready and animal.last_product_day == produced_day, "")

	_fresh()
	gm.day = 28
	gm.season = &"vinter"
	var old := _animal("rabbit", {"last_product_day": 28, "last_fed_day": 27})
	old.erase("v")
	gm.end_day()
	t.check("legacy_husbandry_loads", ah.from_dict(old), "")
	var animal = ah.get_animal(&"animal_1")
	t.check("legacy_animal_dates_migrate", animal.last_product_day == gm.total_day() - 1 and animal.last_fed_day == gm.total_day() - 2, "")
	gm.end_day()
	t.check("legacy_animal_produces_after_year_boundary", animal.products_ready > 0, "")
	var saved: Dictionary = ah.to_dict()
	t.check("absolute_animal_dates_roundtrip", ah.from_dict(saved) and ah.to_dict() == saved, "")

	_fresh()
	ah.from_dict(_animal("cat", {"last_product_day": 1}))
	animal = ah.get_animal(&"animal_1")
	for i in 3:
		gm.end_day()
	t.check("bond_products_are_not_daily_products", animal.products_ready == 0, "")
	ah._add_bond_xp(animal, 50.0)
	t.check("bond_event_creates_friendship_product", animal.products_ready == 1 and ah.collect_product(&"animal_1") == 1 and eco.count_item(&"friendship_token") == 1, "")


func _animal_validation() -> void:
	_fresh()
	ah.from_dict(_animal())
	var before: Dictionary = ah.to_dict()
	var invalid: Array = [
		_animal("missing_species"),
		{"animals": {"bad": 7}},
		{"animals": []},
		{"buildings": {"bad": {"building_type": "missing_building"}}},
		_animal("chicken", {"happiness": "happy"}),
		_animal("chicken", {"age_days": -1}),
		_animal("chicken", {"products_ready": 1.5}),
		_animal("chicken", {"is_baby": "yes"}),
		_animal("chicken", {"hunger": INF}),
		{"counter": "bad"},
		{"v": 999},
		{"animals": {"7": {"id": 7, "species": "chicken"}}},
		{"buildings": {"7": {"id": 7, "building_type": "coop"}}},
	]
	var rejected := true
	for data in invalid:
		rejected = rejected and not ah.from_dict(data) and ah.to_dict() == before
	t.check("invalid_husbandry_records_rejected_without_mutation", rejected, "")
	var payload: Dictionary = sm.gather_payload()
	payload["husbandry"] = _animal("missing_species")
	var file := FileAccess.open(sm.slot_path(1), FileAccess.WRITE)
	file.store_string(JSON.stringify(payload))
	file.close()
	var state_before: Dictionary = sm.gather_payload()
	t.check("invalid_husbandry_slot_not_loadable", sm.inspect_slot(1)["state"] == &"corrupt" and not sm.load_game(1), "")
	# Sections only: meta.timestamp / saved_at are wall clock, so two gathers can legitimately differ between them.
	var before_sections: Dictionary = state_before.duplicate(true)
	before_sections.erase("meta")
	var after_sections: Dictionary = sm.gather_payload()
	after_sections.erase("meta")
	t.check("invalid_husbandry_load_leaves_state_unchanged", after_sections == before_sections, "")
	gm.end_day()
	t.check("daily_tick_after_rejected_load_is_safe", ah.get_animal(&"animal_1").age_days == 11, "")


func _backup_recovery() -> void:
	_fresh()
	_wipe_slots()
	sm.clock_override = 500.0
	gm.player_name = "Recovery hero"
	t.check("backup_source_created", sm.save_game(0), "")
	gm.player_name = "Replacement hero"
	t.check("backup_created", sm.save_game(0), "")
	var backup: PackedByteArray = FileAccess.get_file_as_bytes(sm.backup_path(0))
	var primary := FileAccess.open(sm.slot_path(0), FileAccess.WRITE)
	primary.store_string("{}")
	primary.close()
	t.check("invalid_primary_uses_backup", sm.inspect_slot(0)["state"] == &"backup", "")
	var failing := ShortWriteManager.new()
	failing.save_dir = scratch
	failing.autosave_enabled = false
	t.root.add_child(failing)
	t.check("short_write_save_rejected", not failing.save_game(0), "")
	t.check("failed_save_preserves_valid_backup", FileAccess.get_file_as_bytes(sm.backup_path(0)) == backup and sm.inspect_slot(0)["state"] == &"backup", "")
	t.check("backup_recovers_original_hero", sm.load_game(0) and gm.player_name == "Recovery hero", "")
	failing.free()
