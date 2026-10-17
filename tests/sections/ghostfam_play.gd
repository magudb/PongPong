extends RefCounted
const SECTION := "ghostfam_play"
const TIMEOUT_S := 120.0
const FAMILY := ["ghostfam_dyne","ghostfam_gnist","ghostfam_silke","ghostfam_blund"]
func run(t) -> void:
	await t.start_world("ghost")
	var world: WorldRoot2D = t.world()
	GameManager.set_config_override("time.minutes_per_real_second",0)
	GameManager.set_config_override("towns.curfew.enabled",false)
	Fresh.jump_to_total_day(10)
	GameManager.hour = 20
	GameManager.minute = 0
	EventBus.day_started.emit(GameManager.day,GameManager.season)
	EventBus.time_of_day_changed.emit(20,0)
	await world.travel(&"traetoppen",&"default")
	await t.physics(4)
	var glows: Array[NpcGlow] = []
	for npc in FAMILY:
		var actor: Node = NpcDirector.node_of(npc,world.area)
		t.check(npc+"_present",actor!=null)
		if actor==null:return
		var glow := actor.get_node_or_null("NpcGlow") as NpcGlow
		t.check(npc+"_halo_attached",glow!=null and glow.halo.texture==Glow.halo_texture())
		if glow==null:return
		t.check(npc+"_one_owner",NpcGlow.attach(actor)==glow)
		t.check(npc+"_light_role",(glow.light!=null)==(npc=="ghostfam_silke"))
		glow._refresh()
		t.check(npc+"_night_halo",glow.halo.visible and glow.halo.modulate.a>0)
		glows.append(glow)
	var silke: NpcGlow = glows[2]
	t.check("live_city_light_budget",silke.light.visible and silke._enabled_lights(world)+1<=15,str(silke._enabled_lights(world)+1))
	var extras: Array[PointLight2D] = []
	for i in 15:
		var extra := PointLight2D.new()
		extra.texture = Glow.light_texture()
		world.add_child(extra)
		extras.append(extra)
	silke._refresh()
	t.check("lantern_yields_when_budget_full",not silke.light.visible and silke.lantern_halo.visible)
	for extra in extras:extra.free()
	silke._refresh()
	t.check("lantern_returns_when_budget_free",silke.light.visible)
	world.area.set_night_factor(0)
	for glow in glows:glow._refresh()
	t.check("noon_hides_all_halos",glows.all(func(g):return not g.halo.visible))
	t.check("noon_hides_lantern",not silke.light.visible and is_zero_approx(silke.light.energy))
	var clone := Npc2D.create({"id":"ghostfam_silke"})
	clone.area = world.area
	world.area.objects.add_child(clone)
	var ref: WeakRef = weakref(clone.get_node("NpcGlow"))
	var light_ref: WeakRef = weakref(clone.get_node("NpcGlow").light)
	clone.queue_free()
	await t.frames(3)
	t.check("glow_and_light_free_with_actor",ref.get_ref()==null and light_ref.get_ref()==null)
	await t.go_menu()
