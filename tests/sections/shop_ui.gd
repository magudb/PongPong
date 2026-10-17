extends RefCounted
const SECTION := "shop_ui"
const TIMEOUT_S := 180.0
func run(t) -> void:
	if OS.get_environment("TRAETOPPEN_BAKE_CATALOG") == "1":
		var built: Dictionary = t.run_godot_script("res://tools/ui/bake_catalog.gd")
		t.check("scenes_compile", built.code == 0 and not built.output.contains("SCRIPT ERROR:") and not built.output.contains("ERROR:"), built.output)
		if built.code != 0 or built.output.contains("SCRIPT ERROR:"):
			return
	t.autoload("EventBus").new_game_started.connect(func(): t.autoload("GameManager").set_flag(GameManager.FLAG_INTRO_PENDING, false), CONNECT_ONE_SHOT)
	await t.start_world()
	var game_ui: GameUI = t.tree.get_first_node_in_group("game_ui")
	var shop: Node = game_ui.get_screen(&"shop_ui")
	t.check("shop_scene_live", shop != null)
	if shop == null:
		return
	t.autoload("GameManager").hour = 12
	t.autoload("EconomyManager").gold = 100000
	t.autoload("ShopSystem").open_shop(&"seed_shop")
	await t.frames(4)
	t.check("shop_opens_from_real_service", shop.is_open() and t.tree.paused and shop._rows.size() > 0)

	var gm: Node = t.autoload("GameManager")
	var eco: Node = t.autoload("EconomyManager")
	var service: Node = t.autoload("ShopSystem")
	gm.set_config_override("towns.hours_enabled", false)
	for locale in ["da", "en"]:
		t.autoload("LocalizationManager").set_locale(locale)
		await t.frames(3)
		var rules := UiAudit.rule_report(shop)
		t.check("rules_" + locale, rules.ok, str(rules.defects))
	t.autoload("LocalizationManager").set_locale("da")
	await t.frames(3)
	t.check("initial_focus", shop.get_viewport().gui_get_focus_owner() == shop._rows[0])
	var row: Button = shop._rows[0]
	var item := StringName(str(row.item_id))
	row.pressed.emit()
	t.check("row_accept_focuses_stepper", shop.stepper.has_focus())
	var before: int = eco.gold
	var owned: int = eco.count_item(item)
	var total: int = service.get_buy_total(shop.current_shop, item, 1)
	shop.buy_btn.pressed.emit()
	await t.frames(3)
	t.check("buy_via_control", eco.gold == before - total and eco.count_item(item) == owned + 1)
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	t.check("esc_closes_and_restores", not shop.is_open() and not t.tree.paused and shop.get_viewport().gui_get_focus_owner() == null)
	await _pad_shop(t, shop)
	await _all_shops(t, shop)
	await _prices_and_tabs(t, shop)
	await _inventory_checks(t, game_ui)
	await _equipment_cards(t,game_ui,false)
	gm.clear_config_overrides()

func _equipment_cards(t,game_ui: GameUI,native: bool) -> void:
	var shop: Control = game_ui.get_screen(&"shop_ui")
	if shop.is_open():shop.close()
	var loadout: Control = game_ui.get_screen(&"garderobe")
	for item in ["iron_sword","wpn_staff_star","gem_rune_heart"]:EconomyManager.add_item(StringName(item),1,true)
	for locale in ["da","en"]:
		LocalizationManager.set_locale(locale)
		var broken: Array[String] = []
		var checked := 0
		var raw := RegEx.create_from_string("WEFFECT_|GEMFX_|WSTAT_|DEXP_|WEAPON_FAMILY_|%[dfs]")
		for id in LuaRuntime.get_all_item_ids():
			if str(ItemKinds.def(id).get("category",""))!="weapon" and not LanternGem.can_equip(id):continue
			checked += 1
			var text: String = preload("res://scripts/ui/components/equipment_details.gd").text(str(id))
			if text=="" or raw.search(text)!=null:broken.append(str(id))
		t.check("all_weapon_and_gem_details_localize_"+locale,checked>=40 and broken.is_empty(),"%d cards, broken %s" % [checked,str(broken)])
		loadout.open()
		loadout.set_tab(1)
		for item in ["iron_sword","wpn_staff_star","gem_rune_heart"]:
			loadout._filter("gem" if item.begins_with("gem_") else "weapon")
			loadout._select(item)
			await t.frames(3)
			var copy: String = loadout.equipment_stats.text
			var floors := DungeonRun.weapon_range(item)
			var range_copy := TranslationServer.translate("DEXP_WEAPON_RANGE_FMT") % [floors.x,floors.y]
			t.check("loadout_card_"+item+"_"+locale,copy!="" and loadout.equipment_stats.visible and (item.begins_with("gem_") or copy.contains(range_copy)))
			t.check("loadout_card_bounds_"+item+"_"+locale,loadout.get_global_rect().encloses(loadout.equipment_stats.get_global_rect()) and loadout.item_scroll.size.y>=56,str(loadout.equipment_stats.get_global_rect()))
			if native:await t.capture("equipment_"+item+"_"+locale)
		loadout.close()
		ShopSystem.open_shop(&"smithy")
		await t.frames(3)
		var offer: Dictionary = {}
		for row in ShopSystem.get_shop_inventory(&"smithy"):
			if str(row.item_id)=="iron_sword":offer = row
		t.check("smith_has_comparable_weapon_"+locale,not offer.is_empty())
		if not offer.is_empty():
			shop._select(offer)
			await t.frames(3)
			t.check("shop_weapon_card_"+locale,shop.equipment_stats.visible and shop.equipment_stats.text.contains(TranslationServer.translate("WSTAT_DAMAGE")) and shop.get_global_rect().encloses(shop.equipment_stats.get_global_rect()))
			if native:await t.capture("smith_weapon_card_"+locale)
		shop.close()
	LocalizationManager.set_locale("da")

func _prices_and_tabs(t, screen: Control) -> void:
	var eco: Node = t.autoload("EconomyManager")
	var gm: Node = t.autoload("GameManager")
	var service: Node = t.autoload("ShopSystem")
	gm.hour = 12
	eco.gold = 0
	service.open_shop(&"seed_shop")
	await t.frames(3)
	t.check("too_dear_disabled_and_styled", screen.buy_btn.disabled and screen.buy_btn.focus_mode == Control.FOCUS_NONE and screen._rows.all(func(row): return row._poor and row.price_label.theme_type_variation == &"CatalogTooDear"))
	var tab: int = screen._tab
	screen._rows[0].grab_focus()
	t.tap_key(KEY_PAGEDOWN)
	await t.frames(3)
	t.check("tab_switch_page_actions", screen._tab == posmod(tab + 1, screen._tabs.size()))
	screen.close()
	eco.gold = 100000
	var race: int = gm.character_type
	gm.character_type = 0
	service.open_shop(&"seed_shop")
	await t.frames(3)
	var regular: int = service.get_buy_price(&"seed_shop", &"carrot_seeds")
	screen.close()
	gm.character_type = 2
	service.open_shop(&"seed_shop")
	await t.frames(3)
	for row in screen._rows:
		if row.item_id == &"carrot_seeds":
			row.pressed.emit()
	var discounted: int = service.get_buy_price(&"seed_shop", &"carrot_seeds")
	var gold: int = eco.gold
	screen.buy_btn.pressed.emit()
	await t.frames(3)
	t.check("hobbit_displayed_equals_charged", discounted < regular and gold - eco.gold == discounted)
	screen.close()
	gm.character_type = race

func run_windowed(t) -> void:
	t.autoload("EventBus").new_game_started.connect(func(): t.autoload("GameManager").set_flag(GameManager.FLAG_INTRO_PENDING, false), CONNECT_ONE_SHOT)
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.hour = 12
	gm.set_config_override("towns.hours_enabled", false)
	t.autoload("EconomyManager").gold = 1250
	var ui: GameUI = t.tree.get_first_node_in_group("game_ui")
	t.autoload("ShopSystem").open_shop(&"seed_shop")
	await t.frames(8)
	await t.capture("shop")
	var shop: Control = ui.get_screen(&"shop_ui")
	t.check("shop_panel_fits", shop.get_node("%ShopPanel").get_global_rect().end.y <= 680, str(shop.get_node("%ShopPanel").get_global_rect()))
	shop.close()
	await t.frames(3)
	t.tap_key(KEY_I)
	await t.frames(6)
	var inventory: Control = ui.get_screen(&"inventory_ui")
	t.check("inventory_open", inventory.is_open())
	await t.capture("inventory")
	var bag: Control = inventory.get_node("Margin/Columns/Backpack")
	t.check("inventory_panel_fits", bag.get_global_rect().position.y >= 40 and bag.get_global_rect().end.y <= 680, str(bag.get_global_rect()))
	inventory.close()
	await _equipment_cards(t,ui,true)
	gm.clear_config_overrides()
	# Stable production-screen fixtures keep scenery/weather out of UI regression scoring.
	await t.clear_scene()
	Fresh.new_game(t)
	t.autoload("EconomyManager").gold = 1250
	for id in ["shop", "inventory"]:
		var host := Control.new()
		host.process_mode = Node.PROCESS_MODE_ALWAYS
		t.tree.root.add_child(host)
		host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var screen: Control = await preload("res://scripts/ui/dev/ui_fixtures.gd").make(id, host)
		await t.frames(5)
		await t.capture(id + "_fixture")
		var focus: Control = screen.get_viewport().gui_get_focus_owner()
		UiAudit.expect(t, await UiAudit.ring_pixels(t, focus, {"focus": false, "shot": id + "_ring"}), id + "_native_focus")
		var panel: Control = screen.get_node("%ShopPanel") if id == "shop" else screen.get_node("Margin/Columns/Backpack")
		UiAudit.expect(t, await UiAudit.panel_pixels(t, panel, {"shot": id + "_panel"}), id + "_native_panel")
		var button: Button = screen.get_node("%BuyButton") if id == "shop" else screen.get_node("%AssignButton")
		UiAudit.expect(t, await UiAudit.button_pixels(t, button, {"shot": id + "_button"}), id + "_native_button")
		var baseline: String = "res://docs/qa/ui_baseline/" + id + ".png"
		t.check(id + "_baseline_exists", FileAccess.file_exists(baseline))
		if FileAccess.file_exists(baseline):
			var result: Dictionary = t.run_tool(ProjectSettings.globalize_path("res://tools/art/.venv/bin/python"), PackedStringArray([ProjectSettings.globalize_path("res://tests/checkpoints/compare_guide.py"), t.out_dir.path_join("shop_ui_" + id + "_fixture.png"), "--ref", ProjectSettings.globalize_path(baseline), "--no-frame-crop", "--max", "1.5", "--json"]))
			t.check(id + "_reviewed_baseline", result.code == 0, result.output)
		screen.close()
		host.free()
	var comparison: Dictionary = t.run_tool(ProjectSettings.globalize_path("res://tools/art/.venv/bin/python"), PackedStringArray([ProjectSettings.globalize_path("res://tools/ui/compare_catalog.py"), "--shots", t.out_dir]))
	t.check("guide_catalog_ui", comparison.code == 0, comparison.output)

func _inventory_checks(t, game_ui: GameUI) -> void:
	var inventory: Control = game_ui.get_screen(&"inventory_ui")
	var eco: Node = t.autoload("EconomyManager")
	t.tap_key(KEY_I)
	await t.frames(3)
	t.check("inventory_toggle_i", inventory.is_open() and t.tree.paused)
	t.check("backpack_24_focusable_slots", inventory._slots.size() == 24 and inventory._slots.all(func(slot): return slot.focus_mode == Control.FOCUS_ALL))
	for locale in ["da", "en"]:
		t.autoload("LocalizationManager").set_locale(locale)
		await t.frames(3)
		var rules := UiAudit.rule_report(inventory)
		t.check("inventory_rules_" + locale, rules.ok, str(rules.defects))
	t.autoload("LocalizationManager").set_locale("da")
	await t.frames(3)
	_select_item(inventory, &"hoe_wooden")
	t.check("last_tool_discard_protected", inventory.get_node("%DropButton").disabled)
	inventory._slots[inventory._selected].grab_focus()
	t.tap(&"slot_8")
	await t.frames(3)
	t.check("hotbar_assign_by_digit", t.player().hotbar.slots[7] == &"hoe_wooden")
	inventory.get_node("%AssignButton").pressed.emit()
	await t.frames(2)
	t.check("picker_eight_slots", inventory._picking and inventory._picker_buttons.size() == 8 and inventory.get_viewport().gui_get_focus_owner() == inventory._picker_buttons[0])
	for i in 3:
		UiAudit.press_pad(t, JOY_BUTTON_DPAD_RIGHT)
		await t.frames(2)
	UiAudit.press_pad(t, JOY_BUTTON_A)
	await t.frames(3)
	t.check("hotbar_assign_by_picker_pad", not inventory._picking and t.player().hotbar.slots[3] == &"hoe_wooden")
	inventory._slots[5].grab_focus()
	t.tap_key(KEY_RIGHT)
	await t.frames(2)
	t.check("grid_crosses_to_workshop", inventory.get_viewport().gui_get_focus_owner() == inventory.workshop.recipe_buttons[0])
	inventory.workshop.recipe_buttons[0].grab_focus()
	t.tap_key(KEY_LEFT)
	await t.frames(2)
	t.check("workshop_crosses_to_grid", inventory.get_viewport().gui_get_focus_owner() == inventory._slots[5])
	# These are the four guide recipes; every action goes through its real UI button.
	for needs in [{"glow_mushroom": 7, "iron_ore": 5, "moonstone": 1}, {"wood": 5, "moss": 2}, {"flour": 2, "honey": 1, "egg": 1}, {"copper_ore": 3, "wood": 2}]:
		for id in needs:
			eco.add_item(StringName(id), needs[id], true)
	await t.frames(3)
	for id in ["mushroom_lantern", "scarecrow", "honey_cake", "pickaxe_copper"]:
		var recipe := CraftingSystem.get_recipe(id)
		var before: int = eco.count_item(StringName(str(recipe.output.item)))
		for i in inventory.workshop._recipes.size():
			if str(inventory.workshop._recipes[i].id) == id:
				inventory.workshop.recipe_buttons[i].pressed.emit()
		t.expect(not inventory.workshop.craft_button.disabled, "Guide recipe enabled: " + id)
		inventory.workshop.craft_button.pressed.emit()
		await t.frames(3)
		t.check("craft_guide_" + id, eco.count_item(StringName(str(recipe.output.item))) >= before + int(recipe.output.amount))
	var locked := CraftingSystem.can_craft("forge_copper_plate")
	t.check("workshop_station_locks", not locked.locked.is_empty() and inventory.workshop._status(locked).contains("Kræver"), inventory.workshop._status(locked))
	# A blueprint unlocks the same live recipe list, and consumes its single copy.
	eco.add_item(&"blueprint_kongelig", 1, true)
	await t.frames(3)
	_select_item(inventory, &"blueprint_kongelig")
	inventory.get_node("%UseButton").pressed.emit()
	await t.frames(3)
	t.check("use_blueprint_through_control", eco.count_item(&"blueprint_kongelig") == 0 and bool(t.autoload("GameManager").get_flag(&"bp_kongelig", false)))
	t.tap_key(KEY_TAB)
	await t.frames(3)
	t.check("inventory_tab_closes_while_slot_focused", not inventory.is_open() and not t.tree.paused)
	await _discard_and_equip(t, inventory)
	await _closed_and_price(t, game_ui.get_screen(&"shop_ui"))
	for id in ["shop", "inventory"]:
		var report := await UiAudit.audit_screen(t, id)
		t.check(id + "_audit_live", report.ok and report.status == "live", UiAudit.summary(report))

func _select_item(inventory: Control, id: StringName) -> void:
	for i in inventory._slots.size():
		if inventory._slots[i].item_id == id:
			inventory._slots[i].grab_focus()
			inventory._select(i)
			return

func _pad_shop(t, screen: Control) -> void:
	var service: Node = t.autoload("ShopSystem")
	var eco: Node = t.autoload("EconomyManager")
	eco.gold = 100000
	service.open_shop(&"seed_shop")
	await t.frames(3)
	for row in screen._rows:
		if row.item_id == &"carrot_seeds":
			row.grab_focus()
	UiAudit.press_pad(t, JOY_BUTTON_A)
	await t.frames(2)
	t.check("pad_row_opens_stepper", screen.stepper.has_focus())
	UiAudit.press_pad(t, JOY_BUTTON_DPAD_RIGHT)
	await t.frames(2)
	t.check("stepper_right_adds_one", screen.stepper.value == 2)
	var tab: int = screen._tab
	t.tap_key(KEY_PAGEUP)
	await t.frames(2)
	t.check("stepper_page_up_not_tab", screen.stepper.value == 7 and screen._tab == tab)
	t.tap_key(KEY_PAGEDOWN)
	await t.frames(2)
	t.check("stepper_page_down", screen.stepper.value == 2)
	var before: int = eco.gold
	var count: int = eco.count_item(&"carrot_seeds")
	var total: int = service.get_buy_total(&"seed_shop", &"carrot_seeds", 2)
	UiAudit.press_pad(t, JOY_BUTTON_A)
	await t.frames(3)
	t.check("gamepad_only_buy", eco.gold == before - total and eco.count_item(&"carrot_seeds") == count + 2)
	UiAudit.press_pad(t, JOY_BUTTON_B)
	await t.frames(3)
	t.check("gamepad_close", not screen.is_open() and not t.tree.paused)

func _all_shops(t, screen: Control) -> void:
	var service: Node = t.autoload("ShopSystem")
	var eco: Node = t.autoload("EconomyManager")
	var gm: Node = t.autoload("GameManager")
	var shops: Dictionary = t.autoload("LuaRuntime").get_shops()
	for id in shops:
		Fresh.new_game(t)
		gm.set_config_override("towns.hours_enabled", false)
		eco.gold = 100000
		for day in range(1, 8):
			gm.day = day
			if service.is_open(id):
				break
		service.open_shop(StringName(id))
		await t.frames(3)
		var chosen: Button = null
		for row in screen._rows:
			if bool(row.entry.get("buyable", false)) and eco.can_add_item(row.item_id, 1):
				chosen = row
				break
		t.expect(chosen != null, "Every Lua shop has a usable offer: " + str(id))
		if chosen != null:
			var item: StringName = chosen.item_id
			chosen.pressed.emit()
			var before: int = eco.gold
			var owned: int = eco.count_item(item)
			var total: int = service.get_buy_total(id, item, 1)
			t.expect(screen.total_label.text == tr("SHOP_TOTAL") % str(screen.Fmt.thousands(total)), "Displayed total " + str(id))
			screen.buy_btn.pressed.emit()
			await t.frames(3)
			t.check("buy_control_" + str(id), eco.gold == before - total and eco.count_item(item) == owned + 1)
		# The sell page must use the shop's actual category restrictions.
		for item in [&"carrot", &"wood", &"copper_ore", &"honey"]:
			eco.add_item(item, 3, true)
		await t.frames(3)
		var sell_index: int = screen._tabs.size() - 1
		screen._tab_buttons[sell_index].pressed.emit()
		await t.frames(3)
		var sellable: Array = service.get_sell_list(id)
		if not sellable.is_empty():
			var row: Button = screen._rows[0]
			var item: StringName = row.item_id
			row.pressed.emit()
			screen.stepper.value = 1
			var before: int = eco.gold
			var owned: int = eco.count_item(item)
			var price: int = service.get_sell_price(id, item)
			screen.buy_btn.pressed.emit()
			await t.frames(3)
			t.check("sell_control_" + str(id), eco.gold == before + price and eco.count_item(item) == owned - 1)
		else:
			t.check("no_sellable_" + str(id), screen._rows.is_empty() and screen.buy_btn.disabled)
		screen.close()
		await t.frames(2)
	Fresh.new_game(t)
	gm.set_config_override("towns.hours_enabled", false)

func _discard_and_equip(t, inventory: Control) -> void:
	var eco: Node = t.autoload("EconomyManager")
	eco.add_item(&"carrot", 3, true)
	t.tap_key(KEY_I)
	await t.frames(3)
	_select_item(inventory, &"carrot")
	var count: int = eco.count_item(&"carrot")
	inventory.get_node("%DropButton").pressed.emit()
	await t.frames(3)
	t.check("discard_opens_confirmation", t.autoload("GameManager").top_modal() == &"confirm")
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	t.check("discard_cancel_preserves_item", eco.count_item(&"carrot") == count and inventory.is_open())
	inventory.get_node("%DropButton").pressed.emit()
	await t.frames(3)
	var confirm: Node = t.tree.get_first_node_in_group("ui_confirm")
	if confirm == null:
		confirm = inventory.find_child("UiConfirm", true, false)
	t.check("discard_confirmation_present", confirm != null)
	if confirm != null:
		confirm.get_node("%OkButton").grab_focus()
		UiAudit.press_pad(t, JOY_BUTTON_A)
		await t.frames(3)
		t.check("discard_confirm_removes_exactly_one", eco.count_item(&"carrot") == count - 1 and inventory.is_open())
	_select_item(inventory, &"hoe_wooden")
	var slot: String = eco.equip_slot_of(&"hoe_wooden")
	eco.equip(StringName(slot), &"")
	inventory.get_node("%EquipButton").pressed.emit()
	await t.frames(3)
	t.check("equip_via_control", eco.equipped_item(StringName(slot)) == &"hoe_wooden")
	t.player().half_hearts = t.player().max_half_hearts - 2
	_select_item(inventory, &"health_tonic")
	var tonics: int = eco.count_item(&"health_tonic")
	inventory.get_node("%UseButton").pressed.emit()
	await t.frames(3)
	t.check("consume_via_control", t.player().half_hearts == t.player().max_half_hearts and eco.count_item(&"health_tonic") == tonics - 1)
	inventory.close()
	await t.frames(3)

func _closed_and_price(t, screen: Control) -> void:
	var gm: Node = t.autoload("GameManager")
	var eco: Node = t.autoload("EconomyManager")
	var service: Node = t.autoload("ShopSystem")
	gm.clear_config_overrides()
	gm.day = 1
	gm.hour = 6
	service.open_shop(&"seed_shop")
	await t.frames(3)
	t.check("closed_state_reasons", screen.get_node("%ClosedLabel").visible and screen.get_node("%ClosedLabel").text.contains("08:00") and screen.buy_btn.disabled, screen.get_node("%ClosedLabel").text)
	screen.close()
	gm.hour = 12
	eco.gold = 100000
	service.open_shop(&"seed_shop")
	await t.frames(3)
	for row in screen._rows:
		if row.item_id == &"carrot_seeds":
			row.pressed.emit()
	var before: int = eco.gold
	var owned: int = eco.count_item(&"carrot_seeds")
	var unit: int = screen._displayed_unit
	service.set_price_curve_source(func(_shop, _item, _base): return unit + 5)
	screen.buy_btn.pressed.emit()
	await t.frames(3)
	t.check("price_change_requires_new_confirmation", eco.gold == before and eco.count_item(&"carrot_seeds") == owned and screen._displayed_unit == unit + 5)
	screen.buy_btn.pressed.emit()
	await t.frames(3)
	t.check("price_change_charges_new_displayed_total", eco.gold == before - unit - 5 and eco.count_item(&"carrot_seeds") == owned + 1)
	service.set_price_curve_source(Callable())
	var closed: Array = []
	var on_close := func(id): closed.append(id)
	t.autoload("EventBus").shop_closed.connect(on_close)
	t.autoload("EventBus").ui_panel_toggled.emit(&"shop", false)
	await t.frames(3)
	t.autoload("EventBus").shop_closed.disconnect(on_close)
	t.check("close_request_honoured_once", not screen.is_open() and not t.tree.paused and closed == [&"seed_shop"])
