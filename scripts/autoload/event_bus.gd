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
## Authored Mother evidence/work projection retains its producer origin.
## Public game_event remains an unchanged notification, never a new permit.
signal mother_progressed(origin: Dictionary)
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
	# Variant lifetime checks must precede registered_id's typed Node boundary.
	if not interaction_current(origin) or not is_instance_valid(actor) or not is_instance_valid(body) or not body is Node or not origin.get("physical") is Dictionary: return false
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
## A terminal producer captures before its first callback. Optional bodies do
## not own an earned model kill; world/session/area and exact profiles still do.
func combat_origin(attacker: Variant = null) -> Dictionary:
	if attacker == null: return interaction_origin(&"p0")
	if not is_instance_valid(attacker) or not attacker is Node: return {}
	var id := PlayerRegistry.registered_id(attacker)
	return interaction_origin(id) if id != &"" else {}

func combat_receipt(origin: Dictionary, enemy: Variant = null) -> Dictionary:
	if not interaction_current(origin): return {}
	var world := PlayerRegistry.world()
	var area: Node = world.get("area") if world != null else null
	var session: Node = world.get("session") if world != null else null
	var floors := DungeonFloors.inst()
	var watch: Node = world.get_node_or_null("RunWatch") if world != null else null
	var bodies: Array = []
	for body in PlayerRegistry.all_players():
		var id := PlayerRegistry.registered_id(body)
		if id == &"": continue
		var attached := interaction_origin(id, body, body)
		if interaction_body_current(attached, body, body):
			bodies.append({"body": weakref(body), "origin": attached, "profile": PlayerRegistry.peek_state(id)})
	var receipt := {"origin": origin,
		"anchor_profile": PlayerRegistry.peek_state(&"p0"),
		"profile": PlayerRegistry.peek_state(origin.recipient.player_id),
		"world": weakref(world) if world != null else null,
		"area": weakref(area) if area != null else null,
		"session": weakref(session) if session != null else null,
		"epoch": session.generation if session != null else 0,
		"bodies": bodies,
		"quest": QuestManager.combat_receipt(origin),
		"floors": weakref(floors) if floors != null else null,
		"floor": floors.defeat_receipt(enemy) if floors != null else {},
		"watch": weakref(watch) if watch != null and watch.active else null,
		"watch_run": watch.run_identity if watch != null else null}
	receipt.make_read_only()
	return receipt

## Contact admission inherits every original profile/body/run observation.
## Only the target's marker is selected now; no new model origin is minted.
func combat_target_receipt(parent: Dictionary, enemy: Variant, current: Callable) -> Dictionary:
	if not combat_current(parent) or not current.is_valid() or not current.call(): return {}
	var result := parent.duplicate()
	var floors: Variant = parent.floors.get_ref() if parent.floors != null else null
	result["floor"] = floors.defeat_receipt(enemy) if is_instance_valid(floors) else {}
	result["attack_current"] = current
	result.make_read_only()
	return result

func combat_current(receipt: Dictionary) -> bool:
	if receipt.is_empty() or not interaction_current(receipt.get("origin", {})): return false
	var world: Variant = receipt.world.get_ref() if receipt.world != null else null
	if receipt.world != null and (not is_instance_valid(world) or not world.is_inside_tree() or world.is_queued_for_deletion()): return false
	if PlayerRegistry.world() != world: return false
	var area: Variant = receipt.area.get_ref() if receipt.area != null else null
	if receipt.area != null and (not is_instance_valid(area) or not area.is_inside_tree() or area.is_queued_for_deletion()): return false
	if world != null and world.get("area") != area: return false
	var session: Variant = receipt.session.get_ref() if receipt.session != null else null
	if world != null and world.get("session") != session: return false
	return receipt.session == null or (is_instance_valid(session) and session.generation == receipt.epoch)

## Public once and first; raw notifications cannot mint a new model operation.
func publish_enemy_defeated_owned(receipt: Dictionary, id: StringName, kind: StringName, loot: Array) -> bool:
	enemy_defeated.emit(id, kind, loot)
	if not combat_current(receipt): return false
	QuestManager.enemy_defeated_owned(receipt.quest, id, kind)
	if not combat_current(receipt): return false
	var floors: Variant = receipt.floors.get_ref() if receipt.floors != null else null
	if is_instance_valid(floors): floors.enemy_defeated_owned(receipt, kind)
	if not combat_current(receipt): return false
	var watch: Variant = receipt.watch.get_ref() if receipt.watch != null else null
	if is_instance_valid(watch): watch.enemy_defeated_owned(receipt)
	return combat_current(receipt)

func publish_combat_event_owned(receipt: Dictionary, name: StringName, payload: Dictionary) -> bool:
	if name not in [&"dungeon_boss_defeated", &"skovhjerte_grown"] or not combat_current(receipt): return false
	game_event.emit(name, payload)
	if not combat_current(receipt): return false
	QuestManager.combat_event_owned(receipt.quest, name, payload)
	if not combat_current(receipt): return false
	if name == &"skovhjerte_grown":
		for body_receipt in receipt.bodies:
			if not combat_current(receipt): return false
			var body: Variant = body_receipt.body.get_ref()
			if is_instance_valid(body) and body.has_method("refresh_stats_owned"):
				body.refresh_stats_owned(receipt, body_receipt.origin)
	elif name == &"dungeon_boss_defeated":
		mother_progressed.emit(receipt.origin)
	return combat_current(receipt)

## Genuine independent model producers, including intentional tools/fixtures.
## Already-owned callers must use the retained receipt overloads above.
func defeat_enemy(id: StringName, kind: StringName, loot: Array = []) -> bool:
	var receipt := combat_receipt(interaction_origin())
	return publish_enemy_defeated_owned(receipt, id, kind, loot) if combat_current(receipt) else false

func combat_event(name: StringName, payload: Dictionary) -> bool:
	return publish_combat_event_owned(combat_receipt(interaction_origin()), name, payload)

## Capture model and optional physical recipient before the producer's callbacks.
## Raw dungeon_surprise is notification-only, like the other owned fanouts.
func dungeon_surprise_receipt(origin: Dictionary) -> Dictionary:
	if not interaction_current(origin): return {}
	var world := PlayerRegistry.world()
	var watch: Node = world.get_node_or_null("RunWatch") if world != null else null
	var body: Variant = DungeonRulesData.player()
	var physical := {}
	var combat := {}
	if is_instance_valid(body) and PlayerRegistry.registered_id(body) != &"":
		physical = interaction_origin(PlayerRegistry.registered_id(body),body,body)
		combat = combat_receipt(physical)
	return {"origin":origin,"watch":weakref(watch) if watch != null else null,"world":weakref(world) if world != null else null,"body":weakref(body) if is_instance_valid(body) else null,"physical":physical,"combat":combat}

func publish_dungeon_surprise(receipt: Dictionary, payload: Dictionary) -> bool:
	if receipt.is_empty() or not interaction_current(receipt.origin): return false
	game_event.emit(&"dungeon_surprise",payload)
	if not interaction_current(receipt.origin): return false
	var watch: Variant = receipt.watch.get_ref() if receipt.watch != null else null
	var world: Variant = receipt.world.get_ref() if receipt.world != null else null
	if is_instance_valid(watch) and is_instance_valid(world) and watch.is_inside_tree() and not watch.is_queued_for_deletion() and watch.get_parent()==world and world.get_node_or_null("RunWatch")==watch:
		watch.surprise_owned(receipt,payload)
	return interaction_current(receipt.origin)

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

## Narrow intentional mail migration: unchanged public payload/arity, public
## observers first, then the original earned recipient. Raw emits only notify.
func publish_post_read(origin: Dictionary, payload: Dictionary, receipt: Dictionary = {}) -> bool:
	if not interaction_current(origin): return false
	if receipt.is_empty(): receipt = QuestManager.post_read_receipt(origin)
	game_event.emit(&"post_read", payload)
	if interaction_current(origin): QuestManager.apply_post_read_receipt(receipt, payload)
	return interaction_current(origin)


func emit_lua_event(event_name: StringName, payload: Dictionary = {}) -> void:
	lua_event.emit(event_name, payload)
