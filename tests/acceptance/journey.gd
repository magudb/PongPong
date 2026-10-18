extends RefCounted
## Continuous fresh-save acceptance. No item/gold/quest/boss/health grants,
## teleports, clock overrides, custom maps or changes to combat definitions.
## --fast only runs ordinary physics/time faster than wall time.
const SECTION := "journey"
const TIMEOUT_S := 1800.0
var t
var native := false
var trace: Array[Dictionary] = []
var plots: Array[Vector2i] = []
var reactions: Dictionary = {}
var reaction_area := 0
var walking_to_exit := false
var finished := false

func run(context) -> void:
	t = context
	await _run()
	t.check("journey_finished",finished)
	JourneyWalker.tick_hook = Callable()
	JourneyWalker.precise_city_navigation = false
	if EventBus.area_change_requested.is_connected(_requested): EventBus.area_change_requested.disconnect(_requested)

func run_windowed(context) -> void:
	t = context
	native = true
	if OS.get_environment("JOURNEY_RESUME") == "":
		t.skip("native_earned_checkpoint", "Use an earned journey checkpoint; the full ordinary calendar is exercised by the accelerated headless run.")
		return
	await _run()
	t.check("journey_finished",finished)
	JourneyWalker.tick_hook = Callable()
	JourneyWalker.precise_city_navigation = false
	if EventBus.area_change_requested.is_connected(_requested): EventBus.area_change_requested.disconnect(_requested)

func _run() -> void:
	if not await t.boot(): return
	JourneyWalker.tick_hook = _travel_support
	JourneyWalker.precise_city_navigation = true
	EventBus.area_change_requested.connect(_requested)
	var resume := OS.get_environment("JOURNEY_RESUME")
	if resume != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveManager.save_dir))
		if not _check("copy_previously_earned_save",DirAccess.copy_absolute(resume,ProjectSettings.globalize_path(SaveManager.slot_path(3))) == OK): return
		var old_id: int = t.world().get_instance_id()
		if not _check("continue_earned_checkpoint",SaveManager.load_and_enter(3)): return
		await t.until(func(): return t.world() != null and t.world().get_instance_id() != old_id and t.world().ready_for_play,15)
		_note("resumed_earned_save",{"path":resume,"sha256":FileAccess.get_sha256(resume)})
	_note("opening", {"inventory":EconomyManager.get_inventory_dict()})
	if resume == "": t.check("normal_starter_wallet", EconomyManager.gold == 500)
	t.check("normal_clock", float(GameManager.config_value("time.minutes_per_real_second", 0)) > 0)
	if resume == "":
		if not await _farm(): return
		_save_checkpoint("farm")
	if not await _garden(): return
	if MotherStory.chapter() != "complete":
		if not await _prepare_forest(): return
		if not await _forest(): return
	if not await _home_upgrade(): return
	finished = await _continue_freeplay()
	EventBus.area_change_requested.disconnect(_requested)

func _requested(area_id: StringName, spawn: StringName) -> void:
	if t.player() == null or t.world() == null: return
	_note("area_request",{"destination":str(area_id),"spawn":str(spawn),"hearts":t.player().half_hearts,"player_state":int(t.player().state)})

func _travel_support(player: Player2D) -> void:
	if DungeonFloors.floor_of(player.area) == 0: return
	if player.half_hearts <= 6: player.drink()
	if walking_to_exit: return
	if reaction_area != player.area.get_instance_id():
		reactions.clear()
		reaction_area = player.area.get_instance_id()
	var now: float = t.game_seconds()
	for foe in player.area.objects.get_children():
		if not foe is Enemy2D: continue
		var id := foe.get_instance_id()
		if foe.state != Enemy2D.S.WINDUP:
			reactions.erase(id)
			continue
		if Iso.ground_dist(foe.global_position,player.global_position) > 950: continue
		if not reactions.has(id): reactions[id] = now+maxf(.4,foe.remaining-.3)
		if now < float(reactions[id]): continue
		var evade := Vector2(-foe.aim.y,foe.aim.x)
		# Both sides evade the telegraph. Prefer the side that continues the
		# current route, rather than repeatedly dodging back into a corner.
		var wanted := Input.get_vector("move_left","move_right","move_forward","move_back")
		if evade.dot(wanted) < 0: evade = -evade
		if player.test_move(player.global_transform,Iso.to_screen(evade*280)) and not player.test_move(player.global_transform,Iso.to_screen(-evade*280)): evade = -evade
		DungeonFightBot.steer(evade)
		if player.combat.dodge(): reactions[id] = INF

func _home_upgrade() -> bool:
	if HomeManager.tier >= 2: return true
	if not await _sell_surplus(): return false
	var required := HomeManager.gold_cost(2)
	var materials := LuaData.dict(HomeData.tier_def(2).cost.materials)
	for item in materials:
		required += ShopSystem.get_buy_total("builder_yard",str(item),maxi(0,int(materials[item])-EconomyManager.count_item(StringName(item))))
	while EconomyManager.gold < required:
		if not await _go_to("farm"): return false
		if not await _farm(): return false
	for item in materials:
		var missing := maxi(0,int(materials[item])-EconomyManager.count_item(StringName(item)))
		if missing > 0 and not await _buy("builder_yard",StringName(item),missing): return false
	if not await _go_to("farm"): return false
	t.tap(&"build_menu")
	await t.frames(3)
	var menu: Control = t.world().game_ui.get_screen(&"build_menu_ui")
	var house: Button = menu.find_child("HouseUpgrades",true,false)
	if not _check("farm_upgrade_menu_has_house",menu.is_open() and house != null): return false
	house.grab_focus()
	t.tap(&"ui_accept")
	await t.frames(3)
	var builder: Control = t.world().game_ui.get_screen(&"husbyggeri")
	if not _check("earned_house_requirements_met",builder.is_open() and not builder.build_button.disabled,str(HomeManager.can_start_upgrade(2))): return false
	builder.build_button.grab_focus()
	t.tap(&"ui_accept")
	await t.frames(3)
	var confirm: Button = builder.find_child("OkButton",true,false)
	if not _check("house_upgrade_asks_for_confirmation",confirm != null): return false
	confirm.grab_focus()
	t.tap(&"ui_accept")
	await t.frames(3)
	if not _check("earned_house_is_under_construction",HomeManager.is_under_construction()): return false
	t.tap(&"ui_cancel")
	await t.frames(3)
	if not await _sleep(): return false
	_note("house_upgraded")
	return _check("first_house_upgrade_earned",HomeManager.tier == 2)

func _continue_freeplay() -> bool:
	var before := {"gold":EconomyManager.gold,"entries":MotherStory.entries(),"home":HomeManager.tier,"farm":t.world().farm.to_dict()}
	if not _check("save_completed_journey",SaveManager.save_game(3)): return false
	var id: int = t.world().get_instance_id()
	if not _check("continue_completed_journey",SaveManager.load_and_enter(3)): return false
	await t.until(func(): return t.world() != null and t.world().get_instance_id() != id and t.world().ready_for_play,15)
	if not _check("ending_and_earned_progress_survive_continue",MotherStory.chapter() == "complete" and MotherStory.entries() == before.entries and EconomyManager.gold == before.gold and HomeManager.tier == before.home and t.world().farm.to_dict() == before.farm): return false
	if not await _go_to("secret_garden"): return false
	if native: await t.capture("earned_homecoming")
	var locale := TranslationServer.get_locale()
	for language in ["da","en"]:
		TranslationServer.set_locale(language)
		t.tap(&"journal")
		await t.frames(3)
		var journal: Control = t.world().game_ui.get_screen(&"quest_journal")
		journal._set_tab(3)
		await t.frames(3)
		var book: MotherJournal = journal._mother_journal
		var scroll: Control = book._rows.get_parent()
		_check("selected_journal_entry_visible_"+language,scroll.get_global_rect().grow(1).encloses(book.initial_focus().get_global_rect()))
		if native: await t.capture("earned_journal_"+language)
		t.tap(&"ui_cancel")
		await t.frames(3)
	TranslationServer.set_locale(locale)
	if not await _go_to("farm"): return false
	if not native and not await _sleep(): return false
	if not _check("ordinary_freeplay_after_ending",MotherStory.chapter() == "complete" and t.player().world_input_allowed() and GameManager.current_phase == GameManager.GamePhase.PLAYING): return false
	_note("verified_fresh_journey" if OS.get_environment("JOURNEY_RESUME") == "" else "verified_continuation")
	_save_checkpoint("complete")
	return true

func _prepare_forest() -> bool:
	if not QuestManager.is_completed(&"intro_lottery"):
		if not await _talk("mayor_lyra","close"): return false
		if not _check("lottery_completed_without_grants",QuestManager.is_completed(&"intro_lottery")): return false
	var best: StringName = EconomyManager.equipped_item(&"weapon")
	for id in EconomyManager.arsenal.owned_ids():
		if WeaponInfo.sword_equivalent(id) > WeaponInfo.sword_equivalent(best): best = id
	while WeaponInfo.sword_equivalent(best) < 20 and not MotherStory.boss_cleared(12):
		var offer: Dictionary = {}
		for row in ShopSystem.get_shop_inventory("smithy"):
			if int(row.get("stock",0)) > 0 and WeaponInfo.sword_equivalent(row.item_id) >= 20 and (offer.is_empty() or WeaponInfo.sword_equivalent(row.item_id) > WeaponInfo.sword_equivalent(offer.item_id)): offer = row
		if not _check("deep_floor_weapon_available",not offer.is_empty()): return false
		var price := ShopSystem.get_buy_total("smithy",str(offer.item_id),1)
		if EconomyManager.gold < price+500:
			if not await _go_to("farm"): return false
			if not await _farm(true): return false
			continue
		best = StringName(str(offer.item_id))
		if not await _buy("smithy",best,1): return false
	var supplies := EconomyManager.count_item(&"health_tonic")
	if supplies < 4 and not MotherStory.boss_cleared(12):
		var affordable := mini(4-supplies,floori(float(EconomyManager.gold)/maxi(1,ShopSystem.get_buy_price("magic_store",&"health_tonic"))))
		if affordable > 0 and not await _buy("magic_store",&"health_tonic",affordable): return false
	EconomyManager.equip(&"weapon",best)
	_note("forest_prepared",{"weapon":str(EconomyManager.equipment.get(&"weapon",&"")),"inventory":EconomyManager.get_inventory_dict()})
	_save_checkpoint("prepared")
	return true

func _open_shop(shop: String) -> Control:
	var building := Hours.building_of_shop(shop)
	for wait in 90:
		if Hours.is_open(building): break
		var state := Hours.state(building)
		if str(state.reason) in ["day","festival"] or GameManager.hour >= 18:
			if not await _go_to("farm"): return null
			if not await _sleep(): return null
		else:
			await _idle(300)
	if not await _go_to(str(Hours.building(building).get("interior",""))): return null
	var host: Node2D
	for node in t.tree.get_nodes_in_group("interactable"):
		if node is ShopCounter and node.kind == "shop" and node.shop_id == shop: host = node; break
	if not _check("staffed_counter_"+shop,host != null): return null
	if not await _use(host): return null
	var panel: Control = t.world().game_ui.get_screen(&"shop_ui")
	if not _check("shop_opened_"+shop,panel.is_open()): return null
	return panel

func _buy(shop: String, item: StringName, amount: int) -> bool:
	var panel := await _open_shop(shop)
	if panel == null: return false
	var row: Dictionary = {}
	for offer in ShopSystem.get_shop_inventory(shop):
		if str(offer.item_id) == str(item): row = offer; break
	if not _check("stock_available_"+str(item),not row.is_empty()): return false
	panel._select(row)
	panel.stepper.value = amount
	if not _check("requested_quantity_available_"+str(item),int(panel.stepper.value) == amount): return false
	var gold := EconomyManager.gold
	var owned := EconomyManager.count_item(item)
	var total := ShopSystem.get_buy_total(shop,item,amount)
	panel.buy_btn.grab_focus()
	t.tap(&"ui_accept")
	await t.frames(4)
	if not _check("paid_for_"+str(item),EconomyManager.gold == gold-total and EconomyManager.count_item(item) == owned+amount,"wallet="+str(gold)+" price="+str(total)): return false
	t.tap(&"ui_cancel")
	await t.frames(3)
	_note("purchase",{"item":str(item),"amount":amount,"paid":total})
	return true

func _sell_surplus() -> bool:
	var panel := await _open_shop("seed_shop")
	if panel == null: return false
	for i in panel._tabs.size():
		if bool(panel._tabs[i].get("sell",false)): panel._set_tab(i); break
	for offer in ShopSystem.get_sell_list("seed_shop"):
		if str(ItemKinds.def(offer.item_id).get("category","")) not in ["resource","forage","mineral","gem"]: continue
		var amount := int(offer.amount)
		panel._select(offer)
		panel.stepper.value = amount
		var gold := EconomyManager.gold
		panel.buy_btn.grab_focus()
		t.tap(&"ui_accept")
		await t.frames(4)
		if not _check("sold_earned_surplus_"+str(offer.item_id),EconomyManager.gold == gold+amount*int(offer.price) and EconomyManager.count_item(offer.item_id) == 0): return false
		_note("sold_surplus",{"item":str(offer.item_id),"amount":amount,"earned":amount*int(offer.price)})
	t.tap(&"ui_cancel")
	await t.frames(3)
	return true

func _forest() -> bool:
	var first := DungeonFloors.floor_of(t.world().area)
	if first == 0:
		if not await _go_to("traetoppen"): return false
		# The hub and floors use the oil clock. Wait in town so the real
		# night witness is awake; waiting anywhere in the forest cannot help.
		while not TimeManager.is_night(): await _idle(600)
		if not await _go_to("moerkeskoven"): return false
		if not await _earned_rune(12): return false
		first = DungeonFloors.floor_of(t.world().area)
	for number in range(first,13):
		_note("floor_entered",{"floor":number,"world_seed":DungeonFloors.inst().world_seed_text(),"hearts":t.player().half_hearts,"weapon":str(EconomyManager.equipment.get(&"weapon",&""))})
		_save_checkpoint("entered-"+str(number))
		if not _check("ordinary_floor_"+str(number),DungeonFloors.floor_of(t.world().area) == number): return false
		for stone in t.tree.get_nodes_in_group("runestone"):
			if stone is Runestone2D and not stone.hub:
				if not await _use(stone): return false
		if not await _clear_floor(): return false
		for retry in 6:
			var actual := DungeonFloors.floor_of(t.world().area)
			if actual == number: break
			if actual == 0:
				await t.until(func(): return not t.world().sleeping and not t.world().traveling,15)
				_note("normal_defeat_recovery",{"returning_to":number})
				_save_checkpoint("recovery")
				if not await _go_to("traetoppen"): return false
				while not TimeManager.is_night(): await _idle(600)
				if not await _go_to("moerkeskoven"): return false
				if not await _earned_rune(number): return false
			while DungeonFloors.floor_of(t.world().area) != number:
				actual = DungeonFloors.floor_of(t.world().area)
				if not await _go("moerkeskoven_f"+str(actual+1 if actual < number else actual-1)): return false
			if not await _clear_floor(): return false
		for node in t.tree.get_nodes_in_group("runestone"):
			if node is Runestone2D and not node.hub:
				if not await _use(node): return false
		for row in MotherStory.EVIDENCE:
			if int(row.get("floor",0)) == number and row.id != "mother_fate":
				if not await _evidence(row.id): return false
		if number in [2,10]:
			# Natteblik is present on a night-time entry. Leave and re-enter
			# through the actual stair rather than injecting an arrival hour.
			if _local_npc("mapseller_natteblik") == null:
				if not await _go("moerkeskoven_f"+str(number-1)): return false
				while not TimeManager.is_night(): await _idle(600)
				if not await _go("moerkeskoven_f"+str(number)): return false
			if not await _talk("mapseller_natteblik","mother_story"): return false
		if number == 5:
			# The written owl account is an intentional free fallback; visit
			# the garden using the return stairs, then resume at an earned rune.
			if not MotherStory.has("echo_account"):
				_save_checkpoint("memory-clearing")
				if not await _go_to("secret_garden"): return false
				if not await _evidence("echo_account"): return false
				if not await _go_to("traetoppen"): return false
				while not TimeManager.is_night(): await _idle(600)
				if not await _go_to("moerkeskoven"): return false
				if not await _earned_rune(5): return false
				while DungeonFloors.floor_of(t.world().area) < 5:
					if not await _go("moerkeskoven_f"+str(DungeonFloors.floor_of(t.world().area)+1)): return false
		_save_checkpoint("floor-"+str(number))
		if number < 12:
			if not await _go("moerkeskoven_f"+str(number+1)): return false
	if not await _evidence("mother_fate"): return false
	if not await _go_to("secret_garden"): return false
	if not await _evidence("legacy_home"): return false
	if not _check("ordinary_journey_completed",MotherStory.chapter() == "complete" and QuestManager.is_completed(MotherStory.quest_id("s08"))): return false
	_note("homecoming")
	_save_checkpoint("homecoming")
	return true

func _earned_rune(maximum: int) -> bool:
	for node in t.tree.get_nodes_in_group("runestone"):
		if node is Runestone2D and node.hub:
			if not await _use(node): return false
			var picker: Control = t.world().game_ui.get_node("RunePicker")
			var floors: Array = DungeonFloors.inst().start_floors()
			var index := 0
			for i in floors.size():
				if int(floors[i]) <= maximum: index = i
			picker.rows.get_child(index).grab_focus()
			t.tap(&"ui_accept")
			await t.until(func(): return DungeonFloors.floor_of(t.world().area) == int(floors[index]) and not t.world().traveling,15)
			return _check("returned_through_earned_runestone",DungeonFloors.floor_of(t.world().area) == int(floors[index]))
	return _check("hub_runestone_present",false)

func _clear_floor() -> bool:
	var started_on := DungeonFloors.floor_of(t.world().area)
	var outside_route := {}
	for attempt in 60:
		if started_on in [4,8,12] and MotherStory.boss_cleared(started_on): return true
		var enemies: Array[Enemy2D] = []
		for node in t.world().area.objects.get_children():
			if node is Enemy2D and node.state != Enemy2D.S.DEAD and DungeonCombatRules.enemy_class(node.kind) != "critter" and not outside_route.has(node.get_instance_id()): enemies.append(node)
		if enemies.is_empty(): return _check("guardian_encounter_present_"+str(started_on),false) if started_on in [4,8,12] else true
		if t.player().half_hearts <= 4:
			for stone in t.tree.get_nodes_in_group("runestone"):
				if stone is Runestone2D and not stone.hub:
					if not await _use(stone): return false
					break
		enemies.sort_custom(func(a,b): return a.global_position.distance_squared_to(t.player().global_position) < b.global_position.distance_squared_to(t.player().global_position))
		var enemy := enemies[0]
		var kind := enemy.kind
		if Iso.ground_dist(enemy.global_position,t.player().global_position) > 150:
			var route := await JourneyWalker.walk_to(t,enemy.global_position,150,100,[],&"",enemy)
			_note("approach_enemy",{"kind":kind,"route":route})
			if DungeonFloors.floor_of(t.world().area) != started_on:
				_note("combat_stair_crossing",{"from":started_on,"to":DungeonFloors.floor_of(t.world().area)})
				return true
			if t.player().half_hearts <= 0:
				await _recover_defeat()
				return true
			if not is_instance_valid(enemy):
				_note("target_resolved_while_walking",{"kind":kind})
				continue
			if not _check("survived_approach",DungeonFloors.floor_of(t.world().area) > 0): return false
		for nearby in t.world().area.objects.get_children():
			if nearby is Enemy2D and nearby.state != Enemy2D.S.DEAD and DungeonCombatRules.enemy_class(nearby.kind) != "critter" and not outside_route.has(nearby.get_instance_id()) and nearby.global_position.distance_squared_to(t.player().global_position) < enemy.global_position.distance_squared_to(t.player().global_position): enemy = nearby
		var result := await _fight(enemy)
		_note("fight",result)
		if t.player().half_hearts <= 0:
			await _recover_defeat()
			return true
		if DungeonFloors.floor_of(t.world().area) != started_on:
			_note("combat_stair_crossing",{"from":started_on,"to":DungeonFloors.floor_of(t.world().area)})
			return true
		if not _check("survived_real_fight",t.player().half_hearts > 0 and DungeonFloors.floor_of(t.world().area) > 0,str(result)): return false
		if result.get("outside_route",false) and not enemy is DungeonBoss2D:
			outside_route[enemy.get_instance_id()] = true
			_note("optional_enemy_left_alive",result)
			continue
		if not _check("defeated_live_enemy",bool(result.won),str(result)): return false
		if started_on in [4,8,12] and MotherStory.boss_cleared(started_on): return true
		for drop in t.world().area.objects.get_children():
			if is_instance_valid(drop) and drop is LootDrop2D and Iso.ground_dist(drop.global_position,t.player().global_position) < 400:
				await JourneyWalker.walk_to(t,drop.global_position,15,6)
				if DungeonFloors.floor_of(t.world().area) != started_on: return true
		for chest in t.world().area.objects.get_children():
			if is_instance_valid(chest) and chest is LootChest2D and not chest.is_open and chest.revealed and Iso.ground_dist(chest.global_position,t.player().global_position) < 400:
				if not await _use(chest): return false
	return _check("floor_can_be_cleared",false)

func _recover_defeat() -> void:
	await t.until(func(): return str(t.world().area.map.id) == "farm" and not t.world().sleeping and t.player().half_hearts > 0,15)
	_note("fainted_and_recovered")
	_save_checkpoint("recovery")

func _fight(enemy: Enemy2D) -> Dictionary:
	var player: Player2D = t.player()
	var began: float = t.game_seconds()
	var kind := enemy.kind
	var swings := 0
	var last_position := player.global_position
	var last_progress: float = t.game_seconds()
	var no_route := 0
	player.mouse_aim = false
	while is_instance_valid(enemy) and enemy.state != Enemy2D.S.DEAD and player.half_hearts > 0 and t.game_seconds()-began < 120:
		var now: float = t.game_seconds()
		var direction := Iso.to_ground(enemy.global_position-player.global_position)
		var distance := direction.length()
		direction = direction.normalized()
		var radius := float(player.combat._read_weapon().get("swing_radius",197))
		if player.global_position.distance_to(last_position) > 20:
			last_position = player.global_position
			last_progress = now
		elif distance > radius*.9 and now-last_progress > 1.5:
			DungeonFightBot.release()
			var route := await JourneyWalker.walk_to(t,enemy.global_position,150,60,[],&"",enemy)
			_note("combat_detour",{"kind":kind,"route":route})
			no_route = no_route+1 if int(route.get("waypoints",0)) == 0 else 0
			# Flying optional enemies can wander beyond walkable ground. This
			# journey requires every guardian, not hunting every roaming enemy.
			if no_route >= 3 and not enemy is DungeonBoss2D:
				return {"kind":kind,"won":false,"outside_route":true,"swings":swings,"seconds":t.game_seconds()-began,"hearts":player.half_hearts}
			if no_route > 0: await t.physics(30)
			last_position = player.global_position
			last_progress = t.game_seconds()
			continue
		var safe := not enemy is DungeonBoss2D or enemy.state in [Enemy2D.S.RECOVER,Enemy2D.S.STUN]
		var movement := direction if distance > radius*.75 else Vector2.ZERO
		if enemy is DungeonBoss2D and not safe: movement = Vector2(-enemy.aim.y,enemy.aim.x) if enemy.attack_mode == "dash" else -direction
		DungeonFightBot.steer(movement)
		player.event_face(Iso.to_screen(direction))
		_travel_support(player)
		if safe and distance <= radius*.9 and player.combat.swing(): swings += 1
		if player.half_hearts <= 4: player.drink()
		await t.physics(1)
	DungeonFightBot.release()
	return {"kind":kind,"won":is_instance_valid(enemy) and enemy.state == Enemy2D.S.DEAD,"seconds":t.game_seconds()-began,"hearts":player.half_hearts,"swings":swings}

func _evidence(id: String) -> bool:
	if MotherStory.has(id): return true
	for node in t.world().area.objects.get_children():
		if node is MotherEvidenceMarker and node.evidence_id == id:
			var ui: Node = t.first(&"dialogue_ui")
			_note("reading_evidence",{"id":id,"work":MotherMemoryWork.state(id),"open":ui.is_open(),"lines":ui._lines})
			if not await _use(node): return false
			_note("opened_evidence",{"id":id,"busy":node._busy,"work":MotherMemoryWork.state(id),"lines":ui._lines,"choices":ui._choices})
			if id in MotherMemoryWork.IDS and not MotherMemoryWork.complete(id):
				for action in {"memory_lamp":["stitch_0","stitch_1","stitch_2"],"traveller_account":["name_iva"],"route_stone":["stone_right","stone_match"]}[id]:
					if not await _choose(action): return false
			if not await _choose("mother_record"): return false
			_note("evidence_"+id)
			return _check("recorded_"+id,MotherStory.has(id))
	return _check("story_marker_present_"+id,false)

func _garden() -> bool:
	if SecretGardenStory.step() == 12: return true
	if SecretGardenStory.step() < 0:
		if not await _go_to("secret_garden"): return false
		if not await _garden_work("gate", "garden_start"): return false
	if SecretGardenStory.step() == 0:
		if not await _garden_work("path", "garden_work"): return false
		_note("garden_started")
	for npc in ["gardener_hoppe", "carpenter_brumme"]:
		if SecretGardenStory.step() == (1 if npc == "gardener_hoppe" else 2):
			if not await _talk(npc, "garden_story"): return false
	_note("garden_helpers")
	if not await _go_to("secret_garden"): return false
	for step in [3,4,5]:
		if SecretGardenStory.step() == step:
			if not await _garden_work("bench" if step == 3 else "beds", "garden_work"): return false
	_note("garden_watered")
	_save_checkpoint("garden-watered")
	if SecretGardenStory.step() == 6 and not SecretGardenStory.bloom_ready():
		if not await _go_to("farm"): return false
		if not await _sleep(): return false
	if not await _go_to("secret_garden"): return false
	if SecretGardenStory.step() == 6 and not await _garden_work("beds","garden_work"): return false
	if SecretGardenStory.step() == 7 and not await _garden_work("letter","garden_work"): return false
	for npc in ["postman_pip","guard_oak"]:
		if SecretGardenStory.step() == (8 if npc == "postman_pip" else 9):
			if not await _talk(npc,"garden_story"): return false
	if SecretGardenStory.step() == 10:
		if not await _go_to("moerkeskoven"): return false
		if not await _garden_work("trail","garden_work"): return false
	if SecretGardenStory.step() == 11:
		if not await _go_to("secret_garden"): return false
		if not await _garden_work("bench","garden_work"): return false
	_note("garden_restored")
	_save_checkpoint("garden")
	return _check("restored_garden_by_ordinary_interactions",SecretGardenStory.step() == 12)

func _face_plot(cell: Vector2i) -> bool:
	var area: IsoArea = t.world().area
	var approach := area.cell_to_global(cell+Vector2i(0,1))
	var route := await JourneyWalker.walk_to(t,approach,5,20)
	JourneyWalker._steer(t,area.cell_to_global(cell)-t.player().global_position)
	await t.physics(2)
	t.release_all()
	await t.physics(5)
	return route.ok and t.player().target_cell() == cell

func _farm(large := false) -> bool:
	var seeds := {&"turnip_seeds":10,&"carrot_seeds":10} if large else {&"turnip_seeds":5}
	for seed in seeds:
		var missing := maxi(0,int(seeds[seed])-EconomyManager.count_item(seed))
		if missing > 0:
			if not await _buy("seed_shop",seed,missing): return false
	if not await _go_to("farm"): return false
	var w: WorldRoot2D = t.world()
	plots.clear()
	w.player.hotbar.assign(6,&"turnip_seeds")
	var cells: Array = w.farm.farmable_cells()
	cells.sort_custom(func(a,b): return w.area.cell_to_global(a).distance_squared_to(w.player.global_position) < w.area.cell_to_global(b).distance_squared_to(w.player.global_position))
	for cell in cells:
		var available: bool = w.farm.can_till(cell) or w.farm.state_of(cell) == FarmGrid.State.TILLED
		var approach: bool = w.farm.can_till(cell+Vector2i(0,1)) or w.farm.state_of(cell+Vector2i(0,1)) == FarmGrid.State.TILLED
		if available and approach: plots.append(cell)
		if plots.size() == (20 if large else 5): break
	if not _check("enough_workable_plots",plots.size() == (20 if large else 5)): return false
	for index in plots.size():
		var cell := plots[index]
		w.player.hotbar.assign(6,&"carrot_seeds" if large and index < 10 else &"turnip_seeds")
		if not _check("walk_to_starter_plot", await _face_plot(cell)): return false
		for slot in [1,7,2]:
			t.tap(StringName("slot_%d" % slot))
			await t.frames(2)
			t.tap(&"use_tool")
			await t.physics(2)
			await t.until(func(): return t.player().state == PlayerBody2D.S.FREE, 3)
		if not _check("starter_plot_watered", w.farm.get_plot(cell).watered): return false
	_note("first_planting")
	for morning in 4:
		if not await _sleep(): return false
		if morning < 3:
			for cell in plots:
				if w.farm.get_plot(cell).watered: continue
				if not _check("walk_to_water", await _face_plot(cell)): return false
				t.tap(&"slot_2")
				await t.frames(2)
				t.tap(&"use_tool")
				await t.physics(2)
				await t.until(func(): return t.player().state == PlayerBody2D.S.FREE, 3)
	for cell in plots:
		if not _check("starter_harvest_ripe", w.farm.state_of(cell) == FarmGrid.State.READY): return false
		if not _check("walk_to_harvest", await _face_plot(cell)): return false
		t.tap(&"interact")
		await t.physics(4)
	var bin: Node = w.area.find_markers("shipping_bin")[0].node
	var payout := 0
	var harvest := {}
	for crop in [&"turnip",&"carrot"]:
		var amount := EconomyManager.count_item(crop)
		if amount == 0: continue
		harvest[str(crop)] = amount
		payout += amount*EconomyManager.sell_value(crop)
		w.player.hotbar.assign(6,crop)
		t.tap(&"slot_7")
		await t.frames(2)
		if not await _use(bin): return false
	var gold := EconomyManager.gold
	if not await _sleep(): return false
	if not _check("earned_shipping_income", EconomyManager.gold == gold+payout): return false
	var box: Node = w.area.find_markers("mailbox")[0].node
	if not await _use(box): return false
	await _close_dialogue()
	_note("harvest_paid", {"harvest":harvest,"payout":payout})
	return true

func _sleep() -> bool:
	while GameManager.hour < 18:
		await _idle(600)
	var day := GameManager.total_day()
	var beds: Array = t.world().area.find_markers("bed")
	if not _check("bed_available", not beds.is_empty()): return false
	if not await _use(beds[0].node): return false
	await t.until(func(): return GameManager.total_day() > day and not t.world().sleeping, 10)
	_note("slept")
	return _check("ordinary_bed_advances_day", GameManager.total_day() == day+1)

func _idle(ticks: int) -> void:
	await t.physics(ticks)
	await _close_dialogue()
	if GameManager.is_modal_open():
		t.tap(&"ui_cancel")
		await t.frames(3)

func _go(destination: String) -> bool:
	var w: WorldRoot2D = t.world()
	if destination == "moerkeskoven" and str(w.area.map.id) == "traetoppen":
		var gate: Node2D = CityBuilder.of(w.area).lift_gate
		if not await _use(gate): return false
		await t.until(func(): return str(t.world().area.map.id) == destination and not t.world().traveling,15)
		_note("rode_forest_lift")
		return _check("rode_lift_to_forest",str(t.world().area.map.id) == destination)
	for warp in t.tree.get_nodes_in_group("warp"):
		if warp is Warp2D and str(warp.to_area) == destination and warp.armed:
			if warp is Door2D and not warp.is_open():
				return _check("door_accessible_"+destination,false,warp.last_reason)
			var route := {}
			var start_area: IsoArea = w.area
			var exit_position: Vector2 = warp.global_position
			for attempt in 3:
				if not is_instance_valid(start_area) or t.world().area != start_area:
					route.merge({"ok":true,"area_changed":true},true)
					break
				walking_to_exit = true
				route = await JourneyWalker.walk_to(t,exit_position,4,100)
				walking_to_exit = false
				if route.ok: break
				_note("walk_replan",{"destination":destination,"attempt":attempt+1,"route":route})
				await t.physics(30)
			if not route.ok:
				if native: await t.capture("blocked_route_"+destination)
				return _check("walk_route_"+destination,false,str(route))
			await t.until(func(): return not t.world().traveling, 10)
			await t.frames(3)
			if route.get("area_changed",false) and str(t.world().area.map.id) != destination:
				_note("travel_interrupted",{"wanted":destination,"route":route})
				return true
			_note("travel_"+destination, {"route":route})
			return _check("walked_to_"+destination, str(t.world().area.map.id) == destination)
	return _check("entrance_exists_"+destination,false,str(w.area.map.id))

func _go_to(destination: String) -> bool:
	for i in 24:
		var current := str(t.world().area.map.id)
		if current == destination: return true
		var target_root := destination
		if destination.begins_with("int_"):
			var building := Hours.building(destination.trim_prefix("int_"))
			target_root = str(building.get("area","hyggebyen"))
		var next := ""
		if DungeonFloors.floor_of(t.world().area) > 0:
			var floor_number := DungeonFloors.floor_of(t.world().area)
			next = "moerkeskoven" if floor_number == 1 else "moerkeskoven_f"+str(floor_number-1)
		elif current.begins_with("int_"):
			for warp in t.tree.get_nodes_in_group("warp"):
				if warp is Door2D and warp.always_open: next = str(warp.to_area); break
		elif current == "farm": next = "traetoppen"
		elif current == "secret_garden": next = "hyggebyen"
		elif current == "moerkeskoven": next = "traetoppen"
		elif current == "traetoppen": next = destination if target_root in ["traetoppen","farm","moerkeskoven"] else "hyggebyen"
		elif current == "hyggebyen": next = destination if target_root in ["hyggebyen","secret_garden"] else "traetoppen"
		if not _check("route_step_available",next != "",current+" -> "+destination): return false
		if not await _go(next): return false
	return _check("route_arrived_"+destination,false)

func _use(node: Node2D, report_failure := true) -> bool:
	var id := str(node.name)
	var area: IsoArea = t.world().area
	var cell := area.global_to_cell(node.global_position)
	var approaches: Array[Vector2] = []
	for offset in [Vector2i(0,1),Vector2i(1,0),Vector2i(-1,0),Vector2i(0,-1),Vector2i(1,1),Vector2i(-1,-1)]:
		approaches.append(area.cell_to_global(cell+offset))
	for offset in [Vector2(0,45),Vector2(100,0),Vector2(-100,0),Vector2(0,-65)]:
		approaches.append(node.global_position+offset)
	for approach in approaches:
		var route := await JourneyWalker.walk_to(t,approach,5,80,[],ActorLevel.level_id(node),node)
		if not is_instance_valid(node): return _check("interaction_target_still_present_"+id,false) if report_failure else false
		t.release_all()
		for tick in 120:
			if t.player().state == PlayerBody2D.S.FREE: break
			await t.physics(1)
		await t.physics(8)
		if t.player().state != PlayerBody2D.S.FREE: continue
		if t.player().nearest_interactable() == node:
			t.tap(&"interact")
			await t.physics(4)
			if node is MotherEvidenceMarker and not node._busy:
				_note("interaction_not_started",{"id":node.evidence_id,"input_allowed":t.player().world_input_allowed(),"lines":t.first(&"dialogue_ui")._lines})
				continue
			return true
		if node is Npc2D and node.global_position.distance_to(area.cell_to_global(cell)) > 120: return false
		if not route.ok and Iso.ground_dist(t.player().global_position,node.global_position) > 200:
			_note("approach_failed",{"target":str(node.global_position),"approach":str(approach),"route":route,"actor_level":str(ActorLevel.level_id(t.player()))})
			continue
		JourneyWalker._steer(t,node.global_position-t.player().global_position)
		await t.physics(2)
		t.release_all()
		await t.physics(3)
		if t.player().nearest_interactable() != node:
			_note("approach_missed_target",{"target":str(node.global_position),"approach":str(approach),"route":route,"actor_level":str(ActorLevel.level_id(t.player())),"query":str(t.player().target_global()),"nearest":str(t.player().nearest_interactable())})
			continue
		t.tap(&"interact")
		await t.physics(4)
		if node is MotherEvidenceMarker and not node._busy: continue
		return true
	return _check("can_reach_interaction_"+id,false,str(node.global_position)+" player="+str(t.player().global_position)+" nearest="+str(t.player().nearest_interactable())) if report_failure else false

func _garden_work(kind: String, action: String) -> bool:
	for node in t.world().area.objects.get_children():
		if node is SecretGardenMarker and node.kind == kind:
			if not await _use(node): return false
			return await _choose(action)
	return _check("garden_marker_"+kind,false)

func _talk(npc: String, topic: String) -> bool:
	if npc == "mapseller_natteblik":
		var keeper := _local_npc(npc)
		if not _check("night_witness_present",keeper != null): return false
		if not await _use(keeper): return false
		if not await _visible_story_reply(topic,npc): return false
		if not await _choose(topic): return false
		await _close_dialogue()
		return true
	for attempt in 60:
		var where := NpcDirector.where_is(npc)
		_note("locate_"+npc,where)
		var area := str(where.get("area",""))
		if str(where.get("state","")) == "move":
			await t.physics(120)
			continue
		if area == "" or str(where.get("act","")) == "sleep":
			await t.physics(1800)
			continue
		if area.begins_with("int_") and not Hours.is_open(area.trim_prefix("int_")):
			await t.physics(900)
			continue
		if area.begins_with("int_") and str(Hours.building(area.trim_prefix("int_")).get("kind","")) == "home" and SocialManager.hearts(npc) < 1:
			await t.physics(900)
			continue
		if not await _go_to(area): return false
		var node := NpcDirector.node_of(npc)
		if node == null:
			await t.physics(300)
			continue
		var host: Node2D = node
		for counter in t.tree.get_nodes_in_group("interactable"):
			if counter is ShopCounter and counter.kind == "talk" and counter.keeper_id == npc and counter.is_enabled():
				host = counter
				break
		if not await _use(host,false):
			await t.physics(120)
			continue
		if not await _visible_story_reply(topic,npc): return false
		if not await _choose(topic): return false
		await _close_dialogue()
		return true
	return _check("citizen_available_"+npc,false)

func _visible_story_reply(topic: String, npc: String) -> bool:
	var step := SecretGardenStory.step()
	var required := topic == "garden_story" and step >= 0 and step < SecretGardenStory.STEPS.size() and str(SecretGardenStory.STEPS[step].get("npc","")) == npc
	required = required or (topic == "mother_story" and str(MotherStory.topic_page(npc).get("mother_evidence","")) != "")
	if not required: return true
	var ui: Node = t.first(&"dialogue_ui")
	for i in 100:
		if not ui.is_open() or not ui._buttons.is_empty(): break
		t.tap(&"interact")
		await t.frames(2)
	if native: await t.capture("story_reply_"+npc)
	return _check("required_story_reply_visible_"+npc,ui._choices.any(func(choice):return str(choice.get("action","")) == topic))

func _local_npc(id: String) -> Node2D:
	for node in t.tree.get_nodes_in_group("npc"):
		if str(node.npc_id) == id: return node
	return null

func _choose(action: String) -> bool:
	var ui: Node = t.first(&"dialogue_ui")
	for i in 100:
		if not ui.is_open(): break
		if ui._buttons.is_empty():
			t.tap(&"interact")
			await t.frames(2)
			continue
		for button in ui._buttons:
			if str(button.get_meta("choice").get("action","")) == action:
				button.grab_focus()
				t.tap(&"ui_accept")
				await t.frames(4)
				return true
		for button in ui._buttons:
			var choice: Dictionary = button.get_meta("choice")
			if str(choice.get("action","")) == "social_more" and _contains_action(LuaData.arr(choice.get("choices",[])),action):
				button.grab_focus()
				t.tap(&"ui_accept")
				await t.frames(4)
				return await _choose(action)
		break
	return _check("dialogue_action_"+action,false,str(ui._choices))

func _contains_action(choices: Array, action: String) -> bool:
	for choice in choices:
		if str(choice.get("action","")) == action or _contains_action(LuaData.arr(choice.get("choices",[])),action): return true
	return false

func _close_dialogue() -> void:
	var ui: Node = t.first(&"dialogue_ui")
	for i in 100:
		if not ui.is_open(): return
		if ui._buttons.is_empty(): t.tap(&"interact")
		else:
			var close: Button = ui._buttons[-1]
			for button in ui._buttons:
				if str(button.get_meta("choice").get("action","")) == "close": close = button
			close.grab_focus()
			t.tap(&"ui_accept")
		await t.frames(2)

func _check(id: String, ok: bool, detail := "") -> bool:
	t.check(id,ok,detail)
	if not ok: _note("FAILED_"+id,{"detail":detail})
	return ok

func _note(id: String, detail: Dictionary = {}) -> void:
	var row := {"event":id,"day":GameManager.total_day(),"hour":GameManager.hour,"minute":GameManager.minute,"area":str(t.world().area.map.id),"gold":EconomyManager.gold,"hearts":t.player().half_hearts,"player_state":int(t.player().state),"garden_step":SecretGardenStory.step(),"chapter":MotherStory.chapter(),"detail":detail}
	trace.append(row)
	t.info("JOURNEY "+JSON.stringify(row))
	var path: String = "res://docs/qa/journey/trace-"+t.character+("-native" if native else "")+".json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify(trace,"\t")+"\n")

func _save_checkpoint(id: String) -> void:
	if SaveManager.save_game(3):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(SaveManager.slot_path(3)), "/tmp/pongpong-journey-"+t.character+"-"+id+".json")
