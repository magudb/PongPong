extends Control
## Quest journal: active quests, completed quests, details.

@onready var tab_container: TabContainer = %TabContainer
@onready var active_list: VBoxContainer = %ActiveList
@onready var completed_list: VBoxContainer = %CompletedList
@onready var detail_panel: VBoxContainer = %DetailPanel
@onready var close_btn: Button = %CloseButton

var _selected_quest: StringName = &""


func _ready() -> void:
	visible = false
	close_btn.pressed.connect(func(): visible = false; EventBus.ui_panel_toggled.emit(&"journal", false))
	EventBus.ui_panel_toggled.connect(_on_panel_toggled)
	EventBus.quest_accepted.connect(func(_id): _refresh())
	EventBus.quest_completed.connect(func(_id): _refresh())
	EventBus.quest_objective_updated.connect(func(_q, _o, _p, _t): _refresh())


func _refresh() -> void:
	for child in active_list.get_children():
		child.queue_free()
	for child in completed_list.get_children():
		child.queue_free()

	for quest in QuestManager.get_active_quests():
		var btn := Button.new()
		btn.text = tr("QUEST_%s_TITLE" % str(quest.id).to_upper())
		btn.pressed.connect(func(): _show_details(quest.id))
		active_list.add_child(btn)

	for qid in QuestManager.completed_quests:
		var label := Label.new()
		label.text = "✓ " + tr("QUEST_%s_TITLE" % str(qid).to_upper())
		label.modulate = Color(0.6, 1.0, 0.6)
		completed_list.add_child(label)


func _show_details(quest_id: StringName) -> void:
	_selected_quest = quest_id
	for child in detail_panel.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = tr("QUEST_%s_TITLE" % str(quest_id).to_upper())
	title.add_theme_font_size_override("font_size", 22)
	detail_panel.add_child(title)

	var progress: Dictionary = QuestManager.get_quest_progress(quest_id)
	for obj_id in progress.get("objectives", {}):
		var obj: Dictionary = progress["objectives"][obj_id]
		var obj_label := Label.new()
		var check := "✓ " if obj["done"] else "  "
		obj_label.text = "%s%s (%d/%d)" % [check, tr("OBJ_%s" % str(obj_id).to_upper()), obj["current"], obj["target"]]
		if obj["done"]:
			obj_label.modulate = Color(0.6, 1.0, 0.6)
		detail_panel.add_child(obj_label)


func _on_panel_toggled(panel: StringName, is_open: bool) -> void:
	if panel == &"journal":
		visible = is_open
		if is_open:
			_refresh()
