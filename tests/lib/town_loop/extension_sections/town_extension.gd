extends RefCounted
const SECTION := "town_extension"
const TIMEOUT_S := 90.0
func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var lr: Node = t.autoload("LuaRuntime")
	var sm: Node = t.autoload("SocialManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.set_config_override("towns.curfew.enabled", false)
	await LoopClock.at(t, 0, 10)
	await t.world().travel(&"hyggebyen", &"default")
	var door := TownProbe.door(t, "loop_shop")
	t.check("l18_data_only_building", door != null and door.is_open() and WorldRoot2D.has_area(&"int_loop_shop"))
	if door == null:
		return
	await t.world().travel(&"hyggebyen", &"from_int_loop_shop")
	var entered := await LoopWalker.walk_to(t, door.global_position, 5, 15)
	await t.until(func(): return not t.world().traveling and t.world().area.map.id == &"int_loop_shop", 8)
	var keeper := NpcDirector.node_of("loop_neighbour")
	t.check("l18_data_only_door_and_keeper", entered.ok and keeper != null and t.world().area.map.id == &"int_loop_shop" and t.world().area.global_to_cell(keeper.global_position).y < 2)
	var talks := preload("res://tests/sections/town_loop.gd").new()
	var shops := preload("res://tests/lib/town_loop/shops.gd").new()
	var opened := await shops.host(t, "talk")
	await talks._finish_dialogue(t)
	t.check("l18_data_only_citizen", opened and sm.hearts("loop_neighbour") == 1 and sm.people_rows().any(func(row): return str(row.id) == "loop_neighbour") and not SocialData.citizen("loop_neighbour").derived)
	opened = await shops.host(t, "shop")
	var panel: Control = TownProbe.screens(t).get_screen(&"shop_ui")
	t.check("l18_data_only_shop_hours", opened and panel.is_open() and panel.current_shop == &"loop_shop" and Hours.state("loop_shop", {"weekday":0,"hour":8}).reason == "hours" and Hours.state("loop_shop", {"weekday":0,"hour":10}).open)
	panel.close()
	var ctx := Routines.now_ctx()
	ctx.merge({"weekday":0,"total_day":1,"hour":11.0,"weather":"klart"}, true)
	var hoppe := NpcDirector.where_is("gardener_hoppe", ctx)
	t.check("l18_data_only_routine_edit", str(hoppe.place) == "traetoppen.a_bench", str(hoppe))
	await t.world().travel(&"hyggebyen", &"default")
	t.check("l18_data_only_event", "loop_heart_event" in sm.events_ready("loop_neighbour") and not SocialData.event("loop_heart_event").is_empty())
	# A real post-box offer uses the newly configured mail giver and quest.
	gm.day = 2
	await t.world().travel(&"farm", &"default")
	var box: PostBox2D = t.world().area.find_markers("mailbox")[0].node
	box.refresh()
	box.interact(t.player())
	await t.frames(3)
	await talks._finish_dialogue(t, "quest_accept")
	await LoopClock.next_day(t)
	box.refresh()
	box.interact(t.player())
	await t.frames(3)
	await talks._finish_dialogue(t, "quest_accept")
	t.check("l18_data_only_quest", t.autoload("QuestManager").is_active(&"loop_mail"))
	gm.season = StringName(str(SocialData.festival("loop_festival").meta.season))
	gm.day = int(SocialData.festival("loop_festival").meta.day)
	gm.hour = 12
	gm.minute = 0
	t.check("l18_data_only_festival", sm.festival_today() == &"loop_festival" and sm.shop_closed_by_festival("seed_shop") and not sm.shop_closed_by_festival("loop_shop") and Hours.state("froebutikken").reason == "festival")
	gm.clear_config_overrides()
