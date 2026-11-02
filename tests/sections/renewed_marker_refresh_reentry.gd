extends RefCounted
const SECTION := "renewed_marker_refresh_reentry"
const TIMEOUT_S := 180.0
const ROLLBACK := preload("res://tests/sections/persistence_rollback.gd")

func run(t) -> void:
	for mode in ["success", "complete", "partial", "nested"]:
		await _pictures(t, mode)

func _pictures(t, mode: String) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var qm: Node = t.autoload("QuestManager")
	var sm: Node = t.autoload("SaveManager")
	var eco: Node = t.autoload("EconomyManager")
	sm.autosave_enabled = false
	gm.set_config_override("time.minutes_per_real_second", 0.0)
	gm.clear_flag(&"intro_pending")
	t.check(mode+"_actual_garden_admission", qm.accept_quest(&"secret_garden"))
	# Canonical real section codecs are prerequisites for complete rollback,
	# kept separate from the genuinely sparse uninitialised-p1 controls.
	eco.from_dict(eco.to_dict())
	t.autoload("LootService").from_dict(t.autoload("LootService").to_dict())
	var late: Node
	if mode in ["complete", "partial"]:
		late = ROLLBACK.Reject.new()
		t.root.add_child(late)
		sm.register_section("renewed_refresh_late", late, 999)
		late.restore_bad = mode == "partial"
	var payload: Dictionary = sm.gather_payload()
	if late != null: payload.renewed_refresh_late.reject = true
	var profile: PlayerState = PlayerRegistry._states[&"p0"]
	var incarnation: RefCounted = t.autoload("SocialManager")._accounting_world
	var marker := SecretGardenMarker.new()
	marker.kind = "beds"
	marker.cell = Vector2i(3, 3)
	marker.area = t.world().area
	var observations: Array = []
	var fired := [false]
	var entered := func(child: Node):
		if fired[0] or not child is Sprite2D: return
		fired[0] = true
		if mode == "nested":
			# An independent same-model refresh owns the partially painted set.
			for i in 5: qm.complete_manual(&"secret_garden", StringName(SecretGardenStory.STEPS[i].id))
			observations.append(true)
		else:
			var result: Dictionary = sm._apply_payload(payload)
			observations.append(result.ok)
			observations.append(PlayerRegistry._states[&"p0"] == profile)
			observations.append(t.autoload("SocialManager")._accounting_world == incarnation)
			if mode == "success":
				observations.append(SecretGardenStory.step() == 0)
				# The equal-valued replacement earns its own genuine current work.
				for i in 5: qm.complete_manual(&"secret_garden", StringName(SecretGardenStory.STEPS[i].id))
				observations.append(marker._look == "crop_moonflower_0:6" and marker._pictures.size() == 6)
	marker.area.objects.child_entered_tree.connect(entered)
	t.check(mode+"_sparse_before_actual_ready_producer", PlayerRegistry._states.size() == 1 and not PlayerRegistry._states.has(&"p1"))
	marker.area.objects.add_child(marker)
	marker.area.objects.child_entered_tree.disconnect(entered)
	t.check(mode+"_actual_inner_child_callback_executed", fired[0])
	if mode == "success":
		t.check(mode+"_same_valued_success_replaced_identity_then_new_root_progressed", observations == [true, false, false, true, true])
	elif mode == "complete":
		t.check(mode+"_genuine_failed_apply_restored_exact_identity_and_incarnation", observations == [false, true, true])
	elif mode == "partial":
		t.check(mode+"_incomplete_rollback_did_not_restore_authority", observations == [false, false, false])
	else:
		t.check(mode+"_same_model_current_root_executed", observations == [true] and PlayerRegistry._states[&"p0"] == profile)
	if mode in ["success", "nested"]:
		var texture: Texture2D = ArtCatalog.prop(&"crop_moonflower_0").texture
		t.check(mode+"_older_stack_does_not_append_or_clobber_fresh_pictures", marker._look == "crop_moonflower_0:6" and marker._pictures.size() == 6 and marker._pictures.all(func(p): return p.texture == texture and not p.is_queued_for_deletion()))
	elif mode == "complete":
		t.check(mode+"_legitimate_old_painting_continues_after_full_rollback", marker._look == "bush_farm:6" and marker._pictures.size() == 6)
	else:
		t.check(mode+"_obsolete_stack_retired_before_finishing_paint", marker._look != "bush_farm:6" and marker._pictures.size() <= 1)
		marker.refresh()
		t.check(mode+"_independent_current_refresh_can_repair_partial_paint", marker._look == "bush_farm:6" and marker._pictures.size() == 6)
	await t.frames(3)
	t.check(mode+"_no_unrelated_profile_or_caller_leak", PlayerRegistry._states.size() == 1 and not PlayerRegistry._states.has(&"p1") and PlayerRegistry._acting_id == &"")
	t.check(mode+"_all_pictures_live_and_tracked", marker._pictures.size() == 6 and marker._pictures.all(func(p): return is_instance_valid(p) and p.is_inside_tree() and not p.is_queued_for_deletion()))
	if late != null:
		sm.unregister_section("renewed_refresh_late")
		late.free()
	marker.free()
	gm.clear_config_overrides()
