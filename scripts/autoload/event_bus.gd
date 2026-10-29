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
