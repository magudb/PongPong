extends RefCounted
const SECTION := "social_data"
const Validator := preload("res://tests/lib/social/social_validator.gd")

func run(t) -> void:
	var lr: Node = t.autoload("LuaRuntime")
	var loc: Node = t.autoload("LocalizationManager")
	var sm: Node = t.autoload("SocialManager")
	var data := {"npcs": lr.get_npcs(), "citizens": lr.get_config("citizens", {}), "gift_tastes": lr.get_config("gift_tastes", {}), "items": {}, "shops": lr.get_shops(), "social": lr.get_config("social", {}), "time": lr.get_config("time", {}), "events": lr.get_registry("events"), "festivals": lr.get_registry("festivals")}
	for item in lr.get_all_item_ids():
		data.items[item] = lr.get_item_def(item)
	var result := Validator.validate(data)
	t.check("live_data_valid", result.errors.is_empty(), str(result.errors))
	var giftable: Array = []
	for item in data.items:
		if Validator.giftable(data.items[item]):
			giftable.append(item)
	var tiers := {"A": 0, "B": 0, "C": 0}
	var partner_count := 0
	var keys: PackedStringArray = loc.all_keys()
	for npc in SocialData.friend_ids():
		var c := SocialData.citizen(npc)
		t.expect(not c.derived and c.archetype in ["child", "wanderer", "fairy", "shopkeeper", "gardener", "watcher", "elder", "craftsman"], npc + " has authored social facts")
		tiers[c.tier] += 1
		var loved := 0
		var disliked := 0
		for item in giftable:
			var taste := Validator.taste(data, npc, item)
			loved += int(taste == "love")
			disliked += int(taste in ["dislike", "hate"])
		t.expect(loved >= 3 and float(loved) / giftable.size() <= 0.08 and float(disliked) / giftable.size() <= 0.12, "%s taste distribution: %d loved, %d disliked of %d" % [npc, loved, disliked, giftable.size()])
		var prefix := "SOC_" + npc.to_upper() + "_"
		var first: Array[String] = []
		var greetings := 0
		for key in keys:
			if key.begins_with(prefix + "FIRST_"):
				first.append(key)
			if key.begins_with(prefix + "GREET_"):
				greetings += 1
		t.expect(first.size() == 1 and greetings >= {"A": 4, "B": 2, "C": 1}[c.tier] and loc.has_key(prefix + "BIO_1"), npc + " has first meeting, hearts-band greetings and biography")
		if c.partner:
			partner_count += 1
			t.expect(SocialData.npc_row(npc).get("age", "adult") == "adult", npc + " is an adult partner candidate")
		var sample := SocialData.sample_of(npc)
		if not sample.is_empty():
			var item := str(sample.item)
			var d: Dictionary = lr.get_item_def(item)
			t.expect(d.get("rarity", "normal") == "normal" and int(d.get("sell_price", 999)) <= 20, npc + " offers a cheap normal sample")
	t.check("citizens_cover_friends", SocialData.citizens().size() == SocialData.friend_ids().size() and int(tiers.A) >= 11 and int(tiers.B) >= 18 and int(tiers.C) >= 5 and partner_count >= 11)
	var code: Dictionary = t.run_tool(t.python(), [ProjectSettings.globalize_path("res://tools/copy/copy_lint.py"), "--json"])
	t.check("copy_lint_clean_on_the_social_csvs", code.code == 0, code.output)
	t.expect_tool_ids(t.run_tool(t.python(), [ProjectSettings.globalize_path("res://tools/voice/build_index.py"), "--check"]), "Social voice index")
	# Data-only extension uses the real Lua loader, social defaults and universal taste rules.
	var fixture := "user://social_new_citizen.lua"
	var f := FileAccess.open(fixture, FileAccess.WRITE)
	f.store_string('kind = "config"\nconfig = { npcs = { new_neighbour = { name_key = "NPC_NEW_NEIGHBOUR", friendship = true, role = "child", home_area = "hyggebyen" } } }\n')
	f.close()
	lr.load_file(fixture)
	var derived := SocialData.citizen("new_neighbour")
	t.check("new_npc_by_data_only", derived.derived and derived.tier == "C" and derived.archetype == "child" and int(derived.birthday.day) >= 1 and int(derived.birthday.day) <= 28 and sm.can_befriend("new_neighbour") and sm.add_points("new_neighbour", 100, &"debug").ok and sm.hearts("new_neighbour") == 1, "One roster row gets hearts, a stable birthday and the child archetype")
	data.npcs = lr.get_npcs()
	t.expect(Validator.taste(data, "new_neighbour", "cookie") == "love", "Derived child uses archetype taste without another row")
	lr.reload_scripts()
	DirAccess.remove_absolute(fixture)
	t.new_game()
