extends RefCounted
const SECTION := "festival_activities"
const TIMEOUT_S := 180.0
const Rules := preload("res://scripts/social/events/festival_activities.gd")
const Stage := preload("res://scripts/social/events/festival_stage.gd")
var world: WorldRoot2D
var director: SocialEventDirector
var ui: Node
var picker: Node
func run(t) -> void:
	await _run(t,false)
func run_windowed(t) -> void:
	await _run(t,true)
func _run(t,native: bool) -> void:
	t.check("normal_score_has_no_rarity_bonus",Rules.score({"sell_price":100,"rarity":"normal"}) == 100.0)
	t.check("uncommon_score_bonus",Rules.score({"sell_price":100,"rarity":"uncommon"}) == 150.0)
	t.check("rare_score_bonus",Rules.score({"sell_price":100,"rarity":"rare"}) == 200.0)
	var items := {"small":{"category":"crop","rarity":"normal","sell_price":10},"large":{"category":"crop","rarity":"rare","sell_price":100},"prize":{"rarity":"normal","sell_price":20},"keepsake":{"rarity":"unique","sell_price":1}}
	var rewards := {"first":{"gold":100},"second":{"gold":70},"third":{"gold":40}}
	t.check("cheapest_winning_entry_caps_prize",Rules.cap("category:crop",items) == 200)
	t.check("unknown_selector_has_zero_cap",Rules.cap("category:missing",items) == 0)
	t.check("legal_prizes",Rules.valid_prizes("category:crop",rewards,items))
	for prizes in [{"first":{"gold":201}},{"first":{"gold":100},"second":{"gold":71}},{"first":{"gold":100},"third":{"gold":41}},{"first":{"items":{"keepsake":1}}},{"first":{"items":{"unknown":1}}}]:
		t.check("over_cap_or_keepsake_refused_"+str(prizes),not Rules.valid_prizes("category:crop",prizes,items))
	for seed in range(1,21):
		var result := Rules.contest("large","category:crop",rewards,items,seed,"festival",1)
		t.check("deterministic_entry_seed_%d" % seed,result == Rules.contest("large","category:crop",rewards,items,seed,"festival",1) and result.rank >= 1 and result.rank <= 4 and result.bars.size() == 3)
	t.check("wrong_entry_refused",not Rules.contest("prize","category:crop",rewards,items,1,"festival",1).ok)
	await t.start_world()
	world = t.world()
	GameManager.set_config_override("time.minutes_per_real_second",0)
	GameManager.set_config_override("towns.curfew.enabled",false)
	director = SocialManager.get_node("EventDirector")
	ui = t.first(&"dialogue_ui")
	picker = world.game_ui.get_screen(&"gift_ui")
	var acts: Array = []
	for row in [["contest","judge","category:crop"],["potluck","table_1","category:food"],["wish","host",""],["feast","table_2",""],["dance","host",""],["market","stall_1",""]]:
		acts.append({"id":row[0],"kind":row[0],"select":row[2],"post":"fest_hyggetorv_"+str(row[1]),"name_key":"SOC_EV_ACTIVITY_"+str(row[0]).to_upper(),"shop":"seed_shop"})
	var festival := {"meta":{"name_key":"SOC_EV_TITLE","area":"hyggebyen","spot":"hyggetorv","host":"mayor_lyra","season":"foraar","day":3,"from":12,"to":20,"closes":"none","bed_hold":true},"activities":acts,"scenes":{"opening":"ev_test_open","finale":"ev_test_end"},"rewards":{"contest":{"first":{"gold":20},"second":{"gold":10},"third":{"gold":5}}}}
	var scene := {"meta":{"trigger":"festival","once_per_year":true},"steps":[{"act":"say","who":"mayor_lyra","text_key":"SOC_EV_FEAST"}]}
	SocialFixture.install({}, {"festivals":{"activity_test":festival},"events":{"ev_test_open":scene,"ev_test_end":scene.duplicate(true)}})
	SocialFixture.jump(3,12)
	SocialManager.flush()
	await world.travel(&"hyggebyen",&"default")
	await t.until(func():return is_instance_valid(director._stage) and director._stage.hosts.size() == 6,3.0)
	await _finish(t)
	await t.physics(4)
	var stage: FestivalStage = director._stage
	t.check("stage_attached_to_active_area",stage != null and stage.area == world.area and stage.hosts.size() == 6,"stage=%s area=%s active=%s" % [str(stage),str(world.area.map.id),str(SocialManager.festival_active())])
	if stage == null:
		SocialFixture.uninstall()
		return
	t.check("named_posts_have_no_map_errors",world.area.map.errors.is_empty(),str(world.area.map.errors))
	t.check("all_six_activities_enabled_in_window",stage.hosts.all(func(host):return host.is_enabled()))
	t.check("opening_once_per_year",SocialManager.event_stamp("ev_test_open") == 1)
	var host_points := SocialManager.points("mayor_lyra")
	stage.attendance()
	t.check("attendance_points_once",SocialManager.points("mayor_lyra") == host_points and host_points == 20)
	stage.attendance("gardener_hoppe")
	stage.attendance("gardener_hoppe")
	t.check("talked_citizen_attendance_once",SocialManager.points("gardener_hoppe") == 20)
	EconomyManager.inventory.clear()
	var crops := ItemKinds.all_ids("crop")
	crops.sort_custom(func(a,b):return Rules.score(ItemKinds.def(a)) > Rules.score(ItemKinds.def(b)))
	var best := str(crops[0])
	EconomyManager.add_item(StringName(best),2,true)
	var other := "honey"
	EconomyManager.add_item(StringName(other),2,true)
	var gold := EconomyManager.gold
	await _pick(t,stage,acts[0],best,native)
	t.check("contest_consumes_exactly_one_entry",EconomyManager.count_item(StringName(best)) == 1 and stage.done("contest"))
	t.check("contest_pays_bounded_prize",EconomyManager.gold-gold >= 0 and EconomyManager.gold-gold <= 20)
	stage.perform(acts[0])
	await t.frames(2)
	t.check("contest_cannot_be_repeated",EconomyManager.count_item(StringName(best)) == 1 and not picker.is_open())
	await _pick(t,stage,acts[1],other,false)
	t.check("potluck_donation_is_one_item",EconomyManager.count_item(StringName(other)) == 1 and GameManager.flag_int(&"potluck_activity_test_1") == 1)
	GameManager.hour = 19
	t.check("town_contributions_reach_goal",stage.potluck_count() == 12)
	var player := world.player
	player.half_hearts = 2
	player.stamina = 1
	stage.perform(acts[3])
	t.check("feast_restores_once",player.half_hearts == player.max_half_hearts and player.stamina == player.max_stamina and stage.done("feast"))
	player.half_hearts = 2
	stage.perform(acts[3])
	t.check("feast_repeat_has_no_effect",player.half_hearts == 2)
	var old_points := SocialManager.points("mayor_lyra")
	stage.perform(acts[2])
	await _finish(t)
	t.check("wish_is_flavour_flag",GameManager.get_flag(&"wish_activity_test_1",false) and stage.done("wish"))
	t.check("wish_host_points_once",SocialManager.points("mayor_lyra") == old_points+20)
	stage.perform(acts[2])
	await t.frames(2)
	t.check("wish_repeat_refused",director.queue.is_empty() and director.runner.active == "")
	var present := SocialManager.festival_roster("activity_test")
	var attendees: Array = [present.host]+present.gather
	attendees = attendees.filter(func(id):return NpcDirector.is_present(str(id)))
	if not attendees.is_empty():
		var partner := str(attendees[-1])
		SocialManager.debug_set_hearts(partner,8)
		var before := SocialManager.points(partner)
		stage.perform(acts[4])
		await _finish(t)
		t.check("dance_chooses_highest_hearts_present",SocialManager.points(partner) == before+30 and stage.done("dance"))
	else: t.fail("festival has no present citizen for its dance")
	GameManager.hour = 12
	stage.perform(acts[5])
	await t.frames(3)
	var shop: Node = world.game_ui.get_screen(&"shop_ui")
	t.check("market_opens_existing_shop_panel",shop.is_open())
	shop.close()
	var same_stage := director._stage
	director._schedule()
	await t.frames(3)
	t.check("stage_is_stable_across_flushes",director._stage == same_stage and stage.hosts.size() == 6)
	GameManager.hour = 19
	EventBus.time_of_day_changed.emit(19,0)
	await _finish(t)
	t.check("finale_once_per_year",SocialManager.event_stamp("ev_test_end") == 1)
	GameManager.hour = 20
	EventBus.time_of_day_changed.emit(20,0)
	t.check("activities_disable_at_window_end",stage.hosts.all(func(host):return not host.is_enabled()))
	stage.perform(acts[3])
	t.check("outside_window_has_no_effect",player.half_hearts == 2)
	await t.frames(3)
	t.check("stage_removed_at_end",not is_instance_valid(director._stage))
	SocialFixture.uninstall()
	director.reset()
	t.new_game()

func _pick(t,stage: FestivalStage,activity: Dictionary,item: String,native: bool) -> void:
	stage.perform(activity)
	await t.until(func():return picker.is_open(),3.0)
	t.check("picker_opens_"+str(activity.id),picker.is_open() and picker._selection_mode)
	var at: int = picker.options.find_custom(func(row):return str(row.id) == item)
	t.check("matching_item_available_"+str(activity.id),at >= 0)
	if at < 0:
		picker.close()
		return
	picker._select(at)
	if native: await t.capture("contest_picker")
	picker._give()
	await t.frames(3)

func _finish(t) -> void:
	for i in 800:
		await t.frames(1)
		if ui.is_open() and GameManager.top_modal() == &"dialogue":
			if ui._wants_focus(): ui._pick(ui._choices[0])
			else: ui._advance()
		if director.runner.active == "" and director.queue.is_empty(): return
	t.fail("festival scene did not release")
