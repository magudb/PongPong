extends Control
const L := preload("res://scripts/ui/social/social_layout.gd")
var ribbon: Label
var birthday_chips: HBoxContainer
var _birthday_key := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	ribbon = L.chip(self, "", "ZoneChip")
	ribbon.name = "FestivalRibbon"
	ribbon.position.y = 64
	birthday_chips = HBoxContainer.new()
	birthday_chips.name = "BirthdayChips"
	birthday_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	birthday_chips.position = Vector2(925, 116)
	birthday_chips.add_theme_constant_override("separation", 8)
	add_child(birthday_chips)
	EventBus.game_event.connect(_event)
	EventBus.day_started.connect(_date_changed)
	EventBus.time_of_day_changed.connect(_date_changed)
	EventBus.area_changed.connect(func(_area): refresh())
	EventBus.modal_changed.connect(func(_stack): refresh())
	EventBus.friend_changed.connect(func(_npc, _hearts): refresh())
	EventBus.dialogue_ended.connect(refresh)
	if get_parent() is GameUI:
		get_parent().mode_changed.connect(func(_mode): refresh())
	resized.connect(_position_birthdays)
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("social_hud", Callable(get_script(), &"fixture_setup"))
	refresh()
	_position_birthdays.call_deferred()

func _event(id: StringName, _payload: Dictionary) -> void:
	if id in [&"town_festival_started", &"town_festival_ended", &"birthday_today"]:
		refresh()

func _date_changed(_first: Variant, _second: Variant) -> void:
	refresh()

static func ribbon_text(name: String, window: Dictionary, hour: float) -> String:
	var end := float(window.get("to", 20))
	var start := float(window.get("from", 12))
	var key := "REL_HUD_OPEN" if hour >= start and hour < end else "REL_HUD_FROM"
	var value := end if key == "REL_HUD_OPEN" else start
	return TranslationServer.translate(key) % [name, L.Fmt.clock(floori(value), int(round(fmod(value, 1) * 60)))]

func refresh() -> void:
	if not is_node_ready():
		return
	visible = not (get_parent() is GameUI and get_parent().mode == &"action") and not &"event" in GameManager.modal_stack()
	var fid := str(SocialManager.festival_today())
	ribbon.visible = fid != ""
	if fid != "":
		var meta := LuaData.dict(SocialData.festival(fid).get("meta", {}))
		var name := tr(str(meta.get("name_key", "FEST_" + fid.to_upper() + "_NAME")))
		var hour := GameManager.hour + GameManager.minute / 60.0
		var window := SocialManager.festival_window(fid)
		ribbon.visible = hour < float(window.to)
		ribbon.text = ribbon_text(name, window, hour)
		ribbon.reset_size()
		ribbon.position.x = round((1280 - ribbon.size.x) / 2)
	var ids := SocialManager.birthdays_today().filter(func(id): return SocialManager.birthday_known(id))
	var birthday_key := TranslationServer.get_locale() + "|" + "|".join(ids)
	if birthday_key == _birthday_key:
		_position_birthdays()
		return
	_birthday_key = birthday_key
	L.clear(birthday_chips)
	for i in mini(ids.size(), 2):
		var label := L.chip(birthday_chips, "     " + L.npc_name(ids[i]), "ChipRewardRose")
		var glyph := L.hearts(label, 2, 13)
		glyph.max_hearts = 1
		glyph.position = Vector2(8, 2)
		label.set_meta("tt_text_same_ok", "Canonical citizen names are shared between languages")
	if ids.size() > 2:
		L.chip(birthday_chips, "+%d" % (ids.size() - 2), "ChipRewardRose").set_meta("tt_text_same_ok", "Overflow count has no language-dependent words")
	birthday_chips.reset_size()
	birthday_chips.position.x = maxf(20, 1240 - birthday_chips.size.x)
	_position_birthdays()

func _position_birthdays() -> void:
	if not is_node_ready() or not get_parent() is GameUI:
		return
	var hud: Control = get_parent().get_screen(&"hud")
	if hud != null:
		var height := birthday_chips.get_combined_minimum_size().y if visible and birthday_chips.get_child_count() > 0 else 0.0
		hud.set_social_row_height(height)
		birthday_chips.position.y = hud.hearts.get_global_rect().end.y + 8

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		refresh()

static func fixture_setup(node: Node, _host: Node) -> void:
	preload("res://scripts/ui/social/social_fixtures.gd").seed(true)
	var birthday := SocialData.birthday_of("gardener_hoppe")
	GameManager.season = StringName(birthday.season)
	GameManager.day = int(birthday.day)
	preload("res://scripts/ui/social/social_fixtures.gd").festival()
	node.tree_exited.connect(Callable(preload("res://scripts/ui/social/social_fixtures.gd"), &"cleanup"), CONNECT_ONE_SHOT)
	node.refresh()
