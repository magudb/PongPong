extends TTScreen
const L := preload("res://scripts/ui/social/social_layout.gd")
var selected := ""
var layer_filter := "all"
var rarity_filter := "all"
var cell := Vector2i.ZERO
var rot := 0
var placing := false
var panel: PanelContainer
var title: Label
var hygge: Label
var sets: Label
var listing: VBoxContainer
var reason: Label
var choose_button: Button
var close_button: Button
var _preview: Node2D
var _refreshing := false
var _filters: Array[Button] = []
var pickup_button: Button
func _init() -> void:
	super._init()
	screen_id = &"indretning"
	modal_name = &"indretning"
	hotkey_action = &"decorate"
	wasd_navigation = false
func _ready() -> void:
	super._ready()
	panel = L.panel(self,"PanelBook",Rect2(24,80,340,590))
	var body := L.box(L.margin(panel,16),true,8)
	var header := L.box(body,false,6)
	title = L.label(header,"INDRET_TITLE","Heading22")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = L.button(header,"HINT_CLOSE","ButtonTertiaryS")
	close_button.pressed.connect(close)
	hygge = L.label(body,"","Small14",true)
	sets = L.label(body,"","Muted14",true)
	var layer_row := GridContainer.new()
	layer_row.columns = 3
	body.add_child(layer_row)
	for filter in ["all","floor","wall","tabletop","ceiling","rug"]:
		var button := L.button(layer_row,"INDRET_LAYER_" + filter.to_upper(),"ButtonTertiaryS")
		_filters.append(button)
		button.pressed.connect(func(): layer_filter = filter; _refresh_texts())
	var rarity_row := GridContainer.new()
	rarity_row.columns = 3
	body.add_child(rarity_row)
	for rarity in ["all","normal","uncommon","rare","unique","legendary"]:
		var button := L.button(rarity_row,"INDRET_RARITY_" + rarity.to_upper(),"ButtonTertiaryS")
		_filters.append(button)
		button.pressed.connect(func(): rarity_filter = rarity; _refresh_texts())
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	listing = L.box(scroll,true,4) as VBoxContainer
	listing.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reason = L.label(body,"","Small14",true)
	choose_button = L.button(body,"INDRET_PLACE","ButtonPrimary")
	choose_button.pressed.connect(_start_placing)
	pickup_button = L.button(body,"INDRET_PICKUP_MODE","ButtonSecondaryS")
	pickup_button.pressed.connect(func(): placing = true; UiNav.release_world_focus())
	L.label(body,"INDRET_HINT","Muted14",true)
	EventBus.furniture_changed.connect(func(_why):
		if is_open(): _refresh_texts.call_deferred())
func _world() -> Node:
	return get_tree().get_first_node_in_group("world_2d")
func _hotkey_open_allowed() -> bool:
	var world := _world()
	if world == null or world.area == null or world.area.map.id != &"home":
		EventBus.whisper_requested.emit("INDRET_ONLY_HOME")
		return false
	return true
func open(opener: Control = null) -> void:
	if not _hotkey_open_allowed(): return
	cell = FurnitureManager.ensure_grid().spawn_cell
	placing = false
	super.open(opener)
	if is_open():
		FurnitureManager.decorate_mode = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE
func close() -> void:
	placing = false
	FurnitureManager.decorate_mode = false
	if is_instance_valid(_preview): _preview.queue_free()
	_preview = null
	super.close()
func _initial_focus() -> Control:
	return close_button
func _wants_focus() -> bool:
	return not placing
func _refresh_texts() -> void:
	if listing == null: return
	var level := HomeData.hygge_level(FurnitureManager.hygge_level_index())
	hygge.text = tr("INDRET_HYGGE_FMT") % [tr(str(level.get("name_key",""))),FurnitureManager.hygge_score(),FurnitureManager.ensure_grid().placements.size(),HomeManager.furniture_capacity()]
	var active: Array[String] = []
	for id in FurnitureManager.active_sets():
		var row: Dictionary = FurnitureManager.active_sets()[id]
		if row.pieces > 0:
			active.append("%s %d" % [tr(str(LuaData.dict(Svc.lua_config("furniture_sets", {}))[id].name_key)),row.pieces])
	sets.text = ", ".join(active)
	L.clear(listing)
	var ids: Array = FurnitureManager.stock.keys()
	ids.sort()
	var shown := 0
	var stock_buttons: Array = []
	for id in ids:
		var art: Dictionary = HomeData.furniture().get(id,{})
		if (layer_filter != "all" and art.get("layer","") != layer_filter) or (rarity_filter != "all" and str(ItemKinds.rarity_of(id)) != rarity_filter): continue
		shown += 1
		var row := L.box(listing,false,6)
		var icon := TTItemIcon.new()
		icon.item_id = StringName(id)
		icon.custom_minimum_size = Vector2(40,40)
		row.add_child(icon)
		var button := L.button(row,"%s ×%d" % [L.item_name(id),FurnitureManager.count_stock(id)],"ButtonTertiaryS")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stock_buttons.append(button)
		button.toggle_mode = true
		button.button_pressed = id == selected
		button.pressed.connect(func(): selected = id; rot = 0; _start_placing(); _refresh_texts())
	if shown == 0:
		L.label(listing,"INDRET_EMPTY","Muted14",true)
	choose_button.disabled = selected == "" or FurnitureManager.count_stock(selected) <= 0
	choose_button.focus_mode = Control.FOCUS_NONE if choose_button.disabled else Control.FOCUS_ALL
	UiNav.wire_grid(_filters,3)
	UiNav.wire_ring(stock_buttons)
	UiNav.wire_row([choose_button,pickup_button,close_button])
	UiNav.wire_groups([_filters,stock_buttons,[choose_button,pickup_button,close_button]],true,false)
func _start_placing() -> void:
	if selected == "" or FurnitureManager.count_stock(selected) <= 0: return
	placing = true
	UiNav.release_world_focus()
func _process(dt: float) -> void:
	super._process(dt)
	if not is_open(): return
	var world := _world()
	if world == null or world.area.map.id != &"home":
		close()
		return
	if not is_instance_valid(_preview) or _preview.is_queued_for_deletion() or _preview.get_parent() != world.area:
		_preview = load("res://scripts/home/placement_controller.gd").new()
		world.area.add_child(_preview)
	var check: Dictionary = _preview.update_preview(selected,cell,rot)
	reason.text = tr(str(check.get("text_key",""))) if not check.ok else tr("INDRET_READY")
func _input(event: InputEvent) -> void:
	if not is_open() or not is_top():
		super._input(event)
		return
	if event is InputEventMouseMotion and not panel.get_global_rect().has_point(event.position):
		var world := _world()
		if world != null:
			var position: Vector2 = world.area.get_global_mouse_position()
			cell = Vector2i(HomeData.local_to_cell(world.area.to_local(position)).round())
	if event is InputEventMouseButton and event.pressed and not panel.get_global_rect().has_point(event.position):
		if event.button_index == MOUSE_BUTTON_LEFT: _place()
		elif event.button_index == MOUSE_BUTTON_RIGHT: _pickup()
		elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]: _rotate(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
		get_viewport().set_input_as_handled()
		return
	if placing:
		var handled := true
		if event.is_action_pressed("ui_left",true): cell.x -= 1
		elif event.is_action_pressed("ui_right",true): cell.x += 1
		elif event.is_action_pressed("ui_up",true): cell.y -= 1
		elif event.is_action_pressed("ui_down",true): cell.y += 1
		elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"): _place()
		elif (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y): _rotate(1)
		elif (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_X) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X): _pickup()
		else: handled = false
		if handled:
			cell.x = clampi(cell.x,-1,30)
			cell.y = clampi(cell.y,-1,30)
			get_viewport().set_input_as_handled()
			return
	super._input(event)
func _rotate(step: int) -> void:
	var art: Dictionary = HomeData.furniture().get(selected,{})
	rot = posmod(rot + step,2 if art.get("layer","") == "wall" else 4)
func _place() -> void:
	if selected == "": return
	var result: Dictionary = FurnitureManager.place_from_stock(selected,cell,rot)
	if not result.ok:
		reason.text = tr(str(result.get("text_key","FURNI_REJECT_UNKNOWN_ITEM")))
	else:
		_refresh_texts()
func _pickup() -> void:
	var grid := FurnitureManager.ensure_grid()
	for layer in ["tabletop","wall","ceiling","floor","rug"]:
		for uid in grid.placements.keys():
			var piece: Dictionary = grid.placements[uid]
			if piece.layer == layer and (piece.cell == cell or cell in grid.footprint_cells(piece.item_id,piece.cell,piece.rot)):
				FurnitureManager.pickup(uid)
				_refresh_texts()
				return

func _on_cancel() -> void:
	if placing:
		placing = false
		_apply_initial_focus()
	else:
		close()
