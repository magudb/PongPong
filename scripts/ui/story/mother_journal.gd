class_name MotherJournal
extends Control
const L := preload("res://scripts/ui/social/social_layout.gd")
var buttons: Array[Button] = []
var _rows: VBoxContainer
var _title: Label
var _heading: Label
var _kind: Label
var _text: Label
var _lead: Label
var _selected := ""
var _tabs: Array = []
func _ready() -> void:
	var paper := ColorRect.new()
	paper.color = preload("res://scripts/ui/theme/tt_colors.gd").PARCHMENT
	paper.mouse_filter = MOUSE_FILTER_IGNORE
	paper.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(paper)
	var columns := L.box(self,false,24)
	columns.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var left := L.box(columns,true,10)
	left.custom_minimum_size.x = 340
	_title = L.label(left,tr("FM_JOURNAL_TITLE"),"Display24",true)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_rows = L.box(scroll,true,6) as VBoxContainer
	_rows.size_flags_horizontal = SIZE_EXPAND_FILL
	var right := L.box(columns,true,14)
	right.size_flags_horizontal = SIZE_EXPAND_FILL
	_lead = L.label(right,"","Body",true)
	_heading = L.label(right,"","Display24",true)
	_kind = L.label(right,"","Muted14",true)
	_text = L.label(right,"","Body",true)
	refresh()
func refresh() -> void:
	if not is_node_ready(): return
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	buttons.clear()
	_title.text = tr("FM_JOURNAL_TITLE")
	_lead.text = tr(MotherStory.next_lead())
	var entries := MotherStory.entries()
	if entries.is_empty():
		_heading.text = tr("FM_TAB")
		_kind.text = ""
		_text.text = tr("FM_EMPTY")
		return
	if entries.all(func(row):return str(row.id) != _selected): _selected = str(entries[-1].id)
	for row in entries:
		var button := L.button(_rows,tr("FM_E_"+str(row.id).to_upper()+"_TITLE"),"RowButton")
		button.size_flags_horizontal = SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(330,48)
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(_select.bind(row))
		button.focus_entered.connect(_select.bind(row))
		buttons.append(button)
		if str(row.id) == _selected: _select(row)
	wire_navigation(_tabs)
func _select(row: Dictionary) -> void:
	_selected = str(row.id)
	_heading.text = tr("FM_E_"+_selected.to_upper()+"_TITLE")
	_kind.text = tr("FM_KIND_"+str(row.kind).to_upper())
	_text.text = tr(MotherStory.evidence_text_key(_selected))
func initial_focus() -> Control:
	for button in buttons:
		if button.text == tr("FM_E_"+_selected.to_upper()+"_TITLE"): return button
	return buttons[0] if not buttons.is_empty() else (_tabs[-1] if not _tabs.is_empty() else self)
func wire_navigation(tabs: Array) -> void:
	_tabs = tabs.duplicate()
	UiNav.wire_row(_tabs)
	UiNav.wire_ring(buttons)
	UiNav.wire_groups([_tabs,buttons],true,false)
