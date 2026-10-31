extends RefCounted
const SECTION := "mother_area_origins"
const TIMEOUT_S := 120.0

func run(t) -> void:
	for mode in ["normal", "same_area", "detached", "add_child", "loaded", "loaded_normal", "nested_load"]:
		await _area(t, mode)

func _markers(area: Node) -> int:
	var count := 0
	for node in area.objects.get_children():
		if node is MotherEvidenceMarker: count += 1
	return count

func _area(t, mode: String) -> void:
	if not await t.start_world(): return
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	var world: Node = t.world()
	await world.travel(&"secret_garden", &"default")
	await t.physics(4)
	var director: Node = world.get_node("MotherStory")
	var area: Node = world.area
	GameManager.set_flag(&"forest_mother_version", 1)
	var saves: Node = t.autoload("SaveManager")
	var payload: Dictionary = saves.gather_payload()
	var observed: Array = []
	var callback := func(node):
		if not node is MotherEvidenceMarker or not observed.is_empty(): return
		observed.append(true)
		observed.append(saves._apply_payload(payload).ok)
	var on_flag := func(id, value):
		if id != &"forest_mother_ready_s03" or value != true or not observed.is_empty(): return
		observed.append(true)
		observed.append(saves.load_game(0) if mode == "nested_load" else saves._apply_payload(payload).ok)
	t.check(mode + "_area_eligible_unprojected", _markers(area) == 0 and MotherStory.enabled() and not QuestManager.is_active(MotherStory.quest_id("s03")) and saves.validate_payload(payload).ok)
	if mode == "add_child": area.objects.child_entered_tree.connect(callback)
	if mode in ["loaded", "loaded_normal", "nested_load"]:
		t.check(mode + "_real_save", saves.save_game(0))
		if mode in ["loaded", "nested_load"]: EventBus.flag_changed.connect(on_flag)
		var loaded: bool = saves.load_game(0)
		t.check(mode + "_real_request_precedence", not loaded if mode in ["loaded", "nested_load"] else loaded)
		if mode in ["loaded", "nested_load"]: EventBus.flag_changed.disconnect(on_flag)
	else:
		world.area_ready.emit(area.map.id)
		if mode == "same_area":
			observed.append(true)
			observed.append(saves._apply_payload(payload).ok)
		if mode == "detached":
			await t.physics(1)
			world.get_parent().remove_child(world)
	await t.physics(4)
	if mode == "add_child": area.objects.child_entered_tree.disconnect(callback)
	if mode == "nested_load": t.check("nested_load_actual_newer_request", observed == [true, true])
	if mode in ["normal", "loaded_normal", "nested_load"]:
		t.check(mode + "_area_attaches_exact_current_markers", _markers(area) == 2 and director.anchors.size() == 2 and QuestManager.is_active(MotherStory.quest_id("s03")))
	elif mode == "detached":
		t.check("detached_old_area_never_attaches", _markers(area) == 0 and director.anchors.is_empty())
		t.tree.root.add_child(world)
		t.tree.current_scene = world
	else:
		t.check(mode + "_actual_same_area_replacement", observed == [true, true] and world.area == area)
		t.check(mode + "_old_root_cannot_project_winner", not QuestManager.is_active(MotherStory.quest_id("s03")))
		t.check(mode + "_old_attachment_suffix_stops", _markers(area) == (1 if mode == "add_child" else 0) and director.anchors.is_empty())
	world.area_ready.emit(area.map.id)
	await t.physics(4)
	t.check(mode + "_new_independent_area_progress", _markers(area) == 2 and director.anchors.size() == 2 and QuestManager.is_active(MotherStory.quest_id("s03")))
	world.area_ready.emit(area.map.id)
	await t.physics(4)
	t.check(mode + "_stable_current_no_duplicates", _markers(area) == 2 and director.anchors.size() == 2)
	await t.go_menu()
