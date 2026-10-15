extends RefCounted
const SECTION := "interior_views"
const TIMEOUT_S := 180.0

func run_windowed(t) -> void:
	var old_clear: Color = RenderingServer.get_default_clear_color()
	var gallery: Node2D = load("res://tools/art/drawn/interiors_gallery.tscn").instantiate()
	t.root.add_child(gallery)
	for id in gallery.room_ids:
		gallery.show_room(id)
		await t.frames(3)
		_capture(t, id)
	for id in ["home_t01", "home_t05", "home_t10", "int_bageriet", "int_troldmandstaarnet"]:
		gallery.show_room(id, true)
		await t.frames(3)
		_capture(t, id + "_night")
	gallery.free()
	RenderingServer.set_default_clear_color(old_clear)

func _capture(t, label: String) -> void:
	RenderingServer.force_draw(false)
	var frame: Image = t.tree.root.get_texture().get_image()
	var path: String = t.out_dir.path_join("interior_%s.png" % label)
	t.check("capture_%s" % label, frame != null and not frame.is_empty() and frame.save_png(path) == OK, path)
