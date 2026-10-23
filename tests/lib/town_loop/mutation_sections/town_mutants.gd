extends RefCounted
const SECTION := "town_mutants"
const TIMEOUT_S := 60.0
func run(t) -> void:
	await t.start_world()
	var gm: Node = t.autoload("GameManager")
	gm.set_config_override("time.minutes_per_real_second",0.0)
	gm.set_config_override("towns.curfew.enabled",false)
	await LoopClock.at(t,1,7)
	await t.world().travel(&"hyggebyen",&"default")
	var door := TownProbe.door(t,"froebutikken")
	t.check("l05_closed_before_open",door!=null and not door.is_open() and door.last_reason=="hours")
	# Observe the real producer's request without letting the negative control
	# tear down the room that the following probes need.
	var bus: Node = t.autoload("EventBus")
	var travel := Callable(t.world(),"_on_area_change_requested")
	bus.area_change_requested.disconnect(travel)
	var requests: Array = []
	var spy := func(id,spawn):requests.append([id,spawn])
	bus.area_change_requested.connect(spy)
	door.armed=true
	door._on_body_entered(t.player())
	t.check("l05_closed_door_does_not_travel",requests.is_empty())
	bus.area_change_requested.disconnect(spy)
	bus.area_change_requested.connect(travel)
	await LoopClock.to(t,10)
	AudioManager.clear_cue_log()
	await t.world().travel(&"int_froebutikken",&"default")
	t.check("l16_shop_bell_is_logged",AudioManager.cue_log().any(func(row):return row.kind=="sfx" and row.id=="shop_bell" and row.played))
	var now: int = gm.hour*60+gm.minute
	gm.set_config_override("time.minutes_per_real_second",2.0)
	t.autoload("TimeManager").tick(1.0)
	gm.set_config_override("time.minutes_per_real_second",0.0)
	t.check("l04_zone_and_running_clock",t.world().area.map.projection==&"iso" and gm.hour*60+gm.minute==now+2)
	var social: Node = t.autoload("SocialManager")
	var before: int = social.hearts("merchant_pip")
	var shops := preload("res://tests/lib/town_loop/shops.gd").new()
	var opened := await shops.host(t,"talk")
	t.tap_key(KEY_ESCAPE)
	await t.frames(3)
	t.check("l03_esc_first_line_no_heart",opened and social.hearts("merchant_pip")==before and not TownProbe.dialogue(t).is_open())
	var order := -1
	for row in t.autoload("SaveManager")._ordered_entries():
		if row.name=="social":order=int(row.order)
	t.check("l13_social_section_order",order==60)
	var payload: Dictionary = t.autoload("SaveManager").gather_payload()
	var digest := LoopDigest.of_payload(payload)
	payload.players.rows.p0.gold+=1
	t.check("digest_has_teeth_gold",LoopDigest.of_payload(payload)!=digest)
	await t.world().travel(&"hyggebyen",&"default")
	var citizens: Array[WeakRef] = []
	for actor in TownProbe.director(t).live.values():citizens.append(weakref(actor))
	await t.world().travel(&"farm",&"default")
	await t.frames(3)
	t.check("l02_citizens_freed_on_exit",not citizens.is_empty() and citizens.all(func(w):return w.get_ref()==null))
	gm.clear_config_overrides()
	await t.clear_scene()
