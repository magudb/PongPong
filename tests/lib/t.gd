extends "res://tests/lib/flow.gd"
## The `t` object every section receives (top layer: asserts -> drive -> flow -> t).
## This layer adds the expected-message controls (allow) and the windowed helpers (screenshots, pixel asserts).
##
## Section contract (plan 8.1, one file per section in res://tests/sections/):
##
##   extends RefCounted
##   const SECTION := "farm"
##   func run(t) -> void:                      # headless; may await
##       await t.start_world()
##       t.check("hoe_tills", t.autoload("GameManager") != null)
##   func run_windowed(t) -> void:             # optional; only runs with `tests/run_playtest.sh --windowed`
##       var img: Image = await t.capture("farm_noon")
##       t.expect_not_blank(img, Rect2i(0, 0, 1280, 720), "farm renders")
##   const TIMEOUT_S := 60.0                   # optional per-section watchdog (default 120 s)
##
## Engine errors AND warnings fail the run. Declare expected ones with t.allow("substring") (scoped to the
## section that calls it; the message still has to match, anything else still fails).

# ---------------------------------------------------------------- expected engine messages

## Declares a warning / error whose text contains `substring` as expected for the rest of this section.
func allow(substring: String) -> void:
	catcher.allow(substring)


## How many messages matched an allow() rule of this section so far.
func allowed_count(substring: String) -> int:
	return int(catcher.allowed_count(substring))


## Asserts that an allowed message really happened (a test that provokes a warning must see it).
func expect_allowed(substring: String, min_hits: int = 1, label: Variant = "") -> bool:
	var n: int = catcher.allowed_count(substring)
	var text := "%s (allowed '%s' seen %d time(s), want >= %d)" % [str(label), substring, n, min_hits]
	return expect(n >= min_hits, text)


## Marker into the list of (not allowed) engine messages; pair with log_since() / expect_clean_since().
func log_mark() -> int:
	return int(catcher.mark())


func log_since(mark_value: int) -> Array[String]:
	var out: Array[String] = catcher.since(mark_value)
	return out


## Local attribution: "this action logged no engine error or warning". (Any message fails the run anyway.)
func expect_clean_since(mark_value: int, label: Variant = "") -> bool:
	var msgs: Array[String] = catcher.since(mark_value)
	var text := str(label)
	if not msgs.is_empty():
		text += " -> " + msgs[0]
	return expect(msgs.is_empty(), text)


# ---------------------------------------------------------------- external tools (python lints, godot -s drivers)

## Runs a program and waits for it (blocks the frame loop: keep it to short tools). Returns
## {code: int, output: String (stdout + stderr), lines: PackedStringArray}; code is non-zero (-1 / 127) when the program cannot start.
func run_tool(exe: String, args: PackedStringArray = PackedStringArray()) -> Dictionary:
	var out: Array = []
	var code := OS.execute(exe, args, out, true)
	var text := ""
	for chunk in out:
		text += str(chunk)
	return {"code": code, "output": text, "lines": text.split("\n", false)}


## Runs a `-s` driver script of this project in a child Godot (headless, same project, same throwaway HOME).
func run_godot_script(res_path: String, script_args: PackedStringArray = PackedStringArray()) -> Dictionary:
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", res_path])
	if not script_args.is_empty():
		args.append("--")
		args.append_array(script_args)
	return run_tool(OS.get_executable_path(), args)


## Tools that print one "PASS <id>" or "FAIL <id>" line per check (tests/tools/check_project.gd, print_inputmap.gd ...):
## {pass: Array[String], fail: Array[String]} of the ids found in a run_tool() result.
func parse_tool_ids(result: Dictionary) -> Dictionary:
	var ok: Array[String] = []
	var bad: Array[String] = []
	for line in result.get("lines", PackedStringArray()):
		var l := str(line).strip_edges()
		if l.begins_with("PASS "):
			ok.append(l.substr(5).get_slice(" ", 0))
		elif l.begins_with("FAIL "):
			bad.append(l.substr(5).get_slice(" ", 0))
	return {"pass": ok, "fail": bad}


## Wraps a PASS/FAIL tool one to one: every id becomes a named check "<section>.<id>", the exit code is one more
## check ("<section>.tool_exit_code"), and a tool that printed no id at all fails. Returns the number of ids.
func expect_tool_ids(result: Dictionary, tool_label: String = "tool") -> int:
	var ids := parse_tool_ids(result)
	for id in ids["pass"]:
		check(id, true)
	for id in ids["fail"]:
		check(id, false, "reported by %s" % tool_label)
	var n: int = (ids["pass"] as Array).size() + (ids["fail"] as Array).size()
	check("tool_printed_ids", n > 0, "%s printed %d PASS/FAIL ids" % [tool_label, n])
	check("tool_exit_code", int(result.get("code", -1)) == 0, "%s exit code %s" % [tool_label, str(result.get("code", -1))])
	return n


# ---------------------------------------------------------------- raw translation keys on screen (plan 8.2 row 13)

const RAW_KEY_PATTERN := "^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$"

## "path='TEXT'" of every Label / Button / RichTextLabel under `under` (default: the whole tree) whose text is a raw
## translation key (UPPER_CASE with an underscore). Hidden nodes are skipped unless `include_hidden`.
func find_raw_keys(under: Node = null, include_hidden: bool = false) -> Array[String]:
	var rx := RegEx.new()
	rx.compile(RAW_KEY_PATTERN)
	var bad: Array[String] = []
	var stack: Array[Node] = [under if under != null else tree.root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is CanvasItem and not include_hidden and not (n as CanvasItem).is_visible_in_tree():
			continue
		var txt := ""
		if n is Label:
			txt = (n as Label).text
		elif n is RichTextLabel:
			txt = (n as RichTextLabel).text
		elif n is Button:
			txt = (n as Button).text
		if txt != "":
			# the property holds the translation KEY in a correctly localized scene: test what is displayed
			txt = n.atr(txt)
		if txt != "" and rx.search(txt) != null:
			bad.append("%s='%s'" % [n.get_path(), txt])
	return bad


func expect_no_raw_keys(label: Variant = "no raw translation keys on screen", under: Node = null, include_hidden: bool = false) -> bool:
	var bad := find_raw_keys(under, include_hidden)
	return expect(bad.is_empty(), "%s %s" % [str(label), str(bad.slice(0, 5))] if not bad.is_empty() else str(label))


# ---------------------------------------------------------------- windowed: screenshots and pixels

func has_window() -> bool:
	return DisplayServer.get_name() != "headless"


## Size of the window's viewport in pixels (1280x720 in --windowed runs).
func window_size() -> Vector2i:
	return Vector2i(tree.root.size)


## Grabs the rendered frame (after the next frame has been drawn) and, when `shot_name` is given and --out=DIR
## was passed, writes it to DIR/<section>_<shot_name>.png. Returns null (and records a failure) without a window.
func capture(shot_name: String = "") -> Image:
	if not has_window():
		fail("capture(%s) needs a real window: define run_windowed(t) and run tests/run_playtest.sh --windowed" % shot_name)
		return null
	await tree.process_frame
	# A static or obscured window may not schedule a normal redraw. Request a
	# fresh frame after deferred layout, then wait for its completion.
	RenderingServer.force_draw.call_deferred()
	await RenderingServer.frame_post_draw
	var img := tree.root.get_texture().get_image()
	if img == null or img.is_empty():
		fail("capture(%s): the viewport returned no image" % shot_name)
		return null
	if shot_name != "" and out_dir != "":
		var path := "%s/%s_%s.png" % [out_dir, section, shot_name]
		var err := img.save_png(path)
		if err != OK:
			fail("capture(%s): could not write %s (error %d)" % [shot_name, path, err])
		else:
			info("saved %s (%dx%d)" % [path, img.get_width(), img.get_height()])
	return img


func clear_color() -> Color:
	return RenderingServer.get_default_clear_color()


func luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## Largest per-channel difference of two colours on the 0..255 scale (alpha ignored).
func color_delta(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) * 255.0


## Mean absolute RGB difference of two images on the 0..255 scale (the metric of plan 8.3); sizes must match.
func mean_abs_diff(a: Image, b: Image) -> float:
	if a == null or b == null or a.get_size() != b.get_size():
		return 255.0
	var ia := a.duplicate() as Image
	var ib := b.duplicate() as Image
	ia.convert(Image.FORMAT_RGB8)
	ib.convert(Image.FORMAT_RGB8)
	var da := ia.get_data()
	var db := ib.get_data()
	var total := 0
	for i in da.size():
		total += absi(int(da[i]) - int(db[i]))
	return float(total) / float(maxi(da.size(), 1))


## Sampled statistics of a region: {mean: Color, luma_mean, luma_std, luma_min, luma_max, distinct}.
## `distinct` counts 5-bit-per-channel colours among the samples (a flat fill gives 1).
func region_stats(img: Image, rect: Rect2i, step: int = 4) -> Dictionary:
	var r := rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var n := 0
	var sum := Color(0, 0, 0, 0)
	var lsum := 0.0
	var lsq := 0.0
	var lmin := 1.0
	var lmax := 0.0
	var seen := {}
	var y := r.position.y
	while y < r.end.y:
		var x := r.position.x
		while x < r.end.x:
			var c := img.get_pixel(x, y)
			var l := luma(c)
			n += 1
			sum += c
			lsum += l
			lsq += l * l
			lmin = minf(lmin, l)
			lmax = maxf(lmax, l)
			seen[(int(c.r * 31.0) << 10) | (int(c.g * 31.0) << 5) | int(c.b * 31.0)] = true
			x += step
		y += step
	if n == 0:
		return {"mean": Color(0, 0, 0, 0), "luma_mean": 0.0, "luma_std": 0.0, "luma_min": 0.0, "luma_max": 0.0, "distinct": 0}
	var lm := lsum / n
	return {"mean": sum / float(n), "luma_mean": lm, "luma_std": sqrt(maxf(lsq / n - lm * lm, 0.0)), "luma_min": lmin, "luma_max": lmax, "distinct": seen.size()}


func expect_pixel(img: Image, pos: Vector2i, want: Color, tol: float, label: Variant = "") -> bool:
	if img == null:
		return expect(false, "%s (no image)" % str(label))
	var got := img.get_pixelv(pos)
	var d := color_delta(got, want)
	return expect(d <= tol, "%s (pixel %s is %s, want %s +/- %d)" % [str(label), pos, got.to_html(false), want.to_html(false), int(tol)])


## The pixel differs from the engine clear colour: something was actually drawn there.
func expect_not_clear(img: Image, pos: Vector2i, label: Variant = "") -> bool:
	if img == null:
		return expect(false, "%s (no image)" % str(label))
	var got := img.get_pixelv(pos)
	var d := color_delta(got, clear_color())
	return expect(d >= 6.0, "%s (pixel %s is %s, clear colour %s, delta %d)" % [str(label), pos, got.to_html(false), clear_color().to_html(false), int(d)])


## Two pixels differ by at least `min_delta` (0..255 scale), e.g. ground vs sky vs player.
func expect_differs(img: Image, a: Vector2i, b: Vector2i, min_delta: float, label: Variant = "") -> bool:
	if img == null:
		return expect(false, "%s (no image)" % str(label))
	var ca := img.get_pixelv(a)
	var cb := img.get_pixelv(b)
	var d := color_delta(ca, cb)
	return expect(d >= min_delta, "%s (%s %s vs %s %s, delta %d, want >= %d)" % [str(label), a, ca.to_html(false), b, cb.to_html(false), int(d), int(min_delta)])


## The region is not a flat fill: at least `min_distinct` sampled colours and a luminance spread >= `min_std`.
func expect_not_blank(img: Image, rect: Rect2i, label: Variant = "", min_distinct: int = 8, min_std: float = 0.01) -> bool:
	if img == null:
		return expect(false, "%s (no image)" % str(label))
	var s := region_stats(img, rect)
	var ok: bool = int(s["distinct"]) >= min_distinct and float(s["luma_std"]) >= min_std
	return expect(ok, "%s (%d distinct colours, luma std %.3f)" % [str(label), int(s["distinct"]), float(s["luma_std"])])
