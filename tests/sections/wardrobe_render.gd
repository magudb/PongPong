extends RefCounted
const SECTION := "wardrobe_render"
const TIMEOUT_S := 300.0
var native := false

func run(t) -> void:
	await _run(t)

func run_windowed(t) -> void:
	native = true
	await _run(t)

func _run(t, skin := "") -> void:
	await t.start_world("","Tester","Testgaarden",skin)
	var p: Player2D = t.player()
	var layers := p.outfit_layers
	var clock := p.visual
	p.set_physics_process(false)
	clock.set_process(false)
	var pose_count := 0
	var good := true
	for clip in IsoChibiSprite2D.meta_for(clock.resolved_id).animations:
		clock.cancel_action()
		clock.play_loop(clip)
		var frames := int(IsoChibiSprite2D.meta_for(clock.resolved_id).animations[clip].frames)
		for direction in 8:
			for frame in frames:
				clock.direction_index = direction
				clock._frame = frame
				clock._sync_sprite()
				layers.sync_pose()
				for sprite in layers.layers.values():
					good = good and sprite.get_parent().get_parent() == clock.sprite and sprite.region_rect == Rect2(0,direction*256,256,256)
					good = good and is_equal_approx(float(sprite.material.get_shader_parameter("frame_phase")),float(frame)/frames)
				good = good and layers.occluder.region_rect == clock.sprite.region_rect and layers.occluder.texture == clock.sprite.texture
				pose_count += 1
	t.check("every_live_body_pose_drives_all_clothing_layers", good and pose_count >= 300, "%s: %d clip/frame/direction poses" % [clock.resolved_id,pose_count])
	clock.set_spin(0.7)
	clock.set_altitude(28)
	clock.sprite.modulate = Color(.35,.45,.8,.5)
	layers.sync_pose()
	t.check("clothes_inherit_late_transform_and_tint_once", layers.root.get_parent() == clock.sprite and layers.root.global_transform == clock.sprite.global_transform and layers.root.modulate == Color.WHITE)
	clock.set_spin(0)
	clock.set_altitude(0)
	clock.sprite.modulate = Color.WHITE
	clock.cancel_action()
	clock.play_loop(&"idle")
	clock.direction_index = 0
	clock._frame = 0
	clock._sync_sprite()
	layers.sync_pose()
	var owner: Node = t.autoload("WardrobeManager")
	var original: Dictionary = owner.outfit()
	var body := clock.resolved_id
	var alternative: String = {"animal":"animal_monkey","fairy":"fairy_birk","hobbit":"hobbit_bodil","ghost":"ghost_hviske"}[t.character]
	if skin != "":
		alternative = CharacterCatalog.default_skin(t.character)
	var gm: Node = t.autoload("GameManager")
	var old_skin: StringName = gm.character_skin
	gm.character_skin = StringName(alternative)
	EventBus.player_character_changed.emit(PlayerRegistry.local_id(), gm.character_skin)
	t.check("existing_actor_refits_on_hero_change", clock.resolved_id != body, "resolved %s" % clock.resolved_id)
	t.check("hero_change_keeps_owned_outfit", layers.current_outfit == original and layers._body_id == clock.resolved_id)
	gm.character_skin = old_skin
	EventBus.player_character_changed.emit(PlayerRegistry.local_id(), old_skin)
	if native:
		var ui: Node = t.world().game_ui.get_screen(&"garderobe")
		ui.open()
		await t.frames(3)
		await _gallery(t,ui,t.character == "ghost" or (skin == "" and t.character == "animal"))
		await _turnarounds(t,ui)
		ui.close()
	if skin == "":
		await _run(t,alternative)

func _gallery(t, ui: Node, all_palettes: bool) -> void:
	var clock: IsoChibiSprite2D = ui.preview
	clock.set_process(false)
	clock.cancel_action()
	clock.play_loop(&"idle")
	clock.direction_index = 0
	clock._frame = 0
	clock._sync_sprite()
	ui.preview_layers.set_outfit({})
	ui.preview_layers.sync_pose()
	await t.frames(2)
	var baseline: Image = await t.capture("face_baseline_"+clock.resolved_id)
	var face: Array = WardrobeCatalog.body(clock.resolved_id).face_rect
	var local_face := Rect2(Vector2(face[0]-128,face[1]-200),Vector2(face[2],face[3]))
	var face_rect := Rect2i(clock.sprite.get_global_transform_with_canvas()*local_face)
	var reference := baseline.get_region(face_rect).get_data()
	DirAccess.remove_absolute(t.out_dir.path_join(SECTION+"_face_baseline_"+clock.resolved_id+".png"))
	var families := {}
	var cases: Array = []
	var ids := ItemKinds.all_ids("clothing")
	ids.sort()
	for id in ids:
		var family := str(ItemKinds.def(id).art.layer)
		if all_palettes or not families.has(family):
			cases.append(str(id))
		families[family] = true
	var sheets: Array[Image] = []
	var index := 0
	var max_face_difference := 0.0
	for id in cases:
		ui._select(id)
		ui.preview_layers.sync_pose()
		await t.frames(2)
		var name: String = "case_"+clock.resolved_id+"_"+id
		var picture: Image = await t.capture(name)
		var pixels := picture.get_region(Rect2i(clock.sprite.get_global_transform_with_canvas()*local_face)).get_data()
		var difference := 0.0
		for byte in mini(reference.size(),pixels.size()):
			difference += absf(float(reference[byte])-float(pixels[byte]))
		max_face_difference = maxf(max_face_difference,difference/maxi(reference.size(),1))
		if index%12 == 0:
			var page := Image.create(1120,840,false,Image.FORMAT_RGBA8)
			page.fill(Color("f3e8ce"))
			sheets.append(page)
		var rect: Rect2 = ui.preview_well.get_global_rect()
		var crop := picture.get_region(Rect2i(Vector2i(rect.get_center().x-120,rect.end.y-254),Vector2i(240,250)))
		var at := Vector2i((index%4)*280,floori((index%12)/4.0)*280)
		sheets[-1].blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),at+Vector2i(20,0))
		var label := picture.get_region(Rect2i(Vector2i(ui.detail_name.global_position),Vector2i(260,24)))
		sheets[-1].blit_rect(label,Rect2i(Vector2i.ZERO,label.get_size()),at+Vector2i(10,252))
		DirAccess.remove_absolute(t.out_dir.path_join(SECTION+"_"+name+".png"))
		index += 1
	for page in sheets.size():
		sheets[page].save_png(t.out_dir.path_join("catalog_%s_%02d.png" % [clock.resolved_id,page+1]))
	var metadata := {"body":clock.resolved_id,"cases":cases,"max_face_mean_byte_difference":max_face_difference,"pages":sheets.size(),"view":"S, idle frame zero"}
	var file := FileAccess.open(t.out_dir.path_join("catalog_"+clock.resolved_id+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(metadata,"  "))
	t.check("every_family_or_palette_rendered_without_covering_face", max_face_difference < 3.0 and cases.size() >= 30, str(metadata))

func _turnarounds(t, ui: Node) -> void:
	var clock: IsoChibiSprite2D = ui.preview
	var outfits := [
		{"hat":"hat_hood_green","necklace":"necklace_acorn","earrings":"earrings_copper","shirt":"shirt_linen_cream","pants":"pants_dungarees_blue","bracelet":"bracelet_string","shoes":"shoes_boots_brown"},
		{"hat":"hat_wizard_lavender","dress":"dress_gown_aurora","shoes":"shoes_slippers_cream"},
		{"circlet":"circlet_daisy","dress":"dress_sun_cream","necklace":"necklace_beads_wood","bracelet":"bracelet_copper","shoes":"shoes_clogs_gilded"},
		{"hat":"hat_straw_green","shirt":"shirt_linen_cream","pants":"pants_trousers_brown","shoes":"shoes_boots_brown"}]
	var sheet := Image.create(1920,outfits.size()*250,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("f3e8ce"))
	var fitted := true
	for row in outfits.size():
		fitted = ui.preview_layers.set_outfit(outfits[row]) and fitted
		for direction in 8:
			clock.set_direction_index(direction)
			ui.preview_layers.sync_pose()
			await t.frames(2)
			var id := "turn_%s_%d_%d" % [clock.resolved_id,row,direction]
			var picture: Image = await t.capture(id)
			var rect: Rect2 = ui.preview_well.get_global_rect()
			var crop := picture.get_region(Rect2i(Vector2i(rect.get_center().x-120,rect.end.y-254),Vector2i(240,250)))
			sheet.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(direction*240,row*250))
			DirAccess.remove_absolute(t.out_dir.path_join(SECTION+"_"+id+".png"))
	sheet.save_png(t.out_dir.path_join("turnarounds_"+clock.resolved_id+".png"))
	t.check("mixed_seven_slot_and_dress_outfits_in_all_directions", fitted)
	ui.preview_layers.set_outfit(outfits[0])
	# Include a direction change on every sample, the expensive path that binds
	# the body-specific tailoring to both fabric and skin occlusion materials.
	var samples: Array[float] = []
	for sample_index in 240:
		clock.set_direction_index(sample_index%8)
		var started := Time.get_ticks_usec()
		ui.preview_layers.sync_pose()
		samples.append((Time.get_ticks_usec()-started)/1000.0)
	samples.sort()
	var p95 := samples[floori(samples.size()*0.95)]
	t.check("tailored_pose_update_under_equipment_budget", t.perf_ok("tailored_pose_update_under_equipment_budget", p95, 0.3), "%s p95 %.4f ms across 240 changing directions (native reference 0.3 ms)" % [clock.resolved_id, p95])
	t.check("tailoring_adds_no_extra_canvas_items", ui.preview_layers.root.get_child_count() == outfits[0].size()+1)

	ui.preview_layers.set_outfit(outfits[-1])
	clock.play_loop(&"walk")
	ui.preview_held.preview_item = &"iron_sword"
	var steps := int(IsoChibiSprite2D.meta_for(clock.resolved_id).animations.walk.frames)
	var motion := Image.create(1920,steps*250,false,Image.FORMAT_RGBA8)
	motion.fill(Color("f3e8ce"))
	for frame in steps:
		for direction in 8:
			clock.direction_index = direction
			clock._frame = frame
			clock._sync_sprite()
			ui.preview_layers.sync_pose()
			ui.preview_held.sync_pose()
			await t.frames(2)
			var id := "motion_%s_%d_%d" % [clock.resolved_id,frame,direction]
			var picture: Image = await t.capture(id)
			var rect: Rect2 = ui.preview_well.get_global_rect()
			var crop := picture.get_region(Rect2i(Vector2i(rect.get_center().x-120,rect.end.y-254),Vector2i(240,250)))
			motion.blit_rect(crop,Rect2i(Vector2i.ZERO,crop.get_size()),Vector2i(direction*240,frame*250))
			DirAccess.remove_absolute(t.out_dir.path_join(SECTION+"_"+id+".png"))
	motion.save_png(t.out_dir.path_join("walking_"+clock.resolved_id+".png"))
