class_name DungeonRunWatch
extends Node
var active := false
var floors: Dictionary = {}
var deepest := 0
var finds := 0
var rare := 0
var kills := 0
var best := ""
var _summary: Array[String] = []
var _summary_wait := 0.0
var _hint_poll := 0.0
var _elapsed := 0.0
var _berry_seen := false
var _pack_warned := false
func _ready() -> void:
	EventBus.game_event.connect(_event)
	EventBus.area_changed.connect(_area)
	EventBus.item_gained.connect(_item)
	EventBus.enemy_defeated.connect(func(_id,_kind,_loot):
		if active: kills += 1)
func _area(id: StringName) -> void:
	if str(id) == str(DungeonRulesData.value("dungeon.hub.area","moerkeskoven")):
		active = false
		DungeonTutorial.say("hub")
func _event(event: StringName, payload: Dictionary) -> void:
	match event:
		&"dungeon_floor_entered":
			if not active:
				floors.clear()
				deepest = 0
				finds = 0
				rare = 0
				kills = 0
				best = ""
				_elapsed = 0
				_berry_seen = false
				_pack_warned = false
				_summary.clear()
			active = true
			var number := int(payload.get("floor",1))
			floors[number] = true
			deepest = maxi(deepest,number)
			if payload.get("first_today",false):
				var service := DungeonFloors.inst()
				if service != null and not service.is_revealed(number):
					EconomyManager.consume_backpack_items({"etagekort":1},func(): service.reveal_floor(number); EventBus.game_event.emit(&"floor_map_used",{"floor":number}); EventBus.whisper_requested.emit("DEXP_MAP_READ"))
			DungeonTutorial.say("lantern")
		&"dungeon_run_ended":
			active = false
			if str(payload.get("reason","")) == "left":
				_summary = [tr("DEXP_SUMMARY_FLOORS_FMT") % [floors.size(),deepest],tr("DEXP_SUMMARY_FINDS_FMT") % [finds,rare],tr("DEXP_SUMMARY_BEST_FMT") % tr(str(ItemKinds.def(best).get("name_key","DEXP_SUMMARY_NONE"))) if best != "" else tr("DEXP_SUMMARY_NONE")]
				_summary_wait = 0.3
		&"dungeon_surprise": _surprise(payload)
		&"dungeon_runestone_activated": DungeonTutorial.say("rune")
## The statistics of a run in progress from a save (DungeonFloors' run record): the count goes on after a Continue.
func restore(record: Dictionary) -> void:
	active = true
	floors.clear()
	for number in record.get("floors", []):
		floors[int(number)] = true
	deepest = int(record.get("deepest", 0))
	finds = int(record.get("finds", 0))
	rare = int(record.get("rare", 0))
	kills = int(record.get("kills", 0))
	best = str(record.get("best", ""))
func _item(_player_id: StringName, id: StringName, amount: int) -> void:
	if not active: return
	if id == &"tornebaer": _berry_seen = true
	finds += amount
	if Rarity.rank(ItemKinds.rarity_of(id)) >= Rarity.rank(&"rare"): rare += amount
	if best == "" or Rarity.rank(ItemKinds.rarity_of(id)) > Rarity.rank(ItemKinds.rarity_of(best)): best = str(id)
func _surprise(payload: Dictionary) -> void:
	var player := DungeonRulesData.player()
	match str(payload.get("id","")):
		"firefly_swarm":
			if player != null: player.add_oil(maxf(float(payload.get("oil_s",30)),0))
			EventBus.whisper_requested.emit("DEXP_SURPRISE_FIREFLIES")
		"acorn_purse":
			var gold := maxi(int(payload.get("gold",0)),0)
			EconomyManager.add_gold(gold)
			EventBus.whisper_requested.emit(tr("DEXP_SURPRISE_PURSE_FMT") % gold)
		"cocoa_thermos":
			if player != null: player.heal_half(maxi(int(payload.get("heal_half_hearts",2)),0))
			EventBus.whisper_requested.emit("DEXP_SURPRISE_COCOA")
		"pip_note": EventBus.whisper_requested.emit(tr("DEXP_SURPRISE_NOTE_FMT") % tr(str(payload.get("hint_key","DTUT_RUNE"))))
func _process(dt: float) -> void:
	var gm := Svc.node("GameManager")
	if gm != null and gm.is_modal_open(): return
	if active: _tutorials(dt)
	if _summary.is_empty(): return
	_summary_wait -= dt
	if _summary_wait <= 0:
		EventBus.notification_posted.emit(tr("DEXP_SUMMARY_TITLE"),_summary.pop_front(),"forest")
		_summary_wait = float(DungeonRulesData.cfg("summary.gap",1.2))

func _tutorials(dt: float) -> void:
	_elapsed += dt
	_hint_poll -= dt
	if _hint_poll > 0: return
	_hint_poll = 0.2
	var player := DungeonRulesData.player() as Node2D
	if player == null or player.get("area") == null: return
	var area: IsoArea = player.area
	if DungeonFloors.floor_of(area) <= 0: return
	DungeonTutorial.say("lantern")
	if _elapsed >= 3: DungeonTutorial.say("abilities")
	if _berry_seen: DungeonTutorial.say("berry")
	var eco := Svc.node("EconomyManager")
	if eco != null and not _pack_warned and eco.free_slots() <= 2:
		_pack_warned = true
		EventBus.whisper_requested.emit("DEXP_BACKPACK_FULL" if eco.free_slots() == 0 else "DEXP_BACKPACK_NEAR")
	if eco != null and DungeonCombatRules.weapon_ratio(eco.equipped_item(&"weapon"),DungeonFloors.floor_of(area)) < float(DungeonRulesData.cfg("tutorial.weak_ratio_x100",75))/100.0:
		DungeonTutorial.say("weapon_weak")
	for marker in area.markers:
		var distance := Iso.ground_dist(player.global_position,marker.pos)
		match str(marker.type):
			"runestone":
				if distance < 700: DungeonTutorial.say("rune")
			"chest":
				if distance < 500: DungeonTutorial.say("chest")
			"warp":
				if DungeonFloors.floor_of_id(marker.params.get("to","")) > DungeonFloors.floor_of(area) and distance < 600: DungeonTutorial.say("hulen")
			"enemy":
				if str(marker.params.get("boss","0")) == "1" and distance < 900: DungeonTutorial.say("boss")
				elif str(marker.params.get("ambush","0")) == "1" and distance < 780: DungeonTutorial.say("eyes")
