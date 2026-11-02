extends RefCounted
const SECTION := "npc_story_origin"
const TIMEOUT_S := 180.0
class LateReject extends Node:
	var refuse_restore := false
	var data := {"reject":false}
	func to_dict() -> Dictionary: return data.duplicate(true)
	func reset() -> void: data = {"reject":false}
	func from_dict(d: Dictionary) -> bool:
		if d.get("reject", false) or refuse_restore: return false
		data = d.duplicate(true)
		return true
func run(t) -> void:
	for story in ["garden", "mother"]:
		for mode in ["normal", "depart", "failed", "depart_failed", "partial", "same", "direct"]:
			await t.start_world()
			var gm: Node = t.autoload("GameManager")
			var qm: Node = t.autoload("QuestManager")
			var saves: Node = t.autoload("SaveManager")
			var bus: Node = t.autoload("EventBus")
			gm.set_config_override("time.minutes_per_real_second", 0.0)
			saves.autosave_enabled = false
			saves.save_dir = "user://npc_story_origin"
			DirAccess.make_dir_recursive_absolute(saves.save_dir)
			var late := LateReject.new()
			t.root.add_child(late)
			saves.register_section("npc_story_late", late, 999)
			var body: Node = t.world()._make_player()
			t.world()._register_player(body, 1, 2)
			t.world().add_child(body)
			PlayerRegistry.for_player(&"p1", func():
				var economy: Node = t.autoload("EconomyManager")
				economy.from_dict(economy.to_dict())
				if story == "garden":
					qm.accept_quest(&"secret_garden")
					qm.complete_manual(&"secret_garden", &"clear_path"))
			if story == "mother":
				gm.set_flag(&"forest_mother_version", 1)
				gm.set_flag(&"forest_mother_v1_marked_lamp", gm.total_day())
			var npc: String = "gardener_hoppe" if story == "garden" else "mapseller_natteblik"
			var page: Dictionary = PlayerRegistry.for_player(&"p1", func(): return SecretGardenStory.topic_page(npc) if story == "garden" else MotherStory.topic_page(npc))
			var actor := Npc2D.create({"id":npc, "wander":"0"})
			actor.area = t.world().area
			t.world().add_child(actor)
			var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
			var ticket: RefCounted = actor._begin_followup(body, page)
			await t.page_to_choices(ui)
			var label: String = story+"_"+mode
			t.check(label+"_actual_story_page", ticket != null and ui.is_open() and not page.is_empty())
			var reached: Array = []
			var callback_return: Array = []
			PlayerRegistry.for_player(&"p0", func():
				qm.to_dict()
				var economy: Node = t.autoload("EconomyManager")
				economy.from_dict(economy.to_dict()))
			t.world().roster.to_dict() # canonical host display fields before exact comparison
			var owner_before: Dictionary = PlayerRegistry.for_player(&"p0", func(): return PlayerRegistry._states[&"p0"].to_dict())
			var callback := func(_session, _result, _reason):
				if not reached.is_empty(): return
				reached.append(true)
				if mode in ["depart", "depart_failed"]: t.world()._unregister_player(body)
				if mode in ["failed", "depart_failed", "partial", "same"]:
					var payload: Dictionary = saves.gather_payload()
					if mode != "same": payload.npc_story_late["reject"] = true
					late.refuse_restore = mode == "partial"
					var f := FileAccess.open(saves.slot_path(0), FileAccess.WRITE)
					f.store_string(JSON.stringify(payload)); f.close()
					reached.append(saves.load_game(0))
				elif mode == "direct":
					var same: Dictionary = t.world().roster.to_dict()
					PlayerRegistry.reset_states()
					reached.append(t.world().roster.from_dict(same))
				callback_return.append(PlayerRegistry._states[&"p0"].to_dict())
			bus.dialogue_session_ended.connect(callback)
			ui._pick({"action":"close"})
			bus.dialogue_session_ended.disconnect(callback)
			var earned: bool = mode in ["normal", "depart", "failed", "depart_failed"]
			var result: bool = PlayerRegistry.for_player(&"p1", func(): return SecretGardenStory.step() == 2 if story == "garden" else MotherStory.has("map_account"))
			t.check(label+"_original_earned_story_only", result == earned, str(reached))
			t.check(label+"_actual_transition", reached == ([true, true] if mode in ["same", "direct"] else ([true, false] if mode in ["failed", "depart_failed", "partial"] else [true])))
			# Successful load legitimately refreshes travel/vitals; an old suffix
			# must not change anything after that actual callback-return boundary.
			var expected_host: Dictionary = callback_return[0] if mode == "same" else owner_before
			t.check(label+"_conflicting_p0_no_old_suffix_writes", PlayerRegistry._states[&"p0"].to_dict() == expected_host, str({"before":expected_host,"after":PlayerRegistry._states[&"p0"].to_dict()}))
			t.check(label+"_no_scope_barrier_leak", PlayerRegistry._acting_id == &"" and not gm.lifecycle_busy() and not ui._suspended and ui._barrier == 0 and ui._records.is_empty())
			late.refuse_restore = false
			var next_body: Node = body
			if PlayerRegistry.registered_id(body) == &"":
				next_body = t.world()._make_player()
				t.world()._register_player(next_body, 1, 2)
				t.world().add_child(next_body)
			var next: RefCounted = actor._begin_followup(next_body, {"social":false, "lines":[{"text_key":"LIFE_BOARD_INTRO"}], "choices":[{"action":"close","text_key":"LIFE_LATER"}]})
			await t.page_to_choices(ui)
			t.check(label+"_next_real_page_open", next != null and ui.is_open())
			if ui.is_open(): ui._pick({"action":"close"})
			t.check(label+"_next_real_page_completes", next != null and next.resolved and not actor.is_talking and not actor._held)
			saves.unregister_section("npc_story_late")
			late.free(); actor.free()
			if is_instance_valid(next_body): t.world()._unregister_player(next_body)
			gm.clear_config_overrides()
			await t.frames(1)
	await _deferred_origin(t)

func _deferred_origin(t) -> void:
	for replace in [false, true]:
		await t.start_world()
		var gm: Node = t.autoload("GameManager")
		var qm: Node = t.autoload("QuestManager")
		gm.set_config_override("time.minutes_per_real_second", 0.0)
		qm.accept_quest(&"secret_garden")
		qm.complete_manual(&"secret_garden", &"clear_path")
		var actor := Npc2D.create({"id":"gardener_hoppe", "wander":"0"})
		actor.area = t.world().area
		t.world().add_child(actor)
		var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
		var ticket: RefCounted = actor._begin_followup(t.player(), {"social":false,"lines":[{"text_key":"LIFE_BOARD_INTRO"}],"choices":[{"action":"garden_story","text_key":"SG_TOPIC"}]})
		await t.page_to_choices(ui)
		var replaced: Array = []
		var on_terminal := func(_result):
			if not replaced.is_empty(): return
			replaced.append(true)
			if replace:
				var same: Dictionary = t.world().roster.to_dict()
				PlayerRegistry.reset_states()
				replaced.append(t.world().roster.from_dict(same))
		ui.session_finished.connect(on_terminal)
		ui._pick({"action":"garden_story"})
		ui.session_finished.disconnect(on_terminal)
		await t.frames(3)
		var label := "deferred_replacement" if replace else "deferred_normal"
		t.check(label+"_original_terminal_once", ticket.resolved and replaced == ([true,true] if replace else [true]))
		t.check(label+"_followup_requires_original_model", ui.is_open() == (not replace) and actor.is_talking == (not replace))
		if ui.is_open(): ui.close()
		var next: RefCounted = actor._begin_followup(t.player(), {"social":false,"lines":[{"text_key":"LIFE_BOARD_INTRO"}],"choices":[{"action":"close","text_key":"LIFE_LATER"}]})
		await t.page_to_choices(ui)
		t.check(label+"_next_independent_page_open", next != null and ui.is_open())
		if ui.is_open(): ui._pick({"action":"close"})
		t.check(label+"_next_independent_page_completes", next != null and next.resolved)
		actor.free()
		gm.clear_config_overrides()
