extends RefCounted
const SECTION := "presenter_relationship_ownership"
const TIMEOUT_S := 120.0
func launch(npc: String, n: Npc2D, out: Array) -> void:
	out.append(await RelationshipFlow.play_scene(npc, {"relationship":1}, weakref(n)))
func run(t) -> void:
	await t.start_world()
	t.autoload("SaveManager").autosave_enabled = false
	t.autoload("GameManager").set_config_override("time.minutes_per_real_second", 0.0)
	var director: Node = t.autoload("SocialManager").get_node("EventDirector")
	var r: SocialEventRunner = director.runner
	var n := Npc2D.create({"id":"gardener_hoppe", "guest":true, "wander":"0"})
	n.area = t.world().area
	t.world().area.objects.add_child(n)
	var old := func(id): return t.player() if id == "player" else n
	r.actor_resolver = old
	var out: Array = []
	launch("gardener_hoppe", n, out)
	await t.frames(2)
	t.check("actual_relationship_scene_started", r.active != "" and n._event and t.player()._event_active)
	var newer := func(_id): return null
	r.actor_resolver = newer
	r.cancel()
	await t.frames(3)
	t.check("old_relationship_unwind_preserves_newer_resolver", out.size() == 1 and r.actor_resolver == newer)
	t.check("cancel_releases_exact_relationship_holds", not n._event and not t.player()._event_active)
	r.actor_resolver = old
	out.clear()
	launch("gardener_hoppe", n, out)
	await t.frames(2)
	r.skip()
	# The skipped scene unwinds through the game's own (delta-driven) presentation: a game-time bound, not a frame count.
	await t.until_game(func(): return not out.is_empty(), 3.0)
	t.check("ordinary_skipped_relationship_scene_finishes", out == [true])
	t.check("ordinary_relationship_restores_exact_resolver", r.actor_resolver == old and not n._event and not t.player()._event_active)
	r.actor_resolver = Callable()
	n.free()
