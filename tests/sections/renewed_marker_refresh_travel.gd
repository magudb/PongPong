extends RefCounted
const SECTION := "renewed_marker_refresh_travel"
const TIMEOUT_S := 180.0

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	t.autoload("SaveManager").autosave_enabled = false
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.clear_flag(&"intro_pending")
	var world: Node = t.world()
	t.check("travel_actual_fresh_garden_entry", world._enter(&"secret_garden", &"default"))
	await t.physics(3)
	var markers: Array = world.area.objects.get_children().filter(func(n): return n is SecretGardenMarker)
	t.check("travel_authored_garden_markers_present", markers.size() >= 8)
	t.check("travel_ordinary_fresh_ready_paints_current_story", markers.all(func(m): return m._look != "" and (m.kind == "trail" or not m._pictures.is_empty())))
	t.check("travel_actual_departure_and_parked_return", world._enter(&"farm", &"default") and world.is_parked(&"secret_garden") and world._enter(&"secret_garden", &"default"))
	await t.physics(3)
	t.check("travel_ordinary_deferred_reentry_repaints_without_another_quest_event", markers.all(func(m): return m._look != "" and (m.kind == "trail" or not m._pictures.is_empty())))
	t.check("travel_genuine_story_progress", qm.accept_quest(&"secret_garden") and SecretGardenStory.advance(0))
	var path: Node = markers.filter(func(m): return m.kind == "path")[0]
	t.check("travel_quest_current_path_is_actually_cleared", path._pictures.is_empty() and path._look == ":6")
	t.check("travel_second_real_parked_return", world._enter(&"farm", &"default") and world._enter(&"secret_garden", &"default"))
	await t.physics(3)
	t.check("travel_earned_current_path_and_remaining_art_survive_return", path._pictures.is_empty() and path._look == ":6" and markers.filter(func(m): return m.kind == "beds").all(func(m): return m._look == "bush_farm:6" and m._pictures.size() == 6))
	t.check("travel_host_binding_and_sparse_profile_survive", world._host_live() and PlayerRegistry._states.size() == 1 and not PlayerRegistry._states.has(&"p1"))
	gm.clear_config_overrides()
