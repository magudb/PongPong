extends TTScreen
const L := preload("res://scripts/ui/social/social_layout.gd")
const Slot := preload("res://scenes/ui/components/item_slot.tscn")
var npc := ""
var options: Array = []
var slots: Array[Button] = []
var selected := 0
var panel: PanelContainer
var grid: GridContainer
var title: Label
var portrait: TextureRect
var hearts: SocialHearts
var footer: Label
var detail_name: Label
var detail_stock: Label
var taste: Label
var birthday: Label
var hidden_items: Label
var reason: Label
var give: Button
var back: Button
var _actor: WeakRef
var _busy := false
var _handoff := false
signal selection_finished(item_id: String)
var _selection_mode := false
var _selection_rows: Array = []
var _selection_title := ""
var _selection_result := ""

func _init() -> void:
	super._init()
	screen_id = &"gift_ui"
	modal_name = &"gift"

func _ready() -> void:
	super._ready()
	L.scrim(self)
	panel = L.panel(self, "PanelParchmentL24", Rect2(150, 70, 980, 580))
	var columns := L.box(panel, false, 24)
	var left := L.box(columns, true, 14)
	left.custom_minimum_size.x = 468
	var header := L.box(left, false, 12)
	portrait = L.portrait(header, "gardener_hoppe", 64)
	var heading := L.box(header, true, 4)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title = L.label(heading, "", "Display28", true)
	hearts = L.hearts(heading, 0, 18)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)
	var margin := L.margin(scroll, 6)
	grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	margin.add_child(grid)
	footer = L.label(left, "", "Body", true)
	var right := L.panel(columns, "PanelDetail")
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var details := L.box(L.margin(right, 18), true, 16)
	detail_name = L.label(details, "", "Heavy19", true)
	detail_stock = L.label(details, "", "Body", true)
	taste = L.chip(details, "", "ChipRewardRose")
	taste.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	birthday = L.label(details, "", "Body", true)
	hidden_items = L.label(details, "", "Body", true)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(spacer)
	reason = L.label(details, "", "Body", true)
	var actions := L.box(details, false)
	give = L.button(actions, "", "ButtonPrimary")
	give.name = "GiveButton"
	give.pressed.connect(_give)
	back = L.button(actions, "", "ButtonTertiary")
	back.name = "BackButton"
	back.pressed.connect(close)
	EventBus.game_event.connect(_event)
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("gift", Callable(get_script(), &"fixture_setup"))

func _event(id: StringName, payload: Dictionary) -> void:
	if id == &"open_gift_picker":
		open_for(str(payload.get("npc", "")))

func open_for(id: String) -> void:
	if is_open() or GameManager.is_modal_open():
		return
	npc = id
	_selection_mode = false
	selected = 0
	_handoff = false
	var actor := NpcDirector.node_of(npc)
	if actor != null:
		_actor = weakref(actor)
		actor.hold(true)
	open()
	if not is_open():
		_release_actor()

## Festivals reuse the same item grid and focus paths, with their own transaction.
func choose(title_key: String, rows: Array) -> String:
	if is_open() or GameManager.is_modal_open(): return ""
	_selection_mode = true
	_selection_rows = rows.duplicate(true)
	_selection_title = title_key
	_selection_result = ""
	selected = 0
	_handoff = false
	open()
	if not is_open():
		_selection_mode = false
		return ""
	return await selection_finished

func _initial_focus() -> Control:
	return slots[clampi(selected, 0, slots.size() - 1)] if not slots.is_empty() else back

func _release_actor() -> void:
	if _actor != null and _actor.get_ref() != null:
		_actor.get_ref().hold(false)
	_actor = null

func close() -> void:
	var selecting := _selection_mode
	_selection_mode = false
	super.close()
	if not _handoff:
		_release_actor()
	if selecting: selection_finished.emit(_selection_result)

func _exit_tree() -> void:
	if _selection_mode:
		_selection_mode = false
		selection_finished.emit("")
	if not _handoff:
		_release_actor()
	super._exit_tree()

func _refresh_texts() -> void:
	if not is_node_ready():
		return
	options = _selection_rows if _selection_mode else SocialManager.gift_options(npc)
	var count := maxi(24, ceili(options.size() / 6.0) * 6)
	while slots.size() < count:
		var index := slots.size()
		var slot: Button = Slot.instantiate()
		slot.name = "GiftSlot%d" % (index + 1)
		slot.custom_minimum_size = Vector2(66, 66)
		grid.add_child(slot)
		slot.item_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.item_icon.offset_left = 8
		slot.item_icon.offset_top = 8
		slot.item_icon.offset_right = -8
		slot.item_icon.offset_bottom = -8
		slot.pressed.connect(_activate.bind(index))
		slot.focus_entered.connect(_select.bind(index))
		slots.append(slot)
	for i in slots.size():
		var entry: Dictionary = options[i] if i < options.size() else {}
		slots[i].visible = i < count
		slots[i].focus_mode = Control.FOCUS_ALL if i < count else Control.FOCUS_NONE
		slots[i].setup_item(StringName(str(entry.get("id", ""))), int(entry.get("amount", 0)))
		slots[i].tooltip_text = L.item_name(str(entry.id)) if not entry.is_empty() else tr("INV_EMPTY_SLOT")
	title.text = tr("REL_GIFT_TITLE") % L.npc_name(npc)
	portrait.get_parent().visible = not _selection_mode
	hearts.visible = not _selection_mode
	portrait.texture = L.Portraits.portrait(StringName(npc))
	hearts.half_hearts = SocialManager.half_hearts(npc)
	var limits := SocialManager.gift_limits(npc)
	footer.text = tr("REL_GIFT_LIMITS") % [2 - int(limits.left_week), 1 - int(limits.left_today)]
	give.text = tr("REL_GIFT_GIVE")
	back.text = tr("HINT_BACK")
	var next := SocialManager.next_birthday(npc)
	var state := SocialManager.birthday_state(npc)
	birthday.visible = SocialManager.birthday_known(npc)
	birthday.text = tr("REL_GIFT_BELATED") if state == "belated" else tr("REL_GIFT_BIRTHDAY") % int(next.days)
	var protected := GiftFlow.hidden_quest_items(npc)
	hidden_items.text = tr("REL_GIFT_HIDDEN") % protected if protected > 0 else ""
	if _selection_mode:
		title.text = tr(_selection_title)
		footer.text = tr("SOC_EV_PICK_FOOTER")
		give.text = tr("SOC_EV_SELECT")
		birthday.visible = false
		hidden_items.text = ""
	_select(clampi(selected, 0, count - 1))

func _select(index: int) -> void:
	selected = index
	var entry: Dictionary = options[index] if index < options.size() else {}
	for i in slots.size():
		slots[i].set_pressed_no_signal(i == index)
	detail_name.text = L.item_name(str(entry.id)) if not entry.is_empty() else tr("INV_EMPTY_SLOT")
	detail_stock.text = tr("REL_GIFT_STOCK") % [entry.amount, entry.value] if not entry.is_empty() else ""
	var known := str(entry.get("known", ""))
	taste.visible = known != ""
	taste.text = "♥ " + tr("REL_TASTE_" + known.to_upper()) if known != "" else ""
	taste.theme_type_variation = &"SocialRewardChip" if known == "love" else &"Chip"
	var limits := SocialManager.gift_limits(npc)
	var why := ""
	if int(limits.left_today) <= 0:
		why = "REL_GIFT_LIMIT_DAY"
	elif int(limits.left_week) <= 0 and SocialManager.birthday_state(npc) == "":
		why = "REL_GIFT_LIMIT_WEEK"
	if _selection_mode: why = ""
	reason.text = tr(why) if why != "" else ""
	UiNav.set_enabled(give, not entry.is_empty() and why == "")
	_wire()

func _wire() -> void:
	var visible_slots: Array[Button] = []
	for slot in slots:
		if slot.visible:
			visible_slots.append(slot)
	UiNav.wire_grid(visible_slots, 6)
	UiNav.wire_row([give, back])
	UiNav.wire_groups([visible_slots, [give, back]])

func _activate(index: int) -> void:
	_select(index)
	if not give.disabled:
		give.grab_focus()

func _give() -> void:
	if _busy or not is_open() or not is_top() or give.disabled or selected >= options.size():
		return
	_busy = true
	var item := str(options[selected].id)
	if _selection_mode:
		_selection_result = item
		_busy = false
		close()
		return
	var confirmed := true
	if bool(options[selected].confirm):
		confirmed = await UiConfirm.ask(self, "REL_GIFT_CONFIRM_TITLE", tr("REL_GIFT_CONFIRM_BODY") % L.item_name(item), "REL_GIFT_CONFIRM_YES")
	_busy = false
	if not is_inside_tree() or not is_open() or not confirmed:
		return
	_handoff = true
	close()
	var actor := _actor
	_actor = null
	var result := GiftFlow.give_gift(npc, item)
	if bool(result.get("ok", false)):
		preload("res://scripts/ui/social/gift_reaction.gd").run(npc, result, actor)
	else:
		if actor != null and actor.get_ref() != null:
			actor.get_ref().hold(false)
		EventBus.whisper_requested.emit("GIFT_REFUSE_" + str(result.get("reason", "no_item")).to_upper())

static func fixture_setup(node: Node, _host: Node) -> void:
	preload("res://scripts/ui/social/social_fixtures.gd").seed(true)
	node.open_for("gardener_hoppe")
