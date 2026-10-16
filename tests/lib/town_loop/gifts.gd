extends RefCounted

func run(t, suite) -> void:
	var eco: Node = t.autoload("EconomyManager")
	var sm: Node = t.autoload("SocialManager")
	var npc := "gardener_hoppe"
	eco.add_item(&"carrot", 3, true)
	var points: int = sm.row_of(npc).p
	var count: int = eco.count_item(&"carrot")
	t.tap(&"interact")
	await t.frames(3)
	var choice: Dictionary = await suite._finish_dialogue(t, "give_gift")
	var picker: Control = TownProbe.screens(t).get_screen(&"gift_ui")
	suite._check(t, "L07", "l07_talk_menu_opens_picker", str(choice.get("action", "")) == "give_gift" and picker.is_open())
	if picker.is_open():
		var index: int = picker.options.find_custom(func(row): return str(row.id) == "carrot")
		suite._check(t, "L07", "l07_carrot_available", index >= 0)
		if index >= 0:
			picker.slots[index].grab_focus()
			t.tap(&"ui_accept")
			await t.frames(2)
			t.tap(&"ui_accept")
			await t.frames(3)
			suite._check(t, "L07", "l07_item_removed_once", eco.count_item(&"carrot") == count - 1 and sm.row_of(npc).p == points + 40)
			t.tap_key(KEY_ESCAPE)
			await t.frames(3)
			var refusal: Dictionary = sm.give_gift(npc, "carrot")
			suite._check(t, "L07", "l07_one_gift_per_day", not refusal.ok and refusal.reason == "today" and eco.count_item(&"carrot") == count - 1)
		else:
			picker.close()
	# Follow the real day/week ledger for the remaining taste classes.
	var classes: Array = [{"item": "turnip", "class": "like", "points": 20}, {"item": "flour", "class": "neutral", "points": 8}, {"item": "stone", "class": "dislike", "points": 0}, {"item": "lantern_oil", "class": "hate", "points": 0}]
	var tastes_ok := true
	var weekly_checked := false
	for row in classes:
		await LoopClock.next_day(t)
		if int(sm.gift_limits(npc).left_week) == 0:
			eco.add_item(StringName(row.item), 2, true)
			var refused: Dictionary = sm.give_gift(npc, row.item)
			weekly_checked = not refused.ok and refused.reason == "week"
			for day in 7:
				if int(sm.gift_limits(npc).left_week) > 0:
					break
				await LoopClock.next_day(t)
		# Avoid mixing the separate birthday multiplier into ordinary taste points.
		while sm.birthday_state(npc) != "":
			await LoopClock.next_day(t)
		eco.add_item(StringName(row.item), 2, true)
		var before: int = eco.count_item(StringName(row.item))
		var result: Dictionary = sm.give_gift(npc, row.item)
		tastes_ok = tastes_ok and bool(result.ok) and str(result.get("class", "")) == row.class and int(result.get("points", -1)) == row.points and eco.count_item(StringName(row.item)) == before - 1
		t.info("Gift taste transaction: " + str(result))
	suite._check(t, "L07", "l07_taste_classes_and_points", tastes_ok and sm.taste_of(npc, "carrot").class == &"love")
	suite._check(t, "L07", "l07_two_gifts_per_week", weekly_checked)
	var rules := preload("res://scripts/social/gifts/gift_rules.gd")
	suite._check(t, "L07", "l07_birthday_multiplier", rules.points(SocialData.cfg_dict("gifts"), &"love", "normal", "day") == 160)
	var protected := true
	for item in ["hoe_wooden", "shirt_linen_cream", "bed_birch_single"]:
		var before: int = eco.count_item(StringName(item))
		var result: Dictionary = sm.give_gift(npc, item)
		protected = protected and not result.ok and eco.count_item(StringName(item)) == before
	suite._check(t, "L07", "l07_protected_items_unchanged", protected)
