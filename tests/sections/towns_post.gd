extends RefCounted
const SECTION := "towns_post"
const TIMEOUT_S := 120.0
func run(t) -> void:
	await t.start_world()
	GameManager.set_config_override("time.minutes_per_real_second",0)
	var post: Node = t.world().game_ui.get_screen(&"post")
	t.check("screen_installed",post != null)
	if post == null: return
	var ctx := Routines.make_ctx(2,14,"klart",{"total_day":10,"hero":"","hearts":{}})
	var known := PostLocations.rows(ctx)
	t.check("only_known_citizens",not known.any(func(r):return r.id == "bertil") and known.any(func(r):return r.id == "postman_pip"))
	ctx.hearts.bertil = 1
	t.check("one_heart_adds_friend",PostLocations.rows(ctx).any(func(r):return r.id == "bertil"))
	ctx.hero = "bertil"
	t.check("hero_twin_is_omitted",not PostLocations.rows(ctx).any(func(r):return r.id == "bertil"))
	ctx.hero = ""
	var before: Dictionary = PostLocations.rows(ctx).filter(func(r):return r.id == "postman_pip")[0]
	ctx.hour = 18
	var after: Dictionary = PostLocations.rows(ctx).filter(func(r):return r.id == "postman_pip")[0]
	t.check("rows_follow_clock",before.state.place != after.state.place)
	t.check("no_raw_keys",PostLocations.rows(ctx).all(func(r):return not str(r.place).begins_with("WHERE_") and not str(r.place).begins_with("BLD_")))
	t.check("hiding_withholds_spot",PostLocations.place_text({"npc":"ghostfam_blund","state":"stay","act":"hide","place":"traetoppen.c_logs"}) == TranslationServer.translate("POST_HIDING"))
	t.check("sleep_wording",PostLocations.place_text({"npc":"mapseller_natteblik","state":"absent","act":"away"}) == TranslationServer.translate("POST_NOT_AWAKE"))
	t.check("forest_wording",PostLocations.place_text({"npc":"appraiser_fru_ugle","state":"absent","act":"away"}) == TranslationServer.translate("POST_FOREST"))
	EventBus.game_event.emit(&"open_post_office",{"building":"postkontoret"})
	await t.frames(4)
	t.check("counter_opens",post.is_open() and GameManager.top_modal() == &"post" and t.tree.paused)
	t.check("initial_focus",t.root.gui_get_focus_owner() == post.rows[0])
	var first: Button = post.rows[0]
	t.tap(&"ui_up")
	await t.frames(2)
	t.check("ring_up",t.root.gui_get_focus_owner() == post.rows[-1])
	t.tap(&"ui_down")
	await t.frames(2)
	t.check("ring_down",t.root.gui_get_focus_owner() == first)
	t.tap(&"ui_accept")
	await t.frames(2)
	t.check("read_only_accept",post.is_open() and GameManager.top_modal() == &"post")
	t.tap(&"ui_page_down")
	await t.frames(2)
	t.check("page_changes_town",post.tab == 1)
	TranslationServer.set_locale("en")
	await t.frames(3)
	t.check("english_title",post.title.text == "Where is …?")
	TranslationServer.set_locale("da")
	t.tap(&"ui_cancel")
	await t.frames(3)
	t.check("cancel_unpauses",not post.is_open() and not t.tree.paused and t.root.gui_get_focus_owner() == null)
	var report := UiAudit.rule_report(post)
	t.check("rule_report_clean",bool(report.ok),str(report.defects))
	await t.clear_scene()
	var audit: Dictionary = await UiAudit.audit_screen(t,"post")
	t.check("all_registry_checks",audit.ok,str(audit.defects))
	await t.go_menu()
func run_windowed(t) -> void:
	await t.start_world()
	GameManager.set_config_override("time.minutes_per_real_second",0)
	var post: Node = t.world().game_ui.get_screen(&"post")
	post.get_script().fixture_setup(post,null)
	await t.frames(4)
	await t.capture("post_office_locations")
	t.check("native_list",post.is_open() and post.rows.size() >= 10)
	post.close()
	await t.go_menu()

	await t.clear_scene()
	Fresh.new_game(t)
	var host := Control.new()
	host.process_mode = Node.PROCESS_MODE_ALWAYS
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.tree.root.add_child(host)
	var node: Control = await preload("res://scripts/ui/dev/ui_fixtures.gd").make("post_guide",host)
	await t.frames(5)
	await t.capture("post_guide")
	UiAudit.expect(t,UiAudit.rule_report(node),"native_post_rules")
	node.close()
	host.free()

	await t.clear_scene()
	Fresh.new_game(t)
	var audit: Dictionary = await UiAudit.audit_screen(t,"post")
	t.check("native_registry",audit.ok,str(audit.defects))
