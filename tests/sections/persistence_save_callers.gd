extends RefCounted
const SECTION := "persistence_save_callers"
const TIMEOUT_S := 180.0
class UpdateProbe extends "res://scripts/release/release_updates.gd":
	var target := ""
	func install_target() -> String: return target

func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text); file.close()

func _wire(sm: Node) -> Dictionary:
	return sm._read_json_file(sm.slot_path(sm.AUTO_SLOT)).get("data", {})

func run(t) -> void:
	var sm: Node = t.autoload("SaveManager")
	var previous_dir: String = sm.save_dir
	t.on_cleanup(func(): sm.save_dir = previous_dir)
	await _services(t)
	await _quit_update(t)

func _services(t) -> void:
	await t.start_world()
	var sm: Node = t.autoload("SaveManager")
	var eco: Node = t.autoload("EconomyManager")
	var loot: Node = t.autoload("LootService")
	var gm: Node = t.autoload("GameManager")
	var bus: Node = t.autoload("EventBus")
	var w: Node = t.world()
	sm.autosave_enabled = false
	sm.save_dir = "user://persistence_save_callers/services"
	var saves := []
	var on_saved := func(slot): saves.append([slot, gm.lifecycle_busy()])
	bus.save_completed.connect(on_saved)
	eco.add_item(&"rough_skovkant", 3, true)
	eco.add_gold(2000)
	var gold: int = eco.gold
	var result: Dictionary = loot.appraise("rough_skovkant")
	var wire := _wire(sm)
	t.check("PB23_model_loot_appraisal_commits_before_return", result.ok and eco.gold == gold - result.fee and eco.count_item(&"rough_skovkant") == 2 and wire.get("loot",{}).get("dungeon",{}).get("appraise",{}).get("skovkant") == 1 and int(wire.get("players",{}).get("rows",{}).get("p0",{}).get("gold",-1)) == eco.gold and saves == [[sm.AUTO_SLOT,true]])
	bus.game_event.emit(&"open_appraisal", {"npc":"appraiser_fru_ugle"})
	await t.frames(3)
	var appraisal: Node = loot._appraisal_ui
	appraisal._select("rough_skovkant")
	appraisal.all_button.pressed.emit()
	wire = _wire(sm)
	t.check("PB23_actual_appraisal_batch_button_autosaves_once", eco.count_item(&"rough_skovkant") == 0 and wire.get("loot",{}).get("dungeon",{}).get("appraise",{}).get("skovkant") == 3 and saves.size() == 2 and saves[-1] == [sm.AUTO_SLOT,true])
	appraisal.close()
	var home: Node = t.autoload("HomeManager")
	home.set_tier(2)
	await w.travel(&"home", &"default")
	var amenities: Node = w.game_ui.get_screen(&"home_amenities")
	var recipes: Array = CraftingSystem.get_recipes("bake")
	t.check("PB23_actual_home_oven_recipe_positive", w.area.map.id == &"home" and home.unlocked("oven") and not recipes.is_empty())
	var recipe: Dictionary = recipes[0]
	for item in LuaData.dict(recipe.ingredients): eco.add_item(StringName(item), int(recipe.ingredients[item]), true)
	amenities.open()
	await t.frames(2)
	var before_count: int = saves.size()
	var output: Dictionary = LuaData.dict(recipe.output)
	var old_count: int = eco.count_item(StringName(output.item))
	amenities.recipes[0].button.pressed.emit()
	wire = _wire(sm)
	var disk_count := 0
	for row in wire.get("players",{}).get("rows",{}).get("p0",{}).get("inventory",[]):
		if row.id == output.item: disk_count += int(row.amount)
	t.check("PB23_actual_cooking_button_model_and_disk_root", eco.count_item(StringName(output.item)) > old_count and disk_count == eco.count_item(StringName(output.item)) and saves.size() == before_count + 1 and saves[-1] == [sm.AUTO_SLOT,true])
	amenities.close()
	await w.travel(&"moerkeskoven", &"from_traetoppen")
	var floors := DungeonFloors.inst()
	floors._ensure(3)
	await t.until(func(): return WorldRoot2D.has_area(&"moerkeskoven_f3"), 10.0)
	await w.travel(&"moerkeskoven_f3", &"default")
	var stones: Array = w.area.find_markers("runestone")
	t.check("PB23_actual_runestone_authored_floor_positive", w.area.map.id == &"moerkeskoven_f3" and stones.size() == 1 and not floors.stones.has(3))
	if stones.size() == 1:
		var stone: Node = stones[0].node
		w.player.half_hearts = 2
		w.player.oil = 0
		before_count = saves.size()
		stone.interact(w.player)
		wire = _wire(sm)
		t.check("PB23_actual_runestone_first_activation_autosaves", stone.lit and floors.stones.has(3) and wire.get("dungeon",{}).get("stones",[]).has(3.0) and saves.size() == before_count + 1 and saves[-1] == [sm.AUTO_SLOT,true])
		stone.interact(w.player)
		t.check("PB23_actual_runestone_repeat_rest_no_duplicate_save", saves.size() == before_count + 1 and w.player.half_hearts == w.player.max_half_hearts and w.player.oil == w.player.max_oil)
	bus.save_completed.disconnect(on_saved)

func _quit_update(t) -> void:
	await t.start_world()
	var sm: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	sm.autosave_enabled = false
	sm.save_dir = "user://persistence_save_callers/quit"
	var codes := []
	gm.quit_seam = func(code): codes.append(code)
	await gm.quit_game(7)
	t.check("PB23_real_quit_success_saves_then_safe_terminal_seam", codes == [7] and sm.inspect_slot(sm.AUTO_SLOT).state == &"ok" and not gm._quitting and not gm.lifecycle_busy())
	DirAccess.make_dir_recursive_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
	for accept in [false, true]:
		var answers := []
		var ask := func():
			await gm.quit_game(8)
			answers.append(true)
		ask.call()
		await t.frames(3)
		var question: Node = t.root.find_child("QuitQuestion", true, false)
		var confirmations: Array = question.find_children("*", "UiConfirm", true, false) if question != null else []
		t.check("PB23_quit_"+str(accept)+"_real_failed_save_confirmation_releases_write_root", confirmations.size() == 1 and answers.is_empty() and gm._quit_asking and not gm.lifecycle_busy())
		if confirmations.size() == 1:
			var dialog: Node = confirmations[0]
			(dialog._ok_button if accept else dialog._cancel_button).pressed.emit()
		await t.frames(3)
		t.check("PB23_quit_"+str(accept)+"_actual_confirmation_return_no_process_exit", answers == [true] and codes == ([7,8] if accept else [7]) and not gm._quit_asking and not gm._quitting and not gm.lifecycle_busy())
	gm.quit_seam = Callable()
	DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
	t.check("PB23_quit_later_healthy_save", sm.autosave() and not sm.save_failing)
	var updates := UpdateProbe.new()
	t.root.add_child(updates)
	updates.target = ProjectSettings.globalize_path("user://persistence_save_callers/update/Traetoppen.app")
	DirAccess.make_dir_recursive_absolute(updates.target.get_base_dir())
	updates.downloaded_path = updates.target.get_base_dir().path_join("boundary-input.zip")
	_write(updates.downloaded_path, "only the real digest/pre-save boundary is exercised; never installed")
	updates.available = {"sha256":FileAccess.get_sha256(updates.downloaded_path)}
	updates.state = "ready"
	DirAccess.make_dir_recursive_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
	var installed: bool = await updates.install()
	t.check("PB23_real_updater_failed_save_refuses_before_helper_launch", not installed and updates.state == "save_failed" and FileAccess.file_exists(updates.downloaded_path) and not DirAccess.dir_exists_absolute(updates.target) and not gm._quitting and not gm.lifecycle_busy())
	DirAccess.remove_absolute(sm.slot_path(sm.AUTO_SLOT)+".tmp")
	var response: String = updates.target.get_base_dir().path_join("handshake.json")
	_write(response+".ready", "ready")
	var ready: bool = await updates.handshake(OS.get_process_id(), response)
	t.check("PB23_real_updater_ready_handshake_returns_without_quit_or_install", ready and not FileAccess.file_exists(response+".ready") and not gm._quitting)
	# An inert already-exited process exercises the real failure response. No helper/installer/network is launched.
	var pid := OS.create_process("/usr/bin/true", PackedStringArray())
	await t.until(func(): return not OS.is_process_running(pid), 3.0)
	_write(response, JSON.stringify({"status":"failed","reason":"folder"}))
	var failed: bool = await updates.handshake(pid, response)
	t.check("PB23_real_updater_failed_handshake_keeps_game_running", not failed and updates.state == "install_failed" and updates.failure == "folder" and not FileAccess.file_exists(response) and not gm._quitting and not gm.lifecycle_busy())
	t.check("PB23_updater_later_healthy_save", sm.autosave() and not sm.save_failing)
	updates.free()
