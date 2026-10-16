extends TTScreen
const L := preload("res://scripts/ui/social/social_layout.gd")
const C := preload("res://scripts/ui/theme/tt_colors.gd")
var selected := 2
var ladder: VBoxContainer
var detail: VBoxContainer
var preview: TextureRect
var build_button: Button
var close_button: Button
var status: Label
var _asking := false
func _init() -> void:
	super._init()
	screen_id = &"husbyggeri"
	modal_name = &"husbyggeri"
func _ready() -> void:
	super._ready()
	L.scrim(self)
	var book := L.panel(self,"PanelBook",Rect2(90,40,1100,640))
	var body := L.box(L.margin(book,20),true,10)
	var top := L.box(body,false)
	var title := L.label(top,"HUSBYG_TITLE","Display34")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = L.button(top,"HINT_CLOSE","ButtonTertiaryS")
	close_button.pressed.connect(close)
	var cols := L.box(body,false,24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ladder = L.box(cols,true,3) as VBoxContainer
	ladder.custom_minimum_size.x = 230
	preview = TextureRect.new()
	preview.custom_minimum_size = Vector2(315,400)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cols.add_child(preview)
	var right := L.box(cols,true,10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	detail = L.box(scroll,true,8) as VBoxContainer
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status = L.label(right,"","Muted14",true)
	build_button = L.button(right,"HUSBYG_BUILD","ButtonPrimary")
	build_button.pressed.connect(_build)
	EventBus.game_event.connect(func(event, _payload):
		if event == &"open_home_builder": open())
	EventBus.home_upgrade_started.connect(func(_a,_b,_c): _refresh_texts())
	EventBus.home_upgraded.connect(func(_a,_b): _refresh_texts())
	EventBus.day_started.connect(func(_a,_b): _refresh_texts())
func open(opener: Control = null) -> void:
	selected = mini(HomeManager.tier + 1, 10)
	super.open(opener)
func _initial_focus() -> Control:
	return close_button if build_button.disabled else build_button
func _refresh_texts() -> void:
	if ladder == null:
		return
	L.clear(ladder)
	for tier in range(1,11):
		var button := L.button(ladder,"%02d  %s" % [tier,tr(HomeData.tier_name_key(tier))])
		button.toggle_mode = true
		button.button_pressed = tier == selected
		button.pressed.connect(func(): selected = tier; _refresh_texts())
	L.clear(detail)
	preview.texture = HomeData.tex(HomeData.PROPS + "home/" + str(HomeData.tier(selected).exterior.day))
	L.label(detail,tr(HomeData.tier_name_key(selected)),"Heading22")
	L.label(detail,tr(str(HomeData.tier_def(selected).get("description_key",""))),"Body",true)
	var perks := HomeData.perks(selected)
	L.label(detail,tr("HUSBYG_PERKS_FMT") % [int(perks.get("max_energy_bonus",0)),int(perks.get("storage_slots",0)),int(perks.get("furniture_capacity",0))],"Body",true)
	for row in HomeManager.requirements(selected):
		var text := ""
		match str(row.kind):
			"gold": text = tr("HUSBYG_GOLD_FMT") % [row.have,row.need]
			"material": text = "%s  %d / %d" % [L.item_name(row.id),row.have,row.need]
			"days": text = tr("HUSBYG_DAYS_FMT") % row.need
			_: text = "%s  %d / %d" % [tr(str(row.get("name_key",row.id))),row.have,row.need]
		var label := L.label(detail,text,"Small14",true)
		label.add_theme_color_override("font_color", C.MOSS_DARK if row.met else C.THORNBERRY)
	var check := HomeManager.can_start_upgrade(selected)
	build_button.disabled = not check.ok or _asking
	status.text = tr("HUSBYG_BLOCK_" + str(check.reason).to_upper()) if not check.ok else ""
	if HomeManager.is_under_construction():
		status.text = tr("HUSBYG_PROGRESS_FMT") % HomeManager.days_left()
	if HomeManager.tier >= 8:
		var feast := L.button(detail,tr("HUSBYG_FEAST_FMT") % HomeData.festival_cost(),"ButtonSecondary")
		feast.disabled = not HomeManager.can_hold_festival_unlock() or EconomyManager.gold < HomeData.festival_cost() or (HomeManager.festival_cooldown_left() > 0 and not HomeManager.festival_waiver_active())
		feast.pressed.connect(_feast)
func _build() -> void:
	if _asking or not HomeManager.can_start_upgrade(selected).ok:
		return
	_asking = true
	var target := selected
	var accepted := await UiConfirm.ask(self,"HUSBYG_CONFIRM_TITLE","HUSBYG_CONFIRM_FMT","HUSBYG_BUILD","NAV_CANCEL",&"cancel",[tr(HomeData.tier_name_key(target)),HomeManager.gold_cost(target)])
	_asking = false
	if accepted and target == HomeManager.tier + 1:
		HomeManager.start_upgrade()
	_refresh_texts()
func _feast() -> void:
	if _asking:
		return
	_asking = true
	var accepted := await UiConfirm.ask(self,"HUSBYG_FEAST_TITLE","HUSBYG_FEAST_CONFIRM_FMT","NAV_OK","NAV_CANCEL",&"cancel",[HomeData.festival_cost()])
	_asking = false
	if accepted:
		HomeManager.hold_festival()
	_refresh_texts()
