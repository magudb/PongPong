class_name ShopHours
extends Node
## Closing time inside a building (T-towns-core, TOWNS addendum 4.5): a child of every room whose building has opening hours (or an owner). Lifted from
## D3/final_editor/te1/drafts/shop_hours.gd and edited: the clock context is Hours.now_ctx(), the routines of a home owner are reached only through Hours.where_is (a path string),
## and the eviction WAITS for a running travel or sleep sequence.
##
##   30 game minutes before closing   whisper HOURS_CLOSING_SOON + game_event closing_warning {shop, minutes_left} (once per day)
##   at closing time                  the shop panel is asked to close (EventBus.ui_panel_toggled(&"shop", false): the TTScreen close request), then the whisper HOURS_CLOSED_BELL,
##                                    game_event shop_open_changed {shop, open: false, reason, opens_at, closes_at} and area_change_requested(outer area, from_int_<building>), in that order
## It WAITS (and retries on the next clock tick, `evicted` stays false) while another modal is open (a dialogue at 17:06 delays the bell until it ends), while WorldRoot2D.traveling or a
## sleep sequence runs (WorldRoot2D.travel() returns silently while it travels, so an eviction inside the 0.25 - 0.5 s fade of entering the room would be lost and the player would stand in
## a closed shop). A HOME evicts its guest when the owner goes to bed or leaves (no Routines = no eviction by owner). With the switch towns.hours_enabled off a shop never closes.
## Runs only while the room is in the tree (rooms are rebuilt on every visit).

var building_id: String = ""
var interior_id: String = ""
var exit_area: StringName = &""
var exit_spawn: StringName = &""
var whispered: bool = false
var evicted: bool = false
var whisper_minutes: int = 30
## What happened, for tests: "whisper HOURS_CLOSING_SOON", "evict closed" ...
var trace: Array[String] = []


func setup(building: String, interior: String, to_area: String, to_spawn: String) -> void:
	building_id = building
	interior_id = interior
	exit_area = StringName(to_area)
	exit_spawn = StringName(to_spawn)
	whisper_minutes = int(GameData.cfg("towns.closing_whisper_minutes", 30))
	name = "ShopHours"


func _enter_tree() -> void:
	if not EventBus.time_of_day_changed.is_connected(_on_clock):
		EventBus.time_of_day_changed.connect(_on_clock)
	if not EventBus.day_started.is_connected(_on_day):
		EventBus.day_started.connect(_on_day)


func _exit_tree() -> void:
	if EventBus.time_of_day_changed.is_connected(_on_clock):
		EventBus.time_of_day_changed.disconnect(_on_clock)
	if EventBus.day_started.is_connected(_on_day):
		EventBus.day_started.disconnect(_on_day)


func _on_day(_day: int, _season: StringName) -> void:
	whispered = false
	evicted = false


func _on_clock(_hour: int, _minute: int) -> void:
	check(Hours.now_ctx())


## Evaluates the rules for a context (public for tests; the clock tick calls it with the live context).
func check(ctx: Dictionary) -> void:
	var b: Dictionary = Hours.building(building_id)
	if b.is_empty() or evicted:
		return
	if b.has("hours"):
		if not Hours.enabled():
			return
		var st: Dictionary = Hours.state(building_id, ctx)
		var open: bool = bool(st["open"])
		var left: int = Hours.minutes_to_close(building_id, ctx)
		if open and left <= whisper_minutes and left > 0 and not whispered:
			whispered = true
			trace.append("whisper HOURS_CLOSING_SOON")
			EventBus.whisper_requested.emit("HOURS_CLOSING_SOON")
			EventBus.game_event.emit(&"closing_warning", {"shop": str(b.get("shop", building_id)), "minutes_left": left})
		if not open:
			_evict("closed", b, st)
	elif b.has("owner"):
		var w: Variant = Hours.where_is(str(b["owner"]), ctx)       # no Routines = no eviction by owner
		if w is Dictionary and (str((w as Dictionary).get("act", "")) == "sleep" or not str((w as Dictionary).get("place", "")).begins_with("int_%s" % building_id)):
			_evict("owner_left", b, {})


func _evict(why: String, b: Dictionary, st: Dictionary) -> void:
	var gm: Node = GameData.gm()
	if gm != null and bool(gm.call("is_modal_open", &"shop")):
		EventBus.ui_panel_toggled.emit(&"shop", false)           # TTScreen: ui_panel_toggled(modal_name, false) is the CLOSE REQUEST of a modal (UI_NAVIGATION 4.2)
	if gm != null and bool(gm.call("is_modal_open")) and not bool(gm.call("is_modal_open", &"shop")):
		return                                                   # a dialogue or the pause menu: try again on the next tick
	if is_inside_tree():
		var world: Node = get_tree().get_first_node_in_group("world_2d")        # WorldRoot2D, late bound (group)
		if world != null and (bool(world.get("traveling")) or bool(world.get("sleeping"))):
			return                                               # a travel or a sleep sequence runs (travel() would return silently): retry next tick, `evicted` stays false
	evicted = true
	trace.append("evict %s" % why)
	EventBus.whisper_requested.emit("HOURS_CLOSED_BELL")
	if why == "closed":
		EventBus.game_event.emit(&"shop_open_changed", {"shop": str(b.get("shop", building_id)), "open": false, "reason": str(st.get("reason", "hours")),
				"opens_at": float(st.get("opens_at", 0.0)), "closes_at": float(st.get("closes_at", 0.0))})
	EventBus.area_change_requested.emit(exit_area, exit_spawn)
