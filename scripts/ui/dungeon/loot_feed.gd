extends VBoxContainer
## item_gained is ownership; loot_rolled enriches that row, never grants a
## second row for the same transaction or for an automatically sold duplicate.
const L := preload("res://scripts/ui/social/social_layout.gd")
var entries: Array[Dictionary] = []
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation",8)
	EventBus.item_gained.connect(gain)
	EventBus.loot_rolled.connect(_rolled)
func gain(id: StringName, amount: int) -> void:
	if not is_visible_in_tree(): return
	var now := Time.get_ticks_msec()
	for entry in entries:
		if entry.id == id and now-int(entry.last) <= 1500:
			entry.amount += amount
			entry.last = now
			_label(entry)
			_restart(entry)
			return
	var panel := L.panel(self,"PanelLoot")
	panel.size_flags_horizontal = SIZE_SHRINK_END
	panel.mouse_filter = MOUSE_FILTER_IGNORE
	var row := L.box(panel,false,8)
	var slot := RaritySlot.new()
	slot.slot_size = 34
	slot.item_id = id
	slot.rarity = ItemKinds.rarity_of(id)
	row.add_child(slot)
	var words := L.box(row,true,0)
	words.size_flags_horizontal = SIZE_EXPAND_FILL
	var label := L.label(words,"","Heavy17")
	var entry := {"id":id,"amount":amount,"last":now,"panel":panel,"label":label,"tween":null,"source":""}
	var weapon := WeaponInfo.of(id)
	if not weapon.is_empty():
		var line := L.label(words,TranslationServer.translate("FUND_DAMAGE_FMT") % [int(weapon.damage),TranslationServer.translate("WEAPON_FAMILY_"+str(weapon.family).to_upper())],"Caption")
		line.add_theme_color_override("font_color",Color("e3c372"))
	entries.push_front(entry)
	move_child(panel,0)
	_label(entry)
	_restart(entry)
	while entries.size() > 4: _remove(entries.back())
func _label(entry: Dictionary) -> void:
	entry.label.text = "+%d %s" % [int(entry.amount),L.item_name(str(entry.id))]
func _restart(entry: Dictionary) -> void:
	if entry.tween != null and entry.tween.is_valid(): entry.tween.kill()
	entry.panel.modulate.a = 1
	var rare := Rarity.rank(ItemKinds.rarity_of(entry.id)) >= 3
	var tween := create_tween()
	entry.tween = tween
	if rare and not bool(DungeonRun.assist("assist_reduce_flash")):
		entry.panel.scale = Vector2(.96,.96)
		tween.tween_property(entry.panel,"scale",Vector2.ONE,.25)
		tween.parallel().tween_interval(3.2*1.4)
	else: tween.tween_interval(3.2*1.4 if rare else 3.2)
	tween.tween_property(entry.panel,"modulate:a",0.0,.4)
	tween.tween_callback(_remove.bind(entry))
func _remove(entry: Dictionary) -> void:
	if not entries.has(entry): return
	entries.erase(entry)
	if entry.tween != null and entry.tween.is_valid(): entry.tween.kill()
	remove_child(entry.panel)
	entry.panel.queue_free()
func _rolled(source: StringName, rows: Array) -> void:
	for row in rows:
		for entry in entries:
			if str(entry.id) == str(row.get("id","")): entry.source = str(source)
func clear() -> void:
	for entry in entries.duplicate(): _remove(entry)
