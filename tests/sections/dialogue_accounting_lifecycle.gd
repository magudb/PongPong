extends RefCounted
## Ordinary observer transitions inside the actual earned weekly-chat path.
const SECTION := "dialogue_accounting_lifecycle"
const TIMEOUT_S := 120.0

class LateReject extends Node:
	var data := {"v": 1, "reject": false}
	func to_dict() -> Dictionary: return data.duplicate(true)
	func reset() -> void: data = {"v": 1, "reject": false}
	func from_dict(d: Dictionary) -> bool:
		if d.get("reject", false): return false
		data = d.duplicate(true)
		return true

func _state(t) -> Dictionary:
	return {"social": t.autoload("SocialManager").to_dict().duplicate(true),
		"players": PlayerRegistry.state(&"p0").to_dict().duplicate(true),
		"loot": t.autoload("LootService").to_dict().duplicate(true),
		"flags": t.autoload("GameManager").world_flags.duplicate(true)}

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SocialManager")
	var saves: Node = t.autoload("SaveManager")
	var loot: Node = t.autoload("LootService")
	var bus: Node = t.autoload("EventBus")
	var late := LateReject.new()
	t.tree.root.add_child(late)
	saves.register_section("accounting_late_reject", late, 999)
	saves.save_dir = "user://accounting_lifecycle"
	saves.autosave_enabled = false
	for mode in ["reset", "load", "late_failure", "preflight", "backup"]:
		for seam in ["friend_last", "mirror", "points", "friend", "relation", "inventory", "item_gained", "loot_rolled", "keeper"]:
			if mode in ["late_failure", "preflight", "backup"] and seam not in ["friend_last", "mirror", "inventory"]: continue
			# Each positive save starts with an authenticated physical World.
			# The observer below still performs the intentional raw reset/load.
			await t.start_world("", "Accounting old", "Old")
			gm.set_config_override("time.minutes_per_real_second", 0.0)
			# Keeper's real authored threshold is three hearts. Other seams cross
			# the real first-stage threshold, with two otherwise-valid gift rows.
			if seam == "keeper": sm.debug_set_hearts("smith_thorin", 2)
			loot.set_loot_config({"gifts": [
				{"npc": "smith_thorin", "hearts": 1, "item": "wood"},
				{"npc": "smith_thorin", "hearts": 2 if seam == "keeper" else 0, "item": "stone"}] if seam != "keeper" else []})
			for slot in [0, 1]: saves.delete_save(slot)
			t.check(mode + "_" + seam + "_real_save_ready", saves.save_game(0))
			if mode == "late_failure" or mode == "backup":
				var payload: Dictionary = saves.gather_payload()
				payload.accounting_late_reject["reject"] = true
				var file := FileAccess.open(saves.slot_path(0), FileAccess.WRITE)
				file.store_string(JSON.stringify(payload))
				file.close()
				if mode == "backup":
					var backup := FileAccess.open(saves.backup_path(0), FileAccess.WRITE)
					payload.accounting_late_reject["reject"] = false
					backup.store_string(JSON.stringify(payload))
					backup.close()
			var actor := Npc2D.create({"id": "smith_thorin", "wander": "0"})
			t.world().add_child(actor)
			var ui: Control = t.tree.get_first_node_in_group("dialogue_ui")
			actor.interact(t.player())
			await t.page_to_choices(ui)
			var button: Button
			for candidate in ui._buttons:
				if candidate.get_meta("choice").get("action") == "close": button = candidate
			t.check(mode + "_" + seam + "_actual_weekly_chat_eligible", button != null and actor.is_talking and sm.chat_available("smith_thorin") and ui._shown > 0)
			var observed: Array = []
			var after: Array = []
			var transition := func():
				if not observed.is_empty(): return
				observed.append({"scope": str(PlayerRegistry._acting_id)})
				if mode == "reset": gm.start_new_game("Accounting new", gm.character_type, "New")
				else: observed[0]["loaded"] = saves.load_game(5 if mode == "preflight" else 0)
				observed[0]["state"] = _state(t)
			var on_flag := func(flag, _value):
				if seam == "friend_last" and flag == &"friend_last_smith_thorin" or seam == "mirror" and flag == &"friend_smith_thorin": transition.call()
			var on_event := func(kind, _data):
				if not observed.is_empty() and observed[0].has("state") and kind in [&"social_points", &"relationship_changed", &"chat_done", &"loot_keepsake_found"]: after.append(str(kind))
				if seam == "points" and kind == &"social_points" or seam == "relation" and kind == &"relationship_changed": transition.call()
			var on_friend := func(_pid, _npc, _hearts): transition.call() if seam == "friend" else false
			var on_inventory := func(_pid, _items): transition.call() if seam in ["inventory", "keeper"] else false
			var on_gained := func(_pid, _item, _amount):
				if not observed.is_empty() and observed[0].has("state"): after.append("item_gained")
				if seam == "item_gained": transition.call()
			var on_loot := func(_source, _rows):
				if not observed.is_empty() and observed[0].has("state"): after.append("loot_rolled")
				if seam == "loot_rolled": transition.call()
			bus.flag_changed.connect(on_flag)
			bus.game_event.connect(on_event)
			bus.friend_changed.connect(on_friend)
			bus.player_inventory_changed.connect(on_inventory)
			bus.item_gained.connect(on_gained)
			bus.loot_rolled.connect(on_loot)
			# Production button callback; completion and transition stay synchronous.
			PlayerRegistry.for_player(&"p0", func(): button.pressed.emit())
			t.check(mode + "_" + seam + "_observer_reached", observed.size() == 1 and observed[0].has("state"), str(observed))
			if observed.size() == 1 and observed[0].has("state"):
				if mode in ["reset", "load", "backup"]:
					t.check(mode + "_" + seam + "_no_old_effect_after_transition", _state(t) == observed[0].state and after.is_empty(), "after=" + str(after))
				else:
					t.check(mode + "_" + seam + "_failed_load_retains_earned_completion", observed[0].loaded == false and sm.points("smith_thorin") == 100 and not sm.chat_available("smith_thorin"), "points=" + str(sm.points("smith_thorin")))
					t.check(mode + "_" + seam + "_failed_load_retains_both_gifts_once", t.autoload("EconomyManager").count_item(&"wood") == 1 and t.autoload("EconomyManager").count_item(&"stone") == 1 and loot.claimed.has("smith_thorin:1") and loot.claimed.has("smith_thorin:0"), str(loot.claimed))
			bus.flag_changed.disconnect(on_flag)
			bus.game_event.disconnect(on_event)
			bus.friend_changed.disconnect(on_friend)
			bus.player_inventory_changed.disconnect(on_inventory)
			bus.item_gained.disconnect(on_gained)
			bus.loot_rolled.disconnect(on_loot)
			t.check(mode + "_" + seam + "_scope_and_hold_clean", PlayerRegistry._acting_id == &"" and not actor.is_talking and not actor._held and not ui.is_open())
			actor.free()
			await t.frames(2)
	loot.set_loot_config(null)
	gm.clear_config_overrides()
	saves.unregister_section("accounting_late_reject")
	late.free()
