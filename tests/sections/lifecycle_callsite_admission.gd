extends RefCounted
const SECTION := "lifecycle_callsite_admission"
const TIMEOUT_S := 90.0
func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var saves: Node = t.autoload("SaveManager")
	var eco: Node = t.autoload("EconomyManager")
	saves.autosave_enabled = false
	var token: RefCounted = gm._begin_lifecycle(self,&"callsite_probe")
	eco.gold = 123
	var run: String = saves.run_id
	var model: Dictionary = gm.to_dict()
	var prior_character: String = t.character
	t.new_game("ghost","Refused helper")
	t.check("harness_refusal_no_fallback_reset_or_character_change",saves.run_id == run and eco.gold == 123 and gm.to_dict() == model and t.character == prior_character)
	Fresh.new_game(t,"hobbit","Refused fresh")
	t.check("fresh_refusal_no_post_reset_or_seed",saves.run_id == run and eco.gold == 123 and gm.to_dict() == model and t.character == prior_character)
	var select: Control = load("res://scenes/ui/character_select.tscn").instantiate()
	t.root.add_child(select)
	var chosen: Array = []
	select.character_chosen.connect(func(a,b,c):chosen.append([a,b,c]))
	select._on_confirm()
	t.check("character_select_refusal_no_starting_or_chosen",not select._starting and chosen.is_empty())
	t.check("character_select_refusal_no_world_request",t.tree.current_scene != null and t.tree.current_scene.scene_file_path == "res://scenes/main/world.tscn")
	gm._finish_lifecycle(token,self)
	select.queue_free()
	await t.frames(3)
	if not gm.has_method("try_start_new_game_and_enter"):
		t.check("accepted_newgame_scene_wrapper",false,"Wrapper absent")
		return
	var result: Dictionary = gm.try_start_new_game_and_enter("Owned enter",gm.character_type,"Owned",&"",false)
	t.check("accepted_newgame_scene_wrapper",result.ok and gm.lifecycle_busy())
	await t.until(func():return t.world() != null and t.world().ready_for_play,15.0)
	await t.frames(2)
	t.check("accepted_newgame_world_ready_and_released",not gm.lifecycle_busy() and gm.player_name == "Owned enter")
	await t.go_menu()
	var host := Node.new()
	t.root.add_child(host)
	if not gm.has_method("try_start_new_game_attached"):
		t.check("tool_attached_world_owned_through_bootstrap",false,"Attached adapter absent")
		host.free()
		return
	result = gm.try_start_new_game_attached(host,"Attached",gm.character_type,"Attached",&"",false)
	var world: Node = result.get("world")
	t.check("tool_attached_world_owned_through_bootstrap",result.ok and world.get_parent() == host and gm.lifecycle_busy())
	await t.until(func():return world.ready_for_play,15.0)
	await t.frames(2)
	t.check("tool_attached_world_tail_releases",not gm.lifecycle_busy())
	host.free()
