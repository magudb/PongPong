class_name SocialFixture
extends RefCounted
## Fixtures of the social sections (package S-core; later packages of the track reuse them): a fresh game with the world seed 777 on a chosen date and hour,
## date helpers, the stand-ins of the sibling services (FakeNpcDirector, FakeQuests) and FakeLua, a LuaRuntime proxy that serves another `citizens` /
## `gift_tastes` / `npcs` table or other registries (festivals, events) to everything that reaches the runtime through Svc, so a test can run the real
## SocialManager against the pinned DESIGN data (tests/lib/social/fixtures/design_dump.json) before the real data packages (S-data, S-fest-content) have landed.
##
##   var sm := SocialFixture.fresh(t, total_day, hour)         new game, reset, seed 777, date and clock set (no day_started is emitted: the clock is moved, not run)
##   var fake := SocialFixture.install_design_data()           citizens, tastes, festivals and events of the design dump behind Svc.node("LuaRuntime")
##   SocialFixture.uninstall()                                  Svc.clear_overrides() (always call it when a leg is done)
## Nothing here names a later package's class: the director and the quest manager are NODES a test injects with Svc.override.

const SEED := 777
const DESIGN_DUMP := "res://tests/lib/social/fixtures/design_dump.json"

static var _design: Dictionary = {}
static var _installed: Array[WeakRef] = []


## A clean new game for the social checks: Fresh.new_game + reset + world seed 777 on `total_day` at `hour`:`minute` (game clock, RAW hours).
static func fresh(t, total_day: int = 1, hour: int = 12, minute: int = 0) -> Node:
	Fresh.new_game(t)
	var sm := Svc.node("SocialManager")
	sm.set_seed(SEED)
	jump(total_day, hour, minute)
	sm.reset()
	sm.set_seed(SEED)
	return sm


## Moves the calendar and the clock without running the days (no signal): for the checks that need a date.
static func jump(total_day: int, hour: int = -1, minute: int = 0) -> void:
	Fresh.jump_to_total_day(total_day)
	var gm := Svc.node("GameManager")
	if hour >= 0:
		gm.hour = hour
		gm.minute = minute


static func sm() -> Node:
	return Svc.node("SocialManager")


## total_day of a date (year 1 unless given).
static func td(season: String, day: int, year: int = 1) -> int:
	return CalendarUtil.total_day(day, StringName(season), year)


## total_day (year 1) of an NPC's birthday as the data says it.
static func birthday_td(npc: String, year: int = 1) -> int:
	var b := SocialData.birthday_of(npc)
	return CalendarUtil.total_day(int(b["day"]), StringName(str(b["season"])), year)


## The pinned design data (parsed once).
static func design_dump() -> Dictionary:
	if _design.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESIGN_DUMP))
		_design = parsed as Dictionary if typeof(parsed) == TYPE_DICTIONARY else {}
	return _design


## Puts a FakeLua in front of the real LuaRuntime (for everything that reaches it through Svc) with the design `citizens`, `gift_tastes` and the registries
## `festivals` / `events`. Returns the fake so the test can change a table. Pair with uninstall().
static func install_design_data(extra_config: Dictionary = {}, extra_registries: Dictionary = {}) -> Node:
	var d := design_dump()
	var cfg := {"citizens": (d["citizens"] as Dictionary).duplicate(true), "gift_tastes": (d["gift_tastes"] as Dictionary).duplicate(true)}
	cfg.merge(extra_config, true)
	var regs := {"festivals": (d["festivals"] as Dictionary).duplicate(true), "events": (d["events"] as Dictionary).duplicate(true)}
	regs.merge(extra_registries, true)
	return install(cfg, regs)


## A FakeLua with exactly these overrides (top-level config keys and registries); everything else is the real runtime.
static func install(config_over: Dictionary, registries: Dictionary) -> Node:
	var fake := FakeLua.new()
	fake.name = "FakeLuaRuntime"
	fake.real = (Engine.get_main_loop() as SceneTree).root.get_node("LuaRuntime")
	fake.config_over = config_over
	fake.registries = registries
	Svc.override("LuaRuntime", fake)
	_installed.append(weakref(fake))
	return fake


## Removes ONE injected fake (a leg that uses the design data AND a fake director must not drop the FakeLua with Svc.clear_overrides()). Svc keeps its table private;
## this is the one place that reaches into it.
static func drop(autoload_name: String) -> void:
	Svc._overrides.erase(autoload_name)


static func uninstall() -> void:
	Svc.clear_overrides()
	# Replacing an override (or Fresh clearing it) does not free the old Node.
	for ref in _installed:
		var fake: Variant = ref.get_ref()
		if is_instance_valid(fake):
			fake.free()
	_installed.clear()


## total_day of the nth Sunday... helpers for week logic: the Monday of the week that holds `td`.
static func monday_of(total_day: int) -> int:
	return total_day - CalendarUtil.weekday_of(total_day)


# ================================================================================================ stand-ins

## A LuaRuntime proxy: the config keys in `config_over` (top level) and the registries in `registries` are served from the test's tables, everything else from
## the real runtime. It only offers the methods the social layer reaches through Svc.
class FakeLua extends Node:
	var real: Node
	var config_over: Dictionary = {}
	var registries: Dictionary = {}

	func get_config(path: String, default_value: Variant = null) -> Variant:
		var parts := path.split(".")
		if not config_over.has(parts[0]):
			return real.call("get_config", path, default_value)
		var cur: Variant = config_over[parts[0]]
		for i in range(1, parts.size()):
			if typeof(cur) == TYPE_DICTIONARY and (cur as Dictionary).has(parts[i]):
				cur = (cur as Dictionary)[parts[i]]
			else:
				return default_value
		return cur

	func get_registry(registry_name: String) -> Dictionary:
		if registries.has(registry_name):
			return registries[registry_name]
		return real.call("get_registry", registry_name)

	func get_registry_entry(registry_name: String, id: String) -> Dictionary:
		var d: Variant = get_registry(registry_name).get(id, {})
		return d if typeof(d) == TYPE_DICTIONARY else {}

	func get_item_def(item_id: String) -> Dictionary:
		return real.call("get_item_def", item_id)

	func get_all_item_ids() -> Array:
		return real.call("get_all_item_ids")

	func get_shops() -> Dictionary:
		return real.call("get_shops")

	func get_shop(shop_id: String) -> Dictionary:
		return real.call("get_shop", shop_id)

	func get_recipes(category: String = "") -> Dictionary:
		return real.call("get_recipes", category)

	func get_recipe(recipe_id: String) -> Dictionary:
		return real.call("get_recipe", recipe_id)

	func get_npcs() -> Dictionary:
		return LuaData.dict(get_config("npcs", {}))

	func get_npc(npc_id: String) -> Dictionary:
		var row: Dictionary = LuaData.dict(get_npcs().get(npc_id, {})).duplicate()
		if not row.is_empty():
			row["id"] = npc_id
		return row

	func get_dialogue(dialogue_id: String, context: Dictionary = {}) -> Dictionary:
		return real.call("get_dialogue", dialogue_id, context)


## The towns track's NpcDirector facade as a node: who is absent (hero twin), away and present. `answers` counts the calls (a test proves the late binding).
class FakeNpcDirector extends Node:
	var absent: Array = []
	var away: Array = []
	var present_all: bool = true
	var present: Array = []
	var calls: Array = []

	func is_absent(npc: String) -> bool:
		calls.append(["is_absent", npc])
		return npc in absent

	func is_away(npc: String) -> bool:
		calls.append(["is_away", npc])
		return npc in away

	func is_present(npc: String) -> bool:
		calls.append(["is_present", npc])
		return present_all or npc in present


## QuestManager's answers the social layer asks (is_completed, is_active, item_in_use).
class FakeQuests extends Node:
	var completed: Array = []
	var active: Array = []
	var in_use: Array = []

	func is_completed(quest_id: Variant) -> bool:
		return str(quest_id) in completed

	func get_completed_ids() -> Array:
		return completed.duplicate()

	func is_active(quest_id: Variant) -> bool:
		return str(quest_id) in active

	func item_in_use(item: String) -> bool:
		return item in in_use
