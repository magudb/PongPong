extends Node
## Global signal hub. Decouples systems so they never hard-reference each other.
##
## Contract: PLAN 3.5 (+ R.13) and the feature addendum 3.1. Every `connect` / `emit` anywhere in the project must use a
## declared signal with matching arity; tests/sections/core.gd (core.signal_arity_lint) lints both the declarations
## below (name, argument names and types) and every EventBus use in scripts/ and scenes/.
## Adding a signal is a contract change: it is made here (P02's file) at a wave boundary, never by another package.
## Anything nobody foresaw goes through game_event() below; consumers must ignore names they do not know.

# --- Player ---
signal player_spawned(player: Node2D)
## MP1: a body left the registry. Unused by single-player paths (nothing despawns the one hero).
signal player_despawned(player_id: StringName)
## MP3: a guest joined / left a session. Unused until MP4 lands.
signal player_joined(player_id: StringName, peer_id: int, profile: Dictionary)
signal player_left(player_id: StringName, reason: StringName)
## MP4: idle | hosting | joining | connected | ended
signal net_session_changed(state: StringName)
## MP3: player-scoped signals carry the save id of the hero they belong to (`p0`..`p3`).
signal player_character_changed(player_id: StringName, character_id: StringName)
signal player_inventory_changed(player_id: StringName, inventory: Dictionary)
signal player_stats_changed(player_id: StringName, stats: Dictionary)
signal player_moved(player_id: StringName, zone: StringName)
signal player_health_changed(player_id: StringName, half_hearts: int, max_half_hearts: int)
signal player_oil_changed(player_id: StringName, seconds: float, max_seconds: float)
signal player_defeated(player_id: StringName)
signal hotbar_changed(player_id: StringName, entries: Array, selected: int)
signal hotbar_assign_requested(player_id: StringName, slot: int, item_id: StringName)
signal interaction_prompt_changed(player_id: StringName, text: String)

# --- Time / Day / Weather ---
signal day_started(day: int, season: StringName)
signal day_ended(day: int, season: StringName)
# hour is the RAW game hour 2..25 (6..25 in normal play): 24 and 25 are 00:xx and 01:xx of the SAME game day (the day runs to 02:00);
# show it with TTFormat.clock() / GameManager.clock_hour_of_day(), compare it raw (night = hour >= 20 or hour < 5 holds for 24 and 25 too).
signal time_of_day_changed(hour: int, minute: int)
signal season_changed(season: StringName)
signal weather_changed(weather: StringName)

# --- Run lifecycle ---
signal new_game_started()
## Internal mutating fanout. The public no-argument notification remains usable
## by legacy emitters/observers; each synchronous emission owns its own origin.
signal reset_wave_started(origin: Dictionary)

func _ready() -> void:
	new_game_started.connect(_reset_wave)

func _reset_wave() -> void:
	reset_wave_started.emit(reset_origin())

## No ambient token: callers retain this exact origin through their callees.
func reset_origin() -> Dictionary:
	return {"stamp": SaveManager._save_owner_stamp(), "profile": PlayerRegistry.peek_state(&"p0")}

func reset_current(origin: Dictionary) -> bool:
	return NetAuthority.can_write() and origin.get("profile") == PlayerRegistry.peek_state(&"p0") and origin.get("stamp") == SaveManager._save_owner_stamp()

signal modal_changed(stack: Array)

# --- Farm ---
signal crop_planted(plot_id: StringName, crop_id: StringName)
signal crop_watered(plot_id: StringName)                 # the PLAYER watered (the can): quests and tutorial hints count it
signal crop_auto_watered(plot_id: StringName, source: StringName)   # a crop watered without the player: rain, sprinkler, supply, partner
signal crop_harvested(plot_id: StringName, crop_id: StringName, amount: int)
signal crop_stage_changed(plot_id: StringName, stage: int)
signal plot_unlocked(plot_id: StringName)
signal building_built(building_id: StringName, building_type: StringName)
signal animal_adopted(animal_id: StringName, species: StringName)
signal animal_fed(animal_id: StringName, food_id: StringName)
signal animal_product_collected(animal_id: StringName, product_id: StringName, amount: int)

# --- Economy ---
signal gold_changed(player_id: StringName, amount: int, delta: int)
signal item_gained(player_id: StringName, item_id: StringName, amount: int)
signal item_purchased(player_id: StringName, item_id: StringName, amount: int, cost: int)
signal item_sold(player_id: StringName, item_id: StringName, amount: int, revenue: int)
signal recipe_crafted(recipe_id: StringName, amount: int)
signal shop_opened(shop_id: StringName)
signal shop_closed(shop_id: StringName)

# --- Quests / dialogue ---
signal quest_offered(player_id: StringName, quest_id: StringName)
signal quest_accepted(player_id: StringName, quest_id: StringName)
signal quest_objective_updated(player_id: StringName, quest_id: StringName, objective_id: StringName, progress: int, target: int)
signal quest_completed(player_id: StringName, quest_id: StringName)
signal quest_failed(player_id: StringName, quest_id: StringName)
signal dialogue_started(npc_id: StringName, dialogue_id: StringName)
## Physical dialogue ownership, not the portrait borrowed by a service/offer.
## The consumer derives identity from the live talking actor, never an NPC id supplied by a service.
signal npc_meeting_started(actor: Node)
signal dialogue_line_shown(speaker: String, text: String, voice_key: String)
signal dialogue_ended()
## Raw dialogue signals above are notification-only. Public observers all run
## first; explicit producers retain one origin across every phase and await.
signal interaction_started(origin: Dictionary, npc_id: StringName, dialogue_id: StringName, attachment: RefCounted)
signal interaction_meeting(origin: Dictionary, actor: Variant, attachment: RefCounted)
signal interaction_ended(origin: Dictionary, attachment: RefCounted)

func _interaction_observation(id: StringName) -> Dictionary:
	var profile := PlayerRegistry.peek_state(id)
	var world := PlayerRegistry.world()
	var session: Node = world.get("session") if world != null else null
	return OperationOrigin.snapshot(id, profile, SaveManager._save_owner_stamp(), StringName(session.role) if session != null else &"offline", NetAuthority.can_write(), SaveManager.continuation_available(profile))

## Genuine root only. Internal continuations must carry the returned context.
## p0 is the world anchor even when a different registered hero is the recipient.
func interaction_origin(id: StringName = &"", actor: Variant = null, body: Variant = null) -> Dictionary:
	if id == &"": id = PlayerRegistry.acting_id()
	var anchor := OperationOrigin.capture(_interaction_observation(&"p0"))
	var recipient := OperationOrigin.capture(_interaction_observation(id))
	if anchor.is_empty() or recipient.is_empty(): return {}
	var physical := {}
	var world := PlayerRegistry.world()
	if actor != null and is_instance_valid(body):
		physical = OperationOrigin.capture_physical(OperationOrigin.physical_snapshot(id, body, actor, world, world.get("session") if world != null else null, PlayerRegistry.registered_id(body), PlayerRegistry.by_id(id)))
	var origin := {"anchor": anchor, "recipient": recipient, "physical": physical}
	origin.make_read_only()
	return origin

func interaction_current(origin: Dictionary) -> bool:
	return origin.get("anchor") is Dictionary and origin.get("recipient") is Dictionary and OperationOrigin.is_current(origin.anchor, _interaction_observation(&"p0")) and OperationOrigin.is_current(origin.recipient, _interaction_observation(origin.recipient.get("player_id", &"")))

func interaction_attach(origin: Dictionary, actor: Variant, body: Variant) -> Dictionary:
	if not interaction_current(origin): return {}
	var id: StringName = origin.recipient.player_id
	var world := PlayerRegistry.world()
	var physical := OperationOrigin.capture_physical(OperationOrigin.physical_snapshot(id, body, actor, world, world.get("session") if world != null else null, PlayerRegistry.registered_id(body), PlayerRegistry.by_id(id)))
	if physical.is_empty(): return {}
	var attached := {"anchor": origin.anchor, "recipient": origin.recipient, "physical": physical}
	attached.make_read_only()
	return attached

func interaction_body_current(origin: Dictionary, actor: Variant, body: Variant) -> bool:
	if not interaction_current(origin) or not is_instance_valid(actor) or not origin.get("physical") is Dictionary: return false
	var id := PlayerRegistry.registered_id(body)
	if id == &"" or id != origin.recipient.player_id: return false
	var world := PlayerRegistry.world()
	return OperationOrigin.is_physical_current(origin.physical, OperationOrigin.physical_snapshot(id, body, actor, world, world.get("session") if world != null else null, id, PlayerRegistry.by_id(id)))

func interaction_physical_current(origin: Dictionary, actor: Variant) -> bool:
	return is_instance_valid(actor) and actor is Npc2D and actor.is_talking and interaction_body_current(origin, actor, actor._talk_player)

func publish_dialogue_started(origin: Dictionary, npc_id: StringName, dialogue_id: StringName, attachment: RefCounted) -> bool:
	if not interaction_current(origin) or attachment == null: return false
	dialogue_started.emit(npc_id, dialogue_id)
	if interaction_current(origin): interaction_started.emit(origin, npc_id, dialogue_id, attachment)
	return interaction_current(origin)

func publish_npc_meeting(origin: Dictionary, actor: Variant, attachment: RefCounted) -> bool:
	if not interaction_physical_current(origin, actor) or attachment == null: return false
	npc_meeting_started.emit(actor)
	if interaction_physical_current(origin, actor): interaction_meeting.emit(origin, actor, attachment)
	return interaction_physical_current(origin, actor)

## Terminal notification is owed even for a revoked origin; only labelled model
## effects may authorize anything, paired with the exact original attachment.
func publish_dialogue_ended(origin: Dictionary, attachment: RefCounted) -> bool:
	dialogue_ended.emit()
	if attachment != null and interaction_current(origin): interaction_ended.emit(origin, attachment)
	return interaction_current(origin)

## Explicit root adapters for independent requests/tools. Never use these to
## resume an old interaction. The start receipt must be retained for its end.
func start_dialogue(npc_id: StringName, dialogue_id: StringName) -> Dictionary:
	var origin := interaction_origin()
	var attachment := RefCounted.new()
	publish_dialogue_started(origin, npc_id, dialogue_id, attachment)
	return {"origin": origin, "attachment": attachment}

func end_dialogue(receipt: Dictionary) -> void:
	publish_dialogue_ended(receipt.get("origin", {}), receipt.get("attachment"))

func start_npc_meeting(actor: Variant) -> bool:
	if not is_instance_valid(actor) or not actor is Npc2D or not actor.is_talking: return false
	var id := PlayerRegistry.registered_id(actor._talk_player)
	if id == &"": return false
	var origin := interaction_origin(id, actor, actor._talk_player)
	return publish_npc_meeting(origin, actor, RefCounted.new())

# --- World / Adventure ---
## zone_entered / zone_exited are emitted ONLY by WorldRoot2D (the player entered an area or one of its zones);
## GameManager.unlock_zone() emits zone_unlocked and never zone_entered.
signal zone_entered(zone_id: StringName)
signal zone_exited(zone_id: StringName)
signal zone_unlocked(zone_id: StringName)
signal area_change_requested(area_id: StringName, spawn_name: StringName)
signal area_changed(area_id: StringName)
signal resource_node_hit(node_id: StringName, node_type: StringName, damage: int)
signal resource_node_depleted(node_id: StringName, loot: Array)
signal rare_item_found(item_id: StringName, rarity: StringName)
signal enemy_encountered(enemy_id: StringName)
signal enemy_defeated(enemy_id: StringName, kind: StringName, loot: Array)
signal combat_finished(victory: bool)
signal boss_bar_changed(name_key: String, ratio: float, visible: bool)
signal whisper_requested(text_key: String)
## A world flag changed (GameManager.set_flag / clear_flag / load). `value` is the new flag value, `false` on clear.
signal flag_changed(flag: StringName, value: Variant)

# --- UI ---
signal notification_posted(title: String, message: String, icon: String)
## An open/close REQUEST that the owning panel acts on (it is not a state report; GameManager.modal_changed is).
signal ui_panel_toggled(panel_name: StringName, is_open: bool)
signal save_completed(slot: int)
## A save could not be written (SaveManager.last_error carries the detail). code: write | gather.
signal save_failed(slot: int, code: String)
signal load_completed(slot: int)

# --- Feature addendum 3.1: home, hygge, furniture, wardrobe, loot, friends ---
signal home_upgrade_started(from_tier: int, to_tier: int, ready_total_day: int)
signal home_upgrade_progress(days_left: int, total_days: int)
signal home_upgraded(old_tier: int, new_tier: int)
signal hygge_changed(score: int, level: StringName)
## reason: stock | placed | removed | tier | load
signal furniture_changed(reason: StringName)
signal furniture_placed(item_id: StringName, uid: int)
signal furniture_picked_up(item_id: StringName, uid: int)
signal decorate_mode_changed(active: bool)
## equipped: slot (String) -> item id (String)
signal outfit_changed(player_id: StringName, equipped: Dictionary)
signal garment_equipped(player_id: StringName, item_id: StringName, slot: StringName)
## results: [{id, amount, rarity, kind}]
signal loot_rolled(source_id: StringName, results: Array)
signal visitor_gift(npc_id: StringName, item_id: StringName)
signal friend_changed(player_id: StringName, npc_id: StringName, hearts: int)
## Emitted by CollectionLog only when the optional Samlerbog ships.
signal item_discovered(item_id: StringName, rarity: StringName, category: StringName)

# --- Lua bridge and generic escape hatch ---
signal lua_event(event_name: StringName, payload: Dictionary)
## LuaRuntime re-read every Lua file (F9 in a debug build, reload_scripts() from tools and tests; also once at boot, before
## the later autoloads exist): whoever copied Lua data re-reads or drops it.
signal lua_reloaded()
## For signals nobody foresaw (R.13). Quest bindings of the feature content use it with these names, emitted by the
## owner next to the dedicated signal: furniture_placed {item, rarity}, hygge_level {level}, festival_held {},
## home_upgraded {tier}, garment_equipped {slot, item, rarity}, open_home_builder {tier}, open_home_chest {}.
## GameManager.advance_time() emits midnight_passed {day, season} for every day-end roll the clock crosses (the pass-out trigger; the id is kept from the
## days that ended at 24:00, the roll is now at game hour 26 = 02:00; real midnight, raw hour 24, emits nothing; a hook for a true midnight needs a NEW name).
## Consumers must ignore names they do not know.
signal game_event(name: StringName, payload: Dictionary)


func emit_lua_event(event_name: StringName, payload: Dictionary = {}) -> void:
	lua_event.emit(event_name, payload)
