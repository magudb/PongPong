class_name CurrentItemBadge
extends PanelContainer
## Persistent, translated readout of the player's resolved action/ready item.
## It never interprets inventory selection independently of the controller.
var item_icon: TTItemIcon
var item_name: Label
var context_label: Label
var _player: WeakRef
var _snapshot: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	theme_type_variation = &"PanelCard"
	var box := get_theme_stylebox("panel").duplicate() as StyleBox
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	item_icon = TTItemIcon.new()
	item_icon.custom_minimum_size = Vector2(34, 34)
	item_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_icon.id_fallback = false
	row.add_child(item_icon)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	row.add_child(words)
	context_label = Label.new()
	context_label.theme_type_variation = &"EyebrowL"
	context_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(context_label)
	item_name = Label.new()
	item_name.theme_type_variation = &"Heavy17"
	item_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	item_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_child(item_name)
	_connect_player()

func _enter_tree() -> void:
	if is_node_ready():
		_connect_player.call_deferred()

func _connect_player() -> void:
	if not is_inside_tree():
		return
	if not EventBus.player_spawned.is_connected(bind_player):
		EventBus.player_spawned.connect(bind_player)
	bind_player(PlayerRegistry.local_player(get_tree()))

func bind_player(node: Node) -> void:
	if node != null and node != PlayerRegistry.local_player(get_tree()):
		return
	var previous: Node = _player.get_ref() if _player != null else null
	if previous != null and previous.equipment_display_changed.is_connected(_refresh):
		previous.equipment_display_changed.disconnect(_refresh)
	_player = weakref(node) if node is Player2D else null
	if _player != null:
		node.equipment_display_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var node: Node = _player.get_ref() if _player != null else null
	_snapshot = node.equipment_display() if node != null else {}
	var id := StringName(str(_snapshot.get("id", "")))
	var definition := GameData.item_def(id)
	item_icon.item_id = id
	item_icon.rarity = StringName(str(definition.get("rarity", "normal")))
	item_icon.visible = id != &""
	item_icon.modulate.a = 1.0 if bool(_snapshot.get("available", false)) else 0.45
	item_name.text = tr(str(definition.get("name_key", "HUD_ITEM_EMPTY")))
	var key := "HUD_ITEM_" + str(_snapshot.get("context", "selected")).to_upper()
	if id != &"" and not bool(_snapshot.get("available", false)):
		key = "HUD_ITEM_UNAVAILABLE"
	context_label.text = tr(key)
	tooltip_text = context_label.text + ": " + item_name.text

func shown() -> Dictionary:
	return {"id": item_icon.item_id, "name": item_name.text, "context": context_label.text, "available": bool(_snapshot.get("available", false))}

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh()

func _exit_tree() -> void:
	if EventBus.player_spawned.is_connected(bind_player):
		EventBus.player_spawned.disconnect(bind_player)
	var previous: Node = _player.get_ref() if _player != null else null
	if previous != null and previous.equipment_display_changed.is_connected(_refresh):
		previous.equipment_display_changed.disconnect(_refresh)
