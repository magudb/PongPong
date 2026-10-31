extends RefCounted
const SECTION := "ghostfam_earned"
const TIMEOUT_S := 180.0
const Rollback := preload("res://tests/sections/multiplayer_rollback.gd")
const LOST := &"ghostfam_hittegods"

func run(t) -> void:
	for mode in ["failed", "failed_claim", "incomplete", "same", "actor_free", "body_free"]:
		await _seek(t, mode)
	await _p1(t)
	for mode in ["direct", "failed"]: await _parcel(t, mode)

func _freeze(t) -> void:
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))

func _seek(t, mode: String) -> void:
	var fixture := preload("res://tests/sections/ghostfam_seek.gd").new()
	await fixture._start(t)
	await fixture._stage(t, 8, 19)
	fixture._near(55)
	_freeze(t)
	var saves: Node = t.autoload("SaveManager")
	var old_dir: String = saves.save_dir
	saves.save_dir = "user://ghostfam-earned-" + mode
	DirAccess.make_dir_recursive_absolute(saves.save_dir)
	var late := Rollback.LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("ghostfam_earned_late", late, 1000)
	GameManager.set_flag(&"ghostfam_seek_total", 80 if mode == "failed_claim" else 2)
	var origin := EventBus.interaction_origin(&"p0")
	var profile := PlayerRegistry.peek_state(&"p0")
	var stamp: Variant = saves._save_owner_stamp()
	var points := SocialManager.points("ghostfam_blund")
	var observed: Array = []
	var barriers: Array = []
	var final_barrier: Array = []
	var actor_ref: WeakRef = weakref(fixture.actor)
	var body_ref: WeakRef = weakref(t.player())
	late.callback = func(): barriers.append(not EventBus.interaction_current(origin))
	var final := func(title, _message, kind):
		if kind != "save" or title != TranslationServer.translate("NOTIF_LOAD_FAILED_TITLE"): return
		final_barrier.append(PlayerRegistry.peek_state(&"p0") == profile and saves._save_owner_stamp() == stamp and not saves.continuation_available(profile) and not EventBus.interaction_current(origin))
	EventBus.notification_posted.connect(final)
	t.check(mode + "_real_save_no_backup", saves.save_game(0) and not FileAccess.file_exists(saves.save_dir + "/save_0.bak.json"))
	var callback := func(key, _value):
		if key != (&"ghostfam_seek_claimed" if mode == "failed_claim" else &"ghostfam_seek_total") or not observed.is_empty(): return
		observed.append(true)
		if mode == "actor_free":
			var actor: Variant = actor_ref.get_ref()
			# Retire the real director's membership before destroying its actor;
			# direct free on the executing actor is rejected by Godot's lock.
			for director in NpcDirector._active:
				if is_instance_valid(director) and director.live.get("ghostfam_blund") == actor: director._remove("ghostfam_blund")
			actor.get_parent().remove_child(actor)
			actor.queue_free()
		elif mode == "body_free":
			var body: Variant = body_ref.get_ref()
			body.get_parent().remove_child(body)
			body.free()
		else:
			late.rejects = 1 if mode in ["failed", "failed_claim"] else (2 if mode == "incomplete" else 0)
			observed.append(saves._apply_payload(saves.gather_payload()).ok if mode == "same" else saves.load_game(0))
	EventBus.flag_changed.connect(callback)
	fixture.actor.interact(t.player())
	EventBus.flag_changed.disconnect(callback)
	EventBus.notification_posted.disconnect(final)
	if mode in ["failed", "failed_claim", "actor_free", "body_free"]:
		t.check(mode + "_earned_find_points_reward_mask_once", GameManager.flag_int(&"ghostfam_seek_total", 0) == (81 if mode == "failed_claim" else 3) and GameManager.flag_int(&"ghostfam_seek_claimed", 0) == (31 if mode == "failed_claim" else 1) and SocialManager.points("ghostfam_blund") == points + 5 and EconomyManager.count_item(&"table_lamp_clay") == 1)
		if mode in ["failed", "failed_claim"]: t.check(mode + "_complete_rollback_denied_until_facade_unwinds", observed == [true, false] and barriers == [true, true] and final_barrier == [true] and EventBus.interaction_current(origin), str([observed, barriers, final_barrier, EventBus.interaction_current(origin)]))
	else:
		t.check(mode + "_replacement_or_incomplete_revokes_suffix", observed == [true, mode == "same"] and not EventBus.interaction_current(origin) and GameManager.flag_int(&"ghostfam_seek_claimed", 0) == 0 and SocialManager.points("ghostfam_blund") == points and EconomyManager.count_item(&"table_lamp_clay") == 0)
	if mode == "body_free":
		# Restore only fixture-owned body availability, not model state or authority.
		var body: Node2D = fixture.world._make_player()
		fixture.world._register_player(body, 0, 1)
		fixture.world.add_child(body)
		body.enter_area(fixture.world.area, fixture.actor.global_position)
	if mode == "actor_free":
		await t.frames(1)
		t.check("actor_free_actually_destroyed_after_earned_commit", not is_instance_valid(actor_ref.get_ref()))
	var actor: Variant = actor_ref.get_ref()
	if is_instance_valid(actor) and actor.is_talking: actor._end_talk(0, false)
	var ui: Node = t.first(&"dialogue_ui")
	if ui.is_open(): ui.close()
	saves.unregister_section("ghostfam_earned_late")
	late.free()
	saves.save_dir = old_dir
	await t.go_menu()

func _p1(t) -> void:
	var fixture := preload("res://tests/sections/ghostfam_seek.gd").new()
	await fixture._start(t)
	await fixture._stage(t, 8, 19)
	_freeze(t)
	var body: Node2D = fixture.world._make_player()
	fixture.world._register_player(body, 1, 2)
	fixture.world.add_child(body)
	body.enter_area(fixture.world.area, fixture.actor.global_position + Iso.to_screen(Vector2(55, 0)))
	var p0 := PlayerRegistry.peek_state(&"p0")
	var original := p0.to_dict().duplicate(true)
	GameManager.set_flag(&"ghostfam_seek_total", 2)
	fixture.actor.interact(body)
	t.check("p1_actual_seek_conflicting_p0_explicit_recipient", PlayerRegistry.acting_id() == &"p0" and PlayerRegistry.for_player(&"p1", func(): return SocialManager.points("ghostfam_blund") == 5) and SocialManager.points("ghostfam_blund") == 0 and GameManager.flag_int(&"ghostfam_seek_claimed", 0) == 1)
	t.check("p1_seek_unrelated_row_exact", p0.to_dict() == original)
	if fixture.actor.is_talking: fixture.actor._end_talk(0, false)
	var ui: Node = t.first(&"dialogue_ui")
	if ui.is_open(): ui.close()
	var origin := EventBus.interaction_origin(&"p1")
	PlayerRegistry.for_player(&"p1", func():
		GameManager.set_flag(&"ghostfam_kin_silke", true)
		SocialManager.debug_set_hearts("ghostfam_silke", 4))
	original = p0.to_dict().duplicate(true)
	t.check("p1_intentional_family_accept_explicit", QuestManager.accept_quest_owned(LOST, origin) and PlayerRegistry.for_player(&"p1", func(): return bool(QuestManager.active_quests[LOST].meta.parcel_given)))
	t.check("p1_family_caller_and_other_row_exact", PlayerRegistry.acting_id() == &"p0" and p0.to_dict() == original)
	var result := {}
	var owner: String = PlayerRegistry.for_player(&"p1", func(): return str(QuestManager.active_quests[LOST].meta.lost_owner))
	var item: String = PlayerRegistry.for_player(&"p1", func(): return str(QuestManager.active_quests[LOST].meta.lost_item))
	var gold: int = PlayerRegistry.for_player(&"p1", func(): return EconomyManager.gold)
	EconomyManager.defer_notifications(func():
		PlayerRegistry.for_player(&"p1", func(): result.merge(GiftFlow.give_gift(owner, item))))
	t.check("p1_deferred_real_gift_recipient_retained_under_p0_flush", bool(result.ok) and PlayerRegistry.for_player(&"p1", func(): return QuestManager.is_completed(LOST) and EconomyManager.gold == gold + 60) and PlayerRegistry.acting_id() == &"p0" and p0.to_dict() == original)
	PlayerRegistry.reset_states()
	t.check("missing_p1_hook_no_profile_creation", not GhostFamHook.before_talk(fixture.actor, body) and PlayerRegistry.peek_state(&"p1") == null)
	await t.go_menu()

func _parcel(t, mode: String) -> void:
	if not await t.start_world(): return
	_freeze(t)
	GameManager.set_flag(&"ghostfam_kin_silke", true)
	SocialManager.debug_set_hearts("ghostfam_silke", 4)
	EconomyManager.inventory.clear()
	for i in 24: EconomyManager.inventory.append({"id":&"stone", "amount":99, "meta":{}})
	t.check(mode + "_parcel_full_bag_pending", QuestManager.accept_quest(LOST) and not bool(QuestManager.active_quests[LOST].meta.parcel_given))
	var saves: Node = t.autoload("SaveManager")
	var late := Rollback.LateSection.new()
	t.tree.root.add_child(late)
	saves.register_section("ghostfam_parcel_late", late, 1000)
	EconomyManager.remove_item(&"stone", 99)
	var winner: Dictionary = saves.gather_payload()
	var observed: Array = []
	var item := str(QuestManager.active_quests[LOST].meta.lost_item)
	var first := func(_pid, id, _amount):
		if str(id) != item or not observed.is_empty(): return
		observed.append(true)
		late.rejects = 1 if mode == "failed" else 0
		observed.append(saves._apply_payload(winner).ok)
	var actor := Npc2D.create({"id":"ghostfam_silke"})
	t.world().area.objects.add_child(actor)
	EventBus.item_gained.connect(first)
	actor.interact(t.player())
	EventBus.item_gained.disconnect(first)
	t.check(mode + "_real_silke_parcel_inventory_callback", observed == [true, mode == "direct"])
	if mode == "direct":
		t.check(mode + "_parcel_no_rebind", not bool(QuestManager.active_quests[LOST].meta.parcel_given) and EconomyManager.count_item(StringName(item)) == 0)
	else:
		t.check(mode + "_parcel_failed_earned_once", bool(QuestManager.active_quests[LOST].meta.parcel_given) and EconomyManager.count_item(StringName(item)) == 1)
	if actor.is_talking: actor._end_talk(0, false)
	var ui: Node = t.first(&"dialogue_ui")
	if ui.is_open(): ui.close()
	if mode == "direct":
		t.check(mode + "_parcel_next_current_retry_once", GhostFamHook.before_talk(actor, t.player()) and bool(QuestManager.active_quests[LOST].meta.parcel_given) and EconomyManager.count_item(StringName(item)) == 1 and SocialManager.get_node("FamilyQuests").collect_parcel() and EconomyManager.count_item(StringName(item)) == 1)
	saves.unregister_section("ghostfam_parcel_late")
	late.free()
	await t.go_menu()
