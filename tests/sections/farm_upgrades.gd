extends RefCounted
const SECTION := "farm_upgrades"
const TIMEOUT_S := 180.0
var native := false
func run(t) -> void: await _run(t)
func run_windowed(t) -> void:
	native = true
	await _run(t)
func _run(t) -> void:
	await t.start_world()
	var ah: Node = t.autoload("AnimalHusbandry")
	var gm: Node = t.autoload("GameManager")
	var eco: Node = t.autoload("EconomyManager")
	var sm: Node = t.autoload("SaveManager")
	var w: WorldRoot2D = t.world()
	var menu: TTScreen = w.game_ui.get_screen(&"build_menu_ui")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.day = 28
	gm.season = &"vinter"
	gm.year = 1
	for kind in [&"coop", &"barn", &"house"]:
		var initial: Dictionary = ah.buildings_data[str(kind)]
		for id in initial.build_cost:
			if id == "gold": eco.add_gold(int(initial.build_cost[id]))
			else: eco.add_item(StringName(id), int(initial.build_cost[id]), true)
		t.check(str(kind)+"_can_build_with_real_cost", ah.build_building(kind))
		for tier in [2,3]:
			menu._selected_building = kind
			menu.open()
			await t.frames(2)
			var spec: Dictionary = ah.building_upgrade(kind)
			var building = ah.building_of(kind)
			var before: Dictionary = ah.to_dict()
			eco.gold = 0
			t.check("%s_%d_missing_cost_is_atomic" % [kind,tier], not ah.upgrade_building(kind) and ah.to_dict() == before)
			for id in spec.cost:
				if id == "gold": eco.add_gold(int(spec.cost[id]))
				else: eco.add_item(StringName(id), int(spec.cost[id]), true)
			menu._refresh_texts()
			await t.frames(2)
			t.check("%s_%d_ui_shows_capacity_cost_and_days" % [kind,tier], not menu.build_btn.disabled and str(int(spec.capacity)) in menu.capacity_label.text and str(int(spec.days)) in menu.cost_label.text)
			if native and kind == &"coop" and tier == 2: await t.capture("coop_upgrade_offer")
			menu.build_btn.pressed.emit()
			await t.frames(2)
			var confirm: UiConfirm = menu.find_child("UiConfirm", true, false)
			t.check("%s_%d_cancel_focused" % [kind,tier], confirm != null and confirm.get_node("%CancelButton").has_focus())
			UiAudit.press(t,&"ui_cancel")
			await t.frames(2)
			t.check("%s_%d_cancel_keeps_building" % [kind,tier], ah.to_dict() == before)
			var gold: int = eco.gold
			menu.build_btn.pressed.emit()
			await t.frames(2)
			confirm = menu.find_child("UiConfirm", true, false)
			confirm.get_node("%OkButton").grab_focus()
			UiAudit.press_pad(t,JOY_BUTTON_A)
			await t.frames(3)
			t.check("%s_%d_confirm_pays_once_and_starts" % [kind,tier], building.tier == tier-1 and building.upgrade_ready_day == gm.total_day()+int(spec.days) and eco.gold == gold-int(spec.cost.gold))
			t.check("%s_%d_duplicate_refused" % [kind,tier], not ah.upgrade_building(kind) and menu.build_btn.disabled)
			if native and kind == &"coop" and tier == 2: await t.capture("coop_construction")
			menu.close()
			var wire: Dictionary = JSON.parse_string(JSON.stringify(sm.gather_payload()))
			t.check("%s_%d_construction_save_roundtrip" % [kind,tier], sm._apply_payload(wire).ok and ah.building_of(kind).upgrade_ready_day > gm.total_day())
			var old_capacity: int = ah.get_building_capacity(kind)
			for day in int(spec.days):
				gm.end_day()
				if day < int(spec.days)-1:
					t.check("%s_%d_capacity_waits_for_completion_%d" % [kind,tier,day], ah.get_building_capacity(kind) == old_capacity and ah.has_building(kind))
			await t.frames(2)
			t.check("%s_%d_finishes_on_morning" % [kind,tier], ah.building_of(kind).tier == tier and ah.building_of(kind).upgrade_ready_day == 0 and ah.get_building_capacity(kind) == int(spec.capacity))
			if kind == &"coop" and tier == 2:
				t.check("construction_crosses_season_and_year", gm.year == 2 and gm.season == &"foraar" and gm.day == 2)
		var saved: Dictionary = ah.to_dict()
		t.check(str(kind)+"_max_tier_refused_without_payment", not ah.upgrade_building(kind) and ah.to_dict() == saved)
	# Adoption must use expanded capacity, not the original building definition.
	for i in 5:
		t.expect(eco.buy_item(&"baby_chick", 1, 0), "Adopt chick into expanded housing")
	t.check("expanded_housing_accepts_fifth_chick", ah.get_animals_by_species(&"chicken").size() == 5)
	var bad: Dictionary = JSON.parse_string(JSON.stringify(ah.to_dict()))
	var first: String = bad.buildings.keys()[0]
	bad.buildings[first].tier = 99
	t.check("invalid_building_tier_rejected", not ah.validate_dict(bad))
	menu._selected_building = &"coop"
	menu.open()
	await t.frames(2)
	t.check("max_building_ui_disabled", menu.build_btn.disabled)
	if native: await t.capture("coop_max_tier")
	var house_link: Button = menu.find_child("HouseUpgrades",true,false)
	house_link.pressed.emit()
	await t.frames(3)
	t.check("farm_menu_opens_house_upgrade_screen", not menu.is_open() and w.game_ui.get_screen(&"husbyggeri").is_open())
	w.game_ui.get_screen(&"husbyggeri").close()
