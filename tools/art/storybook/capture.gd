extends SceneTree
## Brief native-engine captures of the finished title and the playable world. Does not save a game.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute("res://docs/art/storybook")
	var title := load("res://scenes/main/main_menu.tscn").instantiate() as Control
	root.add_child(title)
	current_scene = title
	for frame in 4:
		await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://docs/art/storybook/title.png")
	title.queue_free()
	await process_frame
	var manager := root.get_node("GameManager")
	manager.start_new_game("Art review", 0)
	var world := load("res://scenes/main/world.tscn").instantiate() as Node2D
	root.add_child(world)
	current_scene = world
	for frame in 120:
		await process_frame
		if frame > 15 and not bool(world.get("traveling")):
			break
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png("res://docs/art/storybook/world.png")
	print("STORYBOOK captured title and world")
	quit()
