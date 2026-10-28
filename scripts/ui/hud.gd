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
var _slot_epoch := 0

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
	current_item_badge = CurrentItemBadge.new()
	current_item_badge.name = "CurrentItemBadge"
	add_child(current_item_badge)
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
	toasts.z_index = ToastStack.ABOVE_MODALS_Z
	%WhisperLine.z_index = ToastStack.ABOVE_MODALS_Z
	EventBus.modal_changed.connect(func(stack):
		# the whisper follows the toasts: above a panel, hidden under the dialogue and an event scene
		toasts.visible = ToastStack.shown_with_modals(stack)
		%WhisperLine.visible = toasts.visible)
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("hud", Callable(get_script(), &"fixture_setup"))
	EventBus.gold_changed.connect(func(id: StringName, amount, delta) -> void:
		if id == PlayerRegistry.local_id(): _gold(amount, delta))
	EventBus.time_of_day_changed.connect(_time)
	EventBus.day_started.connect(_date)
	EventBus.season_changed.connect(_season_changed)
	EventBus.weather_changed.connect(_weather_changed)
	EventBus.player_stats_changed.connect(func(id: StringName, stats) -> void:
		if id == PlayerRegistry.local_id(): _stats(stats))
	EventBus.player_health_changed.connect(func(id: StringName, half_hearts, max_half_hearts) -> void:
		if id == PlayerRegistry.local_id(): _health(half_hearts, max_half_hearts))
	EventBus.hotbar_changed.connect(func(id: StringName, entries, selected) -> void:
		if id == PlayerRegistry.local_id(): set_hotbar(entries, selected))
	EventBus.player_spawned.connect(_player_spawned)
	EventBus.new_game_started.connect(_refresh_all)
	EventBus.load_completed.connect(func(_slot: int): _refresh_all())
	EventBus.save_completed.connect(func(_slot: int): _show_save_state())
	EventBus.save_failed.connect(func(_slot: int, _code: String): _show_save_state())
	EventBus.quest_accepted.connect(func(_player_id: StringName, quest_id) -> void: _quests_changed(quest_id))
	EventBus.quest_completed.connect(func(_player_id: StringName, quest_id) -> void: _quests_changed(quest_id))
	EventBus.quest_failed.connect(func(_player_id: StringName, quest_id) -> void: _quests_changed(quest_id))
	EventBus.quest_objective_updated.connect(func(_player_id: StringName, _q, _o, _p, _t): _refresh_quests())
	EventBus.home_upgrade_progress.connect(_construction_progress)
	EventBus.home_upgrade_started.connect(func(_from, _to, _ready_day): _refresh_construction())
	EventBus.home_upgraded.connect(func(_from, _to): _refresh_construction())
	EventBus.friend_changed.connect(func(_player_id: StringName, npc_id, hearts) -> void: _friend(npc_id, hearts))
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
	_refresh_all()
	if SaveManager.save_failing:
		_show_save_state()                   # a HUD built while saving fails (a load from the pause menu) shows it from the start

func _refresh_all() -> void:
	_slot_epoch += 1
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_gold(EconomyManager.gold, 0)
	_hour = GameManager.hour
	_minute = GameManager.minute
	_day = GameManager.day
	_season = GameManager.season
	_weather = TimeManager.weather
	_refresh_date()
	_refresh_quests()
	_refresh_construction()
	var player := PlayerRegistry.local_player(get_tree())
	if player != null:
		_player_spawned(player)
	else:
		set_hotbar(_entries, _selected)

func _player_spawned(player: Node2D) -> void:
	if player != PlayerRegistry.local_player(get_tree()):
		return
	if player.get("hotbar") != null:
		set_hotbar(player.hotbar.entries(), player.hotbar.selected)
	_stats({"half_hearts": player.get("half_hearts"), "max_half_hearts": player.get("max_half_hearts"), "stamina": player.get("stamina"), "max_stamina": player.get("max_stamina")})

func _gold(amount: int, _delta: int) -> void:
	gold_label.text = Fmt.thousands(amount)

func _time(hour: int, minute: int) -> void:
	_hour = hour
	_minute = minute
	_refresh_date()

func _date(day: int, season: StringName) -> void:
	_day = day
	_season = season
	_refresh_date()

func _season_changed(season: StringName) -> void:
	_season = season
	_refresh_date()

func _weather_changed(weather: StringName) -> void:
	_weather = weather
	_refresh_date()

func _refresh_date() -> void:
	day_label.text = Fmt.season_day_text(_day, _season)
	time_label.text = "%s · %s · %s" % [TimeManager.weekday_name(_day), Fmt.clock(_hour, _minute), TimeManager.weather_name(_weather)]

func _health(current: int, maximum: int) -> void:
	if _last_health == Vector2i(current, maximum):
		return
	_last_health = Vector2i(current, maximum)
	hearts.set_health(current, maximum)

func _stats(stats: Dictionary) -> void:
	if stats.get("stamina") != null and stats.get("max_stamina") != null:
		stamina_bar.max_value = maxf(1.0, float(stats.max_stamina))
		stamina_bar.value = float(stats.stamina)
	if stats.get("half_hearts") != null and stats.get("max_half_hearts") != null:
		_health(int(stats.half_hearts), int(stats.max_half_hearts))

func set_hotbar(entries: Array, selected: int = 0) -> void:
	_entries = entries.duplicate(true)
	_selected = clampi(selected, 0, SLOT_COUNT - 1)
	for index in hotbar.get_child_count():
		var slot: Button = hotbar.get_child(index)
		var entry: Dictionary = _entries[index] if index < _entries.size() else {}
		var id := StringName(str(entry.get("id", "")))
		var rarity: Variant = entry.get("rarity", entry.get("rare", "normal"))
		if rarity is bool:
			rarity = "rare" if rarity else "normal"
		var amount := int(entry.get("amount", 0))
		slot.setup(id, amount, str(index + 1), false, _item_name(entry), StringName(str(rarity)))
		slot.set_pressed_no_signal(index == _selected)
		slot.modulate.a = 0.45 if id != &"" and amount == 0 else 1.0
	var current: Dictionary = _entries[_selected] if _selected < _entries.size() else {}
	tool_name_label.text = _item_name(current)

func _item_name(entry: Dictionary) -> String:
	var id := str(entry.get("id", ""))
	if id == "":
		return ""
	var key := str(GameData.item_def(StringName(id)).get("name_key", entry.get("name", "")))
	return tr(key) if key != "" else id.capitalize()

func _slot_clicked(index: int) -> void:
	# Keep the physical GUI origin: an unlabelled Action cannot carry authority.
	set_hotbar(_entries, _selected)
	var body := PlayerRegistry.local_player(get_tree())
	if not body is Player2D or not body.world_input_allowed() or not body.controls.accepts_event(InputEventMouseButton.new()):
		return
	var id := PlayerRegistry.registered_id(body)
	_send_slot.call_deferred(index, weakref(body), id, body.controls, body.controls.revision, body.hotbar, body.area, PlayerRegistry.state(id), _slot_epoch)

func _send_slot(index: int, origin: WeakRef, id: StringName, source: PlayerInput, revision: int, bar: Hotbar, origin_area: Variant, row: PlayerState, epoch: int) -> void:
	var body: Variant = origin.get_ref()
	if not is_inside_tree() or is_queued_for_deletion() or epoch != _slot_epoch or not is_instance_valid(body):
		return
	if PlayerRegistry.registered_id(body) != id or PlayerRegistry.local_player(get_tree()) != body or PlayerRegistry.state(id) != row:
		return
	if body.controls != source or source.revision != revision or body.hotbar != bar or not is_instance_valid(origin_area) or body.area != origin_area:
		return
	if not source.accepts_event(InputEventMouseButton.new()):
		return
	body.select_gui_slot(index)

func _quests_changed(_id: StringName) -> void:
	_refresh_quests()

func _refresh_quests() -> void:
	for child in quest_tracker.get_children():
		quest_tracker.remove_child(child)
		child.queue_free()
	var tracked := QuestManager.get_tracked(3)
	quest_card.visible = not tracked.is_empty()
	for id in tracked:
		var row := VBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 2)
		quest_tracker.add_child(row)
		var title := Label.new()
		title.theme_type_variation = &"Display19"
		title.text = QuestManager.get_title(id)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(title)
		var objective := QuestManager.get_current_objective(id)
		if objective != &"":
			var progress := QuestManager.get_objective_progress(id, objective)
			var label := Label.new()
			label.theme_type_variation = &"Muted17"
			label.text = "%s: %d / %d" % [QuestManager.get_objective_text(id, objective), progress.current, progress.target]
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(label)

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
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var failing := bool(SaveManager.save_failing)
	_save_text.text = tr("HUD_SAVE_FAILED" if failing else "HUD_SAVED")
	save_chip.visible = true
	_saved_shown += 1
	if failing:
		return
	var shown := _saved_shown
	await get_tree().create_timer(SAVED_SHOW_SECONDS, true).timeout
	if is_instance_valid(save_chip) and shown == _saved_shown and not SaveManager.save_failing:
		save_chip.visible = false

func _refresh_construction() -> void:
	var home := Svc.node("HomeManager")
	var building := home != null and home.has_method("is_under_construction") and home.has_method("days_left") and bool(home.call("is_under_construction"))
	_construction_progress(int(home.call("days_left")) if building else 0, 0)

func _construction_progress(days_left: int, _total_days: int) -> void:
	_days_left = days_left
	construction.visible = days_left > 0
	%ConstructionText.text = tr("HUD_CONSTRUCTION_FMT") % days_left

func _friend(npc: StringName, _heart_count: int) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	var row := SocialData.npc_row(str(npc))
	var key := str(row.get("name_key", ""))
	if key != "":
		_pending_friends[npc] = key
		_post_friend.call_deferred(npc)

func _social_feedback(_title: String, message: String, icon: String) -> void:
	if icon == "social":
		for npc in _pending_friends.keys():
			if message.contains(tr(_pending_friends[npc])):
				_pending_friends.erase(npc)

func _post_friend(npc: StringName) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		_pending_friends.clear()
		return
	if not _pending_friends.has(npc):
		return
	var key := str(_pending_friends[npc])
	_pending_friends.erase(npc)
	var social := Svc.node("SocialManager")
	if social != null and social.has_method("has_pending_feedback") and social.has_pending_feedback(npc):
		return
	toasts.post(tr("HUD_FRIEND_FMT") % tr(key), "", "info")

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_gold(EconomyManager.gold, 0)
		_refresh_date()
		_refresh_quests()
		set_hotbar(_entries, _selected)
		_construction_progress(_days_left, 0)

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
