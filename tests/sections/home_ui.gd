extends RefCounted
const SECTION := "home_ui"
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
	var home: Node = t.autoload("HomeManager")
	var fm: Node = t.autoload("FurnitureManager")
	var eco: Node = t.autoload("EconomyManager")
	var build: TTScreen = world.game_ui.get_screen(&"husbyggeri")
	var decorate: TTScreen = world.game_ui.get_screen(&"indretning")
	var chest: TTScreen = world.game_ui.get_screen(&"home_chest")
	t.check("three_real_screens_registered",build != null and decorate != null and chest != null)
	t.tap_key(KEY_H)
	await t.frames(3)
	t.check("decorate_outside_home_is_refused",not decorate.is_open() and not GameManager.is_modal_open())
	EventBus.game_event.emit(&"open_home_builder",{})
	await t.frames(3)
	t.check("builder_event_opens_paused",build.is_open() and not world.player.world_input_allowed())
	t.check("builder_shows_all_ten_tiers",build.ladder.get_child_count() == 10 and build.preview.texture != null)
	t.check("missing_requirements_disable_build",build.build_button.disabled)
	if native: await t.capture("builder_requirements")
	build.close()
	Grant.requirements(2)
	build.open()
	await t.frames(3)
	t.check("requirements_enable_build",not build.build_button.disabled)
	var before: Dictionary = home.to_dict()
	var gold: int = eco.gold
	build.build_button.pressed.emit()
	await t.frames(3)
	var confirm := _confirm(build)
	t.check("build_defaults_to_cancel",confirm != null and build.get_viewport().gui_get_focus_owner().name == "CancelButton")
	if native: await t.capture("builder_confirm")
	UiAudit.press(t,&"ui_cancel")
	await t.frames(3)
	t.check("cancel_does_not_spend_or_build",home.to_dict() == before and eco.gold == gold)
	build.build_button.pressed.emit()
	await t.frames(2)
	confirm = _confirm(build)
	confirm.find_child("OkButton",true,false).grab_focus()
	UiAudit.press_pad(t,JOY_BUTTON_A)
	await t.frames(3)
	t.check("confirmed_upgrade_uses_real_payment",home.is_under_construction() and home.construction.target == 2 and eco.gold == gold - home.gold_cost(2))
	t.check("builder_shows_construction",build.build_button.disabled and build.status.text == tr("HUSBYG_PROGRESS_FMT") % home.days_left())
	build.close()
	GameManager.end_day()
	await t.frames(3)
	t.check("next_morning_finishes_tier_two",home.tier == 2 and home.can_enter_home())
	await world.travel(&"home",&"default")
	t.tap_key(KEY_H)
	await t.frames(3)
	t.check("decorate_hotkey_pauses_with_grid",decorate.is_open() and fm.decorate_mode and decorate._preview != null)
	decorate.selected = "chair_pine"
	decorate.rot = 0
	decorate.cell = fm.grid.door_cell
	decorate._start_placing()
	var owned: int = fm.count_total("chair_pine")
	UiAudit.press(t,&"interact")
	await t.frames(3)
	t.check("blocked_door_placement_keeps_stock",fm.count_total("chair_pine") == owned and not decorate._preview.valid)
	var spot: Dictionary = fm._nearest_any("chair_pine")
	decorate.cell = spot.cell
	UiAudit.press(t,&"interact")
	await t.frames(4)
	t.check("place_key_moves_one_owned_piece",fm.count_total("chair_pine") == owned and fm.count_placed("chair_pine") == 1)
	t.check("placement_rebuild_keeps_preview_usable",is_instance_valid(decorate._preview) and decorate._preview.get_parent() == world.area)
	if native: await t.capture("decorate_placed")
	# UIC-06: an unchanged preview is not re-validated every frame; a pickup rebuilds the stock listing once, not twice.
	await t.frames(2)
	var evaluations: int = decorate._preview.evaluations
	await t.frames(10)
	var idle_ok: bool = decorate._preview.evaluations == evaluations
	decorate.cell += Vector2i(1, 0)
	await t.frames(2)
	var moved_ok: bool = decorate._preview.evaluations == evaluations + 1
	decorate.cell -= Vector2i(1, 0)
	await t.frames(2)
	var built := [0]
	var count_rows := func(_node: Node): built[0] += 1
	decorate.listing.child_entered_tree.connect(count_rows)
	t.tap_key(KEY_X)
	await t.frames(3)
	decorate.listing.child_entered_tree.disconnect(count_rows)
	t.check("pickup_key_returns_piece_to_store",fm.count_placed("chair_pine") == 0 and fm.count_total("chair_pine") == owned)
	t.check("decorate_preview_memoised_and_listing_built_once",idle_ok and moved_ok and built[0] == decorate.listing.get_child_count(),
		"idle frames re-validate nothing %s, a moved cell once %s; rows added %d for %d rows" % [idle_ok, moved_ok, built[0], decorate.listing.get_child_count()])
	t.tap_key(KEY_R)
	await t.frames(2)
	t.check("rotate_key_rotates_preview",decorate.rot == 1)
	t.tap_key(KEY_H)
	await t.frames(3)
	t.check("close_restores_world_input",not fm.decorate_mode and not decorate.is_open() and not GameManager.is_modal_open())
	# UIC-07: a dropped modal stack (quit to the title, load) leaves decorate mode like close() does.
	t.tap_key(KEY_H)
	await t.frames(3)
	var decorating: bool = decorate.is_open() and fm.decorate_mode
	GameManager.pop_all_modals()
	await t.frames(2)
	t.check("dropped_stack_ends_decorate_mode",decorating and not decorate.is_open() and not fm.decorate_mode and decorate._preview == null)
	EventBus.game_event.emit(&"open_home_chest",{})
	await t.frames(3)
	t.check("storage_event_opens_chest",chest.is_open())
	var n: int = eco.count_item(&"turnip_seeds")
	chest._transfer("turnip_seeds",2,true)
	await t.frames(2)
	t.check("deposit_button_uses_chest_owner",home.chest_count("turnip_seeds") == 2 and eco.count_item(&"turnip_seeds") == n-2)
	if native: await t.capture("home_chest")
	chest._transfer("turnip_seeds",1,false)
	t.check("withdraw_button_conserves_items",home.chest_count("turnip_seeds") == 1 and eco.count_item(&"turnip_seeds") == n-1)
	chest.close()
	build.open()
	TranslationServer.set_locale("en")
	await t.frames(3)
	t.check("english_builder_uses_live_translation",build.detail.get_child(0).text == tr(HomeData.tier_name_key(build.selected)) and build.status.text == tr("HUSBYG_BLOCK_" + str(home.can_start_upgrade(build.selected).reason).to_upper()) and build.status.text != "HUSBYG_BLOCK_" + str(home.can_start_upgrade(build.selected).reason).to_upper())
	build.close()
	TranslationServer.set_locale("da")
func _confirm(host: Control) -> UiConfirm:
	for child in host.get_children():
		if child is UiConfirm: return child
	return null
