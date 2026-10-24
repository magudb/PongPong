extends RefCounted
const SECTION := "city_life"
const TIMEOUT_S := 180.0

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var eco: Node = t.autoload("EconomyManager")
	var qm: Node = t.autoload("QuestManager")
	var bus: Node = t.autoload("EventBus")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	for type in ["mailbox", "board", "bath", "seed_basket", "kiki_cache", "rejsestolpe"]:
		t.check("handler_" + type, str(IsoArea.resolve_handler(type).kind) == "script")
	var box: PostBox2D = t.world().area.find_markers("mailbox")[0].node
	t.check("mailbox_places_param_prop", box.prop_node != null and str(box.prop_node.get_meta("prop_id")) == "mailbox_red")
	var posts: Array = []
	var listen := func(id, payload):
		if id == &"post_read":
			posts.append(payload.duplicate())
	bus.game_event.connect(listen)
	box.interact(t.player())
	t.check("day_one_mailbox_empty_no_event", box.letter.is_empty() and posts.is_empty() and gm.flag_int(&"post_read_day") == 0)
	gm.day = 2
	var notes: Array = []
	var note := func(key):
		if key == "LIFE_POST_TOAST":
			notes.append(key)
	bus.whisper_requested.connect(note)
	box.refresh()
	box.refresh()
	t.check("post_toast_once", notes.size() == 1)
	t.check("post_letter_selection", not box.letter.is_empty() and str(box.letter.quest_id) == "pips_runde", str(box.letter))
	var offered := str(box.letter.get("quest_id", ""))
	box.interact(t.player())
	await t.frames(3)
	var dialogue: Control = t.tree.get_first_node_in_group("dialogue_ui")
	t.check("letter_uses_real_dialogue", dialogue.is_open() and dialogue._speaker.id == "postman_pip")
	await _choices(t, dialogue)
	if not dialogue._buttons.is_empty():
		dialogue._buttons[0].pressed.emit()
	await t.frames(3)
	t.check("post_accept_starts_quest", qm.is_active(StringName(offered)))
	box.interact(t.player())
	t.check("post_once_per_day", posts.size() == 1 and posts[0].quest_id == offered and not dialogue.is_open())
	gm.day = 3
	gm.set_config_override("traetoppen.post.givers", [])
	box.interact(t.player())
	box.interact(t.player())
	t.check("empty_post_still_emits_once", posts.size() == 2 and str(posts[1].quest_id) == "")
	bus.game_event.disconnect(listen)
	bus.whisper_requested.disconnect(note)
	gm.clear_config_overrides()
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	var board := NoticeBoard2D.new()
	t.world().area.objects.add_child(board)
	var rows := board.rows()
	var everyday := LuaData.arr(gm.config_value("traetoppen.board.givers"))
	t.check("board_lists_only_everyday_givers", not rows.is_empty() and rows.size() <= 5 and rows.all(func(row): return str(row.giver) in everyday))
	board.interact(t.player())
	await _choices(t, dialogue)
	if not dialogue._buttons.is_empty():
		dialogue._buttons[0].pressed.emit()
	await t.frames(3)
	await _choices(t, dialogue)
	if not dialogue._buttons.is_empty():
		dialogue._buttons[0].pressed.emit()
	await t.frames(3)
	t.check("board_accept_starts_quest", qm.is_active(StringName(str(rows[0].quest_id))))
	board.queue_free()
	await _bath(t)
	await _swap(t)
	gm.day += 1
	eco.reset()
	eco.add_item(&"carrot", 2, true)
	bus.game_event.emit(&"swap_seeds_request", {"npc": "gardener_hoppe"})
	t.check("visiting_hoppe_swaps_on_farm", str(t.world().area.map.id) == "farm" and eco.count_item(&"carrot") == 0 and eco.count_item(&"moonflower_seeds") + eco.count_item(&"glow_berry_seeds") == 1)
	await _caches(t)
	for day in range(1, 8):
		gm.day = day
		DailyFlags.refresh()
		var weekday: int = t.autoload("TimeManager").weekday_index()
		var weekend: bool = weekday in [5, 6]
		t.check("market_weekday_" + str(day), gm.flag_int(&"brumme_at_stall") == int(weekend) and gm.flag_int(&"brumme_at_work") == int(not weekend))
		# The stall's opening days and Brumme's routine are the two remaining sources: they must agree (SIM-09).
		t.check("stall_hours_follow_brumme_" + str(day), (not weekday in Hours.closed_days(Hours.building("torvestanden"))) == DailyFlags.keeps_stall_today())
	# All service markers also build through the actual room builder.
	gm.set_config_override("towns.hours_enabled", false)
	for id in ["int_postkontoret", "int_raadhuset", "int_badehuset"]:
		await t.world().travel(StringName(id), &"default")
		await t.frames(3)
		var type: String = {"int_postkontoret": "mailbox", "int_raadhuset": "board", "int_badehuset": "bath"}[id]
		var handled := false
		for child in t.world().area.objects.get_children():
			handled = handled or (child is PostBox2D if type == "mailbox" else child is NoticeBoard2D if type == "board" else child is BathTub2D)
		t.check("room_handler_" + id, handled and str(t.world().area.map.id) == id, str(t.world().area.map.id))
		if id == "int_postkontoret":
			for host in t.world().area.objects.get_children():
				if host is ShopCounter and host.kind == "post_counter":
					host.interact(t.player())
			await t.frames(3)
			var post: Control = t.world().game_ui.get_screen(&"post")
			t.check("post_office_counter_responds",post.is_open() and not post.data.is_empty() and post.tabs.size()==3)
			post.close()
			await t.frames(3)
		elif id == "int_badehuset":
			bus.game_event.emit(&"bath_request", {"npc": "bathkeeper_sofus"})
			t.check("sofus_request_uses_live_bath", gm.top_modal() == &"bath")
			await t.seconds(1.4)
			t.check("sofus_request_completes_once", gm.flag_int(&"bath_day") == gm.total_day() and not gm.is_modal_open())
	var csv := FileAccess.open("res://localization/life.csv", FileAccess.READ)
	csv.get_csv_line()
	while not csv.eof_reached():
		var row := csv.get_csv_line()
		if row.size() < 3 or row[0] == "":
			continue
		for i in [1, 2]:
			t.autoload("LocalizationManager").set_locale("da" if i == 1 else "en")
			t.check("copy_" + row[0] + str(i), row[i] != "" and TranslationServer.translate(row[0]) == row[i])
	t.autoload("LocalizationManager").set_locale("da")
	gm.clear_config_overrides()

func _choices(t, dialogue: Control) -> void:
	if not await t.page_to_choices(dialogue):
		t.fail("Service dialogue never reached choices in 10 game seconds")

func _bath(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var bath := BathTub2D.new()
	t.world().area.objects.add_child(bath)
	gm.hour = 25
	gm.minute = 50
	t.check("bath_refused_before_day_end", bath.refusal() == "LIFE_BATH_LATE")
	gm.hour = 12
	gm.minute = 5
	var player: Node = t.player()
	player.stamina = 1
	player.half_hearts = 1
	bath.interact(player)
	bath.interact(player)
	await t.seconds(1.4)
	t.check("bath_restores_and_costs_time", gm.hour == 12 and gm.minute == 35 and player.stamina == player.max_stamina and player.half_hearts == player.max_half_hearts)
	t.check("bath_once_per_day", bath.refusal() == "LIFE_BATH_USED" and not gm.is_modal_open())
	for mode in ["bed", "roll"]:
		gm.hour = 24 if mode == "bed" else 25
		gm.minute = 30 if mode == "bed" else 59
		var before: int = gm.total_day()
		if mode == "bed":
			gm.end_day()
		else:
			gm.advance_time(1)
		await t.until(func(): return not t.world().traveling and not t.world().sleeping, 6)
		t.check("daily_flags_after_" + mode, gm.total_day() == before + 1 and bath.refusal() == "")
	# Removing an in-flight service must release the modal.
	gm.hour = 12
	bath.interact(player)
	bath.queue_free()
	await t.frames(3)
	t.check("disposed_bath_releases_modal", not gm.is_modal_open())

func _swap(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var eco: Node = t.autoload("EconomyManager")
	var basket := SeedBasket2D.new()
	t.world().area.objects.add_child(basket)
	eco.reset()
	t.check("swap_requires_carrots", not bool(basket.swap().ok) and gm.flag_int(&"swap_day") == 0)
	eco.add_item(&"carrot", 4, true)
	var observations: Array = []
	var observe := func(_player_id: StringName, _inventory):
		observations.append(eco.count_item(&"carrot") == 2 and eco.count_item(&"moonflower_seeds") + eco.count_item(&"glow_berry_seeds") == 1 and gm.flag_int(&"swap_day") == gm.total_day())
		basket.swap()
	t.autoload("EventBus").player_inventory_changed.connect(observe)
	var result := basket.swap()
	t.autoload("EventBus").player_inventory_changed.disconnect(observe)
	t.check("swap_atomic_before_observers", result.ok and not observations.is_empty() and observations.all(func(complete): return complete))
	t.check("swap_once_per_day", not bool(basket.swap().ok) and eco.count_item(&"carrot") == 2)
	gm.day += 1
	eco.reset()
	eco.add_item(&"carrot", 2, true)
	for id in t.autoload("LuaRuntime").get_all_item_ids():
		if eco.free_slots() == 0:
			break
		if str(id) not in ["carrot", "moonflower_seeds", "glow_berry_seeds"] and ItemKinds.storage_of(id) == ItemKinds.BACKPACK:
			eco.add_item(StringName(str(id)), 1, true)
	result = basket.swap()
	t.check("full_bag_preserves_carrots_and_daily_flag", not result.ok and result.reason == "LIFE_BAG_FULL" and eco.count_item(&"carrot") == 2 and gm.flag_int(&"swap_day") != gm.total_day())
	basket.queue_free()

func _caches(t) -> void:
	var gm: Node = t.autoload("GameManager")
	var eco: Node = t.autoload("EconomyManager")
	var old_skin: String = gm.character_skin
	var cache := CrownCache2D.new()
	cache.slot = posmod(gm.total_day(), 5)
	t.world().area.objects.add_child(cache)
	for skin in ["animal_fox", "fairy_meadow", "hobbit_pip", "ghost_bu"]:
		gm.character_skin = skin
		t.check("cache_excludes_" + skin, not cache.eligible())
	gm.character_skin = "animal_monkey"
	eco.reset()
	var gold: int = eco.gold
	cache.interact(t.player())
	var item_count := 0
	for id in ["wild_flower", "apple", "fern", "friendship_token"]:
		item_count += eco.count_item(StringName(id))
	t.check("cache_reward_is_small", eco.gold - gold >= 20 and eco.gold - gold <= 50 and item_count == 1)
	gold = eco.gold
	cache.interact(t.player())
	t.check("cache_once_per_day", eco.gold == gold and not cache.eligible())
	var flags: Dictionary = JSON.parse_string(JSON.stringify(gm.world_flags))
	for key in ["post_read_day", "post_toast_day", "bath_day", "swap_day", "cache_day"]:
		t.check("daily_flag_serializes_" + key, flags.get(key) == gm.world_flags.get(key))
	cache.queue_free()
	gm.character_skin = old_skin
