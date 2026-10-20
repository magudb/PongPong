extends RefCounted
const SECTION := "ghostfam_quests"
const TIMEOUT_S := 180.0
const FAMILY := ["ghostfam_dyne","ghostfam_gnist","ghostfam_silke"]
const QUESTS := ["ghostfam_garn","ghostfam_lygtemager","ghostfam_hittegods"]
const QText := preload("res://scripts/ui/theme/tt_quest_text.gd")
class Absence extends Node:
	var who := ""
	func is_absent(npc: String) -> bool:return who=="all" or npc==who
func _start(t) -> void:
	await t.start_world()
	GameManager.set_config_override("time.minutes_per_real_second",0)
	GameManager.set_config_override("towns.curfew.enabled",false)
	for name in ["dyne","gnist","silke"]:GameManager.set_flag(StringName("ghostfam_kin_"+name),true)
func run(t) -> void:
	await _start(t)
	for i in QUESTS.size():
		var q := StringName(QUESTS[i])
		var npc := str(FAMILY[i])
		t.check(str(q)+"_registered",not QuestManager.get_quest_def(q).is_empty() and QuestManager.validate_definition(QuestManager.get_quest_def(q)).is_empty())
		SocialManager.debug_set_hearts(npc,i+1)
		t.check(str(q)+"_heart_gate",not QuestManager.is_offerable(q) and not QuestManager.accept_quest(q))
		SocialManager.debug_set_hearts(npc,i+2)
		t.check(str(q)+"_offered_at_threshold",q in QuestManager.offerable(npc))
		var page := NpcDialogue.build(npc,npc,NpcDialogue.context(npc,t.world().player))
		t.check(str(q)+"_real_dialogue_offer",_has_quest_choice(page,q))
	SocialManager.debug_set_hearts("ghostfam_dyne",2)
	t.check("garn_accept",QuestManager.accept_quest(&"ghostfam_garn"))
	EventBus.dialogue_started.emit(&"ghostfam_dyne",&"ghostfam_dyne")
	t.check("garn_waits_for_wool",QuestManager.is_active(&"ghostfam_garn"))
	EconomyManager.add_item(&"wool",3,true)
	QuestManager.refresh_objectives()
	var shirt := EconomyManager.count_item(&"shirt_knit_blue")
	EventBus.dialogue_started.emit(&"ghostfam_dyne",&"ghostfam_dyne")
	t.check("garn_consumes_exact_wool",QuestManager.is_completed(&"ghostfam_garn") and EconomyManager.count_item(&"wool")==0)
	t.check("garn_blue_shirt_and_heart",EconomyManager.count_item(&"shirt_knit_blue")==shirt+1 and SocialManager.hearts("ghostfam_dyne")==3)
	t.check("garn_never_repeats",not QuestManager.accept_quest(&"ghostfam_garn"))
	t.check("lantern_accept",QuestManager.accept_quest(&"ghostfam_lygtemager"))
	EconomyManager.add_item(&"glow_mushroom",3,true)
	QuestManager.refresh_objectives()
	EventBus.dialogue_started.emit(&"ghostfam_gnist",&"ghostfam_gnist")
	t.check("lantern_requires_both_ingredients",QuestManager.is_active(&"ghostfam_lygtemager") and EconomyManager.count_item(&"glow_mushroom")==3)
	EconomyManager.add_item(&"night_bloom",1,true)
	QuestManager.refresh_objectives()
	var gold := EconomyManager.gold
	var oil := EconomyManager.count_item(&"lantern_oil")
	EventBus.dialogue_started.emit(&"ghostfam_gnist",&"ghostfam_gnist")
	t.check("lantern_consumes_and_rewards",QuestManager.is_completed(&"ghostfam_lygtemager") and EconomyManager.count_item(&"glow_mushroom")==0 and EconomyManager.count_item(&"night_bloom")==0 and EconomyManager.gold==gold+120 and EconomyManager.count_item(&"lantern_oil")==oil+3)
	t.check("lantern_never_repeats",not QuestManager.accept_quest(&"ghostfam_lygtemager"))
	var fake := Absence.new()
	fake.who = "guard_oak"
	Svc.override("NpcDirector",fake)
	t.check("lost_owner_filters_absence",GhostFamilyQuests.eligible_owners().size()==5 and not GhostFamilyQuests.eligible_owners().any(func(row):return str(row.owner)=="guard_oak"))
	fake.who = "all"
	t.check("no_eligible_owner_no_offer",not QuestManager.is_offerable(&"ghostfam_hittegods") and not QuestManager.accept_quest(&"ghostfam_hittegods"))
	var probe := Node.new()
	t.tree.root.add_child(probe)
	GhostFamilyQuests.attach(probe)
	probe.free()
	var gate: Callable = QuestManager._offer_gates["ghostfam_hittegods"]
	t.check("eligibility_survives_helper_disposal",gate.is_valid() and not QuestManager._offer_allowed(&"ghostfam_hittegods"))
	Svc.clear_overrides()
	fake.free()
	t.check("six_non_twin_owners",GhostFamilyQuests.eligible_owners().size()==6 and GhostFamilyQuests.eligible_owners().all(func(row):return not str(row.owner) in ["rasmus","kiki","bertil","bodil"]))
	var quests := SocialManager.get_node("FamilyQuests") as GhostFamilyQuests
	t.check("lost_accept",QuestManager.accept_quest(&"ghostfam_hittegods"))
	var runtime: QuestManager.QuestRuntime = QuestManager.active_quests[&"ghostfam_hittegods"]
	var owner := str(runtime.meta.lost_owner)
	var item := str(runtime.meta.lost_item)
	var count := EconomyManager.count_item(StringName(item))
	t.check("named_parcel_accepted_once",bool(runtime.meta.parcel_given) and count>0 and quests.collect_parcel() and EconomyManager.count_item(StringName(item))==count)
	var key := str(runtime.meta.objective_keys["return"])
	t.check("journal_names_owner_and_item",QuestManager.get_objective_text(&"ghostfam_hittegods",&"return")==TranslationServer.translate(key) and str(QText.steps(&"ghostfam_hittegods")[0].text)==TranslationServer.translate(key))
	t.check("journal_shows_named_heart",QText.rewards(&"ghostfam_hittegods").any(func(row):return str(row.kind)=="heart" and str(row.text).contains(TranslationServer.translate(str(SocialData.npc_row(owner).name_key)))))
	t.check("lost_save_reload",SaveManager.save_game(3) and SaveManager.load_game(3))
	runtime = QuestManager.active_quests[&"ghostfam_hittegods"]
	t.check("lost_assignment_saved",str(runtime.meta.lost_owner)==owner and str(runtime.meta.lost_item)==item and bool(runtime.meta.parcel_given) and EconomyManager.count_item(StringName(item))==count)
	EventBus.game_event.emit(&"gift_given",{"npc":"ghostfam_silke","item":item})
	EventBus.game_event.emit(&"gift_given",{"npc":owner,"item":"stone"})
	t.check("wrong_owner_or_item_cannot_finish",QuestManager.is_active(&"ghostfam_hittegods"))
	var points := SocialManager.points(owner)
	gold = EconomyManager.gold
	var gift := GiftFlow.give_gift(owner,item)
	t.check("real_gift_finishes_lost_property",bool(gift.ok) and QuestManager.is_completed(&"ghostfam_hittegods") and EconomyManager.gold==gold+60 and SocialManager.points(owner)==points+int(gift.get("points",0))+100,str(gift))
	EventBus.game_event.emit(&"gift_given",{"npc":owner,"item":item})
	t.check("lost_reward_cannot_replay",EconomyManager.gold==gold+60)
	var completed_day := GameManager.total_day()
	Fresh.jump_to_total_day(completed_day+6)
	t.check("lost_seven_day_cooldown",not QuestManager.is_offerable(&"ghostfam_hittegods"))
	Fresh.jump_to_total_day(completed_day+7)
	t.check("lost_returns_after_week",QuestManager.is_offerable(&"ghostfam_hittegods"))
	EconomyManager.inventory.clear()
	for i in 24:EconomyManager.inventory.append({"id":&"stone","amount":99,"meta":{}})
	t.check("full_pack_accepts_deferred_parcel",QuestManager.accept_quest(&"ghostfam_hittegods"))
	runtime = QuestManager.active_quests[&"ghostfam_hittegods"]
	t.check("full_pack_has_no_phantom_parcel",not bool(runtime.meta.parcel_given) and not quests.collect_parcel())
	t.check("deferred_parcel_saves",SaveManager.save_game(3) and SaveManager.load_game(3))
	runtime = QuestManager.active_quests[&"ghostfam_hittegods"]
	item = str(runtime.meta.lost_item)
	t.check("deferred_state_survives",not bool(runtime.meta.parcel_given))
	EconomyManager.remove_item(&"stone",99)
	var silke := Npc2D.create({"id":"ghostfam_silke"})
	t.world().area.objects.add_child(silke)
	t.check("silke_talk_hook_collects_parcel",GhostFamHook.before_talk(silke,t.world().player) and bool(runtime.meta.parcel_given) and EconomyManager.count_item(StringName(item))==1)
	silke.queue_free()
	t.check("deferred_parcel_no_duplicate",quests.collect_parcel() and EconomyManager.count_item(StringName(item))==1)
	t.check("content_reproducible",int(t.run_tool(t.python(), [ProjectSettings.globalize_path("res://tools/social/content/build_family_quests.py"),"--check"]).code)==0)
	t.check("family_lua_has_no_new_findings",not LuaRuntime.lint_report.any(func(row):return str(row.get("path","")).contains("ghostfam")))
	await t.go_menu()
func _has_quest_choice(page: Dictionary,id: StringName) -> bool:
	for choice in LuaData.arr(page.get("choices",[])):
		if str(choice.get("quest_id",""))==str(id):return true
		if str(choice.get("action",""))=="social_more" and _has_quest_choice({"choices":choice.choices},id):return true
	return false
func run_windowed(t) -> void:
	await _start(t)
	var world: WorldRoot2D = t.world()
	Fresh.jump_to_total_day(10)
	GameManager.hour = 20
	EventBus.day_started.emit(GameManager.day,GameManager.season)
	EventBus.time_of_day_changed.emit(20,0)
	SocialManager.debug_set_hearts("ghostfam_silke",4)
	await world.travel(&"traetoppen",&"default")
	await t.physics(4)
	var actor := NpcDirector.node_of("ghostfam_silke",world.area) as Npc2D
	t.check("native_silke_present",actor!=null)
	if actor==null:return
	actor.interact(world.player)
	var ui: Node = t.first(&"dialogue_ui")
	await t.until(func():return ui._wants_focus(),.05)
	var read: bool = await t.until(func() -> bool:
		if ui.is_open() and not ui._wants_focus():ui._advance()
		return ui._wants_focus(),5.0)
	t.check("native_real_offer_choice",read and _has_quest_choice({"choices":ui._choices},&"ghostfam_hittegods"))
	var choices: Array = ui._choices.filter(func(c):return str(c.get("quest_id",""))=="ghostfam_hittegods")
	if not choices.is_empty():ui._pick(choices[0])
	await t.until(func():return not actor.is_talking and not GameManager.is_modal_open(),3.0)
	t.check("native_parcel_accepted",QuestManager.is_active(&"ghostfam_hittegods") and bool(QuestManager.active_quests[&"ghostfam_hittegods"].meta.parcel_given))
	await t.tap(&"journal")
	await t.frames(4)
	await t.capture("lost_property_journal")
	var book: Node = world.game_ui.get_screen(&"quest_journal")
	t.check("native_journal_shows_errand",book.is_open())
	book.close()
	await t.go_menu()
