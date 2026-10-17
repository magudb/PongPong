extends RefCounted
const SECTION := "dungeon_hud"
const TIMEOUT_S := 180.0
func run(t) -> void:
	await _run(t,false)
func run_windowed(t) -> void:
	await _run(t,true)
func _focusable(root: Node) -> int:
	var count := 1 if root is Control and root.focus_mode != Control.FOCUS_NONE else 0
	for child in root.get_children(): count += _focusable(child)
	return count
func _run(t,native: bool) -> void:
	await t.start_world()
	var world: WorldRoot2D = t.world()
	var hud: Control = world.game_ui.get_screen(&"forest_hud")
	t.check("hidden_in_farm_mode",hud != null and not hud.visible and world.game_ui.get_screen(&"hud").visible)
	if hud == null: return
	var eco: Node = t.autoload("EconomyManager")
	eco.remove_item(&"etagekort",eco.count_item(&"etagekort"))
	var floors := DungeonFloors.inst()
	floors.enter(1)
	await t.until(func(): return world.area.map.id == &"moerkeskoven_f1" and not world.traveling,10.0)
	await t.frames(3)
	t.check("action_mode_shows_forest_hud",hud.visible and not world.game_ui.get_screen(&"hud").visible)
	t.check("run_watch_attached_once",hud.get_node_or_null("RunWatch") != null and DungeonRun.attach(hud) == hud.get_node("RunWatch"))
	t.check("chip_text_from_header",hud.zone_label.text == TranslationServer.translate(world.area.map.title)+" · "+str(world.area.map.depth))
	EventBus.player_health_changed.emit(7,10)
	EventBus.player_oil_changed.emit(29,150)
	EventBus.boss_bar_changed.emit("BOSS_SNURRESVAMPEN",.66,true)
	t.check("reacts_to_events",hud.hearts.half_hearts == 7 and is_equal_approx(hud.oil_bar.value,100.0*29/150) and hud.boss_box.visible and is_equal_approx(hud.boss_bar.value,66))
	EventBus.player_health_changed.emit(17,18)
	t.check("hearts_scale_with_bonus",hud.hearts.max_hearts == 6 and hud.second_hearts.visible and hud.second_hearts.max_hearts == 3 and hud.second_hearts.half_hearts == 5 and hud.oil_pill.position.y == 138)
	DungeonRun.apply_preset("cozy")
	t.check("assist_badge",hud.assist_badge.visible and hud.assist_badge.text.contains(TranslationServer.translate("ASSIST_PRESET_COZY")))
	DungeonRun.apply_preset("none")
	EventBus.game_event.emit(&"dungeon_hint",{"id":"dodge"})
	t.check("hint_pulses_ability_slot",hud.abilities.dodge.modulate != Color.WHITE and hud.abilities.dodge.focus_mode == Control.FOCUS_NONE)
	var minimap: Minimap2D = hud.minimap
	floors.reveal.erase(1)
	minimap.set_area(world.area)
	var revealed := minimap.fog.size()
	t.check("minimap_fog_is_per_visit",revealed > 0 and revealed <= 613 and revealed < world.area.map.width*world.area.map.height)
	minimap.reveal_all()
	t.check("minimap_map_reveals_whole_floor",minimap.fully_revealed and minimap.is_seen(Vector2i(world.area.map.width-1,world.area.map.height-1)))
	minimap.set_area(world.area)
	t.check("minimap_fog_resets_on_reentry",not minimap.fully_revealed and minimap.fog.size() == revealed)
	_test_chest_sense(t,world,minimap,eco)
	var feed: VBoxContainer = hud.loot_feed
	feed.clear()
	EventBus.item_gained.emit(&"iron_ore",2)
	EventBus.loot_rolled.emit(&"test",[{"id":"iron_ore","amount":2}])
	EventBus.item_gained.emit(&"iron_ore",3)
	t.check("loot_feed_coalesces_without_transaction_double_count",feed.entries.size() == 1 and feed.entries[0].amount == 5 and feed.entries[0].source == "test")
	EventBus.loot_rolled.emit(&"sold_duplicate",[{"id":"gem_rune_heart","amount":1}])
	t.check("refused_or_sold_keepsake_has_no_feed_row",feed.entries.size() == 1)
	for id in [&"stone",&"wood",&"copper_ore",&"rusty_sword"]: EventBus.item_gained.emit(id,1)
	t.check("loot_feed_caps_newest_first",feed.entries.size() == 4 and feed.entries[0].id == &"rusty_sword")
	var slots_before: Dictionary = eco.to_dict()
	eco.inventory.clear()
	for i in 24: eco.inventory.append({"id":&"stone","amount":99,"meta":{}})
	EventBus.player_inventory_changed.emit(eco.get_inventory_dict())
	t.check("backpack_chip_full",hud.backpack_chip.visible and hud.backpack_chip.text.ends_with("24/24"))
	eco.inventory.resize(20)
	EventBus.player_inventory_changed.emit(eco.get_inventory_dict())
	t.check("backpack_chip_near",hud.backpack_chip.visible and hud.backpack_chip.text.ends_with("20/24"))
	eco.from_dict(slots_before)
	EventBus.boss_bar_changed.emit("",0,false)
	var arrivals: int = hud.floor_banner.arrivals
	EventBus.game_event.emit(&"dungeon_floor_entered",{"floor":1,"first_today":false})
	await t.frames(2)
	t.check("floor_banner_once_per_arrival",hud.floor_banner.arrivals == arrivals+1 and hud.floor_banner.visible)
	EventBus.boss_bar_changed.emit("BOSS_SNURRESVAMPEN",.66,true)
	EventBus.game_event.emit(&"dungeon_floor_entered",{"floor":1,"first_today":false})
	await t.frames(2)
	t.check("floor_banner_suppressed_by_boss",hud.floor_banner.arrivals == arrivals+1 and not hud.floor_banner.visible)
	t.check("no_focusable_controls",_focusable(hud) == 0)
	t.check("ability_keys_resolve_real_actions",hud.abilities.light.action == &"light" and hud.abilities.light.key_label.text == "Q")
	t.check("equipped_item_indicator_preserved",hud.current_item_badge != null and hud.current_item_badge.is_visible_in_tree())
	if native:
		var started := Time.get_ticks_usec()
		for i in 1000: hud._process(1.0/60)
		var frame_ms := (Time.get_ticks_usec()-started)/1000000.0
		started = Time.get_ticks_usec()
		for i in 100: hud.minimap.update_map()
		var map_ms := (Time.get_ticks_usec()-started)/100000.0
		var amortized_ms := frame_ms+map_ms/6
		t.check("hud_update_budget_under_point_four_ms",amortized_ms < .4,"HUD %.4f ms + minimap %.4f ms at 10 Hz = %.4f ms/frame" % [frame_ms,map_ms,amortized_ms])
		EventBus.player_health_changed.emit(10,10)
		EventBus.player_oil_changed.emit(150,150)
		hud.toasts.clear()
		feed.clear()
		for id in [&"iron_ore",&"moonstone",&"amethyst"]: EventBus.item_gained.emit(id,1)
		world.player.camera.reset_smoothing()
		world.player.camera.force_update_scroll()
		await t.frames(4)
		await t.capture("forest_hud_default")
		DungeonRun.apply_preset("cozy")
		EventBus.player_health_changed.emit(18,18)
		await t.frames(3)
		await t.capture("hearts_9_layout")
		EventBus.boss_bar_changed.emit("",0,false)
		floors.activate_stone(3)
		var picker := world.game_ui.get_node_or_null("RunePicker")
		if picker == null:
			picker = preload("res://scenes/ui/rune_picker.tscn").instantiate()
			picker.name = "RunePicker"
			world.game_ui.add_child(picker)
		picker.open()
		await t.frames(3)
		await t.capture("picker_lines")
		picker.close()
	DungeonRun.apply_preset("none")
	await world.travel(&"farm",&"default")
	t.check("hidden_after_return_to_farm",not hud.visible)
	if native: await _guide(t)
func _test_chest_sense(t,world: WorldRoot2D,minimap: Minimap2D,eco: Node) -> void:
	var area := world.area
	var saved_markers: Array[Dictionary] = area.markers.duplicate()
	var saved_position := world.player.global_position
	var saved_items: Dictionary = eco.to_dict()
	var player_cell := Vector2i(area.map.width/2,area.map.height/2)
	world.player.global_position = area.cell_to_global(player_cell)
	var chest_cell := player_cell+Vector2i(DungeonRun.chest_sense_cells()+2,0)
	var params := {"tier":"trae","hidden":1}
	var chest := LootChest2D.create_marker(params,area.cell_to_global(chest_cell),chest_cell,area) as LootChest2D
	area.objects.add_child(chest)
	chest.global_position = area.cell_to_global(chest_cell)
	area.markers.assign([{"type":"chest","params":params,"cell":chest_cell,"node":chest}])
	minimap.set_area(area)
	var has_chest := func(): return minimap._dots.any(func(dot): return dot.color == Minimap2D.C.GOLD and dot.radius == 3)
	t.check("undiscovered_chest_hidden_even_on_seen_terrain",minimap.is_seen(chest_cell) and not chest.revealed and not has_chest.call())
	eco.add_item(&"gem_rune_heart",1,true)
	eco.equip(&"accessory",&"gem_rune_heart")
	minimap.update_map(true)
	t.check("real_lantern_gem_senses_hidden_chest",not chest.revealed and has_chest.call())
	area.markers[0].cell = player_cell+Vector2i(13,0)
	minimap.update_map(true)
	t.check("sense_respects_twelve_cell_limit",not has_chest.call())
	area.markers[0].cell = chest_cell
	eco.from_dict(saved_items)
	world.player.global_position = chest.global_position
	chest._process(.2)
	minimap.update_map(true)
	t.check("real_proximity_discovery_keeps_chest_visible",chest.revealed and has_chest.call())
	chest.set_enabled(false)
	minimap.update_map(true)
	t.check("condition_disabled_chest_is_omitted",not has_chest.call())
	chest.set_enabled(true)
	chest.is_open = true
	minimap.update_map(true)
	t.check("opened_chest_is_omitted",not has_chest.call())
	area.markers.assign(saved_markers)
	world.player.global_position = saved_position
	chest.free()
	minimap.set_area(area)
func _guide(t) -> void:
	await t.clear_scene()
	var host := Control.new()
	host.theme = preload("res://assets/ui/theme.tres")
	t.tree.root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fixture: Control = await preload("res://scripts/ui/dev/ui_fixtures.gd").make("forest_guide",host)
	# Reproduce the guide's two CSS gradients in this isolated UI comparison.
	# The playable scene always uses the painted world.
	var atmosphere := ColorRect.new()
	atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
void fragment() {
 vec2 p = UV * vec2(1280.0,720.0);
 float glow = .18 * clamp(1.0-length(p-vec2(640.0,374.4))/260.0,0.0,1.0);
 float edge = .7 * clamp((length((p-vec2(640.0,360.0))/vec2(905.097,509.117))-.4)/.6,0.0,1.0);
 float alpha = glow + edge*(1.0-glow);
 COLOR = vec4((vec3(111.0,214.0,196.0)/255.0*glow+vec3(10.0,10.0,24.0)/255.0*edge*(1.0-glow))/max(.00001,alpha),alpha);
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	atmosphere.material = material
	host.add_child(atmosphere)
	host.move_child(atmosphere,1)
	var scene_note := Label.new()
	scene_note.text = "scene: top-down sti med lysende svampe, spiller i midten"
	scene_note.theme_type_variation = &"Mono14"
	scene_note.add_theme_font_override("font",preload("res://assets/fonts/IBMPlexMono-Regular.ttf"))
	scene_note.add_theme_font_size_override("font_size",14)
	var note_style := StyleBoxFlat.new()
	note_style.bg_color = Color(0.984,0.961,0.902,.92)
	note_style.set_corner_radius_all(4)
	note_style.content_margin_left = 12
	note_style.content_margin_right = 12
	note_style.content_margin_top = 6
	note_style.content_margin_bottom = 6
	scene_note.add_theme_stylebox_override("normal",note_style)
	fixture.add_child(scene_note)
	scene_note.position = Vector2(640,360)-scene_note.get_minimum_size()*.5
	fixture.current_item_badge.hide()
	fixture.toasts.clear()
	fixture._health(7,10)
	fixture._oil(87,150)
	fixture._boss("BOSS_SNURRESVAMPEN",.64,true)
	fixture.oil_count.hide()
	fixture.oil_bar.custom_minimum_size.x = 180
	fixture.zone_label.text = "Dybe Bregner · 2"
	fixture._fit_zone()
	fixture.minimap.hide()
	var map := ColorRect.new()
	map.set_script(preload("res://scripts/ui/components/tt_stripes.gd"))
	map.color_a = Color("2f4a3f")
	map.color_b = Color("294132")
	map.band = 10
	map.radii = Vector4(94,94,94,94)
	map.border = 3
	fixture.add_child(map)
	map.material.set_shader_parameter("border_color",Color("e3c372"))
	map.position = Vector2(1054,38)
	map.size = Vector2(188,188)
	var note := Label.new()
	note.text = "minikort"
	note.theme_type_variation = &"EyebrowL"
	note.add_theme_color_override("font_color",Color("fbf5e6"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	map.add_child(note)
	note.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fixture.move_child(map,fixture.zone_label.get_index())
	fixture.loot_feed.clear()
	fixture.loot_feed.gain(&"glow_mushroom",2)
	fixture.loot_feed.gain(&"iron_ore",3)
	fixture.loot_feed.gain(&"moonstone",1)
	fixture.abilities.dodge.set_cooldown(.5,"0,4")
	for child in fixture.get_children():
		if child is WhisperLine: child._on_whisper("Noget rasler i bregnerne…")
	await t.seconds(.2)
	await t.capture("forest_guide")
	host.free()
