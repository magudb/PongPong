extends RefCounted
const SECTION := "lifecycle_apply_admission"
const TIMEOUT_S := 90.0
class Probe extends Node:
	var snapshot_hook: Callable
	var apply_hook: Callable
	var data := {"v": 1, "n": 0}
	var snapshots := 0
	var applications := 0
	func to_dict() -> Dictionary:
		snapshots += 1
		if snapshot_hook.is_valid(): snapshot_hook.call()
		return data.duplicate(true)
	func from_dict(d: Dictionary) -> bool:
		applications += 1
		if apply_hook.is_valid(): apply_hook.call()
		data = d.duplicate(true)
		return true
	func reset() -> void: data = {"v": 1, "n": 0}
func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	var saves: Node = t.autoload("SaveManager")
	saves.autosave_enabled = false
	var p := Probe.new()
	t.root.add_child(p)
	saves.register_section("admission_probe", p, 990)
	var payload: Dictionary = saves.gather_payload()
	var seen: Array = []
	p.snapshot_hook = func():
		if not seen.is_empty(): return
		seen.append({})
		seen[0] = saves._apply_payload(payload)
	var outer: Dictionary = saves._apply_payload(payload)
	p.snapshot_hook = Callable()
	t.check("snapshot_naked_apply_cannot_adopt_ambient_root", seen.size() == 1 and seen[0].get("code") == "busy" and not seen[0].ok, str(seen))
	t.check("direct_apply_idle_still_succeeds", outer.ok and not saves._applying)
	var denied: Dictionary = saves._apply_payload_owned(payload, RefCounted.new()) if saves.has_method("_apply_payload_owned") else {"ok": true}
	t.check("explicit_invalid_participant_never_acquires_root", not denied.ok and denied.get("code") == "authority" and not gm.lifecycle_busy(), str(denied))
	var captures: Array = []
	p.apply_hook = func():
		captures.append(saves._apply_payload(payload))
	outer = saves._apply_payload(payload)
	p.apply_hook = Callable()
	t.check("section_apply_recursive_naked_call_busy", outer.ok and captures.size() == 1 and captures[0].get("code") == "busy")
	# Root ownership/stage seams are deliberately internal, never public token discovery.
	var token: RefCounted = gm._begin_lifecycle(self, &"probe")
	gm._finish_lifecycle(token, saves)
	t.check("participant_cannot_release_parent", gm.lifecycle_busy())
	gm._finish_lifecycle(RefCounted.new(), self)
	t.check("wrong_identity_cannot_release", gm.lifecycle_busy())
	denied = saves._apply_payload_owned(payload, token) if saves.has_method("_apply_payload_owned") else {"ok": true}
	t.check("valid_token_wrong_owner_phase_refused", not denied.ok and denied.get("code") == "authority" and gm.lifecycle_busy())
	gm._finish_lifecycle(token, self)
	var next: RefCounted = gm._begin_lifecycle(self, &"next")
	gm._finish_lifecycle(token, self)
	t.check("stale_double_release_cannot_unlock_successor", gm.lifecycle_busy())
	gm._finish_lifecycle(next, self)
	t.check("next_idle_direct_apply_accepted", saves._apply_payload(payload).ok and not gm.lifecycle_busy())
	# Whole-payload helpers are authority surfaces too. An exact active token is
	# deliberately available ONLY through this internal test seam, not the API.
	var other: Dictionary = payload.duplicate(true)
	other.admission_probe["n"] = 777
	var recursive: Array = []
	p.snapshot_hook = func():
		if not recursive.is_empty(): return
		recursive.append({})
		recursive[0] = _whole_payload_probe(gm,saves,p,other)
	outer = saves._apply_payload(payload)
	p.snapshot_hook = Callable()
	t.check("snapshot_whole_sections_bypass_refused_before_callbacks",recursive.size() == 1 and recursive[0].sections_refused and recursive[0].unchanged, str(recursive))
	t.check("snapshot_exact_active_token_cannot_remint_dispatch",recursive.size() == 1 and recursive[0].dispatch_refused and recursive[0].unchanged, str(recursive))
	t.check("snapshot_exact_active_token_cannot_reenter_leaf",recursive.size() == 1 and recursive[0].leaf_refused and recursive[0].unchanged)
	t.check("snapshot_outer_apply_and_cleanup_preserved",outer.ok and p.data == payload.admission_probe and not gm.lifecycle_busy() and not saves._applying)
	var actor := Npc2D.create({"id":"smith_thorin","wander":"0"})
	t.world().add_child(actor)
	actor.interact(t.player())
	var ui: Control = t.tree.get_first_node_in_group("dialogue_ui")
	await t.page_to_choices(ui)
	t.check("finalization_real_owned_page_control",actor.is_talking and actor._held and not ui._buttons.is_empty())
	var finalizing: Array = []
	var finished := func(_result): finalizing.append(_whole_payload_probe(gm,saves,p,other))
	ui.session_finished.connect(finished,CONNECT_ONE_SHOT)
	outer = saves._apply_payload(payload)
	t.check("ui_finish_whole_sections_bypass_refused",finalizing.size() == 1 and finalizing[0].sections_refused and finalizing[0].unchanged,str(finalizing))
	t.check("ui_finish_exact_active_token_cannot_remint_dispatch",finalizing.size() == 1 and finalizing[0].dispatch_refused and finalizing[0].unchanged,str(finalizing))
	t.check("ui_finish_exact_active_token_cannot_reenter_leaf",finalizing.size() == 1 and finalizing[0].leaf_refused and finalizing[0].unchanged)
	t.check("finalization_outer_apply_and_next_idle_root_preserved",outer.ok and not actor.is_talking and not gm.lifecycle_busy() and saves._apply_payload(payload).ok and p.data == payload.admission_probe)
	actor.free()
	saves.unregister_section("admission_probe")
	p.free()
func _whole_payload_probe(gm: Node,saves: Node,p: Node,payload: Dictionary) -> Dictionary:
	var token: RefCounted = gm.get("_lifecycle_token")
	var before := {"game":gm.to_dict(),"data":p.data.duplicate(true),"snapshots":p.snapshots,"applications":p.applications,"pending":saves.pending_world.duplicate(true),"run":saves.run_id}
	var sections: Dictionary = saves._apply_sections(payload)
	var owned_sections: Dictionary = saves._apply_sections(payload,token)
	var owned: Dictionary = saves._apply_payload_owned(payload,token)
	var dispatch: Dictionary = saves._dispatch_apply(payload,token,&"applying")
	var after := {"game":gm.to_dict(),"data":p.data.duplicate(true),"snapshots":p.snapshots,"applications":p.applications,"pending":saves.pending_world.duplicate(true),"run":saves.run_id}
	return {"sections_refused":not sections.ok and sections.get("code") == "authority","dispatch_refused":not dispatch.ok and dispatch.get("code") == "authority","leaf_refused":not owned_sections.ok and owned_sections.get("code") == "authority" and not owned.ok and owned.get("code") == "authority","unchanged":before == after,"before":before,"after":after}
