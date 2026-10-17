extends TTScreen
const L := preload("res://scripts/ui/social/social_layout.gd")
const Row := preload("res://scripts/ui/towns/post_row.gd")
var rows: Array[Button] = []
var data: Array[Dictionary] = []
var tabs: Array[Button] = []
var list: VBoxContainer
var title: Label
var empty: Label
var footer: Label
var tab := 0
var _cache: Dictionary = {}
func _init() -> void:
	super._init()
	screen_id = &"post"
	modal_name = &"post"
func _ready() -> void:
	super._ready()
	L.scrim(self)
	var panel := L.panel(self,"PanelParchmentL24",Rect2(180,60,920,600))
	var body := L.box(panel,true,12)
	title = L.label(body,"","Display34")
	var strip := L.box(body,false,8)
	var group := ButtonGroup.new()
	for i in 3:
		var button := L.button(strip,"")
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(_set_tab.bind(i))
		tabs.append(button)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	list = L.box(L.margin(scroll,6),true,6) as VBoxContainer
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty = L.label(body,"","Muted14")
	footer = L.label(body,"","Muted14")
	EventBus.game_event.connect(_event)
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("post",Callable(get_script(),&"fixture_setup"))
func _event(id: StringName,_payload: Dictionary) -> void:
	if id == &"open_post_office": open()
func open(opener: Control = null) -> void:
	tab = 0
	super.open(opener)
func _initial_focus() -> Control:
	return rows[0] if not rows.is_empty() else tabs[tab]
func _on_page(step: int) -> void:
	_set_tab(posmod(tab+step,3))
	_initial_focus().grab_focus()
func _set_tab(index: int) -> void:
	tab = index
	_refresh_texts()
func _refresh_texts() -> void:
	if not is_node_ready(): return
	title.text = tr("POST_TITLE")
	data = PostLocations.rows()
	for row in _cache.values():
		row.hide()
		row.focus_mode = Control.FOCUS_NONE
	rows.clear()
	for i in 3:
		var group: String = PostLocations.GROUPS[i]
		tabs[i].text = tr("POST_GROUP_"+group.to_upper())+" (%d)" % data.filter(func(r):return r.group == group).size()
		tabs[i].set_pressed_no_signal(i == tab)
	for entry in data:
		if entry.group != PostLocations.GROUPS[tab]: continue
		var row: Button = _cache.get(str(entry.id))
		if row == null:
			row = Row.new()
			row.theme_type_variation = &"RowButton"
			row.custom_minimum_size = Vector2(0,60)
			list.add_child(row)
			_cache[str(entry.id)] = row
		row.setup(entry)
		row.show()
		row.focus_mode = Control.FOCUS_ALL
		list.move_child(row,rows.size())
		rows.append(row)
	empty.text = tr("POST_EMPTY")
	empty.visible = rows.is_empty()
	footer.text = tr("POST_HINT") % UiHints.glyph(&"ui_cancel")
	UiNav.wire_row(tabs)
	UiNav.wire_ring(rows)
	UiNav.wire_groups([tabs,rows],true,false)
	UiNav.hover_focus(rows)
func _input(event: InputEvent) -> void:
	if is_open() and is_top() and event.is_pressed() and (event.is_action_pressed(&"ui_left") or event.is_action_pressed(&"ui_right")):
		if get_viewport().gui_get_focus_owner() in rows:
			tabs[tab].grab_focus()
			get_viewport().set_input_as_handled()
			return
	if is_open() and is_top() and event.is_pressed() and (event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"ui_down")):
		var owner := get_viewport().gui_get_focus_owner()
		if owner in rows:
			var index := rows.find(owner)+(1 if event.is_action_pressed(&"ui_down") else -1)
			if not event.is_echo() or (index >= 0 and index < rows.size()): rows[posmod(index,rows.size())].grab_focus()
			get_viewport().set_input_as_handled()
			return
	super._input(event)
static func fixture_setup(node: Node,_host: Node) -> void:
	GameManager.day = 3
	GameManager.hour = 17
	GameManager.minute = 0
	for id in SocialData.friend_ids(): SocialManager.debug_set_hearts(id,3)
	node.open()
