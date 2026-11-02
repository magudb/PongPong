extends Control
## Miljøer v2 HUD. All updates come from state changes; no frame polling.
const Fmt := preload("res://scripts/ui/theme/tt_format.gd")
const SLOT_COUNT := 8
@onready var day_label: Label = %DayLabel
@onready var time_label: Label = %TimeLabel
@onready var gold_label: Label = %GoldLabel
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var hearts: Control = %Hearts
@onready var quest_card: Control = %QuestCard
var _social_space: Control

@onready var quest_tracker: VBoxContainer = %QuestTracker
@onready var hotbar: HBoxContainer = %Hotbar
@onready var tool_name_label: Label = %ToolNameLabel
var current_item_badge: CurrentItemBadge
@onready var construction: Control = %ConstructionChip
@onready var toasts: ToastStack = %ToastStack
## Bottom-left chip: "Gemt" for SAVED_SHOW_SECONDS after a save, "! Ikke gemt" from a failed save until the next one succeeds
## (a toast may be hidden under a screen, this one is not missed).
const SAVED_SHOW_SECONDS := 2.5
var save_chip: PanelContainer
var _save_text: Label
var _saved_shown := 0
var _entries: Array = []
var _selected := 0
var _hour := 6
var _minute := 0
var _day := 1
var _season: StringName = &"foraar"
var _weather: StringName = &"solskin"
var _days_left := 0
var _pending_friends: Dictionary = {}
var _last_health := Vector2i(-1, -1)
var _view_revision := 0

## The HUD presents logical p0, including a newly loaded model whose old World
## is deliberately no longer a valid physical projection. Never use acting_id
## or the first group body to authorise a lazy manager read.
func _model_guard() -> Callable:
	var model: Variant = PlayerRegistry._states.get(&"p0")
	if not model is PlayerState or model.player_id != &"p0" or model.peer_id != 1:
		return Callable()
	var profile_ref: WeakRef = weakref(model)
	var owner_ref: WeakRef = weakref(self)
	var incarnation: RefCounted = SocialManager._accounting_world
	return func() -> bool:
		var owner: Variant = owner_ref.get_ref()
		var profile: Variant = profile_ref.get_ref()
		return is_instance_valid(owner) and owner.is_inside_tree() and not owner.is_queued_for_deletion() and profile != null and PlayerRegistry._states.get(&"p0") == profile and profile.player_id == &"p0" and profile.peer_id == 1 and not SocialManager._accounting_suspended and SocialManager._accounting_world == incarnation

func _begin_refresh() -> Callable:
	var model := _model_guard()
	if not _current(model): return Callable()
	_view_revision += 1
	var revision := _view_revision
	var owner_ref: WeakRef = weakref(self)
	return func() -> bool:
		return model.call() and owner_ref.get_ref()._view_revision == revision

static func _current(current: Callable) -> bool:
	return current.is_valid() and bool(current.call())

# Empty origins are explicit visual-only setters (including fixture_setup).
# Model-reading roots must authenticate before passing a nonempty receipt.
func _view_current(current: Callable) -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and (not current.is_valid() or bool(current.call()))

func _physical_player(player: Variant) -> bool:
	var world := PlayerRegistry.world(get_tree())
	# The first player_spawned precedes area attachment. Its registered p0
	# body can supply display data, but this never authorises input/travel.
	return is_instance_valid(player) and player is Node2D and player.is_inside_tree() and not player.is_queued_for_deletion() and PlayerRegistry.registered_id(player) == &"p0" and PlayerRegistry.by_id(&"p0", get_tree()) == player and PlayerRegistry.by_peer(1, get_tree()) == player and player.get("player_slot") == 0 and is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() and world.has_method("_host_live") and (world._host_live() or (world.area == null and player.get("area") == null)) and world.player == player and world._host_profile == PlayerRegistry._states.get(&"p0")

## The social overlay reserves a row below health without moving the chosen
## HUD when there are no birthdays. The HUD owns the spacer's lifetime.
func set_social_row_height(height: float) -> void:
	if _social_space == null and height > 0:
		_social_space = Control.new()
		_social_space.name = "SocialSpace"
		_social_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var column := get_node("TopRight")
		column.add_child(_social_space)
		column.move_child(_social_space, hearts.get_index() + 1)
	if _social_space != null:
		_social_space.custom_minimum_size.y = maxf(0, height)
		_social_space.visible = height > 0

func _ready() -> void:
	var current := _begin_refresh()
	if not _current(current): return
	current_item_badge = CurrentItemBadge.new()
	current_item_badge.name = "CurrentItemBadge"
	PlayerRegistry.for_player(&"p0", func(): add_child(current_item_badge))
	if not _current(current): return
	current_item_badge.anchor_left = 0.5
	current_item_badge.anchor_right = 0.5
	current_item_badge.anchor_top = 1.0
	current_item_badge.anchor_bottom = 1.0
	current_item_badge.offset_left = -140
	current_item_badge.offset_right = 140
	current_item_badge.offset_top = -156
	current_item_badge.offset_bottom = -114
	tool_name_label.visible = false
	_build_save_chip()
	if not _current(current): return
	toasts.z_index = ToastStack.ABOVE_MODALS_Z
	%WhisperLine.z_index = ToastStack.ABOVE_MODALS_Z
	EventBus.modal_changed.connect(func(stack):
		# the whisper follows the toasts: above a panel, hidden under the dialogue and an event scene
		toasts.visible = ToastStack.shown_with_modals(stack)
		%WhisperLine.visible = toasts.visible)
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("hud", Callable(get_script(), &"fixture_setup"))
	EventBus.gold_changed.connect(func(player_id: StringName, amount, delta) -> void:
		if player_id == &"p0": _present(_gold, [amount, delta]))
	EventBus.time_of_day_changed.connect(func(hour, minute): _present(_time, [hour, minute]))
	EventBus.day_started.connect(func(day, season): _present(_date, [day, season]))
	EventBus.season_changed.connect(func(season): _present(_season_changed, [season]))
	EventBus.weather_changed.connect(func(weather): _present(_weather_changed, [weather]))
	EventBus.player_stats_changed.connect(func(player_id: StringName, stats) -> void:
		if player_id == &"p0": _present(_stats, [stats]))
	EventBus.player_health_changed.connect(func(player_id: StringName, half_hearts, max_half_hearts) -> void:
		if player_id == &"p0": _present(_health, [half_hearts, max_half_hearts]))
	EventBus.hotbar_changed.connect(func(player_id: StringName, entries, selected) -> void:
		if player_id == &"p0": _present(set_hotbar, [entries, selected]))
	EventBus.player_spawned.connect(_player_spawned)
	EventBus.new_game_started.connect(_refresh_all)
	EventBus.load_completed.connect(func(_slot: int): _refresh_all())
	EventBus.save_completed.connect(func(_slot: int): _show_save_state())
	EventBus.save_failed.connect(func(_slot: int, _code: String): _show_save_state())
	EventBus.quest_accepted.connect(func(player_id: StringName, quest_id) -> void:
		if player_id == &"p0": _quests_changed(quest_id))
	EventBus.quest_completed.connect(func(player_id: StringName, quest_id) -> void:
		if player_id == &"p0": _quests_changed(quest_id))
	EventBus.quest_failed.connect(func(player_id: StringName, quest_id) -> void:
		if player_id == &"p0": _quests_changed(quest_id))
	EventBus.quest_objective_updated.connect(func(player_id: StringName, _q, _o, _p, _t):
		if player_id == &"p0": _refresh_quests())
	EventBus.home_upgrade_progress.connect(func(days, total): _present(_construction_progress, [days, total]))
	EventBus.home_upgrade_started.connect(func(_from, _to, _ready_day): _refresh_construction())
	EventBus.home_upgraded.connect(func(_from, _to): _refresh_construction())
	EventBus.friend_changed.connect(func(player_id: StringName, npc_id, hearts) -> void:
		if player_id == &"p0": _friend(npc_id, hearts))
	EventBus.notification_posted.connect(_social_feedback)
	for index in hotbar.get_child_count():
		var slot: Button = hotbar.get_child(index)
		slot.focus_mode = Control.FOCUS_NONE
		slot.item_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.item_icon.offset_left = 9
		slot.item_icon.offset_top = 9
		slot.item_icon.offset_right = -9
		slot.item_icon.offset_bottom = -9
		slot.pressed.connect(_slot_clicked.bind(index))
	if get_parent() is GameUI:
		get_parent().mode_changed.connect(func(mode):
			if mode == &"action":
				toasts.clear())
	_refresh_all(current)
	if _current(current) and SaveManager.save_failing:
		_show_save_state()                   # a HUD built while saving fails (a load from the pause menu) shows it from the start

func _present(setter: Callable, args: Array) -> void:
	var current := _begin_refresh()
	if _current(current): setter.callv(args + [current])

func _refresh_all(current: Callable = Callable()) -> void:
	if not current.is_valid(): current = _begin_refresh()
	if not _current(current): return
	# A synchronous scope is repeated at each independent root; it never spans
	# an await, nor confers physical authority on an obsolete World/body.
	PlayerRegistry.for_player(&"p0", func(): _paint_all(current))

func _paint_all(current: Callable) -> void:
	if not _current(current): return
	_gold(EconomyManager.gold, 0, current)
	if not _current(current): return
	_hour = GameManager.hour
	_minute = GameManager.minute
	_day = GameManager.day
	_season = GameManager.season
	_weather = TimeManager.weather
	_refresh_date(current)
	if not _current(current): return
	_refresh_quests(current)
	if not _current(current): return
	_refresh_construction(current)
	if not _current(current): return
	var player := PlayerRegistry.by_id(&"p0", get_tree())
	if _physical_player(player):
		_player_spawned(player, current)
	else:
		var model: PlayerState = PlayerRegistry._states[&"p0"]
		var bar := Hotbar.new()
		if model.hotbar is Dictionary: bar.from_dict(model.hotbar)
		set_hotbar(bar.entries(), bar.selected, current)
		if not _current(current): return
		_stats({"half_hearts":model.half_hearts, "max_half_hearts":model.max_half_hearts, "stamina":model.stamina, "max_stamina":model.max_stamina}, current)

func _player_spawned(player: Node2D, current: Callable = Callable()) -> void:
	if not _physical_player(player): return
	if not current.is_valid(): current = _begin_refresh()
	if not _current(current): return
	PlayerRegistry.for_player(&"p0", func():
		if player.get("hotbar") != null:
			set_hotbar(player.hotbar.entries(), player.hotbar.selected, current)
		if not _current(current) or not _physical_player(player): return
		_stats({"half_hearts": player.get("half_hearts"), "max_half_hearts": player.get("max_half_hearts"), "stamina": player.get("stamina"), "max_stamina": player.get("max_stamina")}, current))

func _gold(amount: int, _delta: int, current: Callable = Callable()) -> void:
	if not _view_current(current): return
	gold_label.text = Fmt.thousands(amount)

func _time(hour: int, minute: int, current: Callable = Callable()) -> void:
	if not _view_current(current): return
	_hour = hour
	_minute = minute
	_refresh_date(current)

func _date(day: int, season: StringName, current: Callable = Callable()) -> void:
	if not _view_current(current): return
	_day = day
	_season = season
	_refresh_date(current)

func _season_changed(season: StringName, current: Callable = Callable()) -> void:
	if not _view_current(current): return
	_season = season
	_refresh_date(current)

func _weather_changed(weather: StringName, current: Callable = Callable()) -> void:
	if not _view_current(current): return
	_weather = weather
	_refresh_date(current)

func _refresh_date(current: Callable = Callable()) -> void:
	if not _view_current(current): return
	day_label.text = Fmt.season_day_text(_day, _season)
	if not _view_current(current): return
	time_label.text = "%s · %s · %s" % [TimeManager.weekday_name(_day), Fmt.clock(_hour, _minute), TimeManager.weather_name(_weather)]

func _health(current_hp: int, maximum: int, current: Callable = Callable()) -> void:
	if not _view_current(current): return
	if _last_health == Vector2i(current_hp, maximum): return
	_last_health = Vector2i(current_hp, maximum)
	hearts.set_health(current_hp, maximum)

func _stats(stats: Dictionary, current: Callable = Callable()) -> void:
	if not _view_current(current): return
	if stats.get("stamina") != null and stats.get("max_stamina") != null:
		stamina_bar.max_value = maxf(1.0, float(stats.max_stamina))
		if not _view_current(current): return
		stamina_bar.value = float(stats.stamina)
	if not _view_current(current): return
	if stats.get("half_hearts") != null and stats.get("max_half_hearts") != null:
		_health(int(stats.half_hearts), int(stats.max_half_hearts), current)

func set_hotbar(entries: Array, selected: int = 0, current: Callable = Callable()) -> void:
	if not _view_current(current): return
	_entries = entries.duplicate(true)
	_selected = clampi(selected, 0, SLOT_COUNT - 1)
	for index in hotbar.get_child_count():
		if not _view_current(current): return
		var slot: Button = hotbar.get_child(index)
		var entry: Dictionary = _entries[index] if index < _entries.size() else {}
		var id := StringName(str(entry.get("id", "")))
		var rarity: Variant = entry.get("rarity", entry.get("rare", "normal"))
		if rarity is bool: rarity = "rare" if rarity else "normal"
		var amount := int(entry.get("amount", 0))
		slot.setup(id, amount, str(index + 1), false, _item_name(entry), StringName(str(rarity)))
		if not _view_current(current): return
		slot.set_pressed_no_signal(index == _selected)
		slot.modulate.a = 0.45 if id != &"" and amount == 0 else 1.0
	if not _view_current(current): return
	var entry: Dictionary = _entries[_selected] if _selected < _entries.size() else {}
	tool_name_label.text = _item_name(entry)

func _item_name(entry: Dictionary) -> String:
	var id := str(entry.get("id", ""))
	if id == "":
		return ""
	var key := str(GameData.item_def(StringName(id)).get("name_key", entry.get("name", "")))
	return tr(key) if key != "" else id.capitalize()

func _slot_clicked(index: int) -> void:
	# Deliver the same action as a number key after this GUI event finishes.
	# The normal player guard owns modal / travel / tool restrictions.
	set_hotbar(_entries, _selected)
	_send_slot.call_deferred(index)

func _send_slot(index: int) -> void:
	var press := InputEventAction.new()
	press.action = StringName("slot_%d" % (index + 1))
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = press.action
	release.pressed = false
	Input.parse_input_event(release)

func _quests_changed(_id: StringName) -> void:
	_refresh_quests()

func _refresh_quests(current: Callable = Callable()) -> void:
	if not current.is_valid(): current = _begin_refresh()
	if not _current(current): return
	PlayerRegistry.for_player(&"p0", func(): _paint_quests(current))

func _paint_quests(current: Callable) -> void:
	if not _current(current): return
	for child in quest_tracker.get_children():
		if not _current(current): return
		quest_tracker.remove_child(child)
		# remove_child can run a replacement refresh. Only this detached row is
		# ours to retire; never clear rows published by that nested root.
		if is_instance_valid(child) and child.get_parent() == null: child.queue_free()
		if not _current(current): return
	var tracked := QuestManager.get_tracked(3)
	if not _current(current): return
	quest_card.visible = not tracked.is_empty()
	if not _current(current): return
	for id in tracked:
		if not _current(current): return
		var row := VBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 2)
		quest_tracker.add_child(row)
		if not _current(current): return
		var title := Label.new()
		title.theme_type_variation = &"Display19"
		title.text = QuestManager.get_title(id)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(title)
		if not _current(current): return
		var objective := QuestManager.get_current_objective(id)
		if objective != &"":
			var progress := QuestManager.get_objective_progress(id, objective)
			var label := Label.new()
			label.theme_type_variation = &"Muted17"
			label.text = "%s: %d / %d" % [QuestManager.get_objective_text(id, objective), progress.current, progress.target]
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(label)
			if not _current(current): return

func _build_save_chip() -> void:
	save_chip = PanelContainer.new()
	save_chip.name = "SaveChip"
	save_chip.theme_type_variation = &"PillGold"
	save_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	save_chip.anchor_top = 1.0
	save_chip.anchor_bottom = 1.0
	save_chip.offset_left = 40
	save_chip.offset_top = -84
	save_chip.offset_bottom = -40
	save_chip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	save_chip.visible = false
	_save_text = Label.new()
	_save_text.name = "SaveText"
	_save_text.theme_type_variation = &"Bold15Gold"
	save_chip.add_child(_save_text)
	add_child(save_chip)

## SaveManager.save_failing decides: the failure stays until a save succeeds; a success shows "Gemt" briefly.
func _show_save_state() -> void:
	var current := _model_guard()
	if not _current(current): return
	_saved_shown += 1
	var shown := _saved_shown
	var failing := bool(SaveManager.save_failing)
	_save_text.text = tr("HUD_SAVE_FAILED" if failing else "HUD_SAVED")
	if not _current(current) or shown != _saved_shown: return
	save_chip.visible = true
	if not _current(current) or shown != _saved_shown or failing: return
	await get_tree().create_timer(SAVED_SHOW_SECONDS, true).timeout
	if _current(current) and is_instance_valid(save_chip) and shown == _saved_shown and not SaveManager.save_failing:
		save_chip.visible = false

func _refresh_construction(current: Callable = Callable()) -> void:
	if not current.is_valid(): current = _begin_refresh()
	if not _current(current): return
	var home := Svc.node("HomeManager")
	var building := home != null and home.has_method("is_under_construction") and home.has_method("days_left") and bool(home.call("is_under_construction"))
	if not _current(current): return
	_construction_progress(int(home.call("days_left")) if building else 0, 0, current)

func _construction_progress(days_left: int, _total_days: int, current: Callable = Callable()) -> void:
	if not _view_current(current): return
	_days_left = days_left
	construction.visible = days_left > 0
	if not _view_current(current): return
	%ConstructionText.text = tr("HUD_CONSTRUCTION_FMT") % days_left

func _friend(npc: StringName, _heart_count: int) -> void:
	var current := _model_guard()
	if not _current(current): return
	var row := SocialData.npc_row(str(npc))
	var key := str(row.get("name_key", ""))
	if key != "":
		var entry := {"key":key, "current":current}
		_pending_friends[npc] = entry
		_post_friend.call_deferred(npc, entry)

func _social_feedback(_title: String, message: String, icon: String) -> void:
	var current := _model_guard()
	if not _current(current) or icon != "social": return
	for npc in _pending_friends.keys():
		if not _current(current): return
		var entry: Dictionary = _pending_friends[npc]
		if _current(entry.current) and message.contains(tr(entry.key)) and is_same(_pending_friends.get(npc), entry):
			_pending_friends.erase(npc)

func _post_friend(npc: StringName, entry: Dictionary) -> void:
	# Every deferred entry owns its exact model and slot, not all pending work
	# for this NPC. An obsolete callback cannot erase a fresh same-NPC message.
	if not is_same(_pending_friends.get(npc), entry): return
	if not _current(entry.current):
		_pending_friends.erase(npc)
		return
	PlayerRegistry.for_player(&"p0", func():
		var social := Svc.node("SocialManager")
		var pending := social != null and social.has_method("has_pending_feedback") and bool(social.has_pending_feedback(npc))
		if not is_same(_pending_friends.get(npc), entry): return
		_pending_friends.erase(npc)
		if not _current(entry.current) or pending: return
		toasts.post(tr("HUD_FRIEND_FMT") % tr(entry.key), "", "info"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_refresh_all()

static func fixture_setup(node: Node, _host: Node) -> void:
	node._date(16, &"foraar")
	node._time(10, 20)
	node._weather_changed(&"klart")
	node._gold(1240, 0)
	node._stats({"stamina": 72, "max_stamina": 100, "half_hearts": 7, "max_half_hearts": 10})
	node.set_hotbar([{"id": "axe_wooden", "amount": 1}, {"id": "watering_can_copper", "amount": 1}, {"id": "turnip_seeds", "amount": 5}, {"id": "carrot", "amount": 12}], 0)
	node._construction_progress(0, 0)
	node.quest_card.visible = false
	node.toasts.clear()
	node.get_node("%AreaBanner")._dismiss()
	node.get_node("%WhisperLine")._hide()
	node.get_node("%PromptPill").set_prompt("")
