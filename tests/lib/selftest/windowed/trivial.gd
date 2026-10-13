extends RefCounted
## Harness self-test: a trivial run_windowed section opens a real window, draws, reads pixels back and closes.
const SECTION := "trivial"

func run(t) -> void:
	t.check("headless_part_runs_without_a_window", not t.windowed)

func run_windowed(t) -> void:
	t.check("window_is_1280x720", t.window_size() == Vector2i(1280, 720), str(t.window_size()))
	var left := ColorRect.new()
	left.color = Color("e3c372")
	left.position = Vector2(100, 100)
	left.size = Vector2(300, 200)
	t.root.add_child(left)
	var right := ColorRect.new()
	right.color = Color("2f3654")
	right.position = Vector2(500, 100)
	right.size = Vector2(300, 200)
	t.root.add_child(right)
	var stripes: Array[ColorRect] = []
	for i in 16:
		var stripe := ColorRect.new()
		stripe.color = Color.from_hsv(float(i) / 16.0, 0.7, 0.9)
		stripe.position = Vector2(60 + i * 70, 400)
		stripe.size = Vector2(60, 200)
		t.root.add_child(stripe)
		stripes.append(stripe)
	await t.frames(3)
	var img: Image = await t.capture("trivial")
	t.check("image_has_window_size", img != null and img.get_size() == Vector2i(1280, 720), "%s" % str(img.get_size() if img else null))
	t.expect_pixel(img, Vector2i(250, 200), Color("e3c372"), 3.0, "gold rect pixel")
	t.expect_pixel(img, Vector2i(650, 200), Color("2f3654"), 3.0, "night rect pixel")
	t.expect_differs(img, Vector2i(250, 200), Vector2i(650, 200), 40.0, "the two rects differ")
	t.expect_not_clear(img, Vector2i(250, 200), "drawn pixel is not the clear colour")
	t.expect_not_blank(img, Rect2i(0, 380, 1280, 240), "the stripe band is not a flat fill")
	var flat: Dictionary = t.region_stats(img, Rect2i(120, 120, 100, 50))
	t.expect(int(flat["distinct"]) == 1 and float(flat["luma_std"]) < 0.001, "a flat rectangle is exactly one colour (region_stats)")
	var band: Dictionary = t.region_stats(img, Rect2i(0, 380, 1280, 240))
	t.expect(int(band["distinct"]) >= 16, "the stripe band has >= 16 distinct colours (%d)" % int(band["distinct"]))
	t.expect(t.mean_abs_diff(img, img) == 0.0, "mean_abs_diff of an image with itself is 0")
	left.queue_free()
	right.queue_free()
	for stripe in stripes:
		stripe.queue_free()
