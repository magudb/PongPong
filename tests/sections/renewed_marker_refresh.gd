extends RefCounted
const SECTION := "renewed_marker_refresh"
const TIMEOUT_S := 180.0
const OLD := preload("res://tests/sections/persistence_marker_scope.gd")

func run(t) -> void:
	await _load(t)

func _load(t) -> void:
	await t.start_world()
	var sm: Node = t.autoload("SaveManager")
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	sm.autosave_enabled = false
	sm.save_dir = "user://renewed_marker_refresh"
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.clear_flag(&"intro_pending")
	t.check("refresh_real_p0_garden_admitted", qm.accept_quest(&"secret_garden"))
	for i in 6:
		t.check("refresh_real_garden_step_"+str(i), SecretGardenStory.advance(i))
	t.check("refresh_healthy_p0_only_save", sm.save_game(0) and PlayerRegistry._states.size() == 1 and not PlayerRegistry._states.has(&"p1"))
	var old_world: Node = t.world()
	var old_profile: PlayerState = PlayerRegistry._states[&"p0"]
	var marker := SecretGardenMarker.new()
	marker.kind = "beds"
	marker.cell = Vector2i(3, 3)
	marker.area = old_world.area
	old_world.area.objects.add_child(marker)
	await t.frames(2)
	t.check("refresh_enabled_intree_six_planted_beds", marker.is_inside_tree() and marker.is_enabled() and marker._pictures.size() == 6 and marker._look == "crop_moonflower_1:6")
	t.check("refresh_sparse_before_real_load", PlayerRegistry._states.size() == 1 and not PlayerRegistry._states.has(&"p1"))
	var result: Array = []
	PlayerRegistry.for_player(&"p1", func():
		result.append(sm.load_game(0))
		result.append(PlayerRegistry._acting_id))
	t.check("refresh_real_load_result_and_caller_restored", result == [true, &"p1"] and PlayerRegistry._acting_id == &"")
	t.check("refresh_model_replaced_without_old_world_rebind", PlayerRegistry._states[&"p0"] != old_profile and t.world() == old_world and not old_world._host_live())
	t.check("refresh_real_load_does_not_create_absent_caller", PlayerRegistry._states.size() == 1 and not PlayerRegistry._states.has(&"p1"), str(PlayerRegistry._states.keys()))
	t.check("refresh_load_keeps_p0_story_and_beds", SecretGardenStory.step() == 6 and marker._look == "crop_moonflower_1:6" and marker._pictures.size() == 6)
	await t.frames(3)
	t.check("refresh_after_load_frames_still_sparse", PlayerRegistry._states.size() == 1 and not PlayerRegistry._states.has(&"p1"))
	marker.free()
	gm.clear_config_overrides()
