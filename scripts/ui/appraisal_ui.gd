extends TTScreen
const L := preload("res://scripts/ui/social/social_layout.gd")
var rows: VBoxContainer
var results: VBoxContainer
var close_button: Button
var one_button: Button
var all_button: Button
var fee_label: Label
var status_label: Label
var gold_label: Label
var result_scroll: ScrollContainer
var selected := ""
var npc_id := &"appraiser_fru_ugle"
var busy := false
func _init() -> void:
	super._init()
	screen_id = &"appraisal_ui"
	modal_name = &"appraisal"
func _ready() -> void:
	super._ready()
	L.scrim(self)
	var book := L.panel(self,"PanelBook",Rect2(140,55,1000,610))
	var body := L.box(L.margin(book,24),true,14)
	var header := L.box(body,false)
	var title := L.label(header,"APPRAISE_TITLE","Display34")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = L.button(header,"APPRAISE_CLOSE","ButtonTertiaryS")
	close_button.pressed.connect(close)
	var columns := L.box(body,false,24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var portrait := L.portrait(columns,"appraiser_fru_ugle",150)
	portrait.get_parent().size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.x = 320
	columns.add_child(scroll)
	var row_margin := L.margin(scroll,6)
	row_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows = L.box(row_margin,true,8) as VBoxContainer
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right := L.box(columns,true,12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold_label = L.label(right,"","Heading22")
	fee_label = L.label(right,"","Body",true)
	one_button = L.button(right,"APPRAISE_ONE","ButtonPrimaryS")
	one_button.pressed.connect(_appraise.bind(1))
	all_button = L.button(right,"","ButtonSecondaryS")
	all_button.pressed.connect(_appraise.bind(12))
	status_label = L.label(right,"","Body",true)
	result_scroll = ScrollContainer.new()
	result_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	result_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(result_scroll)
	results = L.box(result_scroll,true,6) as VBoxContainer
	results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	EventBus.player_inventory_changed.connect(func(_player_id: StringName, inventory) -> void: _inventory_changed(inventory))
	EventBus.gold_changed.connect(func(_player_id: StringName, amount, delta) -> void: _gold_changed(amount, delta))
func open_for_npc(npc: StringName) -> void:
	npc_id = npc
	L.clear(results)
	status_label.text = ""
	super.open()
func _inventory_changed(_items: Dictionary) -> void:
	if is_open() and not busy: _refresh_texts()
func _gold_changed(_gold: int, _delta: int) -> void:
	if is_open() and not busy: _refresh_texts()
func _stones() -> Array:
	var ids := []
	for id in EconomyManager.get_inventory_dict():
		if str(id).begins_with("rough_") and EconomyManager.count_item(StringName(id)) > 0: ids.append(str(id))
	ids.sort()
	return ids
func _refresh_texts() -> void:
	if rows == null: return
	var ids := _stones()
	if selected not in ids: selected = str(ids[0]) if not ids.is_empty() else ""
	L.clear(rows)
	var group := ButtonGroup.new()
	group.set_meta("tt_value_selection",true)
	for id in ids:
		var button := L.button(rows,tr("APPRAISE_STONES_FMT") % [tr(str(ItemKinds.def(id).name_key)),EconomyManager.count_item(StringName(id))])
		button.custom_minimum_size.y = 64
		button.clip_text = true
		button.tooltip_text = button.text
		button.set_meta("item_id",id)
		button.button_group = group
		for state in ["normal","hover","pressed","hover_pressed","disabled","focus"]:
			var box := button.get_theme_stylebox(state).duplicate() as StyleBox
			box.content_margin_left = 76
			button.add_theme_stylebox_override(state,box)
		var icon := RaritySlot.new()
		icon.item_id = StringName(id)
		icon.slot_size = 48
		icon.unknown = true
		var stone := TTItemIcon.resolve("stone")
		if stone.path != "": icon.icon = load(stone.path) as Texture2D
		icon.count = EconomyManager.count_item(StringName(id))
		button.add_child(icon)
		icon.position = Vector2(4,0)
		button.pressed.connect(_select.bind(id))
		button.focus_entered.connect(_select.bind(id))
		button.toggle_mode = true
		button.set_pressed_no_signal(id == selected)
	if ids.is_empty(): L.label(rows,"APPRAISE_NO_STONES","Body",true)
	_update_quote()
func _select(id: String) -> void:
	selected = id
	for node in rows.get_children():
		if node is Button: node.set_pressed_no_signal(str(node.get_meta("item_id","")) == id)
	_update_quote()
func _update_quote() -> void:
	var quote: Dictionary = LootService.appraisal_quote(selected)
	var count := mini(12,EconomyManager.count_item(StringName(selected))) if selected != "" else 0
	var fee := int(quote.get("fee",0))
	fee_label.text = tr("APPRAISE_FEE_FMT") % fee if count > 0 else ""
	gold_label.text = tr("UI_GOLD")+": "+str(EconomyManager.gold)
	all_button.text = tr("APPRAISE_ALL_FMT") % [count,count*fee]
	UiNav.set_enabled(one_button,not busy and count > 0 and EconomyManager.gold >= fee)
	UiNav.set_enabled(all_button,not busy and count > 0 and EconomyManager.gold >= fee*count)
	if count > 0 and EconomyManager.gold < fee: status_label.text = tr("APPRAISE_NO_GOLD")
func _appraise(requested: int) -> void:
	if busy or selected == "": return
	busy = true
	var amount := mini(clampi(requested,1,12),EconomyManager.count_item(StringName(selected)))
	var answers := []
	var failure := {"key":""}
	EconomyManager.defer_notifications(func() -> void:
		for i in amount:
			var result: Dictionary = LootService.appraise(selected,{"save":false})
			if not result.ok:
				failure.key = "APPRAISE_NO_GOLD" if result.reason == &"no_gold" else "APPRAISE_BACKPACK_FULL"
				break
			answers.append(result)
		if not answers.is_empty(): SaveManager.autosave()
	)
	busy = false
	L.clear(results)
	for answer in answers:
		var name := tr(str(ItemKinds.def(answer.gem).get("name_key","")))
		L.label(results,tr("APPRAISE_REVEAL_FMT") % [name,tr("RARITY_"+str(answer.rarity).to_upper())],"Body",true)
	if not answers.is_empty():
		EventBus.game_event.emit(&"appraisal_done",{"npc":str(npc_id),"count":answers.size(),"results":answers.duplicate(true)})
		Svc.static_call("res://scripts/ui/dungeon/loot_reveal.gd",&"appraisal_results",[answers])
	_refresh_texts()
	status_label.text = tr(failure.key) if failure.key != "" else tr("APPRAISE_DONE_FMT") % answers.size()
	if is_open(): _initial_focus().grab_focus()
func _initial_focus() -> Control:
	for row in rows.get_children():
		if row is Button and str(row.get_meta("item_id","")) == selected: return row
	return close_button
func _on_page(step: int) -> void:
	result_scroll.scroll_vertical += step*180
## GameUI keeps the screen (SCREEN_ORDER): closing hides it, the next open_for_npc starts it fresh.
func close() -> void:
	if busy: return
	super.close()
