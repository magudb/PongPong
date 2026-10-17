class_name DungeonRun
extends RefCounted
## Static facade: all persistent progression is in GameManager flags; the
## floor state belongs to DungeonFloors and loot belongs to LootService.
static func cfg(path: String, fallback: Variant = null) -> Variant:
	return DungeonRulesData.cfg(path,fallback)
static func expected_weapon(number: int) -> int:
	return DungeonCombatRules.expected_weapon(number)
static func weapon_family(id: String = "sword") -> Dictionary:
	return DungeonCombatRules.weapon_family(id)
static func weapon_rating(item: Variant) -> float:
	return DungeonCombatRules.weapon_rating(item)
static func weapon_ratio(item: Variant, number: int) -> float:
	return DungeonCombatRules.weapon_ratio(item,number)
static func weapon_range(item: Variant) -> Vector2i:
	return DungeonCombatRules.weapon_range(item)
static func enemy_hp(kind: String, number: int) -> int:
	return DungeonCombatRules.enemy_hp(kind,number)
static func enemy_damage(kind: String, tier: int) -> int:
	return DungeonCombatRules.enemy_damage(kind,tier,int(assist("assist_dmg")))
static func boss_hp(kind: String) -> int:
	return DungeonCombatRules.boss_hp(kind)
static func hearts_bonus() -> int:
	return clampi(int(DungeonRulesData.flag("dungeon_hearts_bonus",0)),0,LuaData.arr(cfg("boss_kinds",[])).size()*int(cfg("hearts_per_boss",2)))
static func hearts_max() -> int:
	return maxi(1,int(DungeonRulesData.value("combat.max_half_hearts",10))+hearts_bonus()+assist_hearts())
static func oil_step(oil: float, dt: float, context: Dictionary) -> float:
	return DungeonOilRules.step(oil,dt,context)
static func light_ratio(oil: float) -> float:
	return DungeonOilRules.light_ratio(oil)
static func bite_due(oil: float, hearts_half: int, elapsed: float) -> bool:
	return DungeonOilRules.bite_due(oil,hearts_half,elapsed)
static func auto_refuel_item(oil: float, owned: Dictionary) -> StringName:
	return DungeonOilRules.auto_refuel_item(oil,owned)
static func assist(key: String) -> Variant:
	return DungeonAssist.get_value(key)
static func set_assist(key: String, value: Variant) -> bool:
	return DungeonAssist.set_value(key,value)
static func apply_preset(id: String) -> bool:
	return DungeonAssist.apply_preset(id)
static func windup_mult() -> float:
	return DungeonAssist.windup_mult()
static func dmg_minus() -> int:
	return int(assist("assist_dmg"))
static func assist_hearts() -> int:
	return DungeonAssist.hearts()
static func arc_pct() -> int:
	return DungeonAssist.arc_pct()
static func dodge_bonus() -> float:
	return DungeonAssist.dodge_bonus()
static func boss_killed(kind: String, number: int) -> Dictionary:
	var gm := Svc.node("GameManager")
	if gm == null or kind not in LuaData.strings(cfg("boss_kinds",[])): return {"first":false,"hearts_bonus":hearts_bonus()}
	var key := "dungeon_boss_"+kind
	var first := int(gm.flag_int(StringName(key),0)) == 0
	var bonus := hearts_bonus()
	if first: bonus = mini(bonus+int(cfg("hearts_per_boss",2)),LuaData.arr(cfg("boss_kinds",[])).size()*int(cfg("hearts_per_boss",2)))
	gm.set_flags({key:gm.total_day(),"dungeon_hearts_bonus":bonus})
	if first:
		EventBus.notification_posted.emit(TranslationServer.translate("DEXP_SKOVHJERTE"),"","heart")
		EventBus.game_event.emit(&"skovhjerte_grown",{"bonus":bonus,"hearts_max":hearts_max(),"floor":number,"level":number})
	return {"first":first,"hearts_bonus":bonus}
static func after_defeat(gold_lost: int) -> void:
	var gm := Svc.node("GameManager")
	if gm == null: return
	var loss := maxi(gold_lost,0)
	gm.set_flags({"dungeon_defeats":gm.flag_int(&"dungeon_defeats",0)+1,"dungeon_gold_lost":gm.flag_int(&"dungeon_gold_lost",0)+loss})
	var text: String = TranslationServer.translate("DEXP_DEFEAT_TEXT_FMT") % loss if loss > 0 else TranslationServer.translate("DEXP_DEFEAT_TEXT_FREE")
	EventBus.notification_posted.emit(TranslationServer.translate("DEXP_DEFEAT_TITLE"),text,"heart")
	if gm.flag_int(&"dungeon_defeats",0) >= 2: tutorial_say("assist")
static func chest_sense_cells() -> int:
	var cells := floori(float(SpeciesPerks.current("chest_sense_px",0))/float(Iso.ORTHO_W))
	var gem: Variant = Svc.static_call("res://scripts/combat/lantern_gem.gd",&"equipped",[],&"")
	var effects: Dictionary = Svc.static_call("res://scripts/combat/lantern_gem.gd",&"effects",[gem],{})
	cells = maxi(cells,int(effects.get("chest_sense_cells",0)))
	var eco := Svc.node("EconomyManager")
	var info: Dictionary = Svc.static_call("res://scripts/combat/weapon_info.gd",&"of",[eco.equipped_item(&"weapon") if eco != null else &""],{})
	var effect := LuaData.dict(info.get("effect",{}))
	if str(effect.get("id","")) == "reveal_chests": cells = maxi(cells,int(effect.get("cells",0)))
	return clampi(cells,0,int(DungeonRulesData.value("dungeon_loot.limits.chest_sense_max_cells",12)))
static func chest_sense() -> int:
	return chest_sense_cells()
static func chest_sense_px() -> float:
	return float(chest_sense_cells()*Iso.ORTHO_W)
static func picker_lines(number: int) -> Array:
	return DungeonPickerLines.lines(number)
static func tutorial_say(id: String) -> bool:
	return DungeonTutorial.say(id)
static func attach(host: Node) -> Node:
	if host == null: return null
	# Gameplay effects belong to one world, independently of its HUD instances.
	var owner := host
	while owner != null and not owner.is_in_group("world_2d"):
		owner = owner.get_parent()
	if owner == null: return null
	var existing := owner.get_node_or_null("RunWatch")
	if existing != null: return existing
	var watch := DungeonRunWatch.new()
	watch.name = "RunWatch"
	owner.add_child(watch)
	return watch
