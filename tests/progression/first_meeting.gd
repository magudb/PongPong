extends RefCounted
## Regression through the production opening, save file, NPC and dialogue UI.

static func after_opening(t, label: String) -> void:
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var bus: Node = t.autoload("EventBus")
	t.check(label + "_tutorial_has_own_completion", bool(gm.get_flag(&"first_morning_done", false)) and not bool(gm.get_flag(&"intro_done", false)))
	bus.crop_planted.emit(&"intro_probe", &"turnip")
	bus.zone_entered.emit(&"traetoppen")
	var board_first := label == "finished"
	if board_first:
		# Use the production board/controller, not a borrowed dialogue id or a
		# directly completed quest; no real Lyra actor has begun a meeting.
		await t.world().travel(&"traetoppen", &"default")
		var board := NoticeBoard2D.new()
		t.world().area.objects.add_child(board)
		var pending_at_completion: Array = []
		var observe := func(_pid, quest):
			if quest == &"intro_lottery":
				pending_at_completion.append(bool(gm.get_flag(&"mayor_welcome_pending", false)))
		bus.quest_completed.connect(observe)
		board.interact(t.player())
		var board_screen: Node = t.tree.get_first_node_in_group("dialogue_ui")
		t.check("board_before_mayor_reaches_actual_service", board_screen.is_open() and str(board_screen._speaker.id) == "mayor_lyra" and board_screen._lines.any(func(row): return row.get("text_key", "") == "LIFE_BOARD_INTRO"))
		t.check("board_before_mayor_completes_lottery_with_unread_obligation", qm.is_completed(&"intro_lottery") and pending_at_completion == [true] and not bool(gm.get_flag(&"mayor_welcome_seen", false)))
		bus.quest_completed.disconnect(observe)
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
	var saves: Node = t.autoload("SaveManager")
	var directory: String = saves.save_dir
	saves.save_dir = "user://mayor-" + label
	t.expect(saves.save_game(0), label + " save before first mayor meeting")
	var old_id: int = t.world().get_instance_id()
	t.expect(saves.load_and_enter(0), label + " load before first mayor meeting")
	await t.until(func(): return t.world() != null and t.world().get_instance_id() != old_id and t.player() != null and not t.world().traveling, 10)
	await t.physics(3)
	t.check(label + "_load_keeps_lottery_state", (qm.is_completed(&"intro_lottery") if board_first else qm.is_active(&"intro_lottery") and not qm.is_completed(&"intro_lottery")) and not t.tree.get_first_node_in_group("dialogue_ui").is_open())
	# Use the installed, scheduled citizen, not a test-created stand-in.
	gm.set_clock(16, 0)
	t.autoload("TimeManager").set_weather(&"klart")
	await t.world().travel(&"hyggebyen", &"default")
	NpcDirector.resync("mayor_lyra")
	await t.until(func(): return NpcDirector.node_of("mayor_lyra") != null, 10)
	await t.physics(3)
	var mayor: Npc2D
	for actor in t.tree.get_nodes_in_group("npc"):
		if actor.npc_id == &"mayor_lyra":
			mayor = actor
	if not t.expect(mayor != null, label + " installed mayor is present in Hyggebyen: " + str(t.world().area.map.id) + " " + str(NpcDirector.where_is("mayor_lyra"))):
		saves.save_dir = directory
		return
	mayor.interact(t.player())
	var screen: Node = t.tree.get_first_node_in_group("dialogue_ui")
	var keys: Array = screen._lines.map(func(row): return str(row.get("text_key", "")))
	t.check(label + "_real_first_meeting_shows_welcome", screen.is_open() and keys.has("DLG_LYRA_GREET_1") and keys.has("DLG_LYRA_LOTTERY") and not keys.has("DLG_LYRA_HELLO"), str(keys))
	if board_first:
		var progress: Dictionary = qm.to_dict().duplicate(true)
		var economy: Dictionary = t.autoload("EconomyManager").to_dict().duplicate(true)
		t.check("board_first_real_welcome_still_unread_at_social_line", screen._line == 0 and not bool(gm.get_flag(&"mayor_welcome_seen", false)))
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
		t.check("board_first_mayor_escape_save_load", saves.save_game(0) and saves.load_game(0))
		mayor.interact(t.player())
		keys = screen._lines.map(func(row): return str(row.get("text_key", "")))
		t.check("board_first_escape_load_retries_unread_welcome_without_repaying", keys.has("DLG_LYRA_GREET_1") and not keys.has("DLG_LYRA_HELLO") and qm.to_dict() == progress and t.autoload("EconomyManager").to_dict() == economy, str(keys))
	if DisplayServer.get_name() != "headless":
		# Capture the authored welcome, not the social FIRST line ahead of it.
		var advance := func():
			if str(screen._lines[screen._line].get("text_key", "")) != "DLG_LYRA_GREET_1":
				t.tap(&"interact")
		await t.until_game(func(): return str(screen._lines[screen._line].get("text_key", "")) == "DLG_LYRA_GREET_1", 3.0, advance)
		screen.chars_per_second = 100000.0
		await t.until_game(func(): return not screen._typing, 1.0)
		await t.capture("mayor_first_welcome")
	t.check(label + "_meeting_completes_lottery", qm.is_completed(&"intro_lottery") and bool(gm.get_flag(&"intro_done", false)))
	await t.page_to_choices(screen)
	await t.until_game(func(): return screen._choice_grace <= 0.0, 1.0)
	screen._buttons[-1].grab_focus()
	t.tap(&"ui_accept")
	await t.frames(3)
	t.check(label + "_welcome_page_finished", not screen.is_open() and not mayor.is_talking)
	t.check(label + "_completed_introduction_survives_save_load", saves.save_game(0) and saves.load_game(0) and qm.is_completed(&"intro_lottery"))
	mayor.interact(t.player())
	keys = screen._lines.map(func(row): return str(row.get("text_key", "")))
	t.check(label + "_welcome_not_repeated", keys.has("DLG_LYRA_HELLO") and not keys.has("DLG_LYRA_GREET_1"), str(keys))
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	saves.save_dir = directory

static func early_meeting(t) -> void:
	await t.start_world()
	var qm: Node = t.autoload("QuestManager")
	qm.accept_quest(&"intro_lottery")
	var mayor := Npc2D.create({"id": "mayor_lyra", "wander": "0"})
	mayor.area = t.world().area
	t.world().area.objects.add_child(mayor)
	mayor.interact(t.player())
	var screen: Node = t.tree.get_first_node_in_group("dialogue_ui")
	t.check("early_first_meeting_welcomes", screen._lines.any(func(row): return row.get("text_key", "") == "DLG_LYRA_GREET_1"))
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	t.check("cancelled_early_welcome_is_not_recorded", not bool(t.autoload("GameManager").get_flag(&"mayor_welcome_seen", false)))
	mayor.interact(t.player())
	t.check("cancelled_early_welcome_can_be_read_next_time", screen._lines.any(func(row): return row.get("text_key", "") == "DLG_LYRA_GREET_1"))
	await t.page_to_choices(screen)
	await t.until_game(func(): return screen._choice_grace <= 0.0, 1.0)
	screen._buttons[-1].grab_focus()
	t.tap(&"ui_accept")
	await t.frames(3)
	t.check("early_meeting_does_not_finish_other_objectives", not mayor.is_talking and qm.is_active(&"intro_lottery") and not qm.is_completed(&"intro_lottery"))
	t.check("early_read_welcome_records_its_own_flag", bool(t.autoload("GameManager").get_flag(&"mayor_welcome_seen", false)))
	var saves: Node = t.autoload("SaveManager")
	var directory: String = saves.save_dir
	saves.save_dir = "user://mayor-early"
	t.check("early_introduction_survives_save_load_before_quest_completion", saves.save_game(0) and saves.load_game(0) and qm.is_active(&"intro_lottery") and bool(t.autoload("GameManager").get_flag(&"mayor_welcome_seen", false)))
	saves.save_dir = directory
	mayor.interact(t.player())
	var keys: Array = screen._lines.map(func(row): return str(row.get("text_key", "")))
	t.check("early_welcome_happens_once_before_lottery_complete", keys.has("DLG_LYRA_HELLO") and not keys.has("DLG_LYRA_GREET_1"), str(keys))
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	mayor.queue_free()

static func interrupted_welcome(t) -> void:
	var qm: Node = t.autoload("QuestManager")
	var gm: Node = t.autoload("GameManager")
	var bus: Node = t.autoload("EventBus")
	var saves: Node = t.autoload("SaveManager")
	var directory: String = saves.save_dir
	saves.save_dir = "user://mayor-interrupted"
	for timing in ["same_meeting", "later_completion"]:
		await t.start_world()
		qm.accept_quest(&"intro_lottery")
		var pending_at_completion: Array = []
		var observe := func(_pid, quest):
			if quest == &"intro_lottery":
				pending_at_completion.append(bool(gm.get_flag(&"mayor_welcome_pending", false)) and not bool(gm.get_flag(&"mayor_welcome_seen", false)))
		bus.quest_completed.connect(observe)
		if timing == "same_meeting":
			bus.crop_planted.emit(&"welcome_probe", &"turnip")
			bus.zone_entered.emit(&"traetoppen")
		var mayor := Npc2D.create({"id": "mayor_lyra", "wander": "0"})
		mayor.area = t.world().area
		t.world().area.objects.add_child(mayor)
		mayor.interact(t.player())
		var screen: Node = t.tree.get_first_node_in_group("dialogue_ui")
		t.check(timing + "_welcome_cancelled_at_first_social_line", screen._line == 0 and str(screen._lines[0].get("text_key", "")) != "DLG_LYRA_GREET_1" and screen._lines.any(func(row): return row.get("text_key", "") == "DLG_LYRA_GREET_1"))
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
		if timing == "later_completion":
			bus.crop_planted.emit(&"welcome_probe", &"turnip")
			bus.zone_entered.emit(&"traetoppen")
		t.check(timing + "_lottery_complete_but_welcome_unread", qm.is_completed(&"intro_lottery") and not bool(gm.get_flag(&"mayor_welcome_seen", false)))
		t.check(timing + "_unread_state_exists_before_completion_observers", pending_at_completion == [true])
		bus.quest_completed.disconnect(observe)
		var progress: Dictionary = qm.to_dict().duplicate(true)
		var economy: Dictionary = t.autoload("EconomyManager").to_dict().duplicate(true)
		t.check(timing + "_unread_completion_saved_and_loaded", saves.save_game(0) and saves.load_game(0))
		mayor.interact(t.player())
		t.check(timing + "_completed_lottery_retries_unread_welcome", screen._lines.any(func(row): return row.get("text_key", "") == "DLG_LYRA_GREET_1"), str(screen._lines))
		await t.page_to_choices(screen)
		await t.until_game(func(): return screen._choice_grace <= 0.0, 1.0)
		screen._buttons[-1].grab_focus()
		t.tap(&"ui_accept")
		await t.frames(3)
		t.check(timing + "_retried_welcome_read_without_repaying", bool(gm.get_flag(&"mayor_welcome_seen", false)) and not bool(gm.get_flag(&"mayor_welcome_pending", false)) and qm.to_dict() == progress and t.autoload("EconomyManager").to_dict() == economy)
		t.check(timing + "_read_completion_saved_and_loaded", saves.save_game(0) and saves.load_game(0))
		mayor.interact(t.player())
		t.check(timing + "_retried_welcome_exactly_once", screen._lines.any(func(row): return row.get("text_key", "") == "DLG_LYRA_HELLO") and not screen._lines.any(func(row): return row.get("text_key", "") == "DLG_LYRA_GREET_1"))
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
		mayor.queue_free()
	saves.save_dir = directory

static func legacy_saves(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var bus: Node = t.autoload("EventBus")
	var saves: Node = t.autoload("SaveManager")
	var directory: String = saves.save_dir
	saves.save_dir = "user://mayor-legacy-v3"
	for state in ["pending", "met", "completed", "absent"]:
		await t.start_world()
		if state != "absent":
			qm.accept_quest(&"intro_lottery")
		if state == "met":
			bus.start_dialogue(&"mayor_lyra", &"mayor_lyra")
		if state == "completed":
			qm.complete_quest(&"intro_lottery")
		# These are the actual flags written by the old opening in a v3 file.
		# A freshly created fixture must remove the new-run-only obligation.
		gm.clear_flag(&"mayor_welcome_pending")
		gm.clear_flag(&"mayor_welcome_seen")
		gm.set_flag(&"intro_done", true)
		gm.set_flag(&"intro_letter_seen", true)
		gm.clear_flag(&"first_morning_done")
		t.expect(saves.save_game(0), "Write legacy v3 " + state)
		var file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(saves.slot_path(0)))
		t.check("legacy_v3_fixture_" + state, int(file.meta.version) == 3 and file.game.world_flags.intro_done == true and not file.game.world_flags.has("first_morning_done"))
		var old_id: int = t.world().get_instance_id()
		t.expect(saves.load_and_enter(0), "Load legacy v3 " + state)
		await t.until(func(): return t.world() != null and t.world().get_instance_id() != old_id and t.player() != null, 10)
		await t.physics(3)
		await preload("res://scripts/world2d/intro_sequence.gd").run(t.world())
		var screen: Node = t.tree.get_first_node_in_group("dialogue_ui")
		t.check("legacy_opening_not_replayed_" + state, not screen.is_open() and bool(gm.get_flag(&"intro_done", false)))
		if state == "absent":
			t.check("legacy_ambiguous_flag_does_not_block_lottery_offer", qm.is_offerable(&"intro_lottery"))
			t.check("legacy_unstarted_lottery_can_be_accepted", qm.accept_quest(&"intro_lottery"))
		var before: Dictionary = qm.to_dict()
		var gold: int = t.autoload("EconomyManager").gold
		var mayor := Npc2D.create({"id": "mayor_lyra", "wander": "0"})
		mayor.area = t.world().area
		t.world().area.objects.add_child(mayor)
		mayor.interact(t.player())
		var keys: Array = screen._lines.map(func(row): return str(row.get("text_key", "")))
		# An old active talk objective proves a meeting, not that the buggy old
		# build actually displayed its welcome. Only completed progress is final.
		var welcome: bool = state != "completed"
		t.check("legacy_correct_welcome_" + state, keys.has("DLG_LYRA_GREET_1") == welcome and keys.has("DLG_LYRA_HELLO") != welcome, str(keys))
		if state == "completed":
			t.check("legacy_completed_progress_and_rewards_untouched", qm.to_dict() == before and t.autoload("EconomyManager").gold == gold and not qm.accept_quest(&"intro_lottery"))
		if state == "met":
			t.check("legacy_active_met_progress_and_rewards_untouched", qm.to_dict() == before and t.autoload("EconomyManager").gold == gold)
			await t.page_to_choices(screen)
			await t.until_game(func(): return screen._choice_grace <= 0.0, 1.0)
			screen._buttons[-1].grab_focus()
			t.tap(&"ui_accept")
			await t.frames(3)
			mayor.interact(t.player())
			t.check("legacy_active_met_welcome_happens_once", screen._lines.any(func(row): return row.get("text_key", "") == "DLG_LYRA_HELLO") and bool(gm.get_flag(&"mayor_welcome_seen", false)))
		t.tap_key(KEY_ESCAPE)
		await t.frames(3)
		mayor.queue_free()
	saves.save_dir = directory