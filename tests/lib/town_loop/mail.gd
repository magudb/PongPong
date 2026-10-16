extends RefCounted
## Both boxes consume the same daily letter ledger through the real dialogue.
func _read(t, suite, box: PostBox2D) -> bool:
	var path := await LoopWalker.walk_to(t, box.global_position, 60, 12)
	if not path.ok or t.player().nearest_interactable() != box:
		t.info("Mailbox approach " + str(path) + " selected=" + str(t.player().nearest_interactable()))
		return false
	t.tap(&"interact")
	await t.frames(3)
	var opened: bool = TownProbe.dialogue(t).is_open()
	if opened:
		await suite._finish_dialogue(t, "quest_accept")
	return opened

func farm_day_two(t, suite) -> void:
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var box: PostBox2D = t.world().area.find_markers("mailbox")[0].node
	box.interact(t.player())
	suite._check(t, "L08", "l08_day_one_personal_delivery_no_duplicate", gm.total_day() == 1 and box.letter.is_empty() and suite.probe.named("post_read").is_empty())
	await LoopClock.next_day(t)
	box.refresh()
	var offered := StringName(str(box.letter.get("quest_id", "")))
	var read := await _read(t, suite, box)
	var progress: Dictionary = qm.get_objective_progress(&"forste_dage", &"mail")
	suite._check(t, "L11", "l11_mailbox_day2_completes_mail_objective", gm.total_day() == 2 and read and qm.is_active(offered) and int(progress.get("current", 0)) == 1, str(progress))
	box.interact(t.player())
	suite._check(t, "L08", "l08_one_letter_per_day", suite.probe.named("post_read").size() == 1 and not TownProbe.dialogue(t).is_open())

func office(t, suite) -> void:
	await LoopClock.at(t, 1, 10)
	await t.world().travel(&"int_postkontoret", &"default")
	var boxes: Array = t.world().area.objects.get_children().filter(func(n): return n is PostBox2D)
	var keeper := NpcDirector.node_of("postman_pip")
	suite._check(t, "L08", "l08_post_office_interior", boxes.size() == 1 and keeper != null and t.world().area.map.id == &"int_postkontoret")
	await suite.shot(t,"S10_post_office")
	if boxes.is_empty():
		return
	var box: PostBox2D = boxes[0]
	box.refresh()
	var quest := StringName(str(box.letter.get("quest_id", "")))
	var read := await _read(t, suite, box)
	suite._check(t, "L08", "l08_letter_of_the_day", read and quest != &"" and t.autoload("QuestManager").is_active(quest), str(quest))
	var count: int = suite.probe.named("post_read").size()
	box.interact(t.player())
	suite._check(t, "L08", "l08_office_repeat_does_not_duplicate", suite.probe.named("post_read").size() == count and not TownProbe.dialogue(t).is_open())
	# Parcels are deliberately data/art only until their delivery package exists.
	suite._check(t, "L08", "l08_parcels_honest_stub", not box.has_method("send_parcel") and not box.has_method("claim_parcel") and not t.autoload("GameManager").is_modal_open())
	if not LoopCaps.has("post_ui", t.tree):
		t.skip("l08_post_screen_where_is: post-screen package is not installed; daily letters are usable at both boxes")
