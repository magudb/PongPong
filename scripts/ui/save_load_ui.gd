extends Control
## Save/Load UI: slot browser with summaries, overwrite/delete confirmation.

signal slot_selected(slot: int, is_save: bool)

enum Mode { SAVE, LOAD }

@export var mode: int = Mode.LOAD

@onready var title_label: Label = %TitleLabel
@onready var slot_list: VBoxContainer = %SlotList
@onready var confirm_dialog: ConfirmationDialog = %ConfirmDialog
@onready var delete_dialog: ConfirmationDialog = %DeleteDialog
@onready var info_label: Label = %InfoLabel
@onready var close_btn: Button = %CloseButton

const MAX_SLOTS := 6

var _selected_slot: int = -1
var _pending_action: String = ""
## The request name that opened the panel ("save_menu" | "load_menu"): the modal it pushes and the toggle it answers.
var _open_panel: StringName = &""


func _ready() -> void:
	visible = false
	close_btn.pressed.connect(_close)
	confirm_dialog.confirmed.connect(_on_confirm)
	delete_dialog.confirmed.connect(_on_delete_confirm)
	EventBus.ui_panel_toggled.connect(_on_panel_toggled)
	_populate_slots()


func open(save_mode: int, panel: StringName = &"save_menu") -> void:
	mode = save_mode
	_open_panel = panel
	title_label.text = tr("UI_SAVE_GAME") if mode == Mode.SAVE else tr("UI_LOAD_GAME")
	visible = true
	_populate_slots()
	GameManager.push_modal(&"save_load")


## Esc is this panel's key (while it is the top modal): closes the browser, not the pause menu under it.
func _unhandled_input(event: InputEvent) -> void:
	if visible and GameManager.top_modal() == &"save_load" and event.is_action_pressed(&"ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()


func _populate_slots() -> void:
	for child in slot_list.get_children():
		child.queue_free()

	for i in MAX_SLOTS:
		var slot_container := HBoxContainer.new()
		slot_container.custom_minimum_size = Vector2(0, 80)

		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 70)

		var summary := SaveManager.get_save_summary(i)
		if summary.is_empty():
			btn.text = tr("UI_EMPTY_SLOT") % (i + 1)
			btn.disabled = mode == Mode.LOAD
		else:
			var season_key := "UI_SEASON_%s" % str(summary.get("season", "foraar")).to_upper()
			btn.text = "%s\n%s %d • %s • %d %s\n%s" % [
				summary.get("player_name", ""),
				tr("UI_DAY"), summary.get("day", 1),
				tr(season_key),
				summary.get("gold", 0), tr("UI_GOLD"),
				_format_playtime(float(summary.get("play_time_seconds", 0))),
			]

		var slot_idx := i
		btn.pressed.connect(func(): _on_slot_pressed(slot_idx))

		var delete_btn := Button.new()
		delete_btn.text = "✕"
		delete_btn.custom_minimum_size = Vector2(50, 70)
		delete_btn.disabled = summary.is_empty()
		delete_btn.pressed.connect(func(): _on_delete_pressed(slot_idx))

		slot_container.add_child(btn)
		slot_container.add_child(delete_btn)
		slot_list.add_child(slot_container)

	info_label.text = tr("UI_SAVE_INFO") if mode == Mode.SAVE else tr("UI_LOAD_INFO")


func _on_slot_pressed(slot: int) -> void:
	_selected_slot = slot
	var summary := SaveManager.get_save_summary(slot)

	if summary.is_empty():
		# Direct save to empty slot
		if mode == Mode.SAVE:
			_pending_action = "save"
			confirm_dialog.dialog_text = tr("UI_CONFIRM_SAVE") % (slot + 1)
			confirm_dialog.popup_centered()
		return

	if mode == Mode.SAVE:
		_pending_action = "overwrite"
		confirm_dialog.dialog_text = tr("UI_CONFIRM_OVERWRITE") % (slot + 1)
		confirm_dialog.popup_centered()
	else:
		_pending_action = "load"
		confirm_dialog.dialog_text = tr("UI_CONFIRM_LOAD") % (slot + 1)
		confirm_dialog.popup_centered()


func _on_delete_pressed(slot: int) -> void:
	_selected_slot = slot
	_pending_action = "delete"
	delete_dialog.dialog_text = tr("UI_CONFIRM_DELETE") % (slot + 1)
	delete_dialog.popup_centered()


func _on_confirm() -> void:
	match _pending_action:
		"save", "overwrite":
			if SaveManager.save_game(_selected_slot):
				_populate_slots()
				slot_selected.emit(_selected_slot, true)
				EventBus.notification_posted.emit(tr("NOTIF_SAVED_TITLE"), tr("NOTIF_SAVED_MSG") % (_selected_slot + 1), "save")
		"load":
			# a failed load keeps the browser open (load_and_enter already posted the failure notification);
			# on success it pops every modal itself and enters the world
			if SaveManager.load_and_enter(_selected_slot):
				visible = false
				_open_panel = &""
				slot_selected.emit(_selected_slot, false)
	_pending_action = ""


func _on_delete_confirm() -> void:
	if _pending_action == "delete":
		SaveManager.delete_save(_selected_slot)
		_populate_slots()
		EventBus.notification_posted.emit(tr("UI_DELETED_TITLE"), tr("UI_DELETED_MSG") % (_selected_slot + 1), "save")
	_pending_action = ""


func _format_playtime(seconds: float) -> String:
	var hours := int(seconds) / 3600
	var minutes := (int(seconds) % 3600) / 60
	return "%dt %dm" % [hours, minutes]


func _close() -> void:
	visible = false
	var panel := _open_panel
	_open_panel = &""
	GameManager.pop_modal(&"save_load")
	if panel != &"":
		EventBus.ui_panel_toggled.emit(panel, false)


func _on_panel_toggled(panel: StringName, is_open: bool) -> void:
	if panel == &"save_menu" or panel == &"load_menu":
		if is_open:
			open(Mode.SAVE if panel == &"save_menu" else Mode.LOAD, panel)
		elif _open_panel == panel:
			_close()
