extends Node
## Global signal hub. Decouples systems so they never hard-reference each other.

# --- Player ---
signal player_spawned(player: Node3D)
signal player_character_changed(character_id: StringName)
signal player_inventory_changed(inventory: Dictionary)
signal player_stats_changed(stats: Dictionary)
signal player_moved(zone: StringName)

# --- Time / Day ---
signal day_started(day: int, season: StringName)
signal day_ended(day: int, season: StringName)
signal time_of_day_changed(hour: int, minute: int)
signal season_changed(season: StringName)

# --- Farm ---
signal crop_planted(plot_id: StringName, crop_id: StringName)
signal crop_watered(plot_id: StringName)
signal crop_harvested(plot_id: StringName, crop_id: StringName, amount: int)
signal crop_stage_changed(plot_id: StringName, stage: int)
signal farm_upgraded(farm_id: StringName, upgrade_id: StringName)
signal plot_unlocked(plot_id: StringName)

# --- Economy ---
signal gold_changed(amount: int, delta: int)
signal item_purchased(item_id: StringName, amount: int, cost: int)
signal item_sold(item_id: StringName, amount: int, revenue: int)
signal shop_opened(shop_id: StringName)
signal shop_closed(shop_id: StringName)

# --- Quests ---
signal quest_offered(quest_id: StringName)
signal quest_accepted(quest_id: StringName)
signal quest_objective_updated(quest_id: StringName, objective_id: StringName, progress: int, target: int)
signal quest_completed(quest_id: StringName)
signal quest_failed(quest_id: StringName)
signal dialogue_started(npc_id: StringName, dialogue_id: StringName)
signal dialogue_line_shown(speaker: String, text: String, voice_key: String)
signal dialogue_ended()

# --- World / Adventure ---
signal zone_entered(zone_id: StringName)
signal zone_exited(zone_id: StringName)
signal resource_node_hit(node_id: StringName, node_type: StringName, damage: int)
signal resource_node_depleted(node_id: StringName, loot: Array)
signal rare_item_found(item_id: StringName, rarity: StringName)
signal enemy_encountered(enemy_id: StringName)
signal combat_finished(victory: bool)

# --- UI ---
signal notification_posted(title: String, message: String, icon: String)
signal ui_panel_toggled(panel_name: StringName, is_open: bool)
signal save_completed(slot: int)
signal load_completed(slot: int)

# --- Lua bridge ---
signal lua_event(event_name: StringName, payload: Dictionary)


func emit_lua_event(event_name: StringName, payload: Dictionary = {}) -> void:
	lua_event.emit(event_name, payload)
