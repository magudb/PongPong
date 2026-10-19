extends RefCounted
const SECTION := "animals"
const TIMEOUT_S := 180.0
var native := false
func run(t) -> void:
	await _run(t)
func run_windowed(t) -> void:
	native = true
	await _run(t)
func _run(t) -> void:
	await t.start_world()
	var world: WorldRoot2D = t.world()
	var ah: Node = t.autoload("AnimalHusbandry")
	var eco: Node = t.autoload("EconomyManager")
	var gm: Node = t.autoload("GameManager")
	var menu: TTScreen = world.game_ui.get_screen(&"build_menu_ui")
	var care: TTScreen = world.game_ui.get_screen(&"animal_care_ui")
	t.check("screens_and_three_housing_slots_exist",menu != null and care != null and world.area.handled_count("building_slot") == 3)
	t.check("yard_handler_exists",world.area.handled_count("animal_yard") == 1)
	var before: Dictionary = ah.to_dict()
	t.check("missing_materials_never_spend",not ah.build_building(&"coop") and ah.to_dict() == before)
	eco.add_item(&"wood",100,true)
	eco.add_item(&"stone",80,true)
	eco.add_gold(3000)
	t.tap_key(KEY_B)
	await t.frames(3)
	t.check("build_hotkey_opens_paused_with_painted_preview",menu.is_open() and menu.preview.texture != null and not menu.build_btn.disabled)
	if native: await t.capture("build_coop")
	menu.build_btn.pressed.emit()
	await t.frames(3)
	var confirm: UiConfirm = _confirm(menu)
	t.check("building_confirmation_defaults_cancel",confirm != null and menu.get_viewport().gui_get_focus_owner().name == "CancelButton")
	UiAudit.press(t,&"ui_cancel")
	await t.frames(2)
	t.check("cancel_does_not_build",not ah.has_building(&"coop"))
	menu.build_btn.pressed.emit()
	await t.frames(2)
	confirm = _confirm(menu)
	confirm.find_child("OkButton",true,false).grab_focus()
	UiAudit.press_pad(t,JOY_BUTTON_A)
	await t.frames(3)
	t.check("build_uses_cost_and_commits_housing",ah.has_building(&"coop") and eco.count_item(&"wood") == 80 and eco.count_item(&"stone") == 70)
	t.check("duplicate_slot_not_sold",not ah.build_building(&"coop"))
	menu.close()
	var quest: Node = t.autoload("QuestManager")
	t.check("rosa_offers_care_quest",Grant.accept_via_dialogue("first_animal"))
	t.check("existing_coop_counts_for_late_accept",quest.get_objective_progress(&"first_animal",&"build_coop").done)
	t.check("purchased_baby_adopted",eco.buy_item(&"baby_chick",1,150) and ah.animals.size() == 1 and eco.count_item(&"baby_chick") == 0)
	await t.frames(3)
	var animal = ah.animals.values()[0]
	var yard: Node = world.area.find_markers("animal_yard")[0].node
	t.check("adoption_spawns_visible_actor",yard.actors.has(animal.id) and yard.actors[animal.id].visual != null)
	var actor: Animal2D = yard.actors[animal.id]
	actor.interact(world.player)
	await t.frames(3)
	t.check("actor_opens_preselected_care",care.is_open() and care._selected_animal == animal.id and care.name_label.text == animal.name)
	t.check("no_food_disables_feed",care.feed_btn.disabled)
	eco.add_item(&"chicken_feed",8,true)
	eco.add_item(&"brush",1,true)
	care._refresh_texts()
	t.check("foods_filtered_for_species",care._foods == ["chicken_feed"] and not care.feed_btn.disabled)
	var hunger: float = animal.hunger
	care.feed_btn.pressed.emit()
	t.check("feeding_consumes_correct_food",eco.count_item(&"chicken_feed") == 7 and animal.hunger > hunger)
	care.brush_btn.pressed.emit()
	care.play_btn.pressed.emit()
	var bond: float = animal.bond_xp
	t.check("care_cooldowns_block_repeat_xp",not ah.brush_animal(animal.id) and not ah.play_with_animal(animal.id) and animal.bond_xp == bond)
	care.rename_btn.pressed.emit()
	await t.frames(2)
	var rename := _confirm(care)
	t.check("rename_uses_canvas_dialog",rename != null)
	UiAudit.press(t,&"ui_cancel")
	await t.frames(2)
	t.check("cancelled_rename_frees_dialog",_confirm(care) == null and care.name_label.text == animal.name)
	care.rename_btn.pressed.emit()
	await t.frames(2)
	rename = _confirm(care)
	rename._field.text = "Fnug"
	rename.find_child("OkButton",true,false).grab_focus()
	UiAudit.press_pad(t,JOY_BUTTON_A)
	await t.frames(2)
	t.check("rename_confirmation_updates_record_and_label",animal.name == "Fnug" and care.name_label.text == "Fnug")
	if native: await t.capture("care_baby")
	care.close()
	var inventory: Node = world.game_ui.get_screen(&"inventory_ui")
	inventory.open()
	await t.frames(2)
	for i in inventory._slots.size():
		if inventory._slots[i].item_id == &"chicken_feed": inventory._select(i)
	inventory._use()
	await t.frames(2)
	t.check("backpack_food_opens_care_without_consumption",not inventory.is_open() and care.is_open() and eco.count_item(&"chicken_feed") == 7)
	care.close()
	for _day in 3:
		gm.end_day()
		ah.feed_animal(animal.id,&"chicken_feed")
	t.check("care_quest_completes_from_real_events",quest.is_completed(&"first_animal"))
	await t.frames(3)
	t.check("matures_and_produces_on_absolute_days",not animal.is_baby and animal.products_ready > 0 and yard.actors[animal.id].visual.resolved_id == "hen")
	t.check("rosa_offers_product_quest",Grant.accept_via_dialogue("animal_products"))
	var eggs: int = eco.count_item(&"egg")
	var received: int = ah.collect_product(animal.id)
	await t.frames(2)
	t.check("product_quest_tracks_actual_inventory",quest.get_objective_progress(&"animal_products",&"collect_egg").current > 0)
	t.check("collection_reaches_inventory",received > 0 and eco.count_item(&"egg") == eggs + received and animal.products_ready == 0)
	var save: Dictionary = JSON.parse_string(JSON.stringify(ah.to_dict()))
	ah.reset()
	t.check("save_roundtrip_animals_and_building_positions",ah.from_dict(save) and JSON.parse_string(JSON.stringify(ah.to_dict())) == save)
	animal = ah.animals.values()[0]
	await t.frames(3)
	t.check("load_respawns_actor",yard.actors.has(animal.id))
	gm.day = gm.days_per_season()
	animal.happiness = 80
	animal.hunger = 100
	animal.last_product_day = gm.total_day()
	gm.end_day()
	t.check("season_rollover_keeps_production",animal.products_ready > 0)
	# Fill every remaining backpack slot with nonstackable tools. No product is lost.
	var pack: Dictionary = eco.to_dict()
	var slots: Array = []
	for _slot in 24: slots.append({"id":"hoe_wooden","amount":1})
	pack["inventory"] = slots
	eco.from_dict(pack)
	var owed: int = animal.products_ready
	t.check("full_pack_retains_product",ah.collect_product(animal.id) == 0 and animal.products_ready == owed)
	eco.reset()
	eco.add_item(&"fence",2,true)
	var location := Vector2i.ZERO
	var placed := false
	for c in world.area.map.height:
		for x in world.area.map.width:
			if not placed and PlacementService.place(&"fence",Vector2i(x,c)):
				location = Vector2i(x,c)
				placed = true
	t.check("placeable_commits_one_owned_copy",placed and world.placed_items.size() == 1 and eco.count_item(&"fence") == 1)
	t.check("occupied_cell_refuses_duplicate",not PlacementService.place(&"fence",location) and eco.count_item(&"fence") == 1)
	var saved_world: Dictionary = world.to_dict()
	var drawn: Array = world.area.find_markers("building_slot")[0].node._placed_visuals.duplicate()
	await world.travel(&"hyggebyen",&"default")
	await world.travel(&"farm",&"default")
	await t.frames(3)
	t.check("placeables_replay_without_duplication",world.to_dict().placed == saved_world.placed and world.area.find_markers("building_slot")[0].node._placed_visuals.size() == 1)
	# the parked farm comes back with the same prop nodes: re-entry reconciles instead of tearing down and rebuilding (review GAP4-06)
	var redrawn: Array = world.area.find_markers("building_slot")[0].node._placed_visuals
	t.check("placeables_survive_reentry_unrebuilt",drawn.size() == 1 and redrawn.size() == 1 and redrawn[0] == drawn[0] and is_instance_valid(drawn[0]) and not drawn[0].is_queued_for_deletion())
	var stored_visuals: Array = world.area.find_markers("building_slot")[0].node._placed_visuals
	var decoration: Node = stored_visuals[0].get_children().filter(func(n): return n is Interactable2D)[0]
	decoration.interact(world.player)
	await t.frames(2)
	t.check("decoration_can_return_to_inventory",world.placed_items.is_empty() and eco.count_item(&"fence") == 2)
	var original: Dictionary = ah.to_dict()
	for species in Animal2D.VISUALS:
		var specimen := original.duplicate(true)
		specimen.animals = {"animal_preview":{"id":"animal_preview","species":species,"name":species,"is_baby":false,"age_days":20,"happiness":70,"hunger":90}}
		ah.from_dict(specimen)
		await t.frames(2)
		t.check("species_%s_uses_approved_actor" % species,yard.actors.has(&"animal_preview") and yard.actors[&"animal_preview"].visual.resolved_id == Animal2D.VISUALS[species][1])
	ah.from_dict(original)
	await t.frames(2)
	if native:
		world.game_ui.get_screen(&"hud").toasts.clear()
		world.player.camera_focus(yard,0.65,0.0)
		await t.frames(3)
		await t.capture("farm_animals_building")
		world.player.camera_release(0.0)
func _confirm(host: Control) -> UiConfirm:
	for node in host.get_children():
		if node is UiConfirm: return node
	return null
