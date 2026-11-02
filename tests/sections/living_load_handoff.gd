extends RefCounted
## D09 discriminator: the real model-only load revokes the old physical World;
## the caller's public SceneTree handoff consumes pending data without a reset.
const SECTION := "living_load_handoff"
const TIMEOUT_S := 180.0

func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var saves: Node = t.autoload("SaveManager")
	var sm: Node = t.autoload("SocialManager")
	var eco: Node = t.autoload("EconomyManager")
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	saves.autosave_enabled = false
	saves.save_dir = "user://living-load-handoff"
	var old: Node = t.world()
	var old_id: int = old.get_instance_id()
	var old_profile: Variant = PlayerRegistry._states.get(&"p0")
	for slot in [1, 2]:
		var body := PlayerStub2D.new()
		old._register_player(body, slot, slot + 1)
		old.add_child(body)
		PlayerRegistry.for_player(body.player_id, func(): eco.add_item(&"iron_ore", 7 if slot == 1 else 11))
	t.check("LCH_real_file_positive", saves.save_game(0))
	var primary := FileAccess.get_sha256(saves.slot_path(0))
	t.check("LCH_real_model_only_load", saves.load_game(0))
	t.check("LCH_admission_released_social_valid_model_replaced", not gm.lifecycle_busy() and sm.to_dict() is Dictionary and PlayerRegistry._states.get(&"p0") != old_profile and old._host_profile == old_profile)
	t.check("LCH_obsolete_world_refuses_save_without_touching_disk", not old.persistence_ready() and not saves.save_game(0) and saves.last_error.get("code") == "gather" and saves.last_error.get("detail") == "to_dict() failed for world" and FileAccess.get_sha256(saves.slot_path(0)) == primary and not FileAccess.file_exists(saves.backup_path(0)))
	var area: Variant = old.area
	var day: int = gm.total_day()
	await old.travel(&"hyggebyen", &"default")
	gm.set_clock(18, 0)
	await old.sleep()
	t.check("LCH_obsolete_world_cannot_travel_or_sleep", old.area == area and gm.total_day() == day and not old.traveling and not old.sleeping)
	var rows: Dictionary = PlayerRegistry._states.duplicate()
	var living: Dictionary = sm.living_snapshot()
	var pending: Dictionary = saves.pending_world.duplicate(true)
	t.check("LCH_real_pending_scene_change", await t.change_scene(t.WORLD_SCENE))
	await t.until(func(): return t.world() != null and t.world().get_instance_id() != old_id and t.world().ready_for_play and not gm.lifecycle_busy(), 15.0)
	var fresh: Node = t.world()
	t.check("LCH_fresh_world_consumes_pending_once", fresh.get_instance_id() != old_id and fresh.persistence_ready() and saves.pending_world.is_empty() and saves.consume_pending_world().is_empty() and str(fresh.area.map.id) == pending.area)
	t.check("LCH_same_loaded_independent_profiles_not_reset", PlayerRegistry._states.size() == rows.size() and rows.keys().all(func(pid): return PlayerRegistry._states.get(pid) == rows[pid]) and rows[&"p0"] != rows[&"p1"] and rows[&"p1"] != rows[&"p2"] and sm.living_snapshot() == living)
	for pid in [&"p1", &"p2"]:
		t.check("LCH_loaded_stock_" + str(pid), PlayerRegistry.for_player(pid, func(): return eco.count_item(&"iron_ore")) == (7 if pid == &"p1" else 11))
	t.check("LCH_coherent_new_world_real_save", saves.save_game(1))
	await fresh.travel(&"hyggebyen", &"default")
	t.check("LCH_coherent_new_world_later_physical_progress", fresh.area.map.id == &"hyggebyen" and not fresh.traveling and fresh.persistence_ready())
	gm.clear_config_overrides()
	# The shared delivery fixture must hand a coherent loaded World back to
	# its original physical-activity and save/rollback consumers.
	await load("res://tests/progression/living_delivery.gd").run(t)
	t.check("LCH_original_delivery_returns_coherent_loaded_world", t.world().persistence_ready() and saves.pending_world.is_empty() and sm.living_context("smith_thorin", &"p1").get("memories", []).size() == 1)
	await t.world().travel(&"hyggebyen", &"default")
	t.check("LCH_original_delivery_later_physical_progress", t.world().area.map.id == &"hyggebyen" and not t.world().traveling)
