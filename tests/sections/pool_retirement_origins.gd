extends RefCounted
const SECTION := "pool_retirement_origins"
const TIMEOUT_S := 180.0
const H1 := preload("res://tests/sections/boss_terminal_origins.gd")

func run(t) -> void:
	for kind in ["spark","ring"]:
		for mode in ["finish","queued","detach","reparent"]: await _retirement(t,kind,mode)
		await _normal(t,kind)

func _warm(parent: Node, kind: String) -> void:
	if kind == "spark": DungeonSpark2D.warm(parent)
	else: TelegraphRing2D.warm(parent)

func _play(parent: Node, kind: String) -> Variant:
	return DungeonSpark2D.play(parent,Vector2(20,30),Color.WHITE) if kind == "spark" else TelegraphRing2D.play(parent,Vector2(20,30),{"radius":81,"duration":20})

func _retirement(t, kind: String, mode: String) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	var parent := Node2D.new()
	boss.area.ground_fx.add_child(parent)
	var other := Node2D.new()
	boss.area.ground_fx.add_child(other)
	_warm(parent,kind)
	var pool := parent.get_node("SparkPool" if kind == "spark" else "TelegraphPool")
	var slot: Variant = pool.get_child(0)
	var seen: Array = []
	var observer := func():
		if not slot.visible or not seen.is_empty(): return
		seen.append(true)
		match mode:
			"finish": slot.finish()
			"queued": slot.queue_free()
			"detach": pool.remove_child(slot)
			"reparent": slot.reparent(other)
		slot.z_index = 77
		seen.append([slot.is_processing(),slot.active,slot.visible,slot.serial,slot.z_index])
	slot.visibility_changed.connect(observer)
	var answer: Variant = _play(parent,kind)
	slot.visibility_changed.disconnect(observer)
	var tag := kind+"_"+mode
	t.check(tag+"_actual_visibility_callback_reached",seen.size()==2)
	t.check(tag+"_old_activation_honestly_refused",answer==null)
	t.check(tag+"_no_old_process_or_transferred_slot_write",[slot.is_processing(),slot.active,slot.visible,slot.serial,slot.z_index]==seen[1])
	if mode == "finish": t.check(tag+"_finished_inactive_invisible_stopped",not slot.active and not slot.visible and not slot.is_processing())
	if mode == "queued":
		var ref: WeakRef = weakref(slot)
		await t.frames(3)
		t.check(tag+"_real_queued_destruction",not is_instance_valid(ref.get_ref()))
	elif mode == "detach":
		t.check(tag+"_remains_detached",not slot.is_inside_tree() and slot.get_parent()==null)
		slot.free()
	elif mode == "reparent": t.check(tag+"_new_parent_preserved",slot.get_parent()==other)
	await t.go_menu()

func _normal(t, kind: String) -> void:
	var boss: DungeonBoss2D = await H1.new()._start(t)
	if boss == null: return
	var parent := Node2D.new()
	boss.area.ground_fx.add_child(parent)
	_warm(parent,kind)
	var cap := DungeonSpark2D.CAP if kind == "spark" else TelegraphRing2D.CAP
	var slots: Array = []
	for i in cap: slots.append(_play(parent,kind))
	t.check(kind+"_normal_exact_cap_all_live",slots.size()==cap and slots.all(func(n): return is_instance_valid(n) and n.active and n.visible and n.is_processing()))
	var oldest_serial: int = slots[0].serial
	var overflow: Variant = _play(parent,kind)
	t.check(kind+"_unchanged_saturation_policy",overflow==slots[0] and overflow.serial>oldest_serial if kind=="spark" else overflow==null and slots.all(func(n): return n.active))
	for node in slots: node.finish()
	var slot: Variant = slots[0]
	var seen: Array = []
	var observer := func():
		if not slot.visible or not seen.is_empty(): return
		seen.append(true)
		slot.finish()
		seen.append(_play(parent,kind))
		seen.append(slot.serial)
	slot.visibility_changed.connect(observer)
	var old: Variant = _play(parent,kind)
	slot.visibility_changed.disconnect(observer)
	t.check(kind+"_new_lease_survives_old_activation",seen.size()==3 and seen[1]==slot and old==null and slot.serial==seen[2] and slot.active and slot.visible and slot.is_processing())
	await t.go_menu()
