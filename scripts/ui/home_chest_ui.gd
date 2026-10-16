extends TTScreen
const L := preload("res://scripts/ui/social/social_layout.gd")
var lists: Array[VBoxContainer] = []
var counters: Array[Label] = []
var close_button: Button
var status: Label
func _init() -> void:
	super._init()
	screen_id = &"home_chest"
	modal_name = &"home_chest"
func _ready() -> void:
	super._ready()
	L.scrim(self)
	var book := L.panel(self,"PanelBook",Rect2(100,65,1080,590))
	var body := L.box(L.margin(book,20),true,12)
	var header := L.box(body,false)
	var title := L.label(header,"KISTE_TITLE","Display34")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = L.button(header,"HINT_CLOSE","ButtonTertiaryS")
	close_button.pressed.connect(close)
	var columns := L.box(body,false,24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for index in 2:
		var column := L.box(columns,true,10)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		counters.append(L.label(column,"","Heading22"))
		var scroll := ScrollContainer.new()
		scroll.follow_focus = true
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(scroll)
		var list := L.box(scroll,true,6) as VBoxContainer
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lists.append(list)
	status = L.label(body,"KISTE_HINT","Muted14",true)
	EventBus.game_event.connect(func(event, _payload):
		if event == &"open_home_chest": open())
	HomeManager.chest_changed.connect(func():
		if is_open(): _refresh_texts.call_deferred())
func _initial_focus() -> Control:
	return close_button
func _refresh_texts() -> void:
	if lists.is_empty():
		return
	counters[0].text = tr("KISTE_BACKPACK_FMT") % [EconomyManager.used_slots(),24]
	counters[1].text = tr("KISTE_STORAGE_FMT") % [HomeManager.chest_used(),HomeManager.chest_capacity()]
	for index in 2:
		L.clear(lists[index])
		var items: Dictionary = EconomyManager.get_inventory_dict() if index == 0 else HomeManager.chest_items()
		if items.is_empty():
			L.label(lists[index],"KISTE_EMPTY","Muted14")
		for id in items:
			var row := L.box(lists[index],false,5)
			var icon := TTItemIcon.new()
			icon.item_id = StringName(str(id))
			icon.custom_minimum_size = Vector2(36,36)
			row.add_child(icon)
			var label := L.label(row,"%s ×%d" % [L.item_name(str(id)),items[id]],"Small14",true)
			label.custom_minimum_size.x = 190
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for all_items in [false,true]:
				var button := L.button(row,"KISTE_ALL" if all_items else "KISTE_ONE","ButtonTertiaryS")
				button.pressed.connect(_transfer.bind(str(id),int(items[id]) if all_items else 1,index == 0))
func _transfer(id: String, amount: int, deposit: bool) -> void:
	var moved := HomeManager.deposit(StringName(id),amount) if deposit else HomeManager.withdraw(StringName(id),amount)
	_refresh_texts()
	status.text = tr("KISTE_MOVED_FMT") % moved if moved > 0 else tr("KISTE_FULL")
