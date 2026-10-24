extends RefCounted
## Real world and owners, isolated by the audit's driver lifetime.
func open(t,_host: Node,ctx: Dictionary) -> Node:
	var phase := GameManager.current_phase
	await t.start_world()
	GameManager.set_config_override("time.minutes_per_real_second",0)
	GameManager.set_config_override("towns.curfew.enabled",false)
	var id := str(ctx.get("screen","home_chest"))
	HomeManager.set_tier(int(ctx.get("tier",2)))
	EconomyManager.add_gold(50000)
	EconomyManager.add_item(&"wood",100,true)
	EconomyManager.add_item(&"stone",80,true)
	EconomyManager.add_item(&"flour",4,true)
	EconomyManager.add_item(&"honey",4,true)
	EconomyManager.add_item(&"brush",1,true)
	if id=="animal_care_ui":
		AnimalHusbandry.build_building(&"coop",true)
		EconomyManager.buy_item(&"baby_chick",1,150)
		EconomyManager.add_item(&"chicken_feed",6,true)
	if str(ctx.get("area","farm"))=="home":await t.world().travel(&"home",&"default")
	GameManager.hour = 19
	GameManager.change_phase(phase)
	var node: Node = t.world().game_ui.get_screen(StringName(id))
	node.open()
	await t.frames(3)
	# Building/adopting the fixture posts notifications over the care buttons.
	# Start the audit with a clear modal instead of waiting for their TTL.
	t.world().game_ui.get_screen(&"hud").toasts.clear()
	await t.frames(2)
	return node
func close(t,_node: Node,_host: Node) -> void:
	await t.clear_scene()
	GameManager.clear_config_overrides()
