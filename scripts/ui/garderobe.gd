extends TTScreen
## One wardrobe and hands screen. Local try-on never changes the saved owner.
const L := preload("res://scripts/ui/social/social_layout.gd") # shared theme-only book primitives
const SLOT := preload("res://scenes/ui/components/item_slot.tscn")
const CELLS := [["HAT",["hat","circlet"]],["NECKLACE",["necklace"]],["EARRINGS",["earrings"]],["BODY",["shirt","dress"]],["PANTS",["pants"]],["BRACELET",["bracelet"]],["SHOES",["shoes"]]]
var tab := 0
var selected_id := ""
var filter := ""
var show_all := false
var preset := "work"
var preview: IsoChibiSprite2D
var preview_layers: WardrobeLayers
var preview_held: HeldEquipment2D
var preview_outfit := {}
var title: Label
var tabs: Array[Button] = []
var close_button: Button
var filters: VBoxContainer
var filter_buttons: Array[Button] = []
var grid: GridContainer
var item_scroll: ScrollContainer
var item_buttons: Array[Button] = []
var preview_well: Control
var rotate_buttons: Array[Button] = []
var preview_state: Label
var detail_name: Label
var detail_desc: Label
var status: Label
var equip_button: Button
var remove_button: Button
var assign_button: Button
var clear_button: Button
var owned_label: Label
var browse_button: Button
var hotbar_row: HBoxContainer
var hotbar_buttons: Array[Button] = []
var preset_box: VBoxContainer
var preset_buttons: Array[Button] = []
var save_preset_button: Button
var load_preset_button: Button
var perk_label: Label
var _refresh_pending := false
var _assigning := ""

func _init() -> void:
	super._init()
	screen_id = &"garderobe"
	modal_name = &"garderobe"
	hotkey_action = &"wardrobe"
	for index in 8:
		consumed_actions.append(StringName("slot_%d" % (index+1)))

func _ready() -> void:
	super._ready()
	L.scrim(self)
	var book := L.panel(self,"PanelBook",Rect2(50,30,1180,660))
	var body := L.box(L.margin(book,20),true,12)
	var header := L.box(body,false,12)
	title = L.label(header,"","Display34")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var group := ButtonGroup.new()
	group.set_meta("tt_value_selection",true)
	for index in 2:
		var button := L.button(header,"")
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(set_tab.bind(index))
		tabs.append(button)
	close_button = L.button(header,"","ButtonTertiaryS")
	close_button.pressed.connect(close)
	var columns := L.box(body,false,18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filters = L.box(columns,true,6) as VBoxContainer
	filters.custom_minimum_size.x = 178
	var center := L.box(columns,true,8)
	center.custom_minimum_size.x = 280
	preview_well = L.panel(center,"PanelCard")
	preview_well.custom_minimum_size = Vector2(280,270)
	preview_well.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_well.clip_contents = true
	preview_well.resized.connect(_place_preview)
	preview_state = L.label(center,"","Muted14",true)
	var controls := L.box(center,false,8)
	for index in 3:
		var button := L.button(controls,"","ButtonTertiaryS")
		button.pressed.connect(_preview_control.bind(index))
		rotate_buttons.append(button)
	perk_label = L.label(center,"","Body",true)
	preset_box = L.box(center,true,6) as VBoxContainer
	var choices := L.box(preset_box,false,6)
	var preset_group := ButtonGroup.new()
	preset_group.set_meta("tt_value_selection",true)
	for key in WardrobeManager.PRESETS:
		var button := L.button(choices,"","ButtonTertiaryS")
		button.toggle_mode = true
		button.button_group = preset_group
		button.pressed.connect(_choose_preset.bind(key))
		preset_buttons.append(button)
	var preset_actions := L.box(preset_box,false,6)
	save_preset_button = L.button(preset_actions,"","ButtonSecondaryS")
	load_preset_button = L.button(preset_actions,"","ButtonSecondaryS")
	save_preset_button.pressed.connect(_save_preset)
	load_preset_button.pressed.connect(_load_preset)
	var right := L.box(columns,true,8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var catalog_header := L.box(right,false,8)
	owned_label = L.label(catalog_header,"","Heavy17")
	owned_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browse_button = L.button(catalog_header,"","ButtonTertiaryS")
	browse_button.pressed.connect(func(): show_all = not show_all; _refresh_texts())
	item_scroll = ScrollContainer.new()
	item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	item_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(item_scroll)
	grid = GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",6)
	item_scroll.add_child(grid)
	detail_name = L.label(right,"","Heavy17")
	detail_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_desc = L.label(right,"","Body",true)
	detail_desc.max_lines_visible = 3
	var actions := L.box(right,false,8)
	equip_button = L.button(actions,"","ButtonPrimaryS")
	remove_button = L.button(actions,"","ButtonSecondaryS")
	assign_button = L.button(actions,"","ButtonSecondaryS")
	equip_button.pressed.connect(_equip)
	remove_button.pressed.connect(_remove)
	assign_button.pressed.connect(_begin_assignment)
	status = L.label(right,"","Muted14",true)
	status.custom_minimum_size.y = 36
	hotbar_row = L.box(body,false,8) as HBoxContainer
	var hotbar_selection := ButtonGroup.new()
	hotbar_selection.set_meta("tt_value_selection",true)
	for index in 8:
		var button: Button = SLOT.instantiate()
		button.custom_minimum_size = Vector2(48,48)
		button.button_group = hotbar_selection
		hotbar_row.add_child(button)
		button.pressed.connect(_hotbar.bind(index))
		hotbar_buttons.append(button)
	clear_button = L.button(hotbar_row,"","ButtonTertiaryS")
	clear_button.pressed.connect(_clear_hotbar)
	var hints: Control = preload("res://scenes/ui/components/hint_bar.tscn").instantiate()
	body.add_child(hints)
	hints.set_hints([{"pair":[&"ui_page_up",&"ui_page_down"],"key":"GARDEROBE_SWITCH_TABS"},{"action":&"ui_accept","key":"HINT_OK"},{"action":&"ui_cancel","key":"HINT_BACK"}])
	WardrobeManager.owned_changed.connect(_schedule_refresh)
	WardrobeManager.presets_changed.connect(_schedule_refresh)
	EventBus.outfit_changed.connect(func(_outfit): _schedule_refresh())
	EventBus.player_inventory_changed.connect(func(_items): _schedule_refresh())
	EventBus.hotbar_changed.connect(func(_entries,_selected): _schedule_refresh())
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("garderobe",Callable(get_script(),&"fixture_setup"))

func _player() -> Player2D:
	return get_tree().get_first_node_in_group(&"player") as Player2D

func _hotkey_open_allowed() -> bool:
	var player := _player()
	return player != null and player.area != null and player.state == PlayerBody2D.S.FREE and player.forced_clip != &"sleep" and not player._event_active

func open(opener: Control = null) -> void:
	if not _hotkey_open_allowed():
		return
	_open_for_body(_player().visual.resolved_id,opener)

func _open_for_body(body_id: String, opener: Control = null) -> void:
	selected_id = ""
	_assigning = ""
	preview_outfit = WardrobeManager.outfit()
	if preview == null:
		preview = IsoChibiSprite2D.create(body_id)
		preview_well.add_child(preview)
		preview.scale = Vector2.ONE * 1.3
		_place_preview()
		preview.show_shadow = false
		preview.shadow.hide()
		preview_layers = WardrobeLayers.new()
		preview.add_child(preview_layers)
		preview_layers.set_outfit(preview_outfit)
		preview_held = HeldEquipment2D.new()
		preview.add_child(preview_held)
	super.open(opener)
	_place_preview()

func _place_preview() -> void:
	if is_instance_valid(preview):
		preview.position = Vector2(preview_well.size.x/2,preview_well.size.y-16)

func close() -> void:
	_assigning = ""
	if is_instance_valid(preview):
		preview_well.remove_child(preview)
		preview.queue_free()
	preview = null
	preview_layers = null
	preview_held = null
	preview_outfit.clear()
	super.close()

func _initial_focus() -> Control:
	for button in item_buttons:
		if str(button.item_id) == selected_id:
			return button
	return item_buttons[0] if not item_buttons.is_empty() else tabs[tab]

func set_tab(index: int) -> void:
	tab = index
	filter = ""
	selected_id = ""
	_assigning = ""
	preview_outfit = WardrobeManager.outfit()
	_refresh_texts()

func _on_page(step: int) -> void:
	set_tab(posmod(tab+step,2))
	_initial_focus().grab_focus()

func _on_cancel() -> void:
	if _assigning != "":
		_assigning = ""
		_select(selected_id)
		assign_button.grab_focus()
	else:
		close()

func _input(event: InputEvent) -> void:
	if is_open() and is_top() and _assigning != "" and event.is_pressed() and not event.is_echo():
		for index in 8:
			if event.is_action_pressed(StringName("slot_%d" % (index+1))):
				_hotbar(index)
				get_viewport().set_input_as_handled()
				return
	super._input(event)

func _schedule_refresh() -> void:
	if is_open() and not _refresh_pending:
		_refresh_pending = true
		_flush.call_deferred()

func _flush() -> void:
	_refresh_pending = false
	if is_inside_tree() and is_open():
		_refresh_texts()

func _refresh_texts() -> void:
	if title == null:
		return
	title.text = tr("GARDEROBE_TITLE")
	for index in 2:
		tabs[index].text = tr("GARDEROBE_CLOTHES" if index == 0 else "GARDEROBE_HANDS")
		tabs[index].set_pressed_no_signal(index == tab)
	close_button.text = tr("UI_CLOSE")
	browse_button.text = tr("GARDEROBE_OWNED_ONLY" if show_all else "GARDEROBE_BROWSE_ALL")
	browse_button.visible = tab == 0
	preset_box.visible = tab == 0
	hotbar_row.visible = tab == 1
	rotate_buttons[0].text = tr("GARDEROBE_TURN_LEFT")
	rotate_buttons[1].text = tr("GARDEROBE_TURN_RIGHT")
	rotate_buttons[2].text = tr("GARDEROBE_WALK")
	for index in 3:
		preset_buttons[index].text = tr("GARDEROBE_PRESET_"+str(WardrobeManager.PRESETS[index]).to_upper())
		preset_buttons[index].set_pressed_no_signal(WardrobeManager.PRESETS[index] == preset)
	save_preset_button.text = tr("GARDEROBE_SAVE_WORN")
	load_preset_button.text = tr("GARDEROBE_WEAR_PRESET")
	UiNav.set_enabled(load_preset_button,WardrobeManager.presets.has(preset))
	clear_button.text = tr("GARDEROBE_CLEAR_HOTBAR")
	_build_filters()
	_build_items()
	_select(selected_id)
	var player := _player()
	if player != null:
		for index in 8:
			hotbar_buttons[index].setup_item(player.hotbar.slots[index],0,str(index+1))
			hotbar_buttons[index].set_pressed_no_signal(index == player.hotbar.selected)
	perk_label.text = tr("GARDEROBE_CURRENT_PERKS_FMT") % [roundi(Perks.total("speed")*100),roundi(Perks.total("energy")),roundi(Perks.total("luck")*100),roundi(Perks.total("discount")*100)]
	_wire()

func _build_filters() -> void:
	L.clear(filters)
	filter_buttons.clear()
	var specs: Array = [["",tr("GARDEROBE_ALL")]]
	if tab == 0:
		for cell in CELLS:
			specs.append([cell[0],tr("SLOTCELL_"+cell[0])])
	else:
		specs.append_array([["weapon",tr("HUD_ITEM_WEAPON")],["tool",tr("GARDEROBE_TOOLS")],["gem",tr("GARDEROBE_LANTERN_GEM")]])
	var group := ButtonGroup.new()
	group.set_meta("tt_value_selection",true)
	for spec in specs:
		var button := L.button(filters,spec[1],"PillTab")
		button.toggle_mode = true
		button.button_group = group
		button.set_pressed_no_signal(filter == spec[0])
		button.pressed.connect(_filter.bind(spec[0]))
		if tab == 0 and spec[0] != "":
			for cell in CELLS:
				if cell[0] != spec[0]:
					continue
				var worn := ""
				for slot in cell[1]:
					worn = str(WardrobeManager.equipped.get(slot,worn))
				button.custom_minimum_size = Vector2(178,48)
				button.alignment = HORIZONTAL_ALIGNMENT_LEFT
				button.tooltip_text = spec[1]+": "+_name(worn)
				for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
					var box := button.get_theme_stylebox(state).duplicate() as StyleBox
					box.content_margin_left = 50
					button.add_theme_stylebox_override(state,box)
				var icon := TTItemIcon.new()
				icon.item_id = StringName(worn)
				icon.rarity = ItemKinds.rarity_of(worn)
				icon.id_fallback = false
				icon.size = Vector2(32,32)
				button.add_child(icon)
				button.resized.connect(_place_icon.bind(button,icon))
				_place_icon(button,icon)
		filter_buttons.append(button)
	if tab == 1:
		L.label(filters,tr("GARDEROBE_WORN"),"Heavy17")
		for slot in EconomyManager.equipment:
			var id := str(EconomyManager.equipment[slot])
			var label := L.label(filters,_name(id),"Muted14")
			label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			label.custom_minimum_size.x = 178

func _place_icon(button: Button, icon: Control) -> void:
	icon.position = Vector2(10,(button.size.y-32)/2)

func _filter(key: String) -> void:
	filter = key
	selected_id = ""
	_refresh_texts()
	_initial_focus().grab_focus()

func _build_items() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var restore := focus in item_buttons
	L.clear(grid)
	item_buttons.clear()
	var ids: Array = ItemKinds.all_ids("clothing") if tab == 0 and show_all else WardrobeManager.owned_ids() if tab == 0 else EconomyManager.loadout_ids()
	ids = Rarity.sorted(ids,func(id): return ItemKinds.rarity_of(id),func(id): return str(id))
	var selection := ButtonGroup.new()
	selection.set_meta("tt_value_selection",true)
	for value in ids:
		var id := str(value)
		var category := str(ItemKinds.def(id).get("category",""))
		if tab == 1 and EconomyManager.equip_slot_of(id) == "":
			continue
		if filter != "" and not _matches(id):
			continue
		var button: Button = SLOT.instantiate()
		button.button_group = selection
		button.custom_minimum_size = Vector2(56,56)
		# Reserve the theme's external focus ring inside the clipped viewport.
		# Scroll the padded cell, so first/last rows retain the whole ring too.
		var cell := L.margin(grid,6)
		cell.add_child(button)
		button.focus_entered.connect(func(): _scroll_to_cell.call_deferred(cell))
		button.setup_item(StringName(id),0)
		button.tooltip_text = _name(id)
		button.modulate.a = 1.0 if _owned(id) else 0.45
		button.pressed.connect(_activate.bind(id))
		item_buttons.append(button)
	owned_label.text = tr("GARDEROBE_COUNT_FMT") % item_buttons.size()
	if item_buttons.is_empty():
		var empty_label := L.label(grid,tr("GARDEROBE_EMPTY"),"Body",true)
		empty_label.custom_minimum_size.x = 380
	if restore:
		_initial_focus().grab_focus()

func _scroll_to_cell(cell: Variant) -> void:
	# A queued focus notification may outlive the grid rebuild it came from.
	if is_instance_valid(cell) and item_scroll.is_ancestor_of(cell):
		item_scroll.ensure_control_visible(cell)

func _matches(id: String) -> bool:
	if tab == 1:
		return str(ItemKinds.def(id).get("category","")) == filter
	for cell in CELLS:
		if cell[0] == filter:
			return WardrobeManager.slot_of(id) in cell[1]
	return true

func _owned(id: String) -> bool:
	return WardrobeManager.count_total(id) > 0 if tab == 0 else EconomyManager.has_item(StringName(id))

func _name(id: String) -> String:
	return tr(str(ItemKinds.def(id).get("name_key","GARDEROBE_EMPTY_SLOT")))

func _select(id: String) -> void:
	selected_id = id
	var definition := ItemKinds.def(id)
	detail_name.text = _name(id)
	detail_desc.text = tr(str(definition.get("description_key","GARDEROBE_CHOOSE")))
	var slot := WardrobeManager.slot_of(id) if tab == 0 else EconomyManager.equip_slot_of(id)
	var worn := (str(WardrobeManager.equipped.get(slot,"")) == id if tab == 0 else str(EconomyManager.equipped_item(StringName(slot))) == id) and id != ""
	var owned := id != "" and _owned(id)
	var fitted := preview != null and WardrobeCatalog.supports(preview.resolved_id,id)
	UiNav.set_enabled(equip_button,owned and not worn and slot != "" and (tab == 1 or fitted))
	UiNav.set_enabled(remove_button,worn)
	UiNav.set_enabled(assign_button,owned and tab == 1)
	assign_button.visible = tab == 1
	equip_button.text = tr("GARDEROBE_EQUIP")
	remove_button.text = tr("GARDEROBE_REMOVE")
	assign_button.text = tr("GARDEROBE_ASSIGN")
	preview_outfit = WardrobeManager.preview_equipping(id) if tab == 0 and slot != "" else WardrobeManager.outfit()
	if preview_layers != null:
		preview_layers.set_outfit(preview_outfit)
	if preview_held != null:
		preview_held.preview_item = StringName(id) if tab == 1 and id != "" else EconomyManager.equipped_item(&"weapon") if tab == 1 else &""
		preview_held.sync_pose()
	preview_state.text = tr("GARDEROBE_PREVIEW_FMT") % _name(str(preview_held.preview_item)) if tab == 1 and preview_held != null else tr("GARDEROBE_WORN") if worn or id == "" else tr("GARDEROBE_TRYING_FMT") % _name(id)
	status.text = tr("GARDEROBE_CHOOSE") if id == "" else tr("GARDEROBE_NOT_OWNED") if not owned else tr("GARDEROBE_WORN") if worn else ""
	if _assigning != "":
		status.text = tr("GARDEROBE_PICK_HOTBAR")
	for button in item_buttons:
		button.set_pressed_no_signal(str(button.item_id) == id)
	_wire()

func _activate(id: String) -> void:
	_assigning = ""
	_select(id)
	for button in [equip_button,assign_button,remove_button]:
		if UiNav.is_stop(button):
			button.grab_focus()
			break

func _equip() -> void:
	if not is_open() or not is_top() or equip_button.disabled:
		return
	if tab == 0:
		WardrobeManager.equip(selected_id)
	else:
		EconomyManager.equip(StringName(EconomyManager.equip_slot_of(selected_id)),StringName(selected_id))
	_schedule_refresh()

func _remove() -> void:
	if not is_open() or not is_top() or remove_button.disabled:
		return
	if tab == 0:
		WardrobeManager.unequip(WardrobeManager.slot_of(selected_id))
	else:
		EconomyManager.equip(StringName(EconomyManager.equip_slot_of(selected_id)),&"")
	_schedule_refresh()

func _begin_assignment() -> void:
	if tab != 1 or assign_button.disabled:
		return
	_assigning = selected_id
	status.text = tr("GARDEROBE_PICK_HOTBAR")
	hotbar_buttons[0].grab_focus()

func _hotbar(index: int) -> void:
	var player := _player()
	if player == null:
		return
	if _assigning != "":
		if EconomyManager.has_item(StringName(_assigning)):
			EventBus.hotbar_assign_requested.emit(index,StringName(_assigning))
		_assigning = ""
		assign_button.grab_focus()
	else:
		player.hotbar.select(index)
	_schedule_refresh()

func _clear_hotbar() -> void:
	if _player() != null:
		EventBus.hotbar_assign_requested.emit(_player().hotbar.selected,&"")

func _choose_preset(key: String) -> void:
	preset = key
	_refresh_texts()

func _save_preset() -> void:
	WardrobeManager.save_preset(preset)
	_schedule_refresh()

func _load_preset() -> void:
	var result := WardrobeManager.load_preset(preset)
	selected_id = ""
	_refresh_texts()
	if result.ok and not result.missing.is_empty():
		var names: Array = result.missing.map(func(id): return _name(id))
		status.text = tr("GARDEROBE_MISSING_FMT") % ", ".join(names)

func _preview_control(index: int) -> void:
	if preview == null:
		return
	if index < 2:
		preview.set_direction_index(posmod(preview.direction_index + (-1 if index == 0 else 1),8))
	else:
		preview.play_loop(&"idle" if preview.current_clip == &"walk" else &"walk")

func _wire() -> void:
	if grid == null:
		return
	UiNav.wire_row(tabs + [close_button])
	UiNav.wire_ring(filter_buttons)
	UiNav.wire_grid(item_buttons,7,false)
	UiNav.wire_row(rotate_buttons,false)
	UiNav.wire_row([browse_button])
	var actions: Array = [equip_button,remove_button,assign_button].filter(func(button): return UiNav.is_stop(button))
	UiNav.wire_row(actions)
	var presets_group: Array = preset_buttons + [save_preset_button,load_preset_button] if tab == 0 else []
	var hotbar_group: Array = hotbar_buttons + [clear_button] if tab == 1 else []
	UiNav.wire_ring(presets_group)
	UiNav.wire_row(hotbar_group)
	UiNav.wire_groups([tabs+[close_button],filter_buttons,[browse_button] if tab == 0 else [],item_buttons,actions,rotate_buttons,presets_group,hotbar_group],true,false)

static func fixture_setup(node: Node, _host: Node) -> void:
	# Standalone style fixtures have no world/player. Gameplay open() retains
	# its free-actor guard; the fixture uses the same preview and controls.
	if WardrobeManager.owned_ids().is_empty():
		WardrobeManager.reset()
	node._open_for_body("fox")
