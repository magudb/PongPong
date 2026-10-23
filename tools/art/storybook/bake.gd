extends SceneTree
## Native Godot offline renderer. Never run this on already illustrated inputs.
## Godot --path PROJECT -s tools/art/storybook/bake.gd -- --source=PRISTINE_ASSETS [--only=fox/idle] [--install]

var source_dir: String
var output_dir := "res://tools/art/_stage/storybook"
var only := ""
var install := false
var resume := false
var viewport: SubViewport
var picture: TextureRect
var material: ShaderMaterial
var audit: Array[Dictionary] = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--source="):
			source_dir = arg.trim_prefix("--source=")
		elif arg.begins_with("--only="):
			only = arg.trim_prefix("--only=")
		elif arg == "--install":
			install = true
		elif arg == "--resume":
			resume = true
	if source_dir.is_empty() or not DirAccess.dir_exists_absolute(source_dir):
		push_error("Pass --source=/absolute/path/to/pristine/assets")
		quit(2)
		return
	if source_dir.trim_suffix("/") == ProjectSettings.globalize_path("res://assets").trim_suffix("/"):
		push_error("Source must be a pristine checkout, not the output project's assets")
		quit(2)
		return
	call_deferred("_run")


func _run() -> void:
	root.title = "Trætoppen — painting the asset library"
	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	picture = TextureRect.new()
	# TextureRect's default minimum size is its previous texture's size, which crops smaller successors.
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	viewport.add_child(picture)
	material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = FileAccess.get_file_as_string("res://tools/art/storybook/illustrate.gdshader")
	material.shader = shader
	material.set_shader_parameter("paper", ImageTexture.create_from_image(Image.load_from_file(ProjectSettings.globalize_path("res://tools/art/storybook/watercolor_paper.png"))))
	picture.material = material
	var files: Array[String] = []
	_collect(source_dir, "", files)
	files.sort()
	var count := 0
	for relative in files:
		if not only.is_empty() and not relative.contains(only):
			continue
		var treatment := _treatment(relative)
		if treatment == "preserve":
			if install:
				DirAccess.copy_absolute(source_dir.path_join(relative), "res://assets/" + relative)
			audit.append({"path": relative, "treatment": "preserved light/shadow"})
			continue
		var input := Image.load_from_file(source_dir.path_join(relative))
		if input == null:
			push_error("Cannot decode " + relative)
			quit(1)
			return
		var destination := output_dir.path_join(relative)
		if resume and FileAccess.file_exists(destination) and not relative.begins_with("icons/") and relative != "isometric_characters/fox/idle.webp":
			if install:
				var reused := _install_image(Image.load_from_file(ProjectSettings.globalize_path(destination)), relative)
				if reused != OK:
					push_error("Cannot install " + relative)
					quit(1)
					return
			audit.append({"path": relative, "size": [input.get_width(), input.get_height()], "treatment": treatment})
			count += 1
			continue
		viewport.size = input.get_size()
		picture.size = Vector2(input.get_size())
		picture.texture = ImageTexture.create_from_image(input)
		var tile := treatment == "floor"
		material.set_shader_parameter("contour", 0.0 if tile else 0.88)
		material.set_shader_parameter("pigment", 0.025 if tile else 0.075)
		material.set_shader_parameter("pencil", 0.0 if tile else 0.10)
		material.set_shader_parameter("flatten", 0.0 if tile else 0.72)
		material.set_shader_parameter("ink", Vector3(0.169, 0.137, 0.251) if relative.begins_with("icons/") else Vector3(0.26, 0.19, 0.25))
		material.set_shader_parameter("pale_rim", relative.begins_with("icons/") and relative.ends_with("_night.webp"))
		material.set_shader_parameter("cell_size", Vector2(256, 256) if relative.begins_with("isometric_characters/") else Vector2(input.get_size()))
		await process_frame
		# A minimized macOS window can stop automatic draws. The offline viewport still needs a draw.
		RenderingServer.force_draw(false)
		var rendered := viewport.get_texture().get_image()
		if rendered == null or rendered.get_size() != input.get_size():
			push_error("Renderer failed for " + relative)
			quit(1)
			return
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		var error: Error
		if destination.ends_with(".webp"):
			# Lossless staged masters allow resuming without a second lossy encode.
			error = rendered.save_webp(destination, false)
		else:
			error = rendered.save_png(destination)
		if error != OK:
			push_error("Cannot save " + destination)
			quit(1)
			return
		if install:
			error = _install_image(rendered, relative)
			if error != OK:
				push_error("Cannot install " + relative)
				quit(1)
				return
		audit.append({"path": relative, "size": [input.get_width(), input.get_height()], "treatment": treatment})
		count += 1
		if count % 25 == 0:
			print("STORYBOOK ", count, " ", relative)
	var report_name := "audit.json" if only.is_empty() else "partial_audit.json"
	var report := FileAccess.open(output_dir.path_join(report_name), FileAccess.WRITE)
	report.store_string(JSON.stringify(audit, "\t"))
	print("STORYBOOK COMPLETE: ", count, " illustrated assets; ", audit.size(), " audited")
	quit(0)


func _install_image(image: Image, relative: String) -> Error:
	var destination := "res://assets/" + relative
	if relative.ends_with(".png"):
		return image.save_png(destination)
	var quality := 0.97
	if relative.begins_with("iso_props/home/scaffold"):
		quality = 0.90
	elif relative.begins_with("iso_props/home/"):
		quality = 0.92
	elif relative.begins_with("iso_props/"):
		quality = 0.94
	return image.save_webp(destination, not relative.begins_with("icons/"), quality)


func _collect(base: String, relative: String, files: Array[String]) -> void:
	var dir := DirAccess.open(base.path_join(relative))
	for folder in dir.get_directories():
		_collect(base, relative.path_join(folder), files)
	for file in dir.get_files():
		if file.ends_with(".png") or file.ends_with(".webp"):
			files.append(relative.path_join(file))


func _treatment(path: String) -> String:
	if path.contains("/fx/") or path.get_file().ends_with("_glow.webp") or path.get_file().contains("halo") or path.get_file().contains("shadow") or path.get_file() in ["dig_glimmer.webp", "unique_glimmer.webp"]:
		return "preserve"
	if path.begins_with("iso_props/") and (path.get_file().ends_with("_night.webp") or path.get_file().ends_with("_float.webp")):
		return "preserve"
	if path.begins_with("iso_tiles/"):
		return "floor"
	return "ink, gouache, pencil"
