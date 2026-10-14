extends "res://tests/lib/drive.gd"
## Game-flow helpers of the `t` object: scene changes, the REAL menu boot (main_menu -> character_select ->
## world), the direct new-game shortcut and game-day advancing. Third layer of asserts -> drive -> flow -> t.
##
## Two ways into a world:
##   await t.boot("fairy")        the real UI flow (clicks the real buttons, ~1 s). Used by the harness boot stage
##                                and by acceptance sections that must prove the flow itself.
##   await t.start_world("fairy") GameManager.start_new_game(...) + change_scene_to_file(world.tscn): the same
##                                calls the select screen makes, without the UI. Use this to get a fresh world.
##   t.new_game("fairy")          only the model reset (GameManager.start_new_game + EventBus.new_game_started),
##                                the scene stays as it is. "The harness's own new-game helper" of plan 6.5.

const MENU_SCENE := "res://scenes/main/main_menu.tscn"
const SELECT_SCENE := "res://scenes/ui/character_select.tscn"
const WORLD_SCENE := "res://scenes/main/world.tscn"

const CHARACTER_TYPES := {"animal": 0, "fairy": 1, "hobbit": 2, "ghost": 3}
const PLAYER_NAME := "Tester"
const FARM_NAME := "Testgaarden"

## Unique node names the real menu flow is driven through. They are the names of the UI spike and of the
## legacy scenes; the screen owner (P16) keeps them. A screen that renames one fails boot() with a clear message.
const UI_NEW_GAME := "%NewGameButton"
const UI_NAME := "%NameInput"
const UI_FARM := "%FarmNameInput"
const UI_RACE := {"animal": "%AnimalButton", "fairy": "%FairyButton", "hobbit": "%HobbitButton", "ghost": "%GhostButton"}
const UI_NEXT := "%NextButton"          # optional: page 1 -> page 2 of the two-page Vaelg figur screen
const UI_CONFIRM := "%ConfirmButton"
const UI_CONTINUE := "%ContinueButton"


# ---------------------------------------------------------------- scenes

## 0 animal, 1 fairy, 2 hobbit, 3 ghost (GameManager.CharacterType). `id` defaults to the run's --character.
func character_type(id: String = "") -> int:
	return int(CHARACTER_TYPES.get(character if id == "" else id, 0))


## The world scene when it is the current scene, else null.
func world() -> Node:
	return tree.current_scene if scene_path() == WORLD_SCENE else null


func in_world() -> bool:
	return scene_path() == WORLD_SCENE


## Changes scene and waits until it is the current one (+2 frames). False on error or timeout.
func change_scene(path: String, timeout: float = 10.0) -> bool:
	var err := tree.change_scene_to_file(path)
	if err != OK:
		fail("change_scene_to_file(%s) failed with error %d" % [path, err])
		return false
	var ok := await until(func() -> bool: return scene_path() == path, timeout)
	if ok:
		await frames(2)
	return ok


## Back to a live main menu: pops the pause, releases held input, unpauses the tree.
func go_menu() -> bool:
	release_all()
	tree.paused = false
	var gm := root.get_node_or_null("GameManager")
	if gm != null and gm.has_method("change_phase") and phase_value(gm, "MENU") != null:
		gm.change_phase(phase_value(gm, "MENU"))
	return await change_scene(MENU_SCENE)


# ---------------------------------------------------------------- new game

## Resets the game model like the select screen does and returns. Works before and after P02:
## `new_game_started` is emitted exactly once (by GameManager when it does, else by this helper).
func new_game(char_id: String = "", p_name: String = PLAYER_NAME, farm: String = FARM_NAME, skin: String = "") -> void:
	if char_id != "":
		character = char_id
	var gm := autoload("GameManager")
	if gm == null:
		return
	var bus := root.get_node_or_null("EventBus")
	var emitted := [0]
	var counter := func() -> void: emitted[0] += 1
	var has_signal := bus != null and bus.has_signal("new_game_started")
	if has_signal:
		bus.connect("new_game_started", counter)
	if skin != "" and _arg_count(gm, "start_new_game") >= 4:
		gm.start_new_game(p_name, character_type(), farm, StringName(skin))
	else:
		gm.start_new_game(p_name, character_type(), farm)
	if has_signal:
		bus.disconnect("new_game_started", counter)
		if emitted[0] == 0:
			bus.emit_signal("new_game_started")


## Fresh world without the menus: new_game() then the world scene, then waits for the player node.
func start_world(char_id: String = "", p_name: String = PLAYER_NAME, farm: String = FARM_NAME, skin: String = "") -> bool:
	go_to_neutral()
	new_game(char_id, p_name, farm, skin)
	if not await change_scene(WORLD_SCENE, 20.0):
		fail("world scene did not load (got %s)" % scene_name())
		return false
	var ok := await until(func() -> bool: return player() != null, 10.0)
	await frames(10)
	return ok


## The world, whatever state it is in: reuses the current world scene, else starts a fresh one.
func ensure_world(char_id: String = "") -> bool:
	if in_world() and player() != null:
		return true
	return await start_world(char_id)


## Advances `n` game days through the real GameManager.end_day() path (and lets the day-start handlers run).
func days(n: int) -> void:
	var gm := autoload("GameManager")
	if gm == null:
		return
	for i in n:
		gm.end_day()
		await physics(2)
		await frames(1)


# ---------------------------------------------------------------- the real boot flow

## main_menu.tscn -> character_select.tscn -> world.tscn by pressing the real buttons, with checks
## named <section>.main_menu_loaded / character_select_opened / world_loaded / player_present /
## player_name_stored / farm_name_stored / phase_playing / character_matches.
## Returns false as soon as a step fails (the failing check is already recorded).
func boot(char_id: String = "") -> bool:
	if char_id != "":
		character = char_id
	if not CHARACTER_TYPES.has(character):
		fail("unknown character '%s' (animal|fairy|hobbit|ghost)" % character)
		return false
	release_all()
	tree.paused = false
	# 1. main menu
	var ok := await change_scene(MENU_SCENE)
	check("main_menu_loaded", ok, "got %s" % scene_name())
	if not ok:
		return false
	await frames(3)
	if not press(UI_NEW_GAME):
		return false
	# 2. character select
	ok = await until(func() -> bool: return scene_path() == SELECT_SCENE, 5.0)
	check("character_select_opened", ok, "got %s" % scene_name())
	if not ok:
		return false
	await frames(2)
	set_text(UI_NAME, PLAYER_NAME)
	set_text(UI_FARM, FARM_NAME)
	press(UI_RACE[character], true)          # the legacy screen disables the race button that is already selected
	await frames(2)
	var nxt := node(UI_NEXT)
	if nxt is BaseButton and (nxt as BaseButton).is_visible_in_tree() and not (nxt as BaseButton).disabled:
		press(UI_NEXT)
		await frames(2)
	press(UI_CONFIRM)
	# 3. world
	ok = await until(func() -> bool: return scene_path() == WORLD_SCENE, 20.0)
	check("world_loaded", ok, "got %s" % scene_name())
	if not ok:
		return false
	var spawned := await until(func() -> bool: return player() != null, 10.0)
	check("player_present", spawned, "node in group 'player'")
	await frames(30)
	var gm := root.get_node_or_null("GameManager")
	if gm == null:
		fail("GameManager autoload missing after boot")
		return false
	check("player_name_stored", gm.get("player_name") == PLAYER_NAME, "got '%s'" % str(gm.get("player_name")))
	check("farm_name_stored", gm.get("farm_name") == FARM_NAME, "got '%s'" % str(gm.get("farm_name")))
	check("character_matches", int(gm.get("character_type")) == character_type(), "type %s for %s" % [str(gm.get("character_type")), character])
	var playing: Variant = phase_value(gm, "PLAYING")
	if playing != null:
		check("phase_playing", gm.get("current_phase") == playing, "phase %s" % str(gm.get("current_phase")))
	return spawned


# ---------------------------------------------------------------- internals

## GameManager.GamePhase.<phase_name> (an enum constant is not a property, so it is read from the script); null if absent.
func phase_value(gm: Node, phase_name: String) -> Variant:
	var script: Script = gm.get_script()
	if script == null:
		return null
	var enum_dict: Variant = script.get_script_constant_map().get("GamePhase", null)
	if enum_dict is Dictionary:
		return (enum_dict as Dictionary).get(phase_name, null)
	return null


## Leaves a paused / modal state behind before a scene change (never fails).
func go_to_neutral() -> void:
	release_all()
	tree.paused = false


## Frees the current scene (for example the world that a previous section left behind) and waits two frames, so the next
## windowed section starts on an empty tree: its own widgets are then the only thing on screen.
func clear_scene() -> void:
	release_all()
	tree.paused = false
	var cs: Node = tree.current_scene
	if cs != null:
		tree.current_scene = null
		cs.queue_free()
	await frames(2)


func _arg_count(obj: Object, method: String) -> int:
	for m in obj.get_method_list():
		if m["name"] == method:
			return (m["args"] as Array).size()
	return -1
