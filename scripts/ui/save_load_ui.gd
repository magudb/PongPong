extends TTScreen
## Six manual slots, a read-only autosave and (when there is one) the read-only autosave of the previous game. SaveManager owns
## validation, summaries and feedback.
signal slot_selected(slot: int, is_save: bool)
enum Mode { SAVE, LOAD }
var mode: int = Mode.LOAD
var _rows: Array[Button] = []
var _deletes: Array[Button] = []
var _busy := false
var _focused_slot := -1

func _init() -> void:
	super._init()
	screen_id = &"save_load_ui"
	modal_name = &"save_load"
	nested_under = &"pause"

func _ready() -> void:
	super._ready()
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("saveload", Callable(get_script(), &"fixture_setup"))
	%CloseButton.pressed.connect(close)
	%CloseButton.focus_entered.connect(_refresh_hints)
	_refresh_hints()

func open_mode(value: int, opener: Control = null) -> void:
	mode = value
	pauses_tree = get_tree().get_first_node_in_group("world_2d") != null
	super.open(opener)

func _on_panel_toggled(panel: StringName, value: bool) -> void:
	if panel in [&"save_menu", &"load_menu"]:
		if value:
			open_mode(Mode.SAVE if panel == &"save_menu" else Mode.LOAD)
		else:
			close()
	else:
		super._on_panel_toggled(panel, value)

func _initial_focus() -> Control:
	if _focused_slot >= 0 and _focused_slot < _rows.size() and UiNav.is_stop(_rows[_focused_slot]):
		return _rows[_focused_slot]
	var first := UiNav.first_enabled(_rows)
	return first if first != null else %CloseButton

func _refresh_texts() -> void:
	if not is_node_ready():
		return
	%TitleLabel.text = tr("UI_SAVE_GAME" if mode == Mode.SAVE else "UI_LOAD_GAME")
	for child in %SlotList.get_children():
		%SlotList.remove_child(child)
		child.queue_free()
	_rows.clear()
	_deletes.clear()
	for descriptor in SaveManager.describe_slots():
		var slot := int(descriptor.slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		%SlotList.add_child(row)
		var button := Button.new()
		button.name = "Slot%d" % slot
		button.theme_type_variation = &"RowButton"
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
		button.owner = self
		button.unique_name_in_owner = true
		var labels := VBoxContainer.new()
		labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(labels)
		labels.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		labels.offset_left = 16
		labels.offset_right = -16
		labels.offset_top = 5
		labels.add_theme_constant_override("separation", 0)
		var title := Label.new()
		title.theme_type_variation = &"Display20"
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.text = tr("SAVELOAD_AUTO_PREVIOUS") if descriptor.get("is_previous", false) else tr("SAVELOAD_AUTO") if descriptor.is_auto else tr("SAVELOAD_SLOT") % (slot + 1)
		labels.add_child(title)
		var detail := Label.new()
		detail.theme_type_variation = &"Muted13"
		detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail.text = _summary(descriptor)
		if descriptor.state in ["newer", "corrupt", "backup"]:
			detail.add_theme_color_override("font_color", preload("res://scripts/ui/theme/tt_colors.gd").THORNBERRY)
		labels.add_child(detail)
		UiNav.set_enabled(button, (not descriptor.is_auto) if mode == Mode.SAVE else descriptor.state in ["ok", "backup"])
		button.pressed.connect(func(): _on_slot_pressed(slot))
		button.focus_entered.connect(func(): _focused_slot = slot; _refresh_hints())
		_rows.append(button)
		var remove := Button.new()
		remove.name = "Delete%d" % slot
		remove.text = tr("SAVELOAD_DELETE")
		remove.theme_type_variation = &"ButtonTertiary"
		remove.custom_minimum_size = Vector2(80, 56)
		row.add_child(remove)
		remove.owner = self
		remove.unique_name_in_owner = true
		UiNav.set_enabled(remove, not descriptor.is_auto and descriptor.state != "empty")
		remove.modulate.a = 0.0 if descriptor.is_auto else 1.0
		remove.pressed.connect(func(): _on_delete_pressed(slot))
		remove.focus_entered.connect(func(): _focused_slot = slot; _refresh_hints())
		_deletes.append(remove)
	_wire()

func _summary(descriptor: Dictionary) -> String:
	var state := str(descriptor.state)
	if state == "empty":
		return tr("SAVELOAD_EMPTY")
	if state in ["newer", "corrupt"]:
		return tr("SAVELOAD_STATE_" + state.to_upper())
	var summary: Dictionary = descriptor.summary
	var info := "%s · %s · %s %d · %d %s · %s" % [summary.player_name, summary.farm_name, tr("UI_DAY"), summary.total_day, summary.gold, tr("UI_GOLD"), preload("res://scripts/ui/theme/tt_format.gd").clock(summary.hour, summary.minute)]
	# when it was saved in the real world and how long it has been played: two "Dag 12" saves of siblings tell apart
	for part in [saved_ago(float(summary.get("saved_at", 0.0)), _now()), played(float(summary.get("play_time_seconds", 0.0)))]:
		if part != "":
			info += " · " + part
	return info + (" · " + tr("SAVELOAD_STATE_BACKUP") if state == "backup" else "")

## The run of a slot as a confirm names it: "Rosenhaven, dag 12 · gemt for 2 t. siden" (the player's name for a farm without one).
func run_name(slot: int) -> String:
	var summary: Dictionary = SaveManager.get_save_summary(slot)
	if summary.is_empty():
		return tr("SAVELOAD_SLOT") % (slot + 1)
	var who := str(summary.get("farm_name", ""))
	var text: String = tr("SAVELOAD_RUN_NAME") % [who if who != "" else str(summary.get("player_name", "")), int(summary.get("total_day", 1))]
	var ago := saved_ago(float(summary.get("saved_at", 0.0)), _now())
	return text + (" · " + ago if ago != "" else "")

func _now() -> float:
	return SaveManager.clock_override if SaveManager.clock_override >= 0.0 else Time.get_unix_time_from_system()

## "gemt for 2 t. siden": the real time since `saved_at` (unix seconds); "" when the save does not know it. Older than a month: the date.
func saved_ago(saved_at: float, now: float) -> String:
	if saved_at <= 0.0:
		return ""
	var seconds := maxf(0.0, now - saved_at)
	if seconds < 60.0:
		return tr("SAVELOAD_SAVED_NOW")
	if seconds < 3600.0:
		return tr("SAVELOAD_SAVED_MINUTES") % int(seconds / 60.0)
	if seconds < 86400.0:
		return tr("SAVELOAD_SAVED_HOURS") % int(seconds / 3600.0)
	if seconds < 2.0 * 86400.0:
		return tr("SAVELOAD_SAVED_YESTERDAY")
	if seconds < 31.0 * 86400.0:
		return tr("SAVELOAD_SAVED_DAYS") % int(seconds / 86400.0)
	var date := Time.get_date_dict_from_unix_time(int(saved_at + float(Time.get_time_zone_from_system().get("bias", 0)) * 60.0))
	return tr("SAVELOAD_SAVED_DATE") % ("%d.%d.%d" % [date.day, date.month, date.year])

## "spillet 3 t. 12 min.": the play time of a save; "" before the first minute.
func played(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	if minutes <= 0:
		return ""
	if minutes < 60:
		return tr("SAVELOAD_PLAYED_MINUTES") % minutes
	return tr("SAVELOAD_PLAYED_HOURS") % [minutes / 60, minutes % 60]

func _wire() -> void:
	UiNav.wire_ring(_rows + [%CloseButton])
	UiNav.wire_ring(_deletes + [%CloseButton])
	for index in _rows.size():
		UiNav.link(_rows[index], &"right", _deletes[index] if UiNav.is_stop(_deletes[index]) else _rows[index])
		UiNav.link(_rows[index], &"left", _deletes[index] if UiNav.is_stop(_deletes[index]) else _rows[index])
		UiNav.link(_deletes[index], &"left", _rows[index] if UiNav.is_stop(_rows[index]) else %CloseButton)
		UiNav.link(_deletes[index], &"right", _rows[index] if UiNav.is_stop(_rows[index]) else %CloseButton)
	var enabled_rows: Array = _rows.filter(func(row): return UiNav.is_stop(row))
	UiNav.link(%CloseButton, &"up", enabled_rows[-1] if not enabled_rows.is_empty() else %CloseButton)
	UiNav.link(%CloseButton, &"down", enabled_rows[0] if not enabled_rows.is_empty() else %CloseButton)
	UiNav.hover_focus(_rows + _deletes + [%CloseButton])

## The delete keys are the InputMap's ui_text_delete (Delete) and ui_text_backspace (the key a Mac labels "delete"). They act on the
## row that HAS focus right now (its slot button or its Slet), never on a row focused earlier: on Luk they do nothing. A pad reaches
## the same Slet button with the D-pad (the frozen P01 input contract has no pad binding to spare for it).
func _input(event: InputEvent) -> void:
	if is_open() and is_top() and _is_delete_key(event):
		var slot := _slot_of(get_viewport().gui_get_focus_owner())
		if slot >= 0 and UiNav.is_stop(_deletes[slot]):
			_on_delete_pressed(slot)
		get_viewport().set_input_as_handled()
		return
	super._input(event)

static func _is_delete_key(event: InputEvent) -> bool:
	return event.is_action_pressed(&"ui_text_delete") or event.is_action_pressed(&"ui_text_backspace")

## The slot whose row `control` belongs to (its button or its Slet), -1 for anything else.
func _slot_of(control: Control) -> int:
	var at := _rows.find(control)
	return at if at >= 0 else _deletes.find(control)

func _refresh_hints() -> void:
	var hints: Array = [{"action": &"ui_accept", "key": "HINT_OK"}]
	var slot := _slot_of(get_viewport().gui_get_focus_owner()) if is_inside_tree() else -1
	if slot >= 0 and slot < _deletes.size() and UiNav.is_stop(_deletes[slot]):
		hints.append({"action": &"ui_text_delete", "key": "HINT_DELETE"})          # only while the focused row has a Slet
	hints.append({"action": &"ui_cancel", "key": "HINT_BACK"})
	%HintBar.set_hints(hints)

func _on_slot_pressed(slot: int) -> void:
	if _busy or slot < 0 or slot >= _rows.size() or not UiNav.is_stop(_rows[slot]):
		return
	_busy = true
	var needs_confirm: bool = mode == Mode.LOAD and get_tree().get_first_node_in_group("world_2d") != null or mode == Mode.SAVE and SaveManager.inspect_slot(slot).state != "empty"
	var accepted := true
	if needs_confirm:
		accepted = await UiConfirm.ask(self, "SAVELOAD_CONFIRM", tr("SAVELOAD_OVERWRITE") % run_name(slot) if mode == Mode.SAVE else tr("SAVELOAD_LOAD_CONFIRM"), "NAV_OK")
	if accepted and is_open():
		if mode == Mode.SAVE:
			if SaveManager.save_game(slot):
				slot_selected.emit(slot, true)
				_refresh_texts()
				_initial_focus().grab_focus()
		else:
			if SaveManager.load_and_enter(slot):
				slot_selected.emit(slot, false)
	_busy = false

func _on_delete_pressed(slot: int) -> void:
	if _busy or slot < 0 or slot >= SaveManager.MANUAL_SLOTS or not UiNav.is_stop(_deletes[slot]):
		return
	_busy = true
	var accepted := await UiConfirm.ask(self, "SAVELOAD_CONFIRM", tr("SAVELOAD_DELETE_CONFIRM") % [run_name(slot), slot + 1], "SAVELOAD_DELETE")
	if accepted and is_open():
		SaveManager.delete_save(slot)
		_refresh_texts()
		_initial_focus().grab_focus()
	_busy = false

static func fixture_setup(node: Node, _host: Node) -> void:
	node.call("open_mode", Mode.LOAD)
