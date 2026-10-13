extends Node
## Generates the Trætoppen UI scenes (a scene, NOT -s: the scripts need the autoloads to compile):
##   godot --headless --path . res://tools/ui/build_scenes.tscn [-- name name ... [--out=DIR] [--screens]]
## Each tools/ui/scenes/s_<name>.gd has  func build(K)  and writes a normal .tscn. Generated scenes are ordinary editor scenes
## afterwards; edit them by hand if you prefer, but then stop regenerating that one. Run tools/ui/build_theme.gd FIRST (scenes only
## reference theme variations by name).
##
## FOUNDATION builders (scenes this package owns, written to res://scenes/ui/...):
##   item_slot stepper toast ability components game_ui
## SCREEN builders (tools/ui/scenes/screens/s_<name>.gd: title select hud shop dialogue journal inventory forest pause settings
## saveload) are the spike's layout generators, kept as REFERENCE for the packages that own those screens (P14 P16 P17 P18 P19).
## They hold the guide's mock copy and write scenes this package does not own, so they only run with --screens AND an --out=DIR
## (for example --out=user://ui_ref/), never into res://scenes.

const Kit = preload("res://tools/ui/scene_kit.gd")
const FOUNDATION := ["item_slot", "stepper", "toast", "ability", "components", "game_ui"]
const SCREENS := ["title", "select", "hud", "shop", "dialogue", "journal", "inventory", "forest", "pause", "settings", "saveload"]

func _ready() -> void:
	var want: Array[String] = []
	var out_root := ""
	var with_screens := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_root = a.get_slice("=", 1)
		elif a == "--screens":
			with_screens = true
		else:
			want.append(a)
	if with_screens and out_root == "":
		push_error("build_scenes: --screens needs --out=DIR (those scenes belong to the screen owners, not to the foundation)")
		get_tree().quit(2)
		return
	var jobs: Array[Array] = []   # [name, script path]
	for n in FOUNDATION:
		jobs.append([n, "res://tools/ui/scenes/s_%s.gd" % n])
	if with_screens:
		for n in SCREENS:
			jobs.append([n, "res://tools/ui/scenes/screens/s_%s.gd" % n])
	var built := 0
	for j in jobs:
		if want.size() > 0 and not (j[0] in want):
			continue
		if not ResourceLoader.exists(j[1]):
			print("skip (no builder yet): ", j[0])
			continue
		var script := load(j[1]) as GDScript
		if script == null or not script.can_instantiate():
			push_error("build_scenes: %s does not compile" % j[1])
			get_tree().quit(1)
			return
		var kit = Kit.new()
		kit.out_root = out_root
		var b = script.new()
		b.build(kit)
		built += 1
	print("build_scenes: %d scene(s) built" % built)
	get_tree().quit()
