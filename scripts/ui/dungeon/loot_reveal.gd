extends CanvasLayer
## Presentation only: all items are already saved in their owning store.
const L := preload("res://scripts/ui/social/social_layout.gd")
const C := preload("res://scripts/ui/theme/tt_colors.gd")
var pending: Array[Dictionary] = []
var active := {}
var tier := 0
var elapsed: float = 0
var duration: float = 0
var reduced := false
var _root: Control
var _dim: ColorRect
var _card: PanelContainer
var _awe: Array[Dictionary] = []
var _tween: Tween
var _flush_queued := false
var _duck_bus := -1
var _duck_before: float = 0
var _duck_applied: float = 0
static func tier_for(rarity: StringName) -> int:
	return clampi(Rarity.rank(rarity)-2,0,3)
static func appraisal_results(answers: Array) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null: return
	var target := tree.get_first_node_in_group("loot_reveal")
	if target == null: return
	for answer in answers:
		var row := LuaData.dict(answer)
		target.enqueue(StringName(str(row.get("gem",""))),StringName(str(row.get("rarity","normal"))),true)
func _ready() -> void:
	layer = 25
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("loot_reveal")
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = Color(C.NIGHT,0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_dim)
	EventBus.rare_item_found.connect(_found)
	EventBus.area_changed.connect(func(_id): finish(); pending.clear())
	_root.hide()
	set_process(false)
func _exit_tree() -> void:
	pending.clear()
	_flush_queued = false
	finish()
func _found(id: StringName, rarity: StringName) -> void:
	if not is_inside_tree():return
	if GameManager.is_modal_open(&"appraisal"): return
	if not get_parent().is_visible_in_tree(): return
	enqueue(id,rarity)
func enqueue(id: StringName, rarity: StringName, appraisal := false) -> void:
	if not is_inside_tree():return
	if tier_for(rarity) == 0 or id == &"": return
	pending.append({"id":id,"rarity":rarity,"appraisal":appraisal})
	if not _flush_queued:
		_flush_queued = true
		_flush.call_deferred()
func _flush() -> void:
	_flush_queued = false
	if not is_inside_tree():
		pending.clear()
		return
	if pending.is_empty(): return
	pending.sort_custom(func(a,b): return Rarity.rank(a.rarity) > Rarity.rank(b.rarity))
	if not active.is_empty(): return
	var best: Dictionary = pending.pop_front()
	for row in pending: _small(row)
	pending.clear()
	if tier_for(best.rarity) == 1:
		_small(best)
		return
	_show(best)
func _small(row: Dictionary) -> void:
	if row.appraisal or bool(DungeonRun.assist("assist_reduce_flash")): return
	var world := get_tree().get_first_node_in_group("world_2d") as WorldRoot2D
	if world != null and world.area != null and world.player != null:
		LootMarkers.burst(world.area.objects,world.player.global_position+Vector2(0,-50),C.LAVENDER,12)
func _show(row: Dictionary) -> void:
	active = row
	tier = tier_for(row.rarity)
	reduced = bool(DungeonRun.assist("assist_reduce_flash"))
	elapsed = 0
	duration = 2 if reduced else 3.2 if tier == 3 else 3.0
	_dim.color = Color(C.NIGHT,0)
	_card = L.panel(_root,"PillNight" if tier == 3 else "PanelCard")
	_card.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_card.position += Vector2(-280,-350)
	_card.custom_minimum_size = Vector2(560,210)
	var content := L.box(L.margin(_card,18),false,18)
	var slot := RaritySlot.new()
	slot.slot_size = 96
	slot.item_id = row.id
	slot.rarity = row.rarity
	content.add_child(slot)
	var words := L.box(content,true,4)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var eyebrow := L.label(words,tr("FUND_LEGENDARY" if tier == 3 else "FUND_UNIQUE"),"EyebrowL")
	var name_label := L.label(words,L.item_name(str(row.id)),"Display30",true)
	name_label.add_theme_font_size_override("font_size",30 if tier == 3 else 26)
	var note_key := str(ItemKinds.def(row.id).get("hint_key","FUND_LEGENDARY_NOTE" if tier == 3 else "FUND_UNIQUE_NOTE"))
	var note := L.label(words,tr(note_key),"Body",true)
	var weapon := WeaponInfo.of(row.id)
	if not weapon.is_empty(): L.label(words,tr("FUND_DAMAGE_FMT") % [int(weapon.damage),tr("WEAPON_FAMILY_"+str(weapon.family).to_upper())],"Body")
	if tier == 3:
		for label in [eyebrow,name_label,note]: label.add_theme_color_override("font_color",Color("e4eff5"))
	_root.show()
	if not reduced:
		_card.scale = Vector2(.6,.6)
		_tween = create_tween().set_parallel()
		_tween.tween_property(_card,"scale",Vector2.ONE,.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if tier == 3:
			_tween.tween_property(_dim,"color:a",.45,.4)
			_tween.tween_property(_card,"position:y",_card.position.y-40,.4)
			_stars(slot)
			_duck()
	if tier == 3: _stun_nearby()
	set_process(true)
func _stars(slot: Control) -> void:
	var halo := TextureRect.new()
	halo.texture = Glow.halo_texture()
	halo.modulate = Color(C.LAVENDER,.35)
	halo.position = Vector2(-32,-32)
	halo.size = Vector2(176,176)
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(halo)
	slot.move_child(halo,0)
	var particles := CPUParticles2D.new()
	particles.amount = 24
	particles.one_shot = true
	particles.explosiveness = .9
	particles.lifetime = 2.8
	particles.texture = Glow.halo_texture()
	particles.material = Glow.additive_material()
	particles.color = C.GLOWSHROOM
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 60
	particles.initial_velocity_min = 12
	particles.initial_velocity_max = 24
	particles.gravity = Vector2(0,-8)
	particles.scale_amount_min = .04
	particles.scale_amount_max = .08
	slot.add_child(particles)
	particles.position = Vector2(56,56)
	particles.emitting = true
func _stun_nearby() -> void:
	var world := get_tree().get_first_node_in_group("world_2d") as WorldRoot2D
	if world == null or world.area == null or DungeonFloors.floor_of(world.area) <= 0: return
	for node in get_tree().get_nodes_in_group("enemy"):
		if not node is Enemy2D or node.is_boss or node.is_in_group("boss") or not node.is_awake() or node.state == Enemy2D.S.DEAD: continue
		if Iso.ground_dist(node.global_position,world.player.global_position) > 800: continue
		node.stun(3)
		_awe.append({"node":weakref(node),"generation":node.stun_generation})
func _release_awe() -> void:
	for row in _awe:
		var node: Enemy2D = row.node.get_ref()
		if node != null and node.state == Enemy2D.S.STUN and node.stun_generation == row.generation: node.remaining = 0
	_awe.clear()
func _duck() -> void:
	# A temporary bus gain leaves the player's configured music volume intact.
	_duck_bus = AudioServer.get_bus_index("Music")
	if _duck_bus < 0: return
	_duck_before = AudioServer.get_bus_volume_db(_duck_bus)
	_duck_applied = _duck_before-float(DungeonRun.cfg("audio.duck_db",6))
	AudioServer.set_bus_volume_db(_duck_bus,_duck_applied)
func _unduck() -> void:
	if _duck_bus < 0: return
	if is_equal_approx(AudioServer.get_bus_volume_db(_duck_bus),_duck_applied): AudioServer.set_bus_volume_db(_duck_bus,_duck_before)
	_duck_bus = -1
func _process(dt: float) -> void:
	elapsed += dt
	if elapsed >= duration: finish()
func can_skip() -> bool:
	return not active.is_empty() and elapsed >= (1.0 if tier == 3 else .8)
func _input(event: InputEvent) -> void:
	if not can_skip() or not (event.is_action_pressed("attack") or event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel")): return
	finish()
	get_viewport().set_input_as_handled()
func finish() -> void:
	if _tween != null and _tween.is_valid(): _tween.kill()
	_release_awe()
	_unduck()
	if is_instance_valid(_card):
		_root.remove_child(_card)
		_card.queue_free()
	_card = null
	active.clear()
	tier = 0
	if _root != null: _root.hide()
	set_process(false)
	if not pending.is_empty(): _flush.call_deferred()
