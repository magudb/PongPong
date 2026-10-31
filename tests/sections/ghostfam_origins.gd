extends RefCounted
const SECTION := "ghostfam_origins"
const TIMEOUT_S := 150.0
const LOST := &"ghostfam_hittegods"

func run(t) -> void:
	for mode in ["normal", "direct"]:
		await _accepted(t, mode)
	for seam in ["flag", "points", "claim"]:
		await _seek(t, seam)

func _seek(t, seam: String) -> void:
	var fixture := preload("res://tests/sections/ghostfam_seek.gd").new()
	await fixture._start(t)
	await fixture._stage(t, 8, 19)
	fixture._near(55)
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	var actor: Npc2D = fixture.actor
	var seek: GhostSeek = fixture.seek
	var saves: Node = t.autoload("SaveManager")
	GameManager.set_flag(&"ghostfam_seek_total", 80)
	var winner: Dictionary = saves.gather_payload()
	GameManager.set_flag(&"ghostfam_seek_total", 2)
	var observed: Array = []
	var first := func(key, _value):
		var target := &"ghostfam_seek_total" if seam == "flag" else (&"friend_ghostfam_blund" if seam == "points" else &"ghostfam_seek_claimed")
		if key != target or not observed.is_empty(): return
		observed.append(true)
		observed.append(saves._apply_payload(winner).ok)
		observed.append(saves.gather_payload())
	EventBus.flag_changed.connect(first)
	t.check(seam + "_actual_blund_live_slot_threshold", actor != null and seek != null and not seek._live_slot().is_empty() and not GhostSeek.found_slot(1) and EconomyManager.can_add_item(&"table_lamp_clay"))
	actor.interact(t.player())
	EventBus.flag_changed.disconnect(first)
	t.check(seam + "_replacement_immediate", observed.size() == 3 and observed[1] == true and _same_payload(observed[2], winner), str(observed.slice(0,2)) + " changed=" + str(_changed(winner, observed[2] if observed.size() == 3 else {})))
	t.check(seam + "_whole_hook_no_winner_suffix", _same_payload(saves.gather_payload(), winner), str(_changed(winner, saves.gather_payload())))
	if actor.is_talking: actor._end_talk(0, false)
	var ui: Node = t.first(&"dialogue_ui")
	if ui.is_open(): ui.close()
	await t.go_menu()

# gather_payload generates a fresh wall-clock envelope timestamp each call.
# Compare every gameplay field, including paused game time; only that generated
# saved_at receipt is not state. Raw observed payloads remain unmodified.
func _same_payload(a: Dictionary, b: Dictionary) -> bool:
	var left := a.duplicate(true)
	var right := b.duplicate(true)
	left.meta.erase("saved_at")
	right.meta.erase("saved_at")
	return left == right

func _changed(a: Dictionary, b: Dictionary, prefix := "") -> Array:
	var out: Array = []
	for key in a:
		var path := prefix + "/" + str(key)
		if not b.has(key): out.append(path + " missing")
		elif a[key] is Dictionary and b[key] is Dictionary: out.append_array(_changed(a[key], b[key], path))
		elif a[key] != b[key]: out.append(path + ": " + str(a[key]) + " -> " + str(b[key]))
	for key in b:
		if not a.has(key): out.append(prefix + "/" + str(key) + " added=" + str(b[key]))
	return out

func _accepted(t, mode: String) -> void:
	if not await t.start_world(): return
	TimeManager.pause_time()
	GameManager.set_process(false)
	t.on_cleanup(func():
		TimeManager.resume_time()
		GameManager.set_process(true))
	GameManager.set_flag(&"ghostfam_kin_silke", true)
	SocialManager.debug_set_hearts("ghostfam_silke", 4)
	var saves: Node = t.autoload("SaveManager")
	var family: Node = SocialManager.get_node("FamilyQuests")
	var observed: Array = []
	var notices: Array = []
	var first := func(_pid, id):
		if id != LOST or mode == "normal" or not observed.is_empty(): return
		observed.append(true)
		var incoming: Dictionary = saves.gather_payload()
		observed.append(saves._apply_payload(incoming).ok)
		observed.append(QuestManager.active_quests[LOST].meta.duplicate(true))
	var last := func(pid, id):
		if id == LOST: notices.append(pid)
	EventBus.quest_accepted.disconnect(family._accepted)
	EventBus.quest_accepted.connect(first)
	EventBus.quest_accepted.connect(family._accepted)
	EventBus.quest_accepted.connect(last)
	t.check(mode + "_accepted_real_eligible", QuestManager.is_offerable(LOST) and QuestManager.accept_quest(LOST))
	EventBus.quest_accepted.disconnect(first)
	EventBus.quest_accepted.disconnect(last)
	t.check(mode + "_accepted_public_once", notices == [&"p0"])
	var rt: QuestManager.QuestRuntime = QuestManager.active_quests[LOST]
	if mode == "normal":
		t.check(mode + "_accepted_real_parcel", bool(rt.meta.get("parcel_given", false)) and EconomyManager.count_item(StringName(str(rt.meta.get("lost_item", "")))) == 1)
	else:
		t.check(mode + "_accepted_replacement_immediate", observed.size() == 3 and observed[1] == true and not bool(observed[2].get("parcel_given", false)))
		t.check(mode + "_accepted_no_winner_suffix", rt.meta == observed[2] and not rt.meta.has("lost_owner"))
	await t.go_menu()
