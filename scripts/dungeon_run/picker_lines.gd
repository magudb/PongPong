class_name DungeonPickerLines
extends RefCounted
static func lines(number: int) -> Array:
	var eco := Svc.node("EconomyManager")
	if eco == null: return []
	var item: StringName = eco.equipped_item(&"weapon")
	var range_of_weapon := DungeonCombatRules.weapon_range(item)
	var shown := TranslationServer.translate(str(ItemKinds.def(item).get("name_key","INV_EMPTY_SLOT")))
	var ratio := DungeonCombatRules.weapon_ratio(item,number)
	var weak := ratio < float(DungeonRulesData.cfg("tutorial.weak_ratio_x100",75))/100.0
	var risk := floori(float(eco.gold)*float(DungeonRulesData.value("dungeon.defeat.gold_loss_pct",10))/100.0)
	return [
		{"kind":"weapon","warn":weak,"text":TranslationServer.translate("DPICK_WEAPON_FMT") % [shown,int(ItemKinds.def(item).get("damage",0)),range_of_weapon.x,range_of_weapon.y]+("\n"+TranslationServer.translate("DPICK_WEAPON_WEAK") if weak else "")},
		{"kind":"oil","warn":eco.count_item(&"lantern_oil") == 0,"text":TranslationServer.translate("DPICK_OIL_FMT") % eco.count_item(&"lantern_oil")},
		{"kind":"tonic","warn":false,"text":TranslationServer.translate("DPICK_TONIC_FMT") % (eco.count_item(&"health_tonic")+eco.count_item(&"svampe_eliksir"))},
		{"kind":"pack","warn":eco.free_slots() <= 2,"text":TranslationServer.translate("DPICK_PACK_FMT") % [eco.used_slots(),24]},
		{"kind":"risk","warn":false,"text":TranslationServer.translate("DPICK_RISK_FMT") % [int(DungeonRulesData.value("dungeon.defeat.gold_loss_pct",10)),risk] if risk > 0 else TranslationServer.translate("DPICK_RISK_NONE")},
	]
