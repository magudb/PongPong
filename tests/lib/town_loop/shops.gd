extends RefCounted
## Live-room legs: movement and E select the same hosts a player uses.
var suite

func check(t, leg: String, id: String, ok: bool, detail := "") -> void:
	suite._check(t, leg, id, ok, detail)

func host(t, kind: String) -> bool:
	var hosts := TownProbe.hosts(t, kind)
	if hosts.is_empty():
		return false
	var route := await LoopWalker.walk_to(t, hosts[0].global_position, 7, 10)
	await t.physics(2)
	var selected: Node = t.player().nearest_interactable()
	if not route.ok or selected != hosts[0]:
		t.info("Counter approach: " + str(route) + " selected=" + str(selected) + " wanted=" + str(hosts[0]))
		return false
	t.tap(&"interact")
	await t.frames(3)
	return true

func run(t, owner) -> void:
	suite = owner
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SocialManager")
	var sys: Node = t.autoload("ShopSystem")
	var eco: Node = t.autoload("EconomyManager")
	await LoopClock.at(t, 1, 7)
	await t.world().travel(&"hyggebyen", &"from_int_froebutikken")
	var door := TownProbe.door(t, "froebutikken")
	check(t, "L05", "l05_closed_before_open", door != null and not door.is_open() and door.last_reason == "hours")
	if door == null:
		return
	var closed_walk := await LoopWalker.walk_to(t, door.global_position, 5, 15)
	await t.physics(3)
	check(t, "L05", "l05_closed_door_does_not_travel", closed_walk.ok and t.world().area.map.id == &"hyggebyen")
	# Leave the approach so the real body_entered signal can fire at opening.
	await LoopWalker.walk_to(t, t.world().area.get_spawn("from_int_froebutikken"), 5, 5)
	await LoopClock.to(t, 10)
	check(t, "L05", "l05_opens_from_registry", door.is_open() and Hours.hours_on(Hours.building("froebutikken"), 1) == [8.0, 18.0])
	var entered := await LoopWalker.walk_to(t, door.global_position, 5, 15)
	await t.until(func(): return not t.world().traveling and t.world().area.map.id == &"int_froebutikken", 8)
	check(t, "L04", "l04_door_enters", entered.ok and t.world().area.map.id == &"int_froebutikken", str(entered))
	if t.world().area.map.id != &"int_froebutikken":
		return
	check(t, "L04", "l04_iso_zone_zoom_and_budget", t.world().area.map.projection == &"iso" and t.world().area.map.zone == &"city" and int(InteriorRoom.stats.nodes) <= 130 and int(InteriorRoom.stats.lights) <= 4, str(InteriorRoom.stats))
	var keeper := NpcDirector.node_of("merchant_pip")
	var spec: Dictionary = t.world().area.get_meta("room_spec")
	check(t, "L04", "l04_keeper_behind_counter", keeper != null and t.world().area.global_to_cell(keeper.global_position).y < 2)
	var before: int = sm.hearts("merchant_pip")
	var talking := await host(t, "talk")
	var dialogue := TownProbe.dialogue(t)
	check(t, "L03", "l03b_keeper_talk_host_opens_dialogue", talking and dialogue.is_open())
	await suite._finish_dialogue(t)
	check(t, "L03", "l03b_keeper_weekly_heart_at_counter", talking and sm.hearts("merchant_pip") == before + 1)
	await host(t, "talk")
	await suite._finish_dialogue(t)
	check(t, "L03", "l03b_keeper_repeat_no_extra_heart", sm.hearts("merchant_pip") == before + 1)
	var opened := await host(t, "shop")
	var panel: Control = TownProbe.screens(t).get_screen(&"shop_ui")
	check(t, "L06", "l06_counter_opens_panel", opened and panel.is_open() and panel.current_shop == &"seed_shop")
	if panel.is_open():
		check(t, "L06", "l06_keeper_greeting_and_bust", panel.keeper_speech.text != "" and str(panel._info.get("keeper", "")) == "merchant_pip")
		var offer: Dictionary = {}
		for entry in sys.get_shop_inventory("seed_shop"):
			if str(entry.get("item_id", "")) == "carrot_seeds":
				offer = entry
		check(t, "L10", "l10_seeds_from_shop", not offer.is_empty())
		if not offer.is_empty():
			panel._select(offer)
			panel.stepper.value = 3
			var gold: int = eco.gold
			var owned: int = eco.count_item(&"carrot_seeds")
			var total: int = sys.get_buy_total("seed_shop", "carrot_seeds", 3)
			panel.buy_btn.grab_focus()
			t.tap(&"ui_accept")
			await t.frames(4)
			check(t, "L06", "l06_buy_exact", eco.gold == gold - total and eco.count_item(&"carrot_seeds") == owned + 3, "listed=" + str(total) + " charged=" + str(gold - eco.gold))
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
		check(t, "L06", "l06_escape_restores_world", not panel.is_open() and not gm.is_modal_open() and t.player().state == PlayerBody2D.S.FREE)
	# Closing requests must first close an active shop, then evict safely.
	await LoopClock.to(t, 17, 30)
	check(t, "L05", "l05_warning_thirty_minutes", not suite.probe.named("closing_warning").is_empty())
	await host(t, "shop")
	await LoopClock.to(t, 18)
	check(t, "L05", "l05_panel_closes_before_eviction", not panel.is_open() and t.world().area.map.id == &"hyggebyen" and not gm.is_modal_open())
	await LoopClock.at(t, 6, 10)
	var sunday := Hours.state("froebutikken")
	check(t, "L05", "l05_closed_weekday_reason", not sunday.open and sunday.reason == "day")
	# Always-open exits and the counter barrier use the installed room geometry.
	var p := preload("res://tests/lib/towns/room_probe.gd").new()
	await p.build(t, "int_froebutikken")
	check(t, "L04", "l04_counter_is_barrier", not p.reach(Iso.MASK_WALKING, Vector2i(4, 4)).has(Vector2i(4, 1)))
	var exits_open := false
	for node in p.area.triggers.get_children():
		if node is Door2D:
			exits_open = node.always_open and node.is_open()
	check(t, "L05", "l05_exit_always_open", exits_open)
	p.dispose()
	await _keeper(t, "bageriet", "baker_maja", 1, 10, "l06b_keeper_weekly_heart_at_noon")
	await _builder(t)

func _keeper(t, building: String, npc: String, weekday: int, hour: int, id: String) -> void:
	await LoopClock.at(t, weekday, hour)
	await t.world().travel(StringName("int_" + building), &"default")
	var sm: Node = t.autoload("SocialManager")
	var points: int = sm.hearts(npc)
	var opened := await host(t, "talk")
	await suite._finish_dialogue(t)
	check(t, "L06", id, opened and sm.hearts(npc) == points + 1)

func _builder(t) -> void:
	await LoopClock.at(t, 0, 12)
	await t.world().travel(&"int_toemmerhandlen", &"default")
	var opened := await host(t, "talk")
	var choice: Dictionary = await suite._finish_dialogue(t, "home_upgrade")
	# The talk's action opens the same event seam; close any resulting dialogue.
	if TownProbe.dialogue(t).is_open():
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
	var count_before: int = suite.probe.named("open_home_builder").size()
	var desk := await host(t, "desk")
	var events: Array = suite.probe.named("open_home_builder")
	var tier: int = t.autoload("GameManager").flag_int(&"home_tier", 1)
	check(t, "L06", "l06c_home_upgrade_desk_at_noon", opened and desk and str(choice.get("action", "")) == "home_upgrade" and events.size() == count_before + 1 and int(events[-1].payload.get("tier", -1)) == tier, str(choice) + " / " + str(events))
