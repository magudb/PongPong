class_name HintBar
extends HBoxContainer
## The key hint line of a screen (UI_NAVIGATION.md 3.9 / 4.4): `[KeyCap] word · [KeyCap] word` in Plex Mono 11 (`Eyebrow`, #6a5a48) with the
## guide's key caps (`KeyCap`: Alegreya 800 13 chalk on ink, 1 px gold border). Scene: scenes/ui/components/hint_bar.tscn.
##
##   hint_bar.set_hints([
##       {"pair": [&"ui_up", &"ui_down"], "key": "HINT_MOVE"},           # "↑↓" on the keyboard, "D-pad" on a pad
##       {"action": &"ui_accept", "key": "HINT_OK"},
##       {"action": &"ui_cancel", "key": "HINT_BACK"},
##   ])
## An item is {"action": StringName} or {"pair": [a, b, ...]} plus {"key": a localization key (HINT_* of nav.csv)}. An item whose action has no
## event on the current device is left out (a hint never shows a key that is not live). The bar re-renders itself on a device change
## (UiNav.watcher().device_changed) and on a language switch (NOTIFICATION_TRANSLATION_CHANGED), connecting its signals once. It draws no
## background, takes no focus and no mouse, and hides itself when it has nothing to show.
##
## `force_hidden` is for the guide-compare fixtures: the mocks have no hint line, so a `<screen>_guide` fixture hides the bar for good (a later
## device change must not show it again).

const SEPARATOR := "·"

var _items: Array = []
var force_hidden := false:
	set(v):
		force_hidden = v
		_update_visibility()
var _watcher_connected := false
var _render_queued := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	add_theme_constant_override("separation", 8)
	alignment = BoxContainer.ALIGNMENT_END
	visible = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	var w := UiNav.watcher()
	if w != null and not _watcher_connected:
		_watcher_connected = true
		w.device_changed.connect(_on_device_changed)
	_render()


func _exit_tree() -> void:
	var w := UiNav.watcher()
	if w != null and _watcher_connected and w.device_changed.is_connected(_on_device_changed):
		w.device_changed.disconnect(_on_device_changed)
		_watcher_connected = false


func _enter_tree() -> void:
	var w := UiNav.watcher()
	if w != null and not _watcher_connected and is_node_ready():
		_watcher_connected = true
		w.device_changed.connect(_on_device_changed)


## Replaces the hints (an empty list hides the bar).
func set_hints(items: Array) -> void:
	_items = items.duplicate(true)
	if is_node_ready():
		_render()


func get_hints() -> Array:
	return _items.duplicate(true)


## What the bar shows right now as plain data (tests and the audit read it): [{glyph, text}] in order.
func shown() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in _resolved():
		out.append({"glyph": item["glyph"], "text": item["text"]})
	return out


func _on_device_changed(_dev: StringName) -> void:
	_queue_render()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_queue_render()


## A language switch is delivered while the tree propagates the notification (it blocks child changes): rebuild on the idle step instead.
func _queue_render() -> void:
	if not _render_queued:
		_render_queued = true
		_render_now.call_deferred()


func _render_now() -> void:
	_render_queued = false
	if is_inside_tree():
		_render()


func _resolved() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item in _items:
		var d: Dictionary = item
		var g := ""
		if d.has("pair"):
			g = UiHints.glyph_set(d["pair"] as Array)
		elif d.has("action"):
			g = UiHints.glyph(StringName(d["action"]))
		if g == "":
			continue
		out.append({"glyph": g, "text": str(TranslationServer.translate(str(d.get("key", ""))))})
	return out


func _render() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var list := _resolved()
	for i in list.size():
		if i > 0:
			_add_label(SEPARATOR, &"Eyebrow")
		var cap := _add_label(str(list[i]["glyph"]), &"KeyCap")
		cap.name = "Key%d" % i
		var word := _add_label(str(list[i]["text"]), &"Eyebrow")
		word.name = "Word%d" % i
	_update_visibility()


func _add_label(text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.focus_mode = Control.FOCUS_NONE
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(l)
	return l


func _update_visibility() -> void:
	visible = not force_hidden and get_child_count() > 0
