extends TTScreen
const L := preload("res://scripts/ui/social/social_layout.gd")
var rows: VBoxContainer
var close_button: Button
var detail: Label
var selected := 1
func _init() -> void:
	super._init()
	screen_id = &"rune_picker"
	modal_name = &"rune_picker"
func _ready() -> void:
	super._ready()
	L.scrim(self)
	var book := L.panel(self,"PanelBook",Rect2(300,65,680,590))
	var body := L.box(L.margin(book,24),true,14)
	var header := L.box(body,false)
	var title := L.label(header,"RUNE_PICKER_TITLE","Display34")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = L.button(header,"HINT_CLOSE","ButtonTertiaryS")
	close_button.pressed.connect(close)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	rows = L.box(scroll,true,6) as VBoxContainer
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail = L.label(body,"","Body",true)
func _refresh_texts() -> void:
	if rows == null: return
	L.clear(rows)
	var floors := DungeonFloors.inst()
	if floors == null: return
	for number in floors.start_floors():
		var band: Dictionary = floors.cfg.bands.get(floors.band_of(number),{})
		var button := L.button(rows,tr("RUNE_PICKER_START") if number == 1 else tr("RUNE_PICKER_FLOOR_FMT") % [number,tr(str(band.get("name_key","")))])
		button.pressed.connect(func(): close(); floors.enter(number))
		button.focus_entered.connect(_select.bind(number))
	_select(selected)
func _select(number: int) -> void:
	selected = number
	var lines: Variant = Svc.static_call("res://scripts/dungeon_run/dungeon_run.gd",&"picker_lines",[number],[])
	var texts: Array[String] = []
	for row in LuaData.arr(lines):
		texts.append(str(row.get("text","")) if row is Dictionary else str(row))
	detail.text = "\n".join(texts)
func _initial_focus() -> Control:
	return rows.get_child(0) as Control if rows.get_child_count() > 0 else close_button
