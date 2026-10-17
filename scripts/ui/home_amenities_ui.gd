extends TTScreen
const L := preload("res://scripts/ui/social/social_layout.gd")
var close_button: Button
var royal_button: Button
var forecast: Label
var royal_hint: Label
var status: Label
var recipes: Array[Dictionary] = []
var _asking := false
func _init() -> void:
	super._init()
	screen_id = &"home_amenities"
	modal_name = &"home_amenities"
	nested_under = &"home_chest"
func _ready() -> void:
	super._ready()
	L.scrim(self)
	var book := L.panel(self,"PanelBook",Rect2(160,90,960,540))
	var body := L.box(L.margin(book,24),true,16)
	var header := L.box(body,false)
	var title := L.label(header,"HOME_AMENITIES_TITLE","Display34")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = L.button(header,"HINT_CLOSE","ButtonTertiaryS")
	close_button.pressed.connect(close)
	var columns := L.box(body,false,30)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var kitchen := L.box(columns,true,14)
	kitchen.custom_minimum_size.x = 420
	L.label(kitchen,"HOME_UNLOCK_OVEN","Heading22")
	for recipe in CraftingSystem.get_recipes("bake"):
		var row := L.box(kitchen,true,5)
		var line := L.box(row,false,8)
		var output := LuaData.dict(recipe.output)
		var icon := TTItemIcon.new()
		icon.item_id = StringName(str(output.item))
		icon.custom_minimum_size = Vector2(42,42)
		line.add_child(icon)
		var button := L.button(line,str(recipe.name_key),"ButtonSecondaryS")
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_cook.bind(str(recipe.id)))
		var ingredients := L.label(row,"","Small14",true)
		recipes.append({"id":str(recipe.id),"button":button,"ingredients":ingredients})
	var right := L.box(columns,true,16)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	L.label(right,"HOME_UNLOCK_FORECAST","Heading22")
	forecast = L.label(right,"","Body",true)
	L.label(right,"HOME_UNLOCK_ROYAL_VISIT","Heading22")
	royal_hint = L.label(right,"","Small14",true)
	royal_button = L.button(right,"HOME_AMENITIES_INVITE","ButtonSecondaryS")
	royal_button.pressed.connect(_invite)
	status = L.label(body,"","Body",true)
	EventBus.game_event.connect(func(id,_data):
		if id==&"open_home_amenities" and HomeServices.at_home():open())
	EventBus.player_inventory_changed.connect(func(_items):
		if is_open():_refresh_texts.call_deferred())
	preload("res://scripts/ui/dev/ui_fixtures.gd").register_setup("home_amenities",Callable(get_script(),&"fixture_setup"))
func open(opener: Control = null) -> void:
	status.text = ""
	super.open(opener)
func _initial_focus() -> Control:return close_button
func _refresh_texts() -> void:
	if forecast==null or not is_open():return
	var home := HomeServices.at_home()
	var navigation: Array = []
	for row in recipes:
		var recipe := CraftingSystem.get_recipe(str(row.id))
		var available := CraftingSystem.can_craft(str(row.id))
		row.button.disabled = not home or not HomeManager.unlocked("oven") or not available.ok
		row.button.focus_mode = Control.FOCUS_NONE if row.button.disabled else Control.FOCUS_ALL
		var parts: Array[String] = []
		for ingredient in LuaData.dict(recipe.ingredients):parts.append("%s %d/%d" % [L.item_name(str(ingredient)),EconomyManager.count_item(StringName(str(ingredient))),int(recipe.ingredients[ingredient])])
		row.ingredients.text = ", ".join(parts)
		if not row.button.disabled:navigation.append(row.button)
	if not HomeManager.unlocked("oven"):status.text = tr("HOME_AMENITIES_OVEN_LOCKED")
	elif not home:status.text = tr("HOME_AMENITIES_AWAY")
	if HomeManager.unlocked("forecast"):
		var date := CalendarUtil.date_of(GameManager.total_day()+1)
		forecast.text = tr("HOME_AMENITIES_FORECAST_FMT") % [TimeManager.date_text(int(date.day),StringName(str(date.season))),TimeManager.weather_name(TimeManager.forecast_weather())]
	else:forecast.text = tr("HOME_AMENITIES_FORECAST_LOCKED")
	var reason := HomeServices.royal_reason(true)
	royal_hint.text = tr("HOME_AMENITIES_ROYAL_READY" if reason=="" else "HOME_AMENITIES_ROYAL_"+reason.to_upper())
	royal_button.disabled = reason!="" or _asking
	royal_button.focus_mode = Control.FOCUS_NONE if royal_button.disabled else Control.FOCUS_ALL
	var actions: Array = [close_button]
	if not royal_button.disabled:actions.append(royal_button)
	UiNav.wire_ring(navigation)
	UiNav.wire_ring(actions)
	UiNav.wire_groups([navigation,actions],true,false)
func _cook(id: String) -> void:
	if not HomeServices.at_home() or not HomeManager.unlocked("oven"):return
	var ok := CraftingSystem.craft(id)
	_refresh_texts()
	status.text = tr("HOME_AMENITIES_BAKED" if ok else "HOME_AMENITIES_FULL")
	if ok:SaveManager.autosave()
func _invite() -> void:
	if _asking or HomeServices.royal_reason(true)!="":return
	_asking = true
	var accepted := await UiConfirm.ask(self,"HOME_UNLOCK_ROYAL_VISIT","HOME_AMENITIES_ROYAL_CONFIRM","HOME_AMENITIES_INVITE","NAV_CANCEL",&"cancel")
	_asking = false
	if not accepted:
		_refresh_texts()
		return
	close()
	var host := HomeServices.world()
	var chest: Control = host.game_ui.get_screen(&"home_chest")
	if chest.is_open():chest.close()
	await get_tree().create_timer(0.2).timeout
	await HomeServices.invite_king()
static func fixture_setup(node: Node,_host: Node) -> void:
	HomeManager.set_tier(10)
	GameManager.hour = 19
	node.open()
