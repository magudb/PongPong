class_name ToastStack
extends Control
## The toast stack (UI_NAVIGATION.md 5.1 S22): `EventBus.notification_posted(title, message, icon)` -> a `notification_toast` at the top centre (from y = 96),
## at most 3 on screen, the NEWEST ON TOP, 4 s + 0.4 s fade each. Instanced by hud.tscn, forest_hud.tscn, main_menu.tscn and character_select.tscn (the title
## and the select scene have no GameUI, so a failed Fortsæt, a corrupt Indlæs and the language toast would be silent without their own stack).
## Scene: scenes/ui/components/toast_stack.tscn. Not focusable, mouse_filter IGNORE everywhere.
##
## What a toast shows:
##  * title and message are display strings; one that is a translation key (UPPER_CASE with an underscore: quest toasts from Lua, `LUANOTIF_*`) is run
##    through tr() and re-labels on a language switch;
##  * item gains stack: a toast with the same title and the same message (a trailing " x3" is the count of an item gain) that is still on screen is
##    updated instead of added ("Månesten x2" + "Månesten x3" -> "Månesten x5"; two identical messages -> "title ×2") and its fade starts over;
##  * `icon` is the notification kind ("item", "farm", "save" ...) or an ITEM ID: an item shows its picture on the rarity tile of Rarity.ui(rarity) (a
##    legendary find shows its `_night` icon on the night tile). An "item" notification is paired with the `item_gained` that EconomyManager emits just
##    before it, so the toast of a find carries the item and its rarity although the signal only says "item".
## `item_toasts = false` (the forest HUD: item finds go to the loot feed there) leaves the item notifications out.
##
## Inside a modal (UX-10): a HUD's stack (and its whisper) draws at ABOVE_MODALS_Z, above the scrims of the screens of the same GameUI layer, and
## stays visible (shown_with_modals) so feedback given inside a panel is seen: a hotbar assignment in the backpack, a save from the pause menu,
## a refused buy. Only the cinematic modals of QUIET_MODALS (the dialogue box, an event scene) keep the toasts and the whisper hidden: a whisper
## raised under one (a refused gift, a whisper zone) keeps its timer and shows for what is left of it once the scene closes.

const TOAST_SCENE := "res://scenes/ui/components/notification_toast.tscn"
const MAX_TOASTS := 3
const SECONDS := 4.0
const ITEM_KIND := "item"
## the rarity tile of an item toast (RaritySlot keeps 8 px of its tile free all round for the picture: a 48 px tile shows a 32 px picture)
const TILE_SIZE := 48.0
## notification kinds that are NOT an item id (what the emitters pass today)
const KINDS: Array[String] = ["item", "farm", "save", "shop", "gold", "inventory", "zone", "welcome", "lua", "sleep", "quest", "language", "info", ""]
## z_index of a HUD's toast stack and whisper line: above every modal screen's scrim (the screens draw at z 0)
const ABOVE_MODALS_Z := 100
## modal names under which a HUD's toasts and whisper stay hidden
const QUIET_MODALS: Array[StringName] = [&"dialogue", &"event"]

## false: item notifications are left to the loot feed (forest HUD)
@export var item_toasts := true
## Farm v2 keeps summaries in arrival order. Other screens retain the P28 newest-first contract.
@export var fifo := false
@export_range(1, 8) var max_visible := MAX_TOASTS
@export var farm_only := false

var _entries: Array[Dictionary] = []          # newest first: {toast, title, message, base, count, amount, icon, rarity}
var _stack: VBoxContainer
var _pending_item := {}                       # {id, frame} of the last item_gained, consumed by the next "item" notification of the same frame
var _connected := false
var _queue: Array[Dictionary] = []
var _clearing := false


## Is a HUD's toast stack shown with this modal stack open (GameManager.modal_stack())?
static func shown_with_modals(stack: Array) -> bool:
	for modal in stack:
		if StringName(str(modal)) in QUIET_MODALS:
			return false
	return true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_stack = get_node_or_null("%Stack") as VBoxContainer
	if _stack == null:
		_stack = VBoxContainer.new()
		_stack.name = "Stack"
		add_child(_stack)
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_connect_bus()


func _enter_tree() -> void:
	if is_node_ready():
		_connect_bus()


func _exit_tree() -> void:
	var bus := Svc.node("EventBus")
	if bus != null and _connected:
		if bus.is_connected(&"notification_posted", _on_notification):
			bus.disconnect(&"notification_posted", _on_notification)
		if bus.is_connected(&"item_gained", _on_item_gained):
			bus.disconnect(&"item_gained", _on_item_gained)
	_connected = false


func _connect_bus() -> void:
	if _connected:
		return
	var bus := Svc.node("EventBus")
	if bus == null:
		return
	_connected = true
	bus.connect(&"notification_posted", _on_notification)
	bus.connect(&"item_gained", _on_item_gained)


func _on_item_gained(_player_id: StringName, item_id: StringName, _amount: int) -> void:
	_pending_item = {"id": item_id, "frame": Engine.get_process_frames()}


func _on_notification(title: String, message: String, icon: String) -> void:
	post(title, message, icon)


## The toasts on screen, newest first (the nodes).
func toasts() -> Array[Node]:
	var out: Array[Node] = []
	for e in _entries:
		out.append(e["toast"])
	return out


## Shows one notification (what the EventBus signal does; public so a screen can post without the bus).
func post(title: String, message: String, icon: String = "") -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	if farm_only:
		# Mode belongs to this stack's screen owner. Another UI root may share
		# the group during a transition without implementing GameUI's API.
		var ui: Node = get_parent()
		while ui != null and not ui is GameUI:
			ui = ui.get_parent()
		if ui is GameUI and (ui as GameUI).mode == &"action":
			return
	var item_id := ""
	if icon == ITEM_KIND:
		if not item_toasts:
			return
		if not _pending_item.is_empty() and int(_pending_item["frame"]) == Engine.get_process_frames():
			item_id = str(_pending_item["id"])
		_pending_item = {}
	elif icon not in KINDS and ItemKinds.def(icon).size() > 0:
		if not item_toasts:
			return
		item_id = icon
	var rarity := ItemKinds.rarity_of(item_id) if item_id != "" else &"normal"
	var parts := _split_count(message)
	var key := "%s\n%s" % [title, parts["base"]]
	for e in _entries:
		if e["key"] == key and e["icon"] == item_id:
			_stack_into(e, int(parts["amount"]), parts["has_amount"])
			return
	var entry := {"key": key, "title": title, "message": message, "base": parts["base"], "count": 1, "amount": int(parts["amount"]),
		"has_amount": parts["has_amount"], "icon": item_id, "rarity": rarity}
	if fifo and (_entries.size() >= max_visible or not _queue.is_empty()):
		# A queue of eight is supported without dropping a ninth arrival during a burst.
		_queue.append(entry)
		return
	_show_entry(entry)


func _show_entry(entry: Dictionary) -> void:
	var toast := (load(TOAST_SCENE) as PackedScene).instantiate()
	entry["toast"] = toast
	if fifo:
		_entries.append(entry)
	else:
		_entries.push_front(entry)
	toast.tree_exited.connect(_on_toast_gone.bind(toast))
	(toast as Control).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stack.add_child(toast)
	if not fifo:
		_stack.move_child(toast, 0)
	_present(entry, true)
	while not fifo and _entries.size() > max_visible:
		var oldest: Dictionary = _entries.pop_back()
		(oldest["toast"] as Node).queue_free()


func clear() -> void:
	_clearing = true
	_queue.clear()
	var old := _entries.duplicate()
	_entries.clear()
	for entry in old:
		var toast: Node = entry.toast
		if is_instance_valid(toast):
			toast.queue_free()
	_pending_item = {}
	_clearing = false


func queued_count() -> int:
	return _queue.size()


func _stack_into(entry: Dictionary, amount: int, has_amount: bool) -> void:
	if has_amount:
		entry["amount"] = int(entry["amount"]) + amount
	else:
		entry["count"] = int(entry["count"]) + 1
	var idx := _entries.find(entry)
	if idx > 0 and not fifo:
		_entries.remove_at(idx)
		_entries.push_front(entry)
		_stack.move_child(entry["toast"], 0)
	_present(entry, false)


## "Månesten x3" -> {base: "Månesten", amount: 3, has_amount: true}; anything else -> the whole text, amount 1.
func _split_count(message: String) -> Dictionary:
	var at := message.rfind(" x")
	if at > 0 and message.substr(at + 2).is_valid_int():
		return {"base": message.substr(0, at), "amount": int(message.substr(at + 2)), "has_amount": true}
	return {"base": message, "amount": 1, "has_amount": false}


func _shown_title(entry: Dictionary) -> String:
	var t := _text(str(entry["title"]))
	return "%s ×%d" % [t, int(entry["count"])] if int(entry["count"]) > 1 else t


func _shown_message(entry: Dictionary) -> String:
	var base := _text(str(entry["base"]))
	if bool(entry["has_amount"]):
		return "%s x%d" % [base, int(entry["amount"])]
	return base


func _text(s: String) -> String:
	return str(TranslationServer.translate(s)) if UiHints.is_key(s) else s


## (Re)writes the toast: texts, the icon on its rarity tile, the fade.
func _present(entry: Dictionary, fresh: bool) -> void:
	var toast: Node = entry["toast"]
	toast.setup(_shown_title(entry), _shown_message(entry), SECONDS, StringName(str(entry["icon"])), StringName(str(entry["rarity"])))
	if fresh:
		_add_rarity_tile(toast, entry)


## The item picture sits on the rarity tile of the ladder (RaritySlot reads Rarity.ui(): fill + ring + the night tile of a legendary).
func _add_rarity_tile(toast: Node, entry: Dictionary) -> void:
	if str(entry["icon"]) == "":
		return
	var frame := toast.get_node_or_null("%IconFrame") as Control
	var plain := toast.get_node_or_null("%Icon") as Control
	if frame == null:
		return
	var tile := RaritySlot.new()
	tile.name = "RarityTile"
	tile.slot_size = TILE_SIZE
	tile.rarity = StringName(str(entry["rarity"]))
	tile.item_id = StringName(str(entry["icon"]))
	tile.display_name = _text(str(entry["base"]))
	tile.count = 1
	frame.custom_minimum_size = Vector2(TILE_SIZE + 2.0 * RaritySlot.PAD, TILE_SIZE + 2.0 * RaritySlot.PAD)
	frame.add_child(tile)
	if plain != null:
		plain.visible = false


func _on_toast_gone(toast: Node) -> void:
	for i in range(_entries.size() - 1, -1, -1):
		if _entries[i]["toast"] == toast:
			_entries.remove_at(i)
	if fifo and not _clearing and is_inside_tree() and not is_queued_for_deletion():
		_drain.call_deferred()


func _drain() -> void:
	while not _queue.is_empty() and _entries.size() < max_visible:
		_show_entry(_queue.pop_front())


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		for e in _entries:
			var toast: Node = e["toast"]
			if is_instance_valid(toast):
				toast.title_label.text = _shown_title(e)
				toast.message_label.text = _shown_message(e)
