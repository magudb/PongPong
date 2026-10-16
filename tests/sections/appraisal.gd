extends RefCounted
const SECTION := "appraisal"
func run(t) -> void:
	await _run(t,false)
func run_windowed(t) -> void:
	await _run(t,true)
func _run(t, native: bool) -> void:
	await t.start_world()
	var world: WorldRoot2D = t.world()
	var eco: Node = t.autoload("EconomyManager")
	var loot: Node = t.autoload("LootService")
	var gm: Node = t.autoload("GameManager")
	var sm: Node = t.autoload("SaveManager")
	eco.add_item(&"rough_skovkant",15,true)
	eco.add_item(&"rough_krystalgrotten",2,true)
	eco.add_gold(2000)
	t.check("dialogue_choice_present",FileAccess.get_file_as_string("res://lua/dialogue/appraiser_fru_ugle.lua").contains('event = "open_appraisal"'))
	EventBus.game_event.emit(&"open_appraisal",{"npc":"appraiser_fru_ugle"})
	await t.frames(3)
	var ui: TTScreen = loot._appraisal_ui
	t.check("opens_through_real_service_and_game_ui",ui != null and ui.get_parent() == world.game_ui and ui.is_open() and gm.top_modal() == &"appraisal")
	if ui == null: return
	t.check("lists_owned_rough_stacks",ui.rows.get_child_count() == 2 and ui.rows.get_child(0).get_meta("item_id","") != "")
	ui._select("rough_skovkant")
	var before: int = eco.gold
	var observations := []
	var observer := func(_id,_amount):
		var wire: Variant = JSON.parse_string(FileAccess.get_file_as_string(sm.slot_path(sm.AUTO_SLOT)))
		observations.append(wire is Dictionary and int(wire.get("loot",{}).get("dungeon",{}).get("appraise",{}).get("skovkant",0)) >= 1)
	EventBus.item_gained.connect(observer)
	ui._appraise(1)
	EventBus.item_gained.disconnect(observer)
	t.check("fee_charged_per_stone",eco.gold == before-30 and eco.count_item(&"rough_skovkant") == 14)
	t.check("saved_before_gain_observers",not observations.is_empty() and observations.all(func(value): return value))
	ui._appraise(12)
	t.check("batch_max_twelve",eco.count_item(&"rough_skovkant") == 2 and eco.gold == before-390 and int(loot.dungeon.appraise.skovkant) == 13 and ui.results.get_child_count() == 12,"stones=%d gold=%d counter=%s labels=%d selected=%s" % [eco.count_item(&"rough_skovkant"),eco.gold,loot.dungeon.appraise,ui.results.get_child_count(),ui.selected])
	eco.gold = 0
	before = eco.count_item(&"rough_skovkant")
	ui._appraise(1)
	t.check("no_gold_no_change",eco.count_item(&"rough_skovkant") == before and eco.gold == 0 and ui.status_label.text == TranslationServer.translate("APPRAISE_NO_GOLD"))
	eco.gold = 1000
	var slots := []
	for i in 23: slots.append({"id":"wood","amount":99})
	slots.append({"id":"rough_skovkant","amount":2})
	eco.from_dict({"v":1,"gold":1000,"inventory":slots})
	ui._refresh_texts()
	ui._select("rough_skovkant")
	ui._appraise(1)
	t.check("full_backpack_refuses_before_payment",eco.gold == 1000 and eco.count_item(&"rough_skovkant") == 2 and ui.status_label.text == TranslationServer.translate("APPRAISE_BACKPACK_FULL"))
	if native:
		eco.reset()
		eco.add_item(&"rough_skovkant",4,true)
		eco.add_item(&"rough_dybe_bregner",3,true)
		eco.add_item(&"rough_krystalgrotten",2,true)
		eco.add_gold(2000)
		ui._refresh_texts()
		ui._select("rough_skovkant")
		ui._appraise(1)
		await t.frames(4)
		await t.capture("stones_and_results")
	await t.tap(&"ui_cancel")
	await t.frames(3)
	t.check("escape_closes_and_frees_modal",not is_instance_valid(ui) and gm.top_modal() != &"appraisal")
	EventBus.game_event.emit(&"open_appraisal",{"npc":"appraiser_fru_ugle"})
	await t.frames(2)
	t.check("reopens_once_after_free",loot._appraisal_ui != null and is_instance_valid(loot._appraisal_ui) and loot._appraisal_ui.is_open())
	loot._appraisal_ui.close()
	await t.frames(2)
