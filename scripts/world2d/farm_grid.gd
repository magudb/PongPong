class_name FarmGrid
extends Node
## Persistent crop model. Inventory and plot changes commit together before observers run.
signal plot_changed(cell: Vector2i)

enum State { EMPTY, TILLED, PLANTED, WATERED, READY, WITHERED }

class PlotData:
	var state: int = State.TILLED
	var crop_id: StringName = &""
	var growth_days: float = 0.0
	var watered: bool = false
	var watered_hour: float = 6.0
	var eligible_water: bool = false
	var planted_day: int = 0
	var fertilizer: bool = false
	var auto_water_days: int = 0
	var yield_amount: int = 0 # Roll once per crop, including when the backpack is full.
	var regrowing: bool = false

	func to_dict() -> Dictionary:
		return {"state": state, "crop_id": String(crop_id), "growth_days": growth_days,
			"watered": watered, "watered_hour": watered_hour, "eligible_water": eligible_water, "planted_day": planted_day,
			"fertilizer": fertilizer, "auto_water_days": auto_water_days, "yield_amount": yield_amount, "regrowing": regrowing}

var plots: Dictionary = {} # Vector2i -> PlotData
var crop_defs: Dictionary = {}
var map: AreaMap
var rng := RandomNumberGenerator.new()
var _cells: Dictionary = {}
var _zones: Dictionary = {}
var _unlocked: Dictionary = {}
var _last_day: int = 0
var _busy: bool = false
var map_path := "res://data/maps/farm.map"
var indoor := false

static func crop_definitions() -> Dictionary:
	return GameData.dict_of(GameData.cfg("crops", {})).duplicate(true)

func _ready() -> void:
	crop_defs = crop_definitions()
	configure_map(AreaMap.load_file(map_path))
	_last_day = GameData.gm().total_day()
	rng.randomize()
	EventBus.day_started.connect(_on_day_started)
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.time_of_day_changed.connect(_on_time_changed)

func configure_map(value: AreaMap) -> void:
	map = value
	indoor = map != null and str(map.extra.get("indoor", "false")) == "true"
	_cells.clear()
	_zones.clear()
	_unlocked.clear()
	if map == null:
		return
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			if map.ground_at(cell) == "f":
				_cells[cell] = true
	for marker in map.markers.values():
		if marker.get("marker") == "field_expansion":
			_zones[str(marker.get("id", ""))] = IsoArea.parse_cells(str(marker.get("cells", "")), Vector2i(map.width, map.height))
			for cell in _zones[str(marker.get("id", ""))]:
				_cells.erase(cell)
	_sync_zones()

func _world() -> Node:
	return get_tree().get_first_node_in_group("world_2d") if is_inside_tree() else null

func _sync_zones() -> void:
	var world := _world()
	if world == null or map == null:
		return
	for id in _zones:
		if bool(world.get_area_flag(map.id, "zone_" + id, false)):
			_unlocked[id] = true
			for cell in _zones[id]:
				_cells[cell] = true

func can_till(cell: Vector2i, ignore_placed: bool = false) -> bool:
	if not _cells.has(cell):
		return false
	var world := _world()
	if not ignore_placed and world != null:
		for piece in world.placed_items:
			if str(piece.get("area", "farm")) == str(map.id) and piece.get("cell", []) == [cell.x, cell.y]:
				return false
	var area: Variant = world.get("area") if world != null else null
	if area is IsoArea and area.map.id == map.id:
		# Farm plots and purchased expansion cells are reserved against buildings,
		# while this model's _cells already enforces which fields can be tilled.
		return str(Svc.static_call("res://scripts/farm/steading/objects/farm_reserve.gd", &"blocked", [area, cell], "")) in ["", "field", "zone"]
	return true

func unlock_cells(zone_id: String) -> int:
	if not _zones.has(zone_id) or _unlocked.has(zone_id):
		return 0
	_unlocked[zone_id] = true
	for cell in _zones[zone_id]:
		_cells[cell] = true
	for cell in _zones[zone_id]:
		plot_changed.emit(cell)
	EventBus.plot_unlocked.emit(StringName("zone:" + zone_id))
	return _zones[zone_id].size()

func farmable_cells() -> Array:
	return _cells.keys()

static func plot_id(cell: Vector2i) -> StringName:
	return StringName("plot_%d_%d" % [cell.x, cell.y])

func get_plot(cell: Vector2i) -> PlotData:
	return plots.get(cell)

func state_of(cell: Vector2i) -> int:
	var p := get_plot(cell)
	return State.EMPTY if p == null else p.state

func visual_stage(cell: Vector2i) -> int:
	var p := get_plot(cell)
	if p == null or p.crop_id == &"":
		return -1
	if p.state == State.READY:
		return 3
	if p.regrowing or p.state == State.WITHERED:
		return 2
	return clampi(int(3.0 * p.growth_days / _growth_needed(p)), 0, 2)

func _growth_needed(p: PlotData) -> float:
	var def: Dictionary = crop_defs.get(String(p.crop_id), {})
	if p.regrowing:
		return maxf(1.0, float(def.get("regrow_days", 1)))
	return maxf(1.0, float(def.get("stages", 4)) * float(def.get("days_per_stage", 1)))

func in_season(crop: StringName) -> bool:
	if indoor:
		return true
	var seasons: Array = crop_defs.get(String(crop), {}).get("seasons", [])
	return seasons.is_empty() or str(GameData.gm().season) in seasons

func till(cell: Vector2i) -> bool:
	if _busy or not can_till(cell) or state_of(cell) != State.EMPTY:
		return false
	plots[cell] = PlotData.new()
	EventBus.game_event.emit(&"plot_tilled", {"plot_id": String(plot_id(cell))})
	EventBus.crop_stage_changed.emit(plot_id(cell), State.TILLED)
	plot_changed.emit(cell)
	return true

func plant(cell: Vector2i, seed_item: StringName) -> String:
	var p := get_plot(cell)
	if _busy or p == null or p.state != State.TILLED or not can_till(cell):
		return "UI_TOOL_NO_EFFECT"
	var crop := str(GameData.item_def(seed_item).get("crop_id", ""))
	if not crop_defs.has(crop):
		return "UI_TOOL_NO_EFFECT"
	if not in_season(StringName(crop)):
		return "UI_NOT_IN_SEASON"
	_busy = true
	var ok: bool = GameData.eco().consume_backpack_items({seed_item: 1}, func() -> void:
		p.crop_id = StringName(crop)
		p.state = State.WATERED if p.watered else State.PLANTED
		p.growth_days = 0.0
		p.regrowing = false
		p.planted_day = GameData.gm().total_day()
		# Watering bare soil still counts when the seed goes in later that day.
		p.eligible_water = p.watered and in_water_window(p.watered_hour, p.crop_id)
		if _rain() or p.auto_water_days > 0:
			_water(p, float(GameData.gm().hour))
	)
	_busy = false
	if not ok:
		return "UI_TOOL_NO_EFFECT"
	EventBus.crop_planted.emit(plot_id(cell), p.crop_id)
	plot_changed.emit(cell)
	return ""

func in_water_window(hour: float, crop: StringName = &"moonflower") -> bool:
	var window: Dictionary = crop_defs.get(String(crop), {}).get("water_window", {})
	if window.is_empty():
		return true
	var start := float(window.get("from", 0))
	var end := float(window.get("to", 26))
	return hour >= start and hour < end if start <= end else hour >= start or hour < end

func _water(p: PlotData, hour: float) -> void:
	p.watered = true
	p.watered_hour = hour
	p.eligible_water = p.eligible_water or in_water_window(hour, p.crop_id)
	if p.state == State.PLANTED:
		p.state = State.WATERED

## `source` = &"player" (the can: EventBus.crop_watered, which quests and hints count) or the automation that watered it (&"sprinkler" ...:
## EventBus.crop_auto_watered, only for a plot with a crop; GAP4-03).
func water(cell: Vector2i, at_hour: float = -1.0, source: StringName = &"player") -> bool:
	var p := get_plot(cell)
	if _busy or p == null or p.state in [State.EMPTY, State.WITHERED] or not can_till(cell):
		return false
	# A second watering at night can make a moon crop eligible even if its soil was wet at noon.
	var hour := float(GameData.gm().hour) if at_hour < 0 else at_hour
	if p.watered and (p.eligible_water or not in_water_window(hour, p.crop_id)):
		return false
	_water(p, hour)
	_announce_water(cell, p, source)
	plot_changed.emit(cell)
	return true


func _announce_water(cell: Vector2i, p: PlotData, source: StringName) -> void:
	if source == &"player":
		EventBus.crop_watered.emit(plot_id(cell))
	elif p.crop_id != &"":
		EventBus.crop_auto_watered.emit(plot_id(cell), source)

func apply_supply(cell: Vector2i, item: StringName) -> bool:
	var p := get_plot(cell)
	if _busy or p == null or p.state in [State.EMPTY, State.READY, State.WITHERED] or not can_till(cell):
		return false
	var effect := str(GameData.item_def(item).get("farm_effect", ""))
	if effect == "fertilizer" and not p.fertilizer:
		pass
	elif effect == "auto_water" and p.auto_water_days == 0:
		pass
	else:
		return false
	_busy = true
	var ok: bool = GameData.eco().consume_backpack_items({item: 1}, func() -> void:
		if effect == "fertilizer":
			p.fertilizer = true
		else:
			p.auto_water_days = maxi(1, int(GameData.cfg("farm.auto_water_days", 3)))
			_water(p, float(GameData.gm().hour))
	)
	_busy = false
	if ok:
		plot_changed.emit(cell)
	return ok

func harvest(cell: Vector2i) -> int:
	var p := get_plot(cell)
	if _busy or p == null or p.state != State.READY:
		return 0
	var crop := p.crop_id
	var amount := maxi(1, int(GameData.cfg("farm.harvest_yield", 1)))
	if p.fertilizer:
		amount += int(GameData.cfg("farm.fertilizer_bonus_yield", 1))
	if p.yield_amount == 0:
		if rng.randf() < float(SpeciesPerks.current("harvest_bonus_chance", 0.0)):
			amount += 1
		p.yield_amount = amount
	amount = p.yield_amount
	_busy = true
	var ok: bool = GameData.eco().receive_backpack_item(crop, amount, func() -> void:
		p.regrowing = int(crop_defs[String(crop)].get("regrow_days", 0)) > 0
		p.state = (State.WATERED if p.watered else State.PLANTED) if p.regrowing else State.TILLED
		if not p.regrowing:
			p.crop_id = &""
		p.growth_days = 0.0
		p.fertilizer = false
		p.yield_amount = 0
	, false)
	_busy = false
	if not ok:
		EventBus.notification_posted.emit(tr("NOTIF_INVENTORY_FULL_TITLE"), tr("NOTIF_INVENTORY_FULL_MSG"), "inventory")
		return 0
	EventBus.crop_harvested.emit(plot_id(cell), crop, amount)
	plot_changed.emit(cell)
	return amount

## Scythes clear dead crops; an axe/pickaxe can deliberately remove a living crop.
## Soil, today's water and watering supplies survive clearing and harvesting.
func clear_crop(cell: Vector2i, dead_only: bool = true) -> bool:
	var p := get_plot(cell)
	if _busy or p == null or p.crop_id == &"" or (dead_only and p.state != State.WITHERED):
		return false
	p.state = State.TILLED
	p.crop_id = &""
	p.growth_days = 0.0
	p.regrowing = false
	p.yield_amount = 0
	plot_changed.emit(cell)
	return true

## Waters up to max_n crops that are not watered yet (the partner's daily chore): crop_auto_watered(plot, &"partner"), never the player's event.
func water_unwatered(max_n: int) -> int:
	if _busy:return 0
	var changed: Array[Vector2i] = []
	for cell in plots:
		if changed.size() >= max_n:break
		if plots[cell].state in [State.PLANTED,State.WATERED] and not plots[cell].watered:
			_water(plots[cell],float(GameData.gm().hour))
			changed.append(cell)
	# The entire batch is visible before the first crop observer can save.
	for cell in changed:
		EconomyManager.after_transaction(func() -> void:
			EventBus.crop_auto_watered.emit(plot_id(cell), &"partner")
			plot_changed.emit(cell))
	return changed.size()

func _rain() -> bool:
	if indoor:
		return false
	var tm := GameData.tm()
	return tm.is_raining() or tm.weather == &"torden"

func _on_time_changed(hour: int, _minute: int) -> void:
	# New-day automation runs at logical 06:00, never at the transient 02:00 roll.
	if hour >= 6 and GameData.gm().total_day() == _last_day:
		_auto_water(float(hour))

func _on_weather_changed(_weather: StringName) -> void:
	# TimeManager rolls the NEW weather before day_started. Grow the old day first.
	if GameData.gm().total_day() == _last_day:
		_auto_water(maxf(6.0, float(GameData.gm().hour)))

## Rain (and thunder) waters every tilled plot, a watering supply its own plot (auto_water_days). Runs every game minute: the weather is asked ONCE
## per call and a dry day without a supplied plot leaves at once (GAP4-07).
func _auto_water(hour: float) -> void:
	var rain := _rain()
	if not rain and not _has_auto_water():
		return
	for cell in plots:
		var p: PlotData = plots[cell]
		if p.state == State.EMPTY or p.state == State.WITHERED:
			continue
		if (rain or p.auto_water_days > 0) and (not p.watered or not p.eligible_water and in_water_window(hour, p.crop_id)):
			_water(p, hour)
			_announce_water(cell, p, &"rain" if rain else &"supply")
			plot_changed.emit(cell)


func _has_auto_water() -> bool:
	for p in plots.values():
		if p.auto_water_days > 0:
			return true
	return false

func _on_day_started(_day: int, _season: StringName) -> void:
	var today: int = GameData.gm().total_day()
	if today <= _last_day:
		return
	_last_day = today
	for cell in plots:
		var p: PlotData = plots[cell]
		var was_ready: bool = p.state == State.READY
		if p.crop_id != &"" and not in_season(p.crop_id):
			p.state = State.WITHERED
			p.yield_amount = 0
			p.fertilizer = false
		elif p.state in [State.PLANTED, State.WATERED]:
			if p.eligible_water:
				p.growth_days += 1.0
			p.state = State.READY if p.growth_days >= _growth_needed(p) else State.PLANTED
		p.watered = false
		p.eligible_water = false
		if p.state == State.READY and not was_ready:
			EventBus.game_event.emit(&"crop_ready", {"plot_id": String(plot_id(cell)), "crop": String(p.crop_id)})
		p.auto_water_days = maxi(0, p.auto_water_days - 1)
		EventBus.crop_stage_changed.emit(plot_id(cell), p.state)
		plot_changed.emit(cell)
	_auto_water(6.0)

func to_dict() -> Dictionary:
	var out := {}
	for cell in plots:
		out["%d,%d" % [cell.x, cell.y]] = (plots[cell] as PlotData).to_dict()
	return {"plots": out}

## Reject malformed saves before touching the live model; older valid plots default new fields.
static func validate_dict(value: Variant) -> bool:
	var definitions := crop_definitions()
	if not value is Dictionary or not value.get("plots", {}) is Dictionary:
		return false
	for key in value.get("plots", {}):
		var parts := str(key).split(",")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			return false
		var row: Variant = value.plots[key]
		if not row is Dictionary:
			return false
		for field in ["state", "growth_days", "planted_day", "auto_water_days", "yield_amount"]:
			var n: Variant = row.get(field, 0)
			if not (n is int or n is float) or not is_finite(float(n)) or float(n) < 0 or float(n) > 2147483647.0 or (field != "growth_days" and float(n) != floorf(float(n))):
				return false
		for field in ["watered", "eligible_water", "fertilizer", "regrowing"]:
			if not row.get(field, false) is bool:
				return false
		var watered_hour: Variant = row.get("watered_hour", 6.0)
		if not (watered_hour is int or watered_hour is float) or not is_finite(float(watered_hour)) or float(watered_hour) < 0 or float(watered_hour) >= 26:
			return false
		if int(row.get("state", 0)) > State.WITHERED or not row.get("crop_id", "") is String:
			return false
		var crop := str(row.get("crop_id", ""))
		if crop != "" and not definitions.has(crop):
			return false
		if int(row.get("state", 0)) >= State.PLANTED and crop == "":
			return false
		if bool(row.get("regrowing", false)) and (crop == "" or int(definitions[crop].get("regrow_days", 0)) <= 0):
			return false
	return true

func validate_save(value: Variant) -> bool:
	return validate_dict(value)

func from_dict(value: Dictionary) -> bool:
	if not validate_save(value):
		return false
	configure_map(map)
	var dirty := plots.duplicate()
	var loaded := {}
	for key in value.get("plots", {}):
		var parts := str(key).split(",")
		var cell := Vector2i(int(parts[0]), int(parts[1]))
		if not can_till(cell, true):
			continue
		var row: Dictionary = value.plots[key]
		var p := PlotData.new()
		p.state = int(row.get("state", State.TILLED))
		p.crop_id = StringName(str(row.get("crop_id", "")))
		p.growth_days = float(row.get("growth_days", row.get("growth_stage", 0)))
		p.watered = bool(row.get("watered", false))
		p.watered_hour = float(row.get("watered_hour", GameData.gm().hour))
		p.eligible_water = bool(row.get("eligible_water", p.watered and in_water_window(float(GameData.gm().hour), p.crop_id)))
		p.planted_day = int(row.get("planted_day", 0))
		p.fertilizer = bool(row.get("fertilizer", false))
		p.auto_water_days = int(row.get("auto_water_days", 0))
		p.yield_amount = int(row.get("yield_amount", 0))
		p.regrowing = bool(row.get("regrowing", false))
		loaded[cell] = p
		dirty[cell] = p
	plots = loaded
	_last_day = GameData.gm().total_day()
	for cell in dirty:
		plot_changed.emit(cell)
	return true
