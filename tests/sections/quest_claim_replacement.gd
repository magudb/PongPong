extends RefCounted
const SECTION := "quest_claim_replacement"
const TIMEOUT_S := 180.0

class RejectLate extends Node:
	var partial := false
	var data := {"reject":false}
	func to_dict() -> Dictionary: return data.duplicate(true)
	func reset() -> void: data = {"reject":false}
	func from_dict(d: Dictionary) -> bool:
		if partial or d.get("reject",false): return false
		data = d.duplicate(true)
		return true

func _full(eco: Node) -> void:
	eco.inventory.clear()
	for i in eco.INVENTORY_SLOTS:
		eco.inventory.append({"id":&"wood", "amount":99, "meta":{}})

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var saves: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	saves.autosave_enabled = false
	# Explicit separate scope probe: this root has no successful-load signal.
	# Default coverage retains all disk/backup/direct-roster cases unchanged.
	var modes := ["disk", "backup", "direct"]
	if OS.get_environment("TT_QUEST_CLAIM_DIRECT_APPLY") == "1": modes = ["direct_apply"]
	for mode in modes:
		gm.start_new_game("Winner", gm.character_type, "Winner")
		gm.set_config_override("time.minutes_per_real_second", 0.0)
		gm.clear_flag(&"intro_pending")
		_full(eco)
		qm.accept_quest(&"lost_cat")
		qm.complete_quest(&"lost_cat")
		t.check(mode+"_winner_legitimate_full_backpack_debt", qm.pending_rewards == {&"lost_cat":{"catnip_seeds":3}} and eco.count_item(&"catnip_seeds") == 0)
		eco.inventory.clear() # now room; deliberately no invented inventory notification
		PlayerRegistry.state(&"p1")
		PlayerRegistry.for_player(&"p1", func():
			qm.to_dict()
			eco.from_dict(eco.to_dict())
			eco.add_item(&"stone", 7, true))
		var payload: Dictionary = saves.gather_payload()
		t.check(mode+"_winner_healthy_deliverable_no_refresh", saves.validate_payload(payload).ok and payload.players.rows.p0.quests.active.is_empty() and eco.can_add_item(&"catnip_seeds", 3))
		saves.save_dir = "user://quest_claim_replacement/"+mode
		DirAccess.make_dir_recursive_absolute(saves.save_dir)
		var f := FileAccess.open(saves.slot_path(0), FileAccess.WRITE)
		f.store_string("not json" if mode == "backup" else JSON.stringify(payload)); f.close()
		if mode == "backup":
			var b := FileAccess.open(saves.backup_path(0), FileAccess.WRITE)
			b.store_string(JSON.stringify(payload)); b.close()
		gm.start_new_game("Old", gm.character_type, "Old")
		gm.clear_flag(&"intro_pending")
		_full(eco)
		qm.accept_quest(&"intro_lottery")
		qm.complete_quest(&"intro_lottery")
		t.check(mode+"_old_legitimate_full_backpack_debt", qm.pending_rewards == {&"intro_lottery":{"turnip_seeds":10}} and eco.count_item(&"turnip_seeds") == 0)
		eco.inventory.clear()
		qm.accept_quest(&"secret_garden")
		for i in 11: qm.complete_manual(&"secret_garden", StringName(SecretGardenStory.STEPS[i].id))
		t.check(mode+"_garden_finale_and_delivery_eligible", SecretGardenStory.step() == 11 and eco.can_add_item(&"turnip_seeds", 10))
		var marker := SecretGardenMarker.new()
		marker.kind = "bench"
		marker.area = t.world().area
		t.world().area.objects.add_child(marker)
		marker.interact(t.player())
		var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
		await t.page_to_choices(ui)
		t.check(mode+"_actual_physical_garden_page", ui.is_open())
		var observed: Array = []
		var immediate: Array = []
		var events: Array = []
		var on_item := func(pid, id, amount):
			events.append([pid, id, amount])
			if id != &"turnip_seeds" or not observed.is_empty(): return
			observed.append(eco.count_item(&"turnip_seeds") == 10 and qm._claiming_rewards)
			# The direct profile decoder is a real owner replacement without a
			# fabricated load_completed signal, matching existing alias controls.
			if mode == "direct_apply":
				observed.append(saves._apply_payload(payload).ok)
			else:
				observed.append(t.world().roster.from_dict(payload.players) if mode == "direct" else saves.load_game(0))
			immediate.append(PlayerRegistry._states[&"p0"].to_dict().duplicate(true))
			immediate.append(PlayerRegistry._states[&"p1"].to_dict().duplicate(true))
		bus.item_gained.connect(on_item)
		ui._pick({"action":"garden_work"})
		t.check(mode+"_real_sync_delivery_load_success", observed == [true,true], str(observed))
		t.check(mode+"_winner_immediate_owed_not_old_suffix", immediate.size() == 2 and eco.count_item(&"catnip_seeds") == 0 and qm.pending_rewards == {&"lost_cat":{"catnip_seeds":3}} and not qm.is_completed(&"secret_garden"))
		t.check(mode+"_whole_old_unwind_preserves_winner", immediate.size() == 2 and PlayerRegistry._states[&"p0"].to_dict() == immediate[0])
		await t.frames(4)
		t.check(mode+"_automatic_winner_delivery_exactly_once", eco.count_item(&"catnip_seeds") == 3 and qm.pending_rewards.is_empty() and events.count([&"p0", &"catnip_seeds", 3]) == 1, str({"events":events,"owed":qm.pending_rewards,"inventory":eco.get_inventory_dict()}))
		t.check(mode+"_unrelated_whole_profile_unchanged", immediate.size() == 2 and PlayerRegistry._states[&"p1"].to_dict() == immediate[1] and PlayerRegistry._states.size() == 2)
		await t.frames(4)
		t.check(mode+"_no_duplicate_deferred_delivery", eco.count_item(&"catnip_seeds") == 3 and events.count([&"p0", &"catnip_seeds", 3]) == 1 and eco.count_item(&"turnip_seeds") == 0)
		bus.item_gained.disconnect(on_item)
		t.check(mode+"_scope_and_claim_stack_released", PlayerRegistry._acting_id == &"" and not qm._claiming_rewards and not gm.lifecycle_busy())
		qm.accept_quest(&"intro_lottery")
		qm.complete_quest(&"intro_lottery")
		t.check(mode+"_next_actual_quest_rewards_once", qm.is_completed(&"intro_lottery") and eco.count_item(&"turnip_seeds") == 10 and qm.pending_rewards.is_empty())
		if ui.is_open(): ui.close()
		marker.free()
	await _queued_owner_controls(t)
	await _reentrant_and_rollback_controls(t)
	if OS.get_environment("TT_QUEST_CLAIM_DIRECT_SCOPE") == "1": await _direct_apply_scope_controls(t)
	gm.clear_config_overrides()

func _direct_apply_scope_controls(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var saves: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	for mode in ["success", "newest", "reset", "failed", "partial", "ui_reset"]:
		var successor: Dictionary = {}
		if mode == "newest":
			gm.start_new_game("Direct successor", gm.character_type)
			gm.clear_flag(&"intro_pending")
			_full(eco)
			qm.accept_quest(&"intro_lottery")
			qm.complete_quest(&"intro_lottery")
			eco.inventory.clear()
			PlayerRegistry.state(&"p1")
			PlayerRegistry.for_player(&"p1", func():
				qm.to_dict()
				eco.from_dict(eco.to_dict()))
			successor = saves.gather_payload()
		gm.start_new_game("Direct scoped", gm.character_type)
		gm.clear_flag(&"intro_pending")
		_full(eco)
		qm.accept_quest(&"lost_cat")
		qm.complete_quest(&"lost_cat")
		eco.from_dict(eco.to_dict())
		var loot: Node = t.autoload("LootService")
		loot.from_dict(loot.to_dict())
		# Drain setup's genuine codec/inventory tickets while the backpack is
		# still full. Opening space below emits no notification; failed apply
		# must not mint a new success ticket for that otherwise eligible debt.
		await t.frames(4)
		eco.inventory.clear()
		PlayerRegistry.state(&"p1")
		PlayerRegistry.for_player(&"p1", func():
			qm.to_dict()
			eco.from_dict(eco.to_dict()))
		var late := RejectLate.new()
		t.root.add_child(late)
		saves.register_section("claim_direct_late", late, 999)
		var payload: Dictionary = saves.gather_payload()
		t.check("direct_scope_"+mode+"_legitimate_eligible_debt", qm.pending_rewards == {&"lost_cat":{"catnip_seeds":3}} and eco.can_add_item(&"catnip_seeds",3) and saves.validate_payload(payload).ok)
		if mode in ["failed", "partial"]: payload.claim_direct_late.reject = true
		late.partial = mode == "partial"
		var before_p1: Dictionary = PlayerRegistry._states[&"p1"].to_dict().duplicate(true)
		var terminal_observed: Array = []
		if mode == "ui_reset":
			var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
			ui.request_page(null, {"id":"mayor_lyra"}, [{"text":"Direct apply finalizer"}], [{"action":"close"}], {"body":t.player()})
			ui.closed.connect(func():
				PlayerRegistry.reset_states()
				PlayerRegistry.for_player(&"p0", func():
					_full(eco)
					qm.accept_quest(&"intro_lottery")
					qm.complete_quest(&"intro_lottery")
					eco.inventory.clear()
					qm.to_dict()
					t.autoload("WardrobeManager").to_dict())
				terminal_observed.append(true), CONNECT_ONE_SHOT)
		var result: Dictionary = PlayerRegistry.for_player(&"p1", func():
			var applied: Dictionary = saves._apply_payload(payload)
			t.check("direct_scope_"+mode+"_conflicting_caller_restored", PlayerRegistry._acting_id == &"p1")
			return applied)
		t.check("direct_scope_"+mode+"_actual_apply_result", result.ok == (mode not in ["failed","partial"]))
		if mode == "newest":
			t.check("direct_scope_newest_actual_successor", PlayerRegistry.for_player(&"p1", func(): return saves._apply_payload(successor).ok))
		elif mode == "reset":
			PlayerRegistry.reset_states()
			qm.to_dict()
			t.autoload("WardrobeManager").to_dict()
		var immediate: Dictionary = PlayerRegistry._states[&"p0"].to_dict().duplicate(true)
		var deliveries: Array = []
		var record := func(pid,id,n): deliveries.append([pid,id,n])
		bus.item_gained.connect(record)
		await t.frames(4)
		var expected: Array = [[&"p0", &"catnip_seeds",3]] if mode == "success" else ([[&"p0", &"turnip_seeds",10]] if mode == "newest" else [])
		t.check("direct_scope_"+mode+"_qualified_automatic_delivery_only", deliveries == expected, str(deliveries))
		if mode in ["failed","partial","reset","ui_reset"]: t.check("direct_scope_"+mode+"_no_false_commit_ticket", PlayerRegistry._states[&"p0"].to_dict() == immediate)
		if mode == "ui_reset": t.check("direct_scope_ui_reset_actual_close_observer", terminal_observed == [true] and qm.pending_rewards == {&"intro_lottery":{"turnip_seeds":10}})
		if mode not in ["reset","ui_reset"]: t.check("direct_scope_"+mode+"_whole_unrelated_p1_unchanged", PlayerRegistry._states[&"p1"].to_dict() == before_p1, str({"before":before_p1,"after":PlayerRegistry._states[&"p1"].to_dict()}))
		t.check("direct_scope_"+mode+"_scope_and_root_released", PlayerRegistry._acting_id == &"" and not qm._claiming_rewards and not gm.lifecycle_busy())
		bus.item_gained.disconnect(record)
		saves.unregister_section("claim_direct_late")
		late.free()

func _queued_owner_controls(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var saves: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	# A queued p1 claim is not permission to drain an unrelated, eligible p0
	# debt, even when the inventory signal flushes under a conflicting scope.
	gm.start_new_game("Queue scopes", gm.character_type)
	gm.clear_flag(&"intro_pending")
	_full(eco)
	qm.accept_quest(&"intro_lottery")
	qm.complete_quest(&"intro_lottery")
	eco.inventory.clear()
	PlayerRegistry.for_player(&"p1", func():
		_full(eco)
		qm.accept_quest(&"lost_cat")
		qm.complete_quest(&"lost_cat")
		eco.inventory.clear())
	var host: Dictionary = PlayerRegistry._states[&"p0"].to_dict().duplicate(true)
	var signals: Array = []
	var observer := func(pid, id, n): signals.append([pid,id,n])
	bus.item_gained.connect(observer)
	# Economy transaction captures the real producing pid then flushes after
	# its scope unwinds; this is not a fabricated inventory event.
	eco.defer_notifications(func():
		PlayerRegistry.for_player(&"p1", func(): eco.add_item(&"stone", 1, true)))
	await t.frames(4)
	t.check("queue_p1_actual_notification_delivers_only_owner", PlayerRegistry.for_player(&"p1", func(): return eco.count_item(&"catnip_seeds") == 3 and qm.pending_rewards.is_empty()) and signals == [[&"p1", &"catnip_seeds",3]])
	t.check("queue_p1_whole_eligible_unrelated_p0_unchanged", PlayerRegistry._states[&"p0"].to_dict() == host and PlayerRegistry._states.size() == 2)
	t.check("queue_p1_ambient_scope_restored", PlayerRegistry._acting_id == &"")
	bus.item_gained.disconnect(observer)
	# Every queued ticket is tied to the actual decoded profile. A newer
	# healthy load wins; a direct raw registry reset grants no new authority.
	for mode in ["newest", "raw_reset"]:
		gm.start_new_game("First queued", gm.character_type)
		gm.clear_flag(&"intro_pending")
		_full(eco)
		qm.accept_quest(&"lost_cat")
		qm.complete_quest(&"lost_cat")
		eco.inventory.clear()
		var first: Dictionary = saves.gather_payload()
		gm.start_new_game("Newest queued", gm.character_type)
		gm.clear_flag(&"intro_pending")
		_full(eco)
		qm.accept_quest(&"intro_lottery")
		qm.complete_quest(&"intro_lottery")
		eco.inventory.clear()
		var second: Dictionary = saves.gather_payload()
		saves.save_dir = "user://quest_claim_replacement/queue_"+mode
		DirAccess.make_dir_recursive_absolute(saves.save_dir)
		for pair in [[0,first],[1,second]]:
			var f := FileAccess.open(saves.slot_path(pair[0]), FileAccess.WRITE)
			f.store_string(JSON.stringify(pair[1])); f.close()
		var actual: Array = []
		var record := func(pid,id,n): actual.append([pid,id,n])
		bus.item_gained.connect(record)
		t.check(mode+"_first_real_load_success", saves.load_game(0))
		if mode == "newest":
			t.check(mode+"_second_real_load_success", saves.load_game(1))
		else:
			PlayerRegistry.reset_states()
			# Existing UI readers normalize empty facade containers each frame.
			# Establish that independent reader state before the whole-row oracle.
			qm.to_dict()
			t.autoload("WardrobeManager").to_dict()
		var retained: PlayerState = PlayerRegistry._states[&"p0"]
		var before: Dictionary = retained.to_dict().duplicate(true)
		await t.frames(4)
		if mode == "newest":
			t.check(mode+"_only_latest_incarnation_automatic_once", eco.count_item(&"turnip_seeds") == 10 and eco.count_item(&"catnip_seeds") == 0 and qm.pending_rewards.is_empty() and actual == [[&"p0", &"turnip_seeds",10]])
		else:
			t.check(mode+"_revokes_without_rows_or_claims", actual.is_empty() and PlayerRegistry._states.size() == 1 and PlayerRegistry._states[&"p0"] == retained and retained.to_dict() == before, str({"events":actual,"rows":PlayerRegistry._states.keys(),"same_profile":PlayerRegistry._states[&"p0"] == retained,"before":before,"after":retained.to_dict()}))
		bus.item_gained.disconnect(record)
		t.check(mode+"_queued_stack_scope_released", PlayerRegistry._acting_id == &"" and not qm._claiming_rewards and not gm.lifecycle_busy())
		qm.accept_quest(&"lost_cat")
		qm.complete_quest(&"lost_cat")
		t.check(mode+"_next_actual_quest_healthy", eco.count_item(&"catnip_seeds") == 3 and qm.pending_rewards.is_empty())

func _reentrant_and_rollback_controls(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var eco: Node = t.autoload("EconomyManager")
	var saves: Node = t.autoload("SaveManager")
	var bus: Node = t.autoload("EventBus")
	gm.start_new_game("Reentrant claims", gm.character_type)
	gm.clear_flag(&"intro_pending")
	qm.register_quest_from_lua({"id":"zz_claim_multi", "objectives":[{"id":"done","on":"manual","target":1}], "rewards":{"items":{"wood":2,"stone":3}}, "meta":{}})
	# A test-only definition: the global quest registry must not carry it into later sections (quests lints every definition).
	t.on_cleanup(func(): qm.quest_defs.erase(&"zz_claim_multi"))
	PlayerRegistry.for_player(&"p1", func():
		_full(eco)
		qm.accept_quest(&"lost_cat")
		qm.complete_quest(&"lost_cat")
		eco.inventory.clear())
	var events: Array = []
	var observer := func(pid,id,n):
		events.append([pid,id,n])
		if pid == &"p0" and id == &"wood":
			qm.claim_rewards() # legitimate same-owner reentrant public facade
			PlayerRegistry.for_player(&"p1", func(): qm.claim_rewards())
	bus.item_gained.connect(observer)
	qm.accept_quest(&"zz_claim_multi")
	qm.complete_manual(&"zz_claim_multi", &"done")
	t.check("ordinary_multiitem_reentrant_inline_once", eco.count_item(&"wood") == 2 and eco.count_item(&"stone") == 3 and qm.pending_rewards.is_empty())
	await t.frames(4)
	t.check("reentrant_other_owner_independent_once", PlayerRegistry.for_player(&"p1", func(): return eco.count_item(&"catnip_seeds") == 3 and qm.pending_rewards.is_empty()) and events == [[&"p0",&"wood",2],[&"p0",&"stone",3],[&"p1",&"catnip_seeds",3]], str(events))
	t.check("reentrant_stack_and_scope_released", not qm._claiming_rewards and PlayerRegistry._acting_id == &"")
	bus.item_gained.disconnect(observer)
	for mode in ["failed", "partial"]:
		gm.start_new_game("Queued rollback", gm.character_type)
		gm.clear_flag(&"intro_pending")
		_full(eco)
		qm.accept_quest(&"lost_cat")
		qm.complete_quest(&"lost_cat")
		eco.inventory.clear()
		# Raw full-backpack construction removed equipped tools. Normalize via
		# the real codecs before demanding a genuine all-section rollback.
		eco.from_dict(eco.to_dict())
		var loot: Node = t.autoload("LootService")
		loot.from_dict(loot.to_dict())
		var late := RejectLate.new()
		t.root.add_child(late)
		saves.register_section("claim_late", late, 999)
		var payload: Dictionary = saves.gather_payload()
		payload.claim_late["reject"] = true
		saves.save_dir = "user://quest_claim_replacement/"+mode
		DirAccess.make_dir_recursive_absolute(saves.save_dir)
		var f := FileAccess.open(saves.slot_path(0), FileAccess.WRITE)
		f.store_string(JSON.stringify(payload)); f.close()
		var original: PlayerState = PlayerRegistry._states[&"p0"]
		var owed: Dictionary = qm.pending_rewards
		var nested: Dictionary = owed[&"lost_cat"]
		# A real producer queues work before admission. Complete rollback must
		# retain this lexical ticket as well as the restored legacy queue bit.
		eco.add_item(&"stone", 1, true)
		late.partial = mode == "partial"
		var before_payload: Dictionary = saves.gather_payload()
		t.check(mode+"_genuine_late_failed_load", not saves.load_game(0))
		var after_payload: Dictionary = saves.gather_payload()
		var delta := {}
		for key in before_payload:
			if before_payload[key] != after_payload.get(key): delta[key] = {"before":before_payload[key],"after":after_payload.get(key)}
		t.check(mode+"_queued_alias_restoration_policy", (PlayerRegistry._states[&"p0"] == original) == (mode == "failed"), str(delta))
		if mode == "failed":
			t.check(mode+"_owed_nested_aliases_restored", is_same(qm.pending_rewards, owed) and is_same(qm.pending_rewards[&"lost_cat"], nested))
		var delivered: Array = []
		var catch := func(pid,id,n): delivered.append([pid,id,n])
		bus.item_gained.connect(catch)
		await t.frames(4)
		t.check(mode+"_queued_work_restoration_policy", (eco.count_item(&"catnip_seeds") == 3 and nested.is_empty() and owed.is_empty() and delivered == [[&"p0",&"catnip_seeds",3]]) if mode == "failed" else (eco.count_item(&"catnip_seeds") == 0 and delivered.is_empty()))
		bus.item_gained.disconnect(catch)
		t.check(mode+"_rollback_claim_stack_released", not qm._claiming_rewards and PlayerRegistry._acting_id == &"" and not gm.lifecycle_busy())
		saves.unregister_section("claim_late")
		late.free()

