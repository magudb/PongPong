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

const TOAST_SCENE := "res://scenes/ui/components/notification_toast.tscn"
const MAX_TOASTS := 3
const SECONDS := 4.0
const ITEM_KIND := "item"
## the rarity tile of an item toast (RaritySlot keeps 8 px of its tile free all round for the picture: a 48 px tile shows a 32 px picture)
const TILE_SIZE := 48.0
## notification kinds that are NOT an item id (what the emitters pass today)
const KINDS: Array[String] = ["item", "farm", "save", "shop", "gold", "inventory", "zone", "welcome", "lua", "sleep", "quest", "language", "info", ""]

## false: item notifications are left to the loot feed (forest HUD)
@export var item_toasts := true

var _entries: Array[Dictionary] = []          # newest first: {toast, title, message, base, count, amount, icon, rarity}
var _stack: VBoxContainer
var _pending_item := {}                       # {id, frame} of the last item_gained, consumed by the next "item" notification of the same frame
var _connected := false


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


func _on_item_gained(item_id: StringName, _amount: int) -> void:
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
	var toast := (load(TOAST_SCENE) as PackedScene).instantiate()
	var entry := {"toast": toast, "key": key, "title": title, "message": message, "base": parts["base"], "count": 1, "amount": int(parts["amount"]),
		"has_amount": parts["has_amount"], "icon": item_id, "rarity": rarity}
	_entries.push_front(entry)
	toast.tree_exited.connect(_on_toast_gone.bind(toast))
	(toast as Control).size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stack.add_child(toast)
	_stack.move_child(toast, 0)                                   # newest on top
	_present(entry, true)
	while _entries.size() > MAX_TOASTS:
		var oldest: Dictionary = _entries.pop_back()
		(oldest["toast"] as Node).queue_free()


func _stack_into(entry: Dictionary, amount: int, has_amount: bool) -> void:
	if has_amount:
		entry["amount"] = int(entry["amount"]) + amount
	else:
		entry["count"] = int(entry["count"]) + 1
	var idx := _entries.find(entry)
	if idx > 0:                                                    # the stacked toast is the newest again
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		for e in _entries:
			var toast: Node = e["toast"]
			if is_instance_valid(toast):
				toast.title_label.text = _shown_title(e)
				toast.message_label.text = _shown_message(e)
