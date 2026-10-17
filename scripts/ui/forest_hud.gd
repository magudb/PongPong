extends Control
const L := preload("res://scripts/ui/social/social_layout.gd")
const C := preload("res://scripts/ui/theme/tt_colors.gd")
const Hearts := preload("res://scripts/ui/components/tt_hearts.gd")
const Feed := preload("res://scripts/ui/dungeon/loot_feed.gd")
const Banner := preload("res://scripts/ui/dungeon/floor_banner.gd")
var hearts: Control
var second_hearts: Control
var oil_pill: PanelContainer
var oil_bar: ProgressBar
var oil_count: Label
var oil_caption: Label
var _boss_key := ""
var boss_box: VBoxContainer
var boss_name: Label
var boss_bar: ProgressBar
var minimap: Minimap2D
var zone_label: Label
var loot_feed: VBoxContainer
var floor_banner: VBoxContainer
var current_item_badge: CurrentItemBadge
var abilities := {}
var drink_count: Label
var backpack_chip: Label
var assist_badge: Label
var toasts: ToastStack
var _player: Player2D
var _oil_pulse: Tween
var _hint_tweens := {}
var _pending_arrivals := 0
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var plate := L.panel(self,"PanelHearts",Rect2(40,42,282,54))
	var column := L.box(plate,true,8)
	hearts = Hearts.new()
	hearts.max_hearts = 5
	column.add_child(hearts)
	second_hearts = Hearts.new()
	column.add_child(second_hearts)
	second_hearts.hide()
	oil_pill = L.panel(self,"PillNight",Rect2(40,102,280,30))
	var row := L.box(oil_pill,false,8)
	oil_caption = L.label(row,"FOREST_OIL","OwlEye15")
	oil_bar = ProgressBar.new()
	oil_bar.theme_type_variation = &"MeterNight"
	oil_bar.custom_minimum_size = Vector2(132,12)
	oil_bar.size_flags_vertical = SIZE_SHRINK_CENTER
	oil_bar.size_flags_horizontal = SIZE_EXPAND_FILL
	oil_bar.show_percentage = false
	oil_bar.step = 0
	row.add_child(oil_bar)
	oil_count = L.label(row,"","Display15Owl")
	boss_box = VBoxContainer.new()
	add_child(boss_box)
	boss_box.position = Vector2(428,40)
	boss_box.size = Vector2(424,54)
	boss_box.add_theme_constant_override("separation",6)
	boss_name = L.label(boss_box,"","DisplayCream24")
	boss_name.add_theme_font_size_override("font_size",22)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = ProgressBar.new()
	boss_bar.theme_type_variation = &"MeterBoss"
	boss_bar.custom_minimum_size = Vector2(424,20)
	boss_bar.show_percentage = false
	boss_bar.step = 0
	boss_box.add_child(boss_bar)
	for fraction in [.33,.66]:
		var tick := ColorRect.new()
		tick.color = C.CHALK
		tick.position = Vector2(424*fraction,2)
		tick.size = Vector2(2,16)
		tick.mouse_filter = MOUSE_FILTER_IGNORE
		boss_bar.add_child(tick)
	boss_box.hide()
	minimap = Minimap2D.new()
	add_child(minimap)
	minimap.anchor_left = 1
	minimap.anchor_right = 1
	minimap.offset_left = -226
	minimap.offset_right = -38
	minimap.offset_top = 38
	minimap.offset_bottom = 226
	zone_label = L.label(self,"","ZoneChip")
	zone_label.anchor_left = 1
	zone_label.anchor_right = 1
	zone_label.offset_left = -320
	zone_label.offset_right = -24
	zone_label.offset_top = 30
	zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loot_feed = Feed.new()
	loot_feed.name = "LootFeed"
	add_child(loot_feed)
	loot_feed.anchor_left = 1
	loot_feed.anchor_right = 1
	loot_feed.offset_left = -350
	loot_feed.offset_right = -40
	loot_feed.offset_top = 262
	floor_banner = Banner.new()
	add_child(floor_banner)
	floor_banner.position = Vector2(400,120)
	floor_banner.size = Vector2(480,80)
	var ability_row := HBoxContainer.new()
	add_child(ability_row)
	ability_row.set_anchors_and_offsets_preset(PRESET_CENTER_BOTTOM)
	ability_row.position += Vector2(-164,-134)
	ability_row.add_theme_constant_override("separation",12)
	for spec in [["slash","attack",78],["dodge","dodge",64],["light","light",64],["drink","drink",64]]:
		var slot := preload("res://scenes/ui/components/ability_slot.tscn").instantiate()
		slot.setup(StringName(spec[0]),StringName(spec[1]),spec[2])
		slot.size_flags_vertical = SIZE_SHRINK_END
		ability_row.add_child(slot)
		abilities[spec[0]] = slot
	drink_count = L.label(abilities.drink.get_node("Frame/Inner"),"","Display15Owl")
	drink_count.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	drink_count.offset_left = -26
	drink_count.offset_top = -20
	drink_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	current_item_badge = CurrentItemBadge.new()
	current_item_badge.name = "CurrentItemBadge"
	add_child(current_item_badge)
	current_item_badge.anchor_left = .5
	current_item_badge.anchor_right = .5
	current_item_badge.anchor_top = 1
	current_item_badge.anchor_bottom = 1
	current_item_badge.offset_left = -140
	current_item_badge.offset_right = 140
	current_item_badge.offset_top = -180
	current_item_badge.offset_bottom = -138
	backpack_chip = L.label(self,"","OwlEye15")
	backpack_chip.position = Vector2(40,160)
	assist_badge = L.label(self,"","OwlEye15")
	assist_badge.position = Vector2(40,192)
	add_child(preload("res://scenes/ui/components/whisper_line.tscn").instantiate())
	var prompt := preload("res://scenes/ui/components/prompt_pill.tscn").instantiate()
	add_child(prompt)
	# Leave a full row between the equipped item and the interaction prompt.
	prompt.get_node("Pill").offset_top = -226
	prompt.get_node("Pill").offset_bottom = -196
	toasts = preload("res://scenes/ui/components/toast_stack.tscn").instantiate()
	toasts.item_toasts = false
	add_child(toasts)
	add_child(preload("res://scenes/ui/dungeon/loot_reveal.tscn").instantiate())
	preload("res://scripts/dungeon_run/cues.gd").attach(self)
	EventBus.player_spawned.connect(_spawned)
	EventBus.player_health_changed.connect(_health)
	EventBus.player_oil_changed.connect(_oil)
	EventBus.boss_bar_changed.connect(_boss)
	EventBus.area_changed.connect(_area_changed)
	EventBus.player_inventory_changed.connect(_inventory)
	EventBus.game_event.connect(_event)
	EventBus.modal_changed.connect(func(_stack): toasts.visible = not GameManager.is_modal_open())
	DungeonRun.attach(self)
	_spawned(get_tree().get_first_node_in_group("player"))
	_inventory({})
	_assist()
	_area_changed(&"")
func _spawned(player: Node) -> void:
	_player = player as Player2D
	if _player != null:
		_health(_player.half_hearts,_player.max_half_hearts)
		_oil(_player.oil,_player.max_oil)
func _health(current: int, maximum: int) -> void:
	var count := ceili(maximum/2.0)
	hearts.max_hearts = mini(count,6)
	hearts.half_hearts = mini(current,12)
	second_hearts.visible = count > 6
	second_hearts.max_hearts = maxi(1,count-6)
	second_hearts.half_hearts = maxi(0,current-12)
	oil_pill.position.y = 138 if count > 6 else 102
	backpack_chip.position.y = 180 if count > 6 else 146
	assist_badge.position.y = backpack_chip.position.y+28
func _oil(seconds: float, maximum: float) -> void:
	oil_bar.value = 100*seconds/maxf(1,maximum)
	var low := oil_bar.value <= 20
	if _oil_pulse != null and _oil_pulse.is_valid():
		if low and not bool(DungeonRun.assist("assist_reduce_flash")): return
		_oil_pulse.kill()
	oil_pill.modulate = Color.WHITE
	if low and not bool(DungeonRun.assist("assist_reduce_flash")):
		_oil_pulse = create_tween().set_loops()
		_oil_pulse.tween_property(oil_pill,"modulate",Color(1,.8,.6),.65)
		_oil_pulse.tween_property(oil_pill,"modulate",Color.WHITE,.65)
func _boss(key: String, ratio: float, shown: bool) -> void:
	_boss_key = key
	boss_box.visible = shown
	boss_name.text = tr(key)
	boss_bar.value = clampf(ratio,0,1)*100
	if shown: floor_banner.dismiss()
func _area_changed(_id: StringName) -> void:
	var world := get_tree().get_first_node_in_group("world_2d") as WorldRoot2D
	var area: IsoArea = world.area if world != null else null
	minimap.set_area(area)
	zone_label.text = tr(area.map.title)+" · "+str(area.map.depth) if area != null else ""
	_fit_zone()
	loot_feed.clear()
	boss_box.hide()
func _fit_zone() -> void:
	var width := zone_label.get_minimum_size().x
	zone_label.offset_left = -132-width*.5
	zone_label.offset_right = -132+width*.5
func _inventory(_items: Dictionary) -> void:
	var eco := Svc.node("EconomyManager")
	if eco == null: return
	oil_count.text = "×%d" % (eco.count_item(&"lantern_oil")+eco.count_item(&"lysdraabe"))
	drink_count.text = "×%d" % (eco.count_item(&"health_tonic")+eco.count_item(&"svampe_eliksir"))
	var used: int = eco.used_slots()
	backpack_chip.visible = used >= 20
	backpack_chip.text = tr("DEXP_BACKPACK_FULL" if used >= 24 else "DEXP_BACKPACK_NEAR")+" %d/24" % used
	backpack_chip.add_theme_color_override("font_color",C.HONEY if used >= 24 else C.CHALK)
func _assist() -> void:
	var preset := str(DungeonRulesData.flag("assist_preset","none"))
	assist_badge.visible = preset != "none"
	assist_badge.text = tr("ASSIST_TITLE")+": "+tr("ASSIST_PRESET_"+preset.to_upper())
	if is_instance_valid(_player): _oil(_player.oil,_player.max_oil)
func _event(id: StringName, payload: Dictionary) -> void:
	match id:
		&"dungeon_floor_entered":
			_pending_arrivals += 1
			_show_arrival.call_deferred()
		&"dungeon_floor_revealed": minimap.reveal_all()
		&"assist_changed", &"skovhjerte_grown":
			_assist()
			if is_instance_valid(_player): _health(_player.half_hearts,_player.max_half_hearts)
		&"dungeon_hint": pulse_ability(str(payload.get("id","")))
func _show_arrival() -> void:
	if _pending_arrivals <= 0: return
	_pending_arrivals = 0
	floor_banner.show_floor(minimap.area,boss_box.visible)
func pulse_ability(id: String) -> void:
	if id == "abilities":
		for ability in abilities: pulse_ability(ability)
		return
	var key: String = {"swing":"slash","attack":"slash","weapon_weak":"slash","boss":"dodge","eyes":"light","lantern":"light","berry":"drink","oil":"drink"}.get(id,id)
	if not abilities.has(key): return
	var slot: Control = abilities[key]
	if _hint_tweens.has(key) and _hint_tweens[key].is_valid(): _hint_tweens[key].kill()
	slot.modulate = C.OWL_EYE
	var tween := create_tween()
	_hint_tweens[key] = tween
	tween.tween_property(slot,"modulate",Color.WHITE,.8)
func _process(_dt: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(_player): return
	for key in abilities:
		var left := _player.cd_seconds(key)
		abilities[key].set_cooldown(_player.cd_ratio(key),"%.1f" % left if left > .05 else "")

func _notification(what: int) -> void:
	if what!=NOTIFICATION_TRANSLATION_CHANGED or not is_node_ready() or oil_caption==null:return
	oil_caption.text = tr("FOREST_OIL")
	if _boss_key!="":boss_name.text = tr(_boss_key)
	if minimap!=null and minimap.area!=null:
		zone_label.text = tr(minimap.area.map.title)+" · "+str(minimap.area.map.depth)
		_fit_zone()
	_inventory({})
	_assist()
