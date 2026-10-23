extends RefCounted
const SECTION := "art_farm_dress"
const TIMEOUT_S := 120.0
func run(t) -> void:
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/art/farm-seasons/prompts.json"))
	var bytes := 0
	for spec in plan.items:
		var path := "res://assets/iso_props/farm_dress/"+str(spec.id)+".webp"
		var texture := load(path) as Texture2D
		var image := texture.get_image() if texture!=null else null
		if image!=null and image.is_compressed():image.decompress()   # world props import S3TC (tools/import/write_import_stubs.py POLICY)
		t.check(str(spec.id)+"_native_dimensions",image!=null and texture.get_width()==int(spec.size[0]) and texture.get_height()==int(spec.size[1]))   # an S3TC image is stored at 4 px multiples
		if image==null:continue
		bytes += texture.get_width()*texture.get_height()*4
		t.check(str(spec.id)+"_transparent_gutter",image.get_pixel(0,0).a<0.01 and image.get_pixel(image.get_width()-1,image.get_height()-1).a<0.01)
		t.check(str(spec.id)+"_source_retained",FileAccess.file_exists("res://"+str(spec.source)))
		if str(spec.type)!="particle":t.check(str(spec.id)+"_catalogued",ArtCatalog.has_real_prop(StringName(str(spec.get("catalog_id",spec.id)))) and ArtCatalog.prop(StringName(str(spec.get("catalog_id",spec.id)))).texture==texture)
	t.check("nineteen_painted_assets",plan.items.size()==19)
	t.check("vram_under_four_mib",bytes<=4*1024*1024,str(float(bytes)/1024/1024)+" MiB RGBA")
	var tool: Dictionary = t.run_tool(ProjectSettings.globalize_path("res://tools/art/.venv/bin/python"),["-B",ProjectSettings.globalize_path("res://tools/art/environment/farm_dress/pack_paintings.py"),"--check"])
	t.check("packing_reproducible",int(tool.code)==0,str(tool.output))

func run_windowed(t) -> void:
	await t.start_world()
	GameManager.set_config_override("time.minutes_per_real_second",0)
	var layer := CanvasLayer.new()
	layer.layer = 100
	t.world().add_child(layer)
	var root := Control.new()
	root.size = Vector2(1280,720)
	layer.add_child(root)
	var background := ColorRect.new()
	background.color = Color("f4e6c4")
	background.size = Vector2(1280,720)
	root.add_child(background)
	var title := _label(root,"Painted farm dressing · native game scale",Vector2(25,12),24)
	var ids := ["flower_box","garden_arch","fountain_small","royal_banner","blossom_cluster","sunflower_row","leaf_pile","pumpkin_stack","snow_patch","bunting_x","vine_hang","pond_lily_farm"]
	var cards: Array[Node] = []
	for i in ids.size():
		var x := 20.0+(i%6)*208.0
		var y := 45.0+(i/6)*245.0
		var art := ArtCatalog.prop(StringName(str(ids[i])))
		var sprite := Sprite2D.new()
		sprite.texture = art.texture
		sprite.centered = false
		sprite.scale = Vector2.ONE*0.75
		sprite.position = Vector2(x+(200.0-sprite.texture.get_width()*0.75)/2.0,y+180.0-sprite.texture.get_height()*0.75)
		root.add_child(sprite)
		cards.append(sprite)
		cards.append(_label(root,str(ids[i]),Vector2(x+4,y+188),14))
	for i in 4:
		var id := str(["leaf_a","leaf_b","petal","snowflake"][i])
		var texture := load("res://assets/iso_props/farm_dress/"+id+".webp") as Texture2D
		var sprite := Sprite2D.new()
		sprite.texture = texture
		sprite.position = Vector2(175+i*300,604)
		sprite.scale = Vector2.ONE*4
		root.add_child(sprite)
		cards.append(sprite)
		cards.append(_label(root,id+" (4× diagnostic)",Vector2(72+i*300,664),14))
	await t.frames(4)
	await t.capture("painted_dress_catalog")
	t.check("native_twelve_dress_paintings",ids.all(func(id):return ArtCatalog.has_real_prop(StringName(str(id)))))
	for card in cards:card.queue_free()
	await t.frames(2)
	title.text = "The same apple tree · four seasons"
	for i in 4:
		var season := str(["foraar","sommer","efteraar","vinter"][i])
		var art := ArtCatalog.prop(StringName("apple_tree" if season=="sommer" else "apple_tree_"+season))
		var sprite := Sprite2D.new()
		sprite.texture = art.texture
		sprite.centered = false
		sprite.position = Vector2(i*315+12,150)
		sprite.scale = Vector2.ONE*0.85
		root.add_child(sprite)
		_label(root,TranslationServer.translate("UI_SEASON_"+season.to_upper()),Vector2(i*315+75,540),24)
	await t.frames(4)
	await t.capture("painted_apple_tree_seasons")
	t.check("native_four_tree_paintings",["apple_tree","apple_tree_foraar","apple_tree_efteraar","apple_tree_vinter"].all(func(id):return ArtCatalog.has_real_prop(StringName(str(id))) and ArtCatalog.prop(StringName(str(id))).texture!=null))
	layer.queue_free()
	await t.go_menu()
func _label(parent: Control,text: String,at: Vector2,size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_override("font",load("res://assets/fonts/IBMPlexMono-Regular.ttf") as Font)
	label.add_theme_font_size_override("font_size",size)
	label.add_theme_color_override("font_color",Color("2b2340"))
	parent.add_child(label)
	return label
