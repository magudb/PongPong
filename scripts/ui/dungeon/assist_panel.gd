extends TTScreen
const L := preload("res://scripts/ui/social/social_layout.gd")
var preset_buttons: Dictionary = {}
var value_buttons: Dictionary = {}
var close_button: Button
var preset_label: Label
func _init() -> void:
	super._init()
	screen_id = &"forest_help"
	modal_name = &"forest_help"
	nested_under = &"settings"
func _ready() -> void:
	super._ready()
	L.scrim(self)
	var book := L.panel(self,"PanelBook",Rect2(85,35,1110,650))
	var body := L.box(L.margin(book,22),true,12)
	var header := L.box(body,false)
	var title := L.label(header,"ASSIST_TITLE","Display34")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = L.button(header,"HINT_CLOSE","ButtonTertiaryS")
	close_button.pressed.connect(close)
	var presets := L.box(body,false,8)
	var group := ButtonGroup.new()
	group.set_meta("tt_value_selection",true)
	for id in ["none","light","cozy"]:
		var button := L.button(presets,"ASSIST_PRESET_"+id.to_upper())
		button.toggle_mode = true
		button.button_group = group
		button.pressed.connect(func(): DungeonRun.apply_preset(id))
		preset_buttons[id] = button
	preset_label = L.label(presets,"ASSIST_PRESET_CUSTOM","Muted14")
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var rows := L.box(scroll,true,10)
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key in DungeonAssist.defaults():
		if key == "assist_preset": continue
		var row := L.box(rows,false,14)
		var words := L.box(row,true,3)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var suffix := str(key).trim_prefix("assist_").to_upper()
		L.label(words,"ASSIST_"+suffix,"Heavy17")
		var description := L.label(words,"ASSIST_"+suffix+"_DESC","Muted14",true)
		description.custom_minimum_size.x = 650
		var button := L.button(row,"","ButtonSecondaryS")
		button.custom_minimum_size.x = 150
		button.pressed.connect(_cycle.bind(str(key)))
		value_buttons[key] = button
	EventBus.game_event.connect(func(event,_payload):
		if event == &"assist_changed" and is_open(): _refresh_texts())
func _initial_focus() -> Control:
	return preset_buttons.get(str(DungeonRun.assist("assist_preset")),preset_buttons["none"])
func _refresh_texts() -> void:
	if close_button == null: return
	var preset := str(DungeonRun.assist("assist_preset"))
	preset_label.visible = preset == "custom"
	for id in preset_buttons: preset_buttons[id].set_pressed_no_signal(id == preset)
	for key in value_buttons:
		var value := int(DungeonRun.assist(key))
		value_buttons[key].text = tr("ASSIST_LEVEL_"+str(value)) if key in ["assist_dmg","assist_telegraph","assist_hearts","assist_arc","assist_dodge","assist_oil"] else tr("ASSIST_ON" if value > 0 else "ASSIST_LEVEL_0")
func _cycle(key: String) -> void:
	var count := 3 if key in ["assist_dmg","assist_telegraph","assist_hearts","assist_arc","assist_dodge","assist_oil"] else 2
	DungeonRun.set_assist(key,posmod(int(DungeonRun.assist(key))+1,count))
