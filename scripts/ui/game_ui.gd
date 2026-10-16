class_name GameUI
extends CanvasLayer
## Root of everything the player sees in the world (plan 3.7 / 5.2): one CanvasLayer (layer 10, PROCESS_MODE_ALWAYS, group
## `game_ui`) that instances the screens DYNAMICALLY from an ordered list, each only if its scene file exists
## (ResourceLoader.exists). A package that lands later only has to ship scenes/ui/<id>.tscn: nothing here changes, and a tree
## with no screen at all is valid (this package's foundation smoke runs exactly that).
##
## Rules (documented for the screen owners):
##  * DRAW ORDER = LIST ORDER (SCREEN_ORDER, first = back, last = front). Godot asks _unhandled_input in REVERSE tree order, so
##    the front-most screen sees a key first.
##  * NO KEY HANDLING HERE. Every modal owns its key (I, J, Esc ...), calls get_viewport().set_input_as_handled() and pushes /
##    pops itself on GameManager's modal stack. The panels are PROCESS_MODE_ALWAYS (set here when a screen leaves it at INHERIT)
##    so they keep working while the tree is paused.
##  * HUD controls use focus_mode NONE (plan R.14, rule for P17 and P19): otherwise Space/Enter act on the last clicked hotbar
##    slot through ui_accept while `jump` / `interact` fire. GameUI enforces it for the screens `hud` and `forest_hud`, also for
##    controls the HUD adds later.
##  * set_mode(&"farm" | &"action") shows the farm HUD (iso areas) or the forest HUD (ortho action areas); WorldRoot2D calls it on
##    every area switch.
##  * Screens are found with get_screen(&"inventory_ui") (the list id, or the node name "InventoryUi"); group `dialogue_ui` etc.
##    are the screens' own business.

signal mode_changed(new_mode: StringName)
signal screen_loaded(screen_id: StringName, screen: Node)

const SCENE_DIR := "res://scenes/ui/"
## Back to front (21 ids; only the ones whose scene exists are instanced, so an id is inert until its package lands).
##  * The home screens of the feature addendum (husbyggeri, indretning, home_chest, garderobe, samlerbog) are modals of the same
##    rank as the backpack: above the shops, below the pause menu and everything it opens.
##  * The towns / social screens (RT7): `social_hud` (festival ribbon, birthday chips) sits right behind the HUDs; `event_overlay`
##    (the letterbox of an event scene) is between the HUDs and `dialogue_ui`, so the bars are drawn BEHIND the dialogue;
##    `people`, `gift_ui` and `post` are modals of the quest book's rank: above it, above the shops, below the pause menu.
## Invariants (pinned by ui_foundation.game_ui_loads_new_ids_in_order and the foundation smoke): order[0] == hud,
## order[1] == forest_hud, order[-3] == pause_menu, order[-1] == settings_ui.
const SCREEN_ORDER: Array[StringName] = [
	&"hud", &"forest_hud", &"social_hud", &"event_overlay", &"dialogue_ui", &"inventory_ui", &"quest_journal",
	&"people", &"gift_ui", &"post", &"shop_ui", &"animal_care_ui", &"build_menu_ui",
	&"husbyggeri", &"indretning", &"home_chest", &"garderobe", &"samlerbog",
	&"pause_menu", &"save_load_ui", &"settings_ui",
]
const MODE_FARM := &"farm"
const MODE_ACTION := &"action"
## mode -> the HUD screen shown in it
const HUD_FOR_MODE := {&"farm": &"hud", &"action": &"forest_hud"}
## screens whose controls must never take keyboard focus
const NO_FOCUS_SCREENS: Array[StringName] = [&"hud", &"forest_hud", &"social_hud"]

var mode: StringName = MODE_FARM

var _screens: Dictionary = {}            # id -> Node
var _order: Array[StringName] = SCREEN_ORDER
var _dir: String = SCENE_DIR
## How many of NO_FOCUS_SCREENS are loaded: node_added is a no-op until then.
var _no_focus_loaded: int = 0


func _init() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	add_to_group(&"game_ui")
	var tree := get_tree()
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)
	load_screens()
	set_mode(mode)


func _exit_tree() -> void:
	var tree := get_tree()
	if tree != null and tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)


## Scene path of a screen id.
static func scene_path(screen_id: StringName, dir: String = SCENE_DIR) -> String:
	return "%s%s.tscn" % [dir, screen_id]


## Instances every screen of `order` whose scene exists in `dir` and that is not loaded yet; returns the ids loaded by THIS
## call. May be called again later (a screen that landed meanwhile joins at its place in the order). `dir` / `order` default to
## SCENE_DIR / SCREEN_ORDER; tests pass their own.
func load_screens(dir: String = "", order: Array = []) -> Array[StringName]:
	if dir != "":
		_dir = dir if dir.ends_with("/") else dir + "/"
	if not order.is_empty():
		_order = []
		for id in order:
			_order.append(StringName(str(id)))
	var loaded: Array[StringName] = []
	for id in _order:
		if _screens.has(id):
			continue
		var path := scene_path(id, _dir)
		if not ResourceLoader.exists(path):
			continue
		var ps := load(path) as PackedScene
		if ps == null:
			push_error("GameUI: %s exists but is not a scene" % path)
			continue
		var node := ps.instantiate()
		node.name = String(id).capitalize().replace(" ", "")
		node.set_meta(&"screen_id", id)
		if node.process_mode == Node.PROCESS_MODE_INHERIT:
			node.process_mode = Node.PROCESS_MODE_ALWAYS
		_screens[id] = node
		add_child(node)
		move_child(node, _index_for(id))
		if id in NO_FOCUS_SCREENS:
			_enforce_no_focus(node)
			_no_focus_loaded += 1
		loaded.append(id)
		screen_loaded.emit(id, node)
	if not loaded.is_empty():
		_apply_mode()
	return loaded


## The loaded screen of an id (&"hud", &"inventory_ui", ... or the node name "InventoryUi"); null when its scene does not exist.
func get_screen(screen_id: StringName) -> Node:
	var id := StringName(String(screen_id).to_snake_case())
	return _screens.get(id) as Node


func has_screen(screen_id: StringName) -> bool:
	return get_screen(screen_id) != null


## Ids of the loaded screens in draw order (back to front).
func loaded_screens() -> Array[StringName]:
	var out: Array[StringName] = []
	for id in _order:
		if _screens.has(id):
			out.append(id)
	return out


## &"farm" shows the farm HUD, &"action" the forest HUD; the other one is hidden. Works with no HUD loaded (the mode is kept and
## applied when the screen appears).
func set_mode(new_mode: StringName) -> void:
	if not HUD_FOR_MODE.has(new_mode):
		push_error("GameUI.set_mode: unknown mode '%s' (farm | action)" % new_mode)
		return
	var changed := new_mode != mode
	mode = new_mode
	_apply_mode()
	if changed:
		mode_changed.emit(mode)


func _apply_mode() -> void:
	for m in HUD_FOR_MODE:
		var hud := get_screen(HUD_FOR_MODE[m])
		if hud is CanvasItem:
			(hud as CanvasItem).visible = (m == mode)


## draw index of a screen: the number of already loaded screens that come before it in the order
func _index_for(id: StringName) -> int:
	var idx := 0
	for other in _order:
		if other == id:
			break
		if _screens.has(other):
			idx += 1
	return idx


func _enforce_no_focus(root: Node) -> void:
	if root is Control:
		(root as Control).focus_mode = Control.FOCUS_NONE
	for c in root.get_children():
		_enforce_no_focus(c)


func _on_node_added(n: Node) -> void:
	if not (n is Control):
		return
	# Cheap early-out: nothing to enforce until a no-focus screen is loaded.
	if _no_focus_loaded == 0:
		return
	for id in NO_FOCUS_SCREENS:
		var hud: Node = _screens.get(id)
		if hud != null and is_instance_valid(hud) and hud != n and hud.is_ancestor_of(n):
			(n as Control).focus_mode = Control.FOCUS_NONE
			return
