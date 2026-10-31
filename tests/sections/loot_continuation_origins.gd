extends RefCounted
const SECTION := "loot_continuation_origins"
const TIMEOUT_S := 180.0
const H1 := preload("res://tests/sections/boss_terminal_origins.gd")
const H2 := preload("res://tests/sections/boss_inner_origins.gd")
const Compare := preload("res://tests/sections/ghostfam_origins.gd")

func run(t) -> void:
	var selected := OS.get_environment("H4_CASE")
	for seam in ([selected] if selected != "" else ["commit"]):
		await _delegate(t,seam,"direct")
		await _delegate(t,seam,"normal")

func _delegate(t, seam: String, mode: String) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	GameManager.set_flag(&"forest_mother_version",0)
	var saves: Node = t.autoload("SaveManager")
	var loot: Node = t.autoload("LootService")
	var prior: String = loot.delegate_path
	loot.delegate_path = "res://tests/fixtures/h4_loot_delegate.gd"
	var tag := "delegate_"+seam+"_"+mode
	var origin := EventBus.interaction_origin()
	var seen: Array = []
	var calls: Array = []
	var baseline := EconomyManager.count_item(&"wood")
	var files := H1.new()._files(saves)
	var callback := func(at):
		calls.append(at)
		if at != seam or mode != "direct" or not seen.is_empty(): return
		seen.append(true)
		var payload: Dictionary = saves.gather_payload()
		seen.append(saves.validate_payload(payload).ok and saves._apply_payload(payload).ok)
		seen.append(saves.gather_payload())
		seen.append(t.player()._last_stats.duplicate(true))
		H2.new()._journal(tag,"callback",{"payload":seen[2],"files":H1.new()._files(saves),"body_cache":seen[3]})
	Engine.set_meta("h4_delegate_hook",callback)
	var result: Dictionary = loot.open_container("skovkant","trae","dg:h4:"+tag)
	Engine.remove_meta("h4_delegate_hook")
	t.check(tag+"_real_supported_delegate_entered",seam in calls)
	if mode == "direct":
		t.check(tag+"_same_valued_success_revokes",seen.size()==4 and seen[1] and not EventBus.interaction_current(origin))
		var after: Dictionary = saves.gather_payload()
		H2.new()._journal(tag,"unwind",{"payload":after,"files":H1.new()._files(saves),"body_cache":t.player()._last_stats})
		t.check(tag+"_full_winner_exact_unwind",Compare.new()._same_payload(seen[2],after),str(Compare.new()._changed(seen[2],after)))
		t.check(tag+"_old_commit_refused",not loot.dungeon.has("h4_commits") and str(result.reason)=="superseded")
		await t.frames(3)
		var queued: Dictionary = saves.gather_payload()
		H2.new()._journal(tag,"three_frames",{"payload":queued,"files":H1.new()._files(saves),"body_cache":t.player()._last_stats})
		t.check(tag+"_full_winner_exact_three_frames",Compare.new()._same_payload(seen[2],queued) and t.player()._last_stats==seen[3])
	else:
		t.check(tag+"_ordinary_economics_commit_once",result.ok and calls==["plan","fit","commit"] and EconomyManager.count_item(&"wood")==baseline+2 and loot.dungeon.h4_commits==1)
	t.check(tag+"_files_exact",H1.new()._files(saves)==files)
	loot.delegate_path = prior
	await t.go_menu()
