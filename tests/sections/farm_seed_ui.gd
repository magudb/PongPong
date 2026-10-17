extends RefCounted
const SECTION := "farm_seed_ui"
const TIMEOUT_S := 180.0
var native := false
func run(t) -> void: await _run(t)
func run_windowed(t) -> void:
	native = true
	await _run(t)
func _run(t) -> void:
	await t.start_world()
	var w: WorldRoot2D = t.world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.season = &"vinter"
	var shop: Control = w.game_ui.get_screen(&"shop_ui")
	var bag: Control = w.game_ui.get_screen(&"inventory_ui")
	for crop in FarmGrid.crop_definitions(): EconomyManager.add_item(StringName(str(crop)+"_seeds"),1,true)
	for locale in ["da", "en"]:
		LocalizationManager.set_locale(locale)
		ShopSystem.open_shop(&"greenhouse_seeds")
		await t.frames(3)
		var broken: Array[String] = []
		var tested := 0
		for row in shop._rows:
			row.pressed.emit()
			await t.frames(2)
			var stats: Label = shop.farming_stats
			tested += 1
			if not _readable(shop,stats) or shop.get_node("ShopPanel/PanelBody/ItemScroll").size.y < 84 or stats.get_global_rect().intersects(shop.buy_btn.get_global_rect()): broken.append(str(row.item_id))
		t.check("all_shop_seed_facts_visible_"+locale, tested==11 and broken.is_empty(),str(broken))
		if native and locale=="da": await t.capture("shop_seed_details")
		shop.close()
		bag.open()
		await t.frames(3)
		broken.clear()
		tested = 0
		for i in bag._items.size():
			var id := str(bag._items[i].id)
			if not id.ends_with("_seeds"): continue
			bag._slots[i].pressed.emit()
			await t.frames(2)
			var stats: Label = bag.farming_stats
			tested += 1
			if not _readable(bag,stats) or stats.get_global_rect().intersects(bag.get_node("%AssignButton").get_global_rect()): broken.append(id)
		t.check("all_backpack_seed_facts_visible_"+locale,tested==11 and broken.is_empty(),str(broken))
		if native and locale=="da": await t.capture("backpack_seed_details")
		bag.close()
	LocalizationManager.set_locale("da")
func _readable(screen: Control, label: Label) -> bool:
	return label.is_visible_in_tree() and label.text.contains(TranslationServer.translate("FARMSITE_GROWTH_FMT").split("%")[0]) and label.max_lines_visible == -1 and label.get_visible_line_count() == label.get_line_count() and screen.get_global_rect().encloses(label.get_global_rect())
