extends RefCounted
## Harness self-test: every helper of the `t` object on its happy path. Must pass with zero engine messages.
const SECTION := "a_basics"

class _Emitter extends Object:
	signal two(a, b)
	signal none

func run(t) -> void:
	t.check("named_check", true, "detail text")
	t.expect(1 + 1 == 2, "free text check")
	t.expect_eq([1, 2, 3], [1, 2, 3], "deep equality of arrays")
	t.expect_eq(1, 1.0, "int equals float")
	t.expect_eq(&"a", "a", "StringName equals String")
	t.expect_near(0.1 + 0.2, 0.3, 0.0001, "float tolerance")
	t.expect_has({"k": 1}, "k", "dictionary key")
	t.expect_has([1, 2], 2, "array value")
	t.expect_has("hello world", "lo w", "substring")
	t.expect(typeof(t.character) == TYPE_STRING, "t.character is a String")
	t.skip("a skipped check is counted, never a failure")
	t.info("info lines are free")
	# time
	var f0 := Engine.get_process_frames()
	await t.frames(3)
	t.expect(Engine.get_process_frames() >= f0 + 3, "frames(3) advances three process frames")
	var p0 := Engine.get_physics_frames()
	await t.physics(4)
	t.expect(Engine.get_physics_frames() >= p0 + 4, "physics(4) advances four physics ticks")
	var t0 := Time.get_ticks_msec()
	await t.seconds(0.2)
	var waited := Time.get_ticks_msec() - t0
	t.expect(waited >= 100 and waited < 3000, "seconds(0.2) waits about 0.2 s (%d ms; the first timer tick may include part of the previous frame)" % waited)
	var flag := [false]
	t.tree.create_timer(0.1).timeout.connect(func() -> void: flag[0] = true)
	t.expect(await t.until(func() -> bool: return flag[0], 2.0), "until() sees a condition become true")
	t.expect(not await t.until(func() -> bool: return false, 0.2), "until() gives up after its timeout")
	# input (an action that exists in every version of the project)
	var got := [0]
	var probe := Node.new()
	probe.set_script(load("res://tests/lib/selftest/pass/_action_probe.gd"))
	probe.counter = got
	t.root.add_child(probe)
	t.tap(&"zoom_in")
	await t.frames(2)
	t.expect_eq(got[0], 1, "tap() delivers one press event to an input handler")
	t.hold(&"zoom_in")
	await t.frames(2)
	t.expect(Input.is_action_pressed(&"zoom_in"), "hold() keeps the action pressed")
	t.release_all()
	await t.frames(1)
	t.expect(not Input.is_action_pressed(&"zoom_in"), "release_all() lets go")
	probe.queue_free()
	# signals and mouse
	var emitter := _Emitter.new()
	t.tree.create_timer(0.1).timeout.connect(func() -> void: emitter.two.emit(7, "x"))
	var args: Variant = await t.wait_signal(emitter.two, 2.0)
	t.expect_eq(args, [7, "x"], "wait_signal() returns the emitted arguments")
	t.expect_eq(await t.wait_signal(emitter.none, 0.2), null, "wait_signal() returns null on timeout")
	var clicked := [0]
	var layer := CanvasLayer.new()
	layer.layer = 1000                     # above whatever scene is running
	t.root.add_child(layer)
	var btn := Button.new()
	btn.text = "button"
	btn.position = Vector2(100, 100)
	btn.size = Vector2(80, 30)
	btn.pressed.connect(func() -> void: clicked[0] += 1)
	layer.add_child(btn)
	await t.frames(2)
	t.click(Vector2(140, 115))
	await t.frames(2)
	t.expect_eq(clicked[0], 1, "click() presses the button under the cursor")
	btn.text = "SOME_RAW_KEY"
	t.expect_eq(t.find_raw_keys(btn).size(), 1, "find_raw_keys() spots an UPPER_CASE text")
	btn.text = "plain text"
	t.expect_eq(t.find_raw_keys(btn).size(), 0, "find_raw_keys() ignores normal text")
	t.expect_no_raw_keys("expect_no_raw_keys() on a clean button", btn)
	layer.queue_free()
	emitter.free()
	# nodes and autoloads
	t.expect(t.has_autoload("EventBus") and t.autoload("EventBus") != null, "autoload() / has_autoload()")
	t.expect(not t.has_autoload("NoSuchAutoloadAnywhere"), "has_autoload() is false for a missing autoload")
	t.expect_eq(t.character_type("fairy"), 1, "character_type()")
	var button := Button.new()
	button.name = "SelfTestButton"
	var hits := [0]
	button.pressed.connect(func() -> void: hits[0] += 1)
	t.root.add_child(button)
	t.expect(t.press("SelfTestButton") and hits[0] == 1, "press() emits pressed on a button found under root")
	t.expect(t.node("SelfTestButton") == button, "node() finds a node by name")
	button.queue_free()
	var line := LineEdit.new()
	line.name = "SelfTestLine"
	t.root.add_child(line)
	t.expect(t.set_text("SelfTestLine", "hej") and line.text == "hej", "set_text() types into a LineEdit")
	line.queue_free()
	# the throwaway user dir and the seeded RNG
	t.expect(OS.get_environment("PLAYTEST_ISOLATED") != "1" or t.user_dir.begins_with(OS.get_environment("HOME")), "user:// lives under the throwaway HOME (%s)" % t.user_dir)
	var r1: int = t.rng.randi()
	t.rng.seed = 424242
	t.expect_eq(t.rng.randi(), r1, "t.rng starts from the --seed value")
