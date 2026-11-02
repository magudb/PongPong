extends RefCounted
const SECTION := "presenter_retained_origin"
const TIMEOUT_S := 240.0
class LateReject extends Node:
	var reject_restore := false
	var data := {"v":1,"reject":false}
	func to_dict() -> Dictionary: return data.duplicate(true)
	func reset() -> void: data = {"v":1,"reject":false}
	func from_dict(value: Dictionary) -> bool:
		if reject_restore or value.get("reject",false): return false
		data = value.duplicate(true)
		return true
func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var saves: Node = t.autoload("SaveManager")
	var sm: Node = t.autoload("SocialManager")
	var bus: Node = t.autoload("EventBus")
	var late := LateReject.new()
	t.tree.root.add_child(late)
	saves.register_section("presenter_late", late, 999)
	saves.save_dir = "user://presenter_retained"
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	saves.autosave_enabled = false
	for seam in ["water", "record", "work", "reward"]:
		for mode in ["ordinary", "rollback", "load", "partial"]:
			gm.start_new_game("Retained", gm.character_type, "Retained")
			gm.set_config_override("time.minutes_per_real_second", 0.0)
			late.reject_restore = false
			late.data = {"v":1,"reject":false}
			gm.clear_flag(&"intro_pending")
			PlayerRegistry.state(&"p1") # deliberate unrelated-row fixture admission
			PlayerRegistry.for_player(&"p1", func():
				qm.to_dict()
				var economy: Node = t.autoload("EconomyManager")
				economy.from_dict(economy.to_dict()))
			var marker: Node
			if seam in ["water", "reward"]:
				qm.accept_quest(&"secret_garden")
				for i in (5 if seam == "water" else 11): qm.complete_manual(&"secret_garden", StringName(SecretGardenStory.STEPS[i].id))
				marker = SecretGardenMarker.new()
				marker.kind = "beds" if seam == "water" else "bench"
			else:
				gm.set_flag(&"forest_mother_version", 1)
				marker = MotherEvidenceMarker.new()
				marker.evidence_id = "marked_lamp" if seam == "record" else "memory_lamp"
			marker.area = t.world().area
			t.world().area.objects.add_child(marker)
			var payload: Dictionary = saves.gather_payload()
			if mode in ["rollback", "partial"]: payload.presenter_late["reject"] = true
			var file := FileAccess.open(saves.slot_path(0), FileAccess.WRITE)
			file.store_string(JSON.stringify(payload, "", true, true))
			file.close()
			var unrelated: Dictionary = PlayerRegistry._states[&"p1"].to_dict().duplicate(true)
			var gold: int = t.autoload("EconomyManager").gold
			var reached: Array = []
			var suffix: Array = []
			var at_return: Array = []
			var transition := func():
				if not reached.is_empty(): return
				reached.append(true)
				if mode == "partial": late.reject_restore = true
				if mode != "ordinary": reached.append(saves.load_game(0))
				at_return.append({"quest":qm.to_dict().duplicate(true), "hoppe":sm.hearts("gardener_hoppe"), "brumme":sm.hearts("carpenter_brumme")})
			var on_flag := func(key, _value):
				if (seam == "water" and key == SecretGardenStory.WATER_DAY) or (seam == "record" and key == &"forest_mother_v1_marked_lamp") or (seam == "work" and key == &"forest_mother_v1_work_memory_lamp"): transition.call()
			var on_gold := func(_pid, _gold, _delta):
				if seam == "reward": transition.call()
			var on_event := func(id, _payload):
				if id == &"forest_mother_work": suffix.append(true)
			marker.interact(t.player())
			var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
			await t.page_to_choices(ui)
			var label: String = seam+"_"+mode
			t.check(label+"_real_page", ui.is_open())
			bus.flag_changed.connect(on_flag)
			bus.gold_changed.connect(on_gold)
			bus.game_event.connect(on_event)
			ui._pick({"action":"garden_work" if seam in ["water", "reward"] else ("mother_record" if seam == "record" else "stitch_0")})
			bus.flag_changed.disconnect(on_flag)
			bus.gold_changed.disconnect(on_gold)
			bus.game_event.disconnect(on_event)
			t.check(label+"_actual_callback_and_load_result", reached == ([true] if mode == "ordinary" else [true, mode == "load"]), str(reached))
			var allowed: bool = mode in ["ordinary", "rollback"]
			match seam:
				"water": t.check(label+"_retained_callee_suffix", SecretGardenStory.step() == (6 if allowed else 5))
				"record": t.check(label+"_retained_callee_suffix", qm.is_active(&"forest_mother_s03") if allowed else qm.to_dict() == at_return[0].quest)
				"work": t.check(label+"_retained_callee_suffix", suffix.size() == (1 if allowed else 0))
				"reward":
					t.check(label+"_retained_callee_suffix", sm.hearts("gardener_hoppe") == (1 if allowed else 0) and sm.hearts("carpenter_brumme") == (1 if allowed else 0))
					if allowed: t.check(label+"_first_earned_gold_retained", t.autoload("EconomyManager").gold == gold+150)
			t.check(label+"_unrelated_owner_unchanged", PlayerRegistry._states[&"p1"].to_dict() == unrelated, str({"before":unrelated, "after":PlayerRegistry._states[&"p1"].to_dict()}))
			if ui.is_open(): ui.close()
			marker.free()
			late.reject_restore = false
			# A genuine independent operation after unwind must not inherit BUSY/suspension.
			var origin: RefCounted = preload("res://scripts/traetoppen/life/presenter_origin.gd").capture(t.world())
			t.check(label+"_next_operation_current", origin != null and origin.current())
			var completed: Array = []
			var next := LifeFlow.request(t.world(), "mayor_lyra", [{"text_key":"LIFE_BOARD_INTRO"}], [{"action":"close", "text_key":"LIFE_LATER"}], t.player(), func(_ticket, result): completed.append(result.completed))
			await t.page_to_choices(ui)
			t.check(label+"_next_actual_page_open", next != null and ui.is_open())
			if ui.is_open(): ui._pick({"action":"close"})
			t.check(label+"_next_actual_operation_completes_once", next != null and next.resolved and completed == [true])
			await t.frames(1)
	saves.unregister_section("presenter_late")
	late.free()
	gm.clear_config_overrides()
