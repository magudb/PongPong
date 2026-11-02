extends RefCounted
const SECTION := "presenter_busy_ownership"
const TIMEOUT_S := 150.0
func run(t) -> void:
	for kind in ["board", "post", "travel"]:
		await t.start_world()
		var gm: Node = t.autoload("GameManager")
		var bus: Node = t.autoload("EventBus")
		t.autoload("SaveManager").autosave_enabled = false
		gm.set_config_override("time.minutes_per_real_second", 0.0)
		gm.day = 2
		var service: Node
		match kind:
			"board": service = NoticeBoard2D.new()
			"post":
				service = PostBox2D.new()
				service.area = t.world().area
			"travel":
				service = Rejsestolpe2D.new()
				service.area = t.world().area
				service.stop = "farm"
		t.world().add_child(service)
		service.set_process(false)
		var ui: Node = t.tree.get_first_node_in_group("dialogue_ui")
		service.interact(t.player())
		await t.page_to_choices(ui)
		t.check(kind+"_ordinary_page_open", ui.is_open() and service._busy)
		var original: Variant = ui._active
		service.interact(t.player())
		t.check(kind+"_same_incarnation_overlap_refused", ui._active == original)
		var changed: Array = []
		var newer := func():
			changed.append(true)
			PlayerRegistry.reset_states()
			PlayerRegistry.state(&"p0") # explicit new-operation fixture admission
			if kind == "post": gm.day += 1
			service.interact(t.player())
		bus.dialogue_ended.connect(newer, CONNECT_ONE_SHOT)
		ui._pick({"action":"close"})
		await t.frames(2)
		t.check(kind+"_new_incarnation_admitted_before_old_waiter_unwinds", changed.size() == 1 and ui.is_open() and ui._active != original)
		t.check(kind+"_old_waiter_cannot_clear_new_busy", service._busy)
		if ui.is_open():
			await t.page_to_choices(ui)
			ui._pick({"action":"close"})
		await t.frames(2)
		t.check(kind+"_new_operation_releases_own_busy", not service._busy)
		if kind == "post": gm.day += 1
		service.interact(t.player())
		await t.page_to_choices(ui)
		t.check(kind+"_exit_fixture_page_open", ui.is_open())
		var exit_ticket: RefCounted = ui._active
		t.world().remove_child(service)
		t.check(kind+"_tree_exit_releases_exact_page_and_busy", exit_ticket.resolved and not ui.is_open() and not service._busy)
		if ui.is_open(): ui.close()
		service.free()
