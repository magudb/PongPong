class_name FarmStage
extends Node
## World lifetime, including time spent away from the parked farm. No state lives in scenery.
var world: Node
var _stage := 0
var _paying := false

static func of_tier(tier: int) -> Dictionary:
	var stages := LuaData.arr(Svc.lua_config("farm_site.stages", []))
	for i in stages.size():
		if tier in LuaData.arr(stages[i].get("tiers", [])):
			var row := LuaData.dict(stages[i]).duplicate(true)
			row["index"] = i + 1
			return row
	return {"id": "spiren", "index": 1, "rows": 0, "name_key": "FARMSITE_STAGE_1"}

static func attach(target: Node) -> Node:
	var existing := target.get_node_or_null("FarmSteading")
	if existing != null:
		return existing
	var service := FarmStage.new()
	service.name = "FarmSteading"
	service.world = target
	target.add_child(service)
	return service

func _ready() -> void:
	EventBus.day_started.connect(_morning)
	EventBus.home_upgraded.connect(func(_old, _new): _refresh(true))
	EventBus.load_completed.connect(func(_slot): _refresh(false))
	EventBus.area_changed.connect(func(_area): _refresh(false))
	EventBus.game_event.connect(func(event, _payload):
		if event == &"home_exterior_ready":
			_refresh(true))
	_refresh(false)

func _refresh(announce: bool) -> void:
	var tier := int(HomeManager.tier)
	var row := of_tier(tier)
	var next := int(row.index)
	var rose := _stage > 0 and next > _stage
	var changed := _stage != next
	_stage = next
	GameManager.set_flag(&"farm_stage", next)
	if changed:
		EventBus.game_event.emit(&"farm_stage_changed", {"stage": next, "tier": tier})
	if announce and rose:
		EventBus.notification_posted.emit(tr("FARMSITE_STAGE_UP_TITLE"), tr("FARMSITE_STAGE_UP") % tr(str(row.name_key)), "home")

func _morning(_day: int, _season: StringName) -> void:
	if _paying or not is_instance_valid(world):
		return
	var flags := LuaData.dict(world.area_flags.get("farm", {}))
	var shipped: Array[String] = []
	var gold := 0
	var ratio := clampf(float(GameManager.config_value("farm_site.bin.pay_ratio", 1.0)), 0, 1)
	for key in flags:
		if str(key).begins_with("bin_"):
			var count := maxi(0, int(flags[key]))
			var id := StringName(str(key).trim_prefix("bin_"))
			gold += roundi(EconomyManager.sell_value(id) * ratio) * count
			shipped.append(str(key))
	if shipped.is_empty():
		return
	_paying = true
	EconomyManager.defer_notifications(func():
		for key in shipped:
			world.set_area_flag(&"farm", key, null)
		EconomyManager.add_gold(gold)
		EconomyManager.after_transaction(func():
			EventBus.game_event.emit(&"bin_payout", {"gold": gold})
			if bool(GameManager.config_value("farm_site.bin.morning_toast", true)):
				EventBus.notification_posted.emit(tr("FARMSITE_BIN_MORNING_TITLE"), tr("FARMSITE_BIN_MORNING") % gold, "coins")))
	_paying = false
