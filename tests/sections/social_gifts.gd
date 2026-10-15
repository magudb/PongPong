extends RefCounted
const SECTION := "social_gifts"
const Rules := preload("res://scripts/social/gifts/gift_rules.gd")
const Flow := preload("res://scripts/social/gifts/gift_flow.gd")

class Home extends Node:
	var tier := 1
	var have := 2
	func requirements(_n: int) -> Array:
		return [{"kind": "material", "id": "wood", "have": have, "need": 2}]

class Capstones extends Node:
	var granted := false
	func set_capstone_granted(_id: String) -> bool:
		return granted

class HotbarProbe extends RefCounted:
	var slots: Array = []
	func to_dict() -> Dictionary:
		return {"slots": slots}

class PlayerProbe extends Node:
	var hotbar := HotbarProbe.new()

class Store extends Node:
	var available: Dictionary = {}
	var owned: Dictionary = {}
	func owned_ids() -> Array:
		return owned.keys()
	func count_stock(id: Variant) -> int:
		return int(available.get(str(id), 0))
	func count_free(id: Variant) -> int:
		return count_stock(id)
	func count_total(id: Variant) -> int:
		return int(owned.get(str(id), 0))
	func remove(id: Variant, n: int) -> bool:
		if count_stock(id) < n:
			return false
		available[str(id)] = count_stock(id) - n
		owned[str(id)] = count_total(id) - n
		return true

func run(t) -> void:
	await t.go_menu()
	var sm: Node = t.autoload("SocialManager")
	var eco: Node = t.autoload("EconomyManager")
	var qm: Node = t.autoload("QuestManager")
	var bus: Node = t.autoload("EventBus")
	var lr: Node = t.autoload("LuaRuntime")
	var cfg := SocialData.cfg_dict("gifts")
	for cls in [&"love", &"like", &"neutral", &"dislike", &"hate"]:
		for rarity in ["normal", "uncommon", "rare"]:
			var points := Rules.points(cfg, cls, rarity)
			var expected := {"love": 40, "like": 20, "neutral": 8, "dislike": 0, "hate": 0}
			var multiplier := {"normal": 1.0, "uncommon": 1.25, "rare": 1.5}
			t.expect(points == roundi(expected[str(cls)] * multiplier[rarity]), "%s / %s points" % [cls, rarity])
	t.check("birthday_x4_capped", Rules.points(cfg, &"love", "rare", "day") == 160)
	t.check("belated_x2", Rules.points(cfg, &"love", "normal", "belated") == 80)
	t.check("repeat_halves", Rules.points(cfg, &"love", "normal", "", true) == 20)
	for def in [{"category": "quest", "giftable": true}, {"category": "special"}, {"category": "animal"}, {"category": "building"}, {"category": "blueprint"}, {"rarity": "unique"}, {"rarity": "legendary"}, {"protected": true}]:
		t.expect(not Rules.giftable("probe", def, 10).ok, "Progress/keepsake guard: " + str(def))
	t.expect(not Rules.giftable("probe", {"category": "forage"}, 0).ok and Rules.giftable("probe", {"category": "forage", "giftable": true}, 0).ok, "Zero-value gifts require an explicit data opt-in")
	for def in [{"category": "tool"}, {"rarity": "rare"}, {"category": "forage"}]:
		var price := 100 if def.get("category") == "forage" else 1
		t.expect(Rules.needs_confirm("probe", def, price), "Valuable/rare/tool confirmation")
	t.check("confirm_never_for_cheap_forage", not Rules.needs_confirm("fern", {"category": "forage", "rarity": "normal"}, 2))
	var tastes := {"npcs": {"probe": {"like": ["apple"]}}, "archetypes": {"child": {"love": ["apple", "category:food"]}}, "universal": {"dislike": ["category:food"]}}
	t.check("taste_resolution_levels", Rules.taste_of(tastes, "probe", "child", "apple", {"category": "food"}).level == "npc" and Rules.taste_of(tastes, "other", "child", "apple", {"category": "food"}).level == "archetype" and Rules.taste_of(tastes, "other", "absent", "apple", {"category": "food"}).level == "universal")
	var selectors := Rules.selectors_of("probe", {"category": "furniture", "furniture_type": "lamp"})
	t.check("item_id_beats_ftype_beats_category", Rules.match_row({"love": ["probe"], "like": ["ftype:lamp"], "hate": ["category:furniture"]}, selectors).class == &"love" and Rules.match_row({"like": ["ftype:lamp"], "hate": ["category:furniture"]}, selectors).class == &"like")
	var npc := "gardener_hoppe"
	SocialFixture.fresh(t, 10)
	eco.add_item(&"carrot", 5)
	var events: Array = []
	var observer := func(name: StringName, payload: Dictionary) -> void:
		if name == &"gift_given":
			events.append(payload.duplicate())
	bus.game_event.connect(observer)
	var snapshots: Array = []
	var on_inventory := func(_inventory: Dictionary) -> void:
		snapshots.append({"items": eco.count_item(&"carrot"), "day_left": sm.gift_limits(npc).left_today, "points": sm.points(npc), "reentry": sm.give_gift(npc, "carrot")})
	bus.player_inventory_changed.connect(on_inventory)
	var gift: Dictionary = sm.give_gift(npc, "carrot")
	bus.player_inventory_changed.disconnect(on_inventory)
	t.check("gift_love_points_and_items", gift.ok and gift.points == 40 and sm.points(npc) == 40 and eco.count_item(&"carrot") == 4)
	t.check("observer_sees_complete_transaction", snapshots.size() == 1 and snapshots[0].items == 4 and snapshots[0].day_left == 0 and snapshots[0].points == 40 and not snapshots[0].reentry.ok)
	t.check("quest_event_payload_shape", events.size() == 1 and events[0] == {"npc": npc, "item": "carrot", "taste": "love", "points": 40, "birthday": false})
	t.check("limit_one_per_day", not sm.give_gift(npc, "carrot").ok and eco.count_item(&"carrot") == 4)
	SocialFixture.jump(11)
	var again: Dictionary = sm.give_gift(npc, "carrot")
	t.expect(again.ok and again.repeated and again.points == 20, "A recent repeat pays half")
	SocialFixture.jump(12)
	t.check("limit_two_per_week", sm.give_gift(npc, "carrot").get("reason") == "week")
	SocialFixture.jump(15)
	t.expect(sm.give_gift(npc, "carrot").ok, "Monday reopens the calendar-week slot")
	bus.game_event.disconnect(observer)
	SocialFixture.fresh(t, 5)
	eco.add_item(&"carrot", 3)
	var birthday: Dictionary = sm.give_gift(npc, "carrot")
	t.expect(birthday.ok and birthday.points == 160 and birthday.birthday == "day" and sm.row_of(npc).gw == 0, "Birthday gift bypasses weekly slots and is capped")
	SocialFixture.jump(6)
	t.expect(sm.birthday_state(npc) == "", "The same birthday cannot be celebrated again as belated")
	SocialFixture.fresh(t, 6)
	eco.add_item(&"carrot", 2)
	t.expect(sm.give_gift(npc, "carrot").points == 80, "A first gift the day after a birthday pays twice")
	SocialFixture.fresh(t, 10)
	eco.add_item(&"carrot", 2)
	qm.accept_quest(&"supply_run")
	eco.add_item(&"wood", 2)
	t.check("quest_item_not_offered", Flow.protection("wood", lr.get_item_def("wood")) == "quest_needs_it" and not "wood" in sm.gift_options(npc).map(func(r): return str(r.id)))
	qm.reset()
	var home := Home.new()
	Svc.override("HomeManager", home)
	t.check("next_tier_materials_not_offered", Flow.protection("wood", lr.get_item_def("wood")) == "home_material")
	home.have = 3
	t.expect(Flow.protection("wood", lr.get_item_def("wood")) == "", "One surplus material can be gifted without losing the next-tier requirements")
	Svc.clear_overrides()
	home.free()
	t.expect(Flow.protection("hoe_wooden", lr.get_item_def("hoe_wooden")) == "last_tool", "Last tool is protected")
	eco.add_item(&"hoe_wooden", 1)
	var player := PlayerProbe.new()
	player.hotbar.slots = ["hoe_wooden"]
	t.root.add_child(player)
	player.add_to_group("player")
	t.expect(Flow.protection("hoe_wooden", lr.get_item_def("hoe_wooden")) == "hotbar_tool", "Hotbar tool remains protected even with a spare")
	player.free()
	var capstones := Capstones.new()
	Svc.override("LootService", capstones)
	t.check("incomplete_set_pieces_not_offered", Flow.protection("shirt", {"category": "clothing", "set": "proof"}) == "incomplete_set")
	capstones.granted = true
	t.expect(Flow.protection("shirt", {"category": "clothing", "set": "proof"}) == "", "Completed set pieces may be offered")
	Svc.clear_overrides()
	capstones.free()
	var storage := Store.new()
	storage.owned = {"chair_pine": 2}
	storage.available = {"chair_pine": 0}
	Svc.override("FurnitureManager", storage)
	t.check("placed_not_offered", not "chair_pine" in sm.gift_options(npc).map(func(r): return str(r.id)))
	storage.available["chair_pine"] = 1
	t.expect("chair_pine" in sm.gift_options(npc).map(func(r): return str(r.id)), "Unplaced furniture uses free stock")
	Svc.clear_overrides()
	storage.free()
	var wardrobe := Store.new()
	wardrobe.owned = {"hat_straw_plain": 1}
	wardrobe.available = {"hat_straw_plain": 0}
	var completed_set := Capstones.new()
	completed_set.granted = true
	Svc.override("WardrobeManager", wardrobe)
	Svc.override("LootService", completed_set)
	t.expect(not "hat_straw_plain" in sm.gift_options(npc).map(func(r): return str(r.id)), "A worn garment is excluded")
	wardrobe.available["hat_straw_plain"] = 1
	t.expect("hat_straw_plain" in sm.gift_options(npc).map(func(r): return str(r.id)), "A spare unworn garment uses its store's free count")
	Svc.clear_overrides()
	wardrobe.free()
	completed_set.free()
	# Learning a new taste evicts the oldest, retaining the newest forty.
	var known := {}
	for i in 40:
		known["old_%d" % i] = "neutral"
	sm.row_of(npc)["kn"] = known
	eco.add_item(&"carrot", 2)
	t.expect(sm.give_gift(npc, "carrot").ok, "Gift for knowledge cap probe")
	var after: Dictionary = sm.row_of(npc).kn
	t.check("known_tastes_cap", after.size() == 40 and not after.has("old_0") and after.get("carrot") == "love")
	var toasts: Array = []
	var on_toast := func(title: String, body: String, _kind: String) -> void: toasts.append([title, body])
	bus.notification_posted.connect(on_toast)
	var line := Flow.react(npc, gift)
	bus.notification_posted.disconnect(on_toast)
	t.check("reaction_line_cascade", str(line.get("text_key", "")).begins_with("GIFT_GARDENER_HOPPE_LOVE_"))
	var name := str(TranslationServer.translate(str(lr.get_item_def("carrot").name_key)))
	t.check("toast_names_item_not_sentence", toasts.size() == 1 and str(toasts[0][1]).contains(name), "One combined toast names the item; the reaction remains a complete sentence")
	SocialFixture.uninstall()
	t.new_game()
