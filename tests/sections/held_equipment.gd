extends RefCounted
const SECTION := "held_equipment"
const TIMEOUT_S := 180.0
var shots := false

func run(t) -> void:
	await _run(t, false)

func run_windowed(t) -> void:
	await _run(t, true)

func _run(t, capture: bool, skin := "") -> void:
	shots = capture
	if not await t.start_world("", "Tester", "Testgaarden", skin):
		return
	var world: WorldRoot2D = t.world()
	var p: Player2D = world.player
	var eco: Node = t.autoload("EconomyManager")
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.set_flag(&"intro_pending", false)
	p.set_physics_process(false)
	p.visual.set_process(false)
	p.held_equipment.set_process(false)
	var badge: CurrentItemBadge = world.game_ui.get_screen(&"hud").current_item_badge
	t.check("badge_cannot_take_focus_or_eat_world_input", badge.focus_mode == Control.FOCUS_NONE and badge.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	p.hotbar.assign(0, &"hoe_wooden")
	p.hotbar.select(0)
	p.held_equipment.sync_pose()
	t.check("selected_tool_has_matching_picture_and_name", badge.shown().id == &"hoe_wooden" and badge.shown().name == tr("ITEM_HOE_WOODEN") and p.held_equipment.item_id == &"hoe_wooden")
	var data := HeldEquipment2D.manifest()
	var missing: Array[String] = []
	for id in GameData.lua().get_all_item_ids():
		if str(GameData.item_def(StringName(id)).get("category", "")) in ["tool", "weapon"] and not data.items.has(str(id)):
			missing.append(str(id))
	t.check("whole_item_catalog_has_held_tool_and_weapon_art", missing.is_empty(), str(missing))
	var body := p.visual.resolved_id
	var poses: Dictionary = data.bodies[body].clips
	var checked := 0
	var valid := true
	for clip in poses:
		p.visual.cancel_action()
		p.visual.play_loop(StringName(clip))
		for direction in 8:
			for frame in poses[clip][direction].size():
				p.visual.direction_index = direction
				p.visual._frame = frame
				p.visual._sync_sprite()
				p.held_equipment.sync_pose()
				var fit: Dictionary = p.held_equipment.pose
				var expected: Dictionary = poses[clip][direction][frame]
				valid = valid and fit == expected and p.held_equipment.tool.position == Vector2(expected.grip[0]-128, expected.grip[1]-200)
				valid = valid and p.held_equipment.tool.get_parent() == (p.held_equipment.rear if expected.depth == "rear" else p.held_equipment.front)
				valid = valid and p.held_equipment.hand.visible == (expected.depth == "front")
				checked += 1
	t.check("every_body_frame_and_direction_has_fitted_grip", valid and checked >= 300, "%s: %d real body poses" % [body, checked])
	p.visual.play_loop(&"idle")
	p.visual.set_direction_index(0)
	p.visual.set_altitude(28)
	p.visual.set_spin(0.6)
	p.visual.sprite.modulate = Color("b8a4cf")
	p.held_equipment.sync_pose()
	t.check("altitude_spin_and_flash_follow_body_once", p.held_equipment.front.get_parent() == p.visual.sprite and p.held_equipment.front.global_transform == p.visual.sprite.global_transform and p.held_equipment.front.modulate == Color.WHITE)
	p.visual.set_spin(0)
	p.visual.set_altitude(0)
	p.visual.sprite.modulate = Color.WHITE
	var all_items := true
	for id in data.items:
		if not eco.has_item(StringName(id)):
			eco.add_item(StringName(id), 1)
		p.hotbar.assign(0, StringName(id))
		for direction in 8:
			p.visual.set_direction_index(direction)
			p.held_equipment.sync_pose()
			var art: Dictionary = data.items[id].views[direction]
			all_items = all_items and p.held_equipment.item_id == StringName(id) and p.held_equipment.tool.region_rect == Rect2(art.rect[0],art.rect[1],128,128)
	t.check("all_items_use_dedicated_directional_paintings", all_items)
	if shots and t.character == "animal" and skin == "":
		await _catalog_gallery(t, world, p, badge, data)
	p.hotbar.assign(0, &"hoe_wooden")
	p.visual.set_direction_index(0)
	p.held_equipment.sync_pose()
	if shots:
		world.game_ui.get_screen(&"hud").toasts.clear()
		p.visual.set_process(true)
		p.held_equipment.set_process(true)
		await t.frames(4)
		await t.capture("tool_" + body)
		p.visual.set_process(false)
		p.held_equipment.set_process(false)
	var cell: Vector2i = world.farm.farmable_cells()[0]
	p.facing8 = 0
	p.facing_vec = Iso.dir8_vector(0)
	p.global_position = world.area.cell_to_global(cell - world.area.facing_step(0))
	t.check("real_hoe_action_starts", p.use_selected())
	p.hotbar.assign(0, &"watering_can_copper")
	p.held_equipment.sync_pose()
	t.check("action_readout_keeps_hoe_after_hotbar_swap", p.equipment_display().id == &"hoe_wooden" and badge.shown().context == tr("HUD_ITEM_USING") and p.held_equipment.item_id == &"hoe_wooden")
	p._physics_process(0.5)
	t.check("next_selection_appears_after_action_finishes", p.equipment_display().id == &"watering_can_copper")
	p.hotbar.assign(0, &"")
	p.held_equipment.sync_pose()
	t.check("empty_slot_clears_attachment_and_names_empty_hands", p.equipment_display().id == &"" and badge.shown().name == tr("HUD_ITEM_EMPTY") and not p.held_equipment.front.visible and not p.held_equipment.rear.visible)
	p.hotbar.assign(0, &"iron_sword")
	eco.equip(&"weapon", &"sword_rusty")
	t.check("selected_sword_is_actual_weapon_in_farm_action", p.use_selected() and p.combat.active_weapon_id() == &"iron_sword" and int(p.combat._weapon.damage) == 12)
	p.hotbar.assign(0, &"hoe_wooden")
	eco.equip(&"weapon", &"sword_rusty")
	t.check("swing_snapshot_survives_equipment_change", badge.shown().id == &"iron_sword" and p.equipment_display().id == &"iron_sword")
	p.combat.cancel_action()
	p.state = PlayerBody2D.S.FREE
	p.begin_talk(p.global_position + Vector2.UP)
	p.held_equipment.sync_pose()
	t.check("dialogue_puts_held_item_away", not p.held_equipment.front.visible and not p.held_equipment.rear.visible)
	p.end_talk()
	p.held_equipment.sync_pose()
	t.check("dialogue_release_restores_selected_tool", p.held_equipment.front.visible or p.held_equipment.rear.visible)
	t.check("enter_real_forest_hub", world._enter(&"moerkeskoven", &"default"))
	await t.physics(3)
	p.set_physics_process(false)
	p.visual.set_process(false)
	p.held_equipment.set_process(false)
	p.held_equipment.sync_pose()
	t.check("forest_shows_equipped_weapon_even_with_hoe_selected", p.hotbar.current() == &"hoe_wooden" and p.equipment_display().id == &"sword_rusty" and badge.shown().id == &"sword_rusty")
	t.check("forest_keeps_actual_readout_and_health_visible", world.game_ui.get_screen(&"hud").is_visible_in_tree() and badge.is_visible_in_tree())
	eco.equip(&"weapon", &"")
	p.combat.cooldowns.slash = 0
	t.check("empty_weapon_slot_never_uses_phantom_sword", not p.swing() and p.equipment_display().id == &"")
	eco.equip(&"weapon", &"iron_sword")
	p.visual.cancel_action()
	p.visual.play_loop(&"idle")
	p.visual.set_direction_index(0)
	p.global_position = world.area.cell_to_global(Vector2i(20, 24))
	p.camera.reset_smoothing()
	p.held_equipment.sync_pose()
	if shots:
		world.game_ui.get_screen(&"hud").toasts.clear()
		p.visual.set_process(true)
		p.held_equipment.set_process(true)
		await t.frames(4)
		await t.capture("weapon_" + body)
		p.visual.set_process(false)
		p.held_equipment.set_process(false)
	var original := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	await t.frames(2)
	t.check("readout_follows_language_change", badge.shown().name == tr("ITEM_IRON_SWORD") and badge.shown().context == tr("HUD_ITEM_WEAPON"))
	TranslationServer.set_locale(original)
	var sm: Node = t.autoload("SaveManager")
	t.check("equipment_save_written", sm.save_game(4))
	eco.equip(&"weapon", &"sword_rusty")
	p.hotbar.assign(0, &"axe_wooden")
	var old_world := world.get_instance_id()
	t.check("equipment_save_loaded", sm.load_and_enter(4))
	await t.until(func(): return t.world() != null and t.world().get_instance_id() != old_world and t.world().ready_for_play, 10)
	await t.physics(4)
	world = t.world()
	p = world.player
	badge = world.game_ui.get_screen(&"hud").current_item_badge
	p.held_equipment.sync_pose()
	t.check("save_rebuilds_correct_held_weapon_without_extra_state", p.hotbar.current() == &"hoe_wooden" and badge.shown().id == &"iron_sword" and p.held_equipment.item_id == &"iron_sword")
	sm.delete_save(4)
	gm.clear_config_overrides()
	if skin == "":
		var alternate: String = {"animal":"animal_monkey","fairy":"fairy_birk","hobbit":"hobbit_bodil","ghost":"ghost_hviske"}[t.character]
		await _run(t, capture, alternate)


func _catalog_gallery(t, world: WorldRoot2D, p: Player2D, badge: CurrentItemBadge, data: Dictionary) -> void:
	# Review the actual renderer at game zoom, including every tool upgrade.
	# Retain exact pixel crops in one contact sheet rather than 12 full frames.
	var gallery := Image.create(1200, ceili(data.items.size()/4.0)*240, false, Image.FORMAT_RGBA8)
	gallery.fill(Color("f3e8ce"))
	world.game_ui.get_screen(&"hud").toasts.clear()
	p.visual.cancel_action()
	p.visual.play_loop(&"idle")
	p.visual.set_direction_index(0)
	var index := 0
	for id in data.items:
		p.hotbar.assign(0, StringName(id))
		p.held_equipment.sync_pose()
		await t.frames(3)
		var name: String = "catalog_" + str(id)
		var picture: Image = await t.capture(name)
		var foot := p.visual.get_global_transform_with_canvas().origin
		var actor := picture.get_region(Rect2i(Vector2i(foot)-Vector2i(100,130),Vector2i(200,170)))
		var label := picture.get_region(Rect2i(badge.get_global_rect().grow(2)))
		var at := Vector2i((index%4)*300,floori(index/4.0)*240)
		gallery.blit_rect(actor,Rect2i(Vector2i.ZERO,actor.get_size()),at+Vector2i(50,0))
		gallery.blit_rect(label,Rect2i(Vector2i.ZERO,label.get_size()),at+Vector2i(8,175))
		DirAccess.remove_absolute(t.out_dir.path_join(SECTION+"_"+name+".png"))
		index += 1
	gallery.save_png(t.out_dir.path_join("catalog-contact.png"))
