extends PanelContainer
## One HUD toast (gold double ring, ink outline). The HUD instances it into %NotificationBox; it fades itself out.
## Text arguments are DISPLAY strings (the HUD runs tr() / LocalizationManager.t() first). With `icon_id` the toast shows the
## item picture on the left (loot feed, "Du fandt ..."): the picture is found through the three icon directories (TTItemIcon),
## a legendary find shows its `_night` variant like every other tile.
## setup() may be called before add_child (the arguments are applied when the toast is ready); the fade needs the tree, so the
## toast only starts and frees itself once it is in it. A second setup() on a toast that is already showing REPLACES the first
## one: the running fade is killed (its queue_free would otherwise remove the toast early) and a new one starts from the
## current opacity, so the toast neither flickers nor disappears on the first call's schedule.

@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var icon_frame: Control = %IconFrame
@onready var item_icon: Control = %Icon

## setup() before the toast is in the tree (instantiate, setup, add_child) keeps the arguments and applies them in `_ready`
var _pending: Array = []
var _tween: Tween


func _ready() -> void:
	if not _pending.is_empty():
		var a := _pending
		_pending = []
		_apply(a[0], a[1], a[2], a[3], a[4])


func setup(title: String, message: String, seconds: float = 4.0, icon_id: StringName = &"", p_rarity: StringName = &"normal") -> void:
	if not is_node_ready():
		_pending = [title, message, seconds, icon_id, p_rarity]
		return
	_apply(title, message, seconds, icon_id, p_rarity)


func _apply(title: String, message: String, seconds: float, icon_id: StringName, p_rarity: StringName) -> void:
	title_label.text = title
	message_label.text = message
	message_label.visible = message != ""
	icon_frame.visible = icon_id != &""
	item_icon.rarity = p_rarity
	item_icon.item_id = icon_id
	if _tween != null and _tween.is_valid():
		_tween.kill()                      # the earlier setup()'s fade must not run on: its queue_free would end this toast early
	else:
		modulate.a = 0.0                   # a first showing fades in from nothing; a repeated one carries on from its opacity
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, 0.15)
	_tween.tween_interval(seconds)
	_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	_tween.tween_callback(queue_free)
