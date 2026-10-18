extends TTScreen
const L := preload("res://scripts/ui/social/social_layout.gd")
const Snapshot := preload("res://scripts/ui/maps/area_map_snapshot.gd")
const Canvas := preload("res://scripts/ui/maps/map_canvas.gd")
var view: Control
var title: Label
var area_title: Label
var legend: Label
var places_title: Label
var places: VBoxContainer
var empty_label: Label
var close_button: Button
var rows: Array[Button] = []
var hints: HintBar

func _init() -> void:
	super._init()
	screen_id = &"map_ui"
	modal_name = &"map"
	hotkey_action = &"map"

func _ready() -> void:
	super._ready()
	L.scrim(self)
	var margin := L.margin(self, 32)
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var book := L.panel(margin, "PanelBook")
	var body := L.box(L.margin(book, 24), true, 12)
	var header := L.box(body, false)
	title = L.label(header, "", "Display34")
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	close_button = L.button(header, "", "ButtonSecondaryS")
	close_button.name = "MapClose"
	close_button.owner = self
	close_button.unique_name_in_owner = true
	close_button.pressed.connect(close)
	area_title = L.label(body, "", "Display20")
	var columns := L.box(body, false, 20)
	columns.size_flags_vertical = SIZE_EXPAND_FILL
	view = Canvas.new()
	view.size_flags_horizontal = SIZE_EXPAND_FILL
	columns.add_child(view)
	closed.connect(func(): view.snapshot = {}; view.queue_redraw())
	var side := L.box(columns)
	side.custom_minimum_size.x = 300
	places_title = L.label(side, "", "Display20")
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	side.add_child(scroll)
	places = L.box(scroll, true, 6) as VBoxContainer
	places.size_flags_horizontal = SIZE_EXPAND_FILL
	empty_label = L.label(places, "", "Body", true)
	legend = L.label(body, "", "Muted14", true)
	hints = preload("res://scenes/ui/components/hint_bar.tscn").instantiate()
	body.add_child(hints)
	hints.set_hints([{"pair": [&"ui_up", &"ui_down"], "key": "HINT_MOVE"}, {"action": &"map", "key": "HINT_BACK"}, {"action": &"ui_cancel", "key": "HINT_BACK"}])

func _hotkey_open_allowed() -> bool:
	var world := get_tree().get_first_node_in_group("world_2d") as WorldRoot2D
	return world != null and world.area != null and world.player != null and not world.traveling and not world.sleeping and world.player.state == PlayerBody2D.S.FREE

func open(opener: Control = null) -> void:
	if _hotkey_open_allowed(): super.open(opener)

func _initial_focus() -> Control:
	return rows[0] if not rows.is_empty() else close_button

func _refresh_texts() -> void:
	if not is_node_ready() or not is_open(): return
	var world := get_tree().get_first_node_in_group("world_2d") as WorldRoot2D
	if world == null or world.area == null: return
	var forest: Node = world.game_ui.get_screen(&"forest_hud")
	var fog: Minimap2D = forest.minimap if forest != null and world.area.projection == &"ortho" and forest.minimap.area == world.area else null
	var snapshot := Snapshot.capture(world.area, world.player, fog)
	view.show_map(snapshot)
	title.text = tr("MAP_TITLE")
	area_title.text = tr(snapshot.title)
	places_title.text = tr("MAP_PLACES")
	legend.text = tr("MAP_LEGEND") + (" · " + tr("MAP_EXPLORED") if fog != null else "")
	close_button.text = tr("UI_CLOSE")
	# Keep row controls across language changes so their focus and scroll position survive.
	while rows.size() > snapshot.places.size():
		var removed: Button = rows.pop_back()
		places.remove_child(removed)
		removed.queue_free()
	while rows.size() < snapshot.places.size():
		var index := rows.size()
		var row := L.button(places, "", "ChoiceRow")
		row.name = "MapPlace%d" % index
		row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.custom_minimum_size.x = 288
		row.focus_entered.connect(view.select.bind(index))
		row.pressed.connect(view.select.bind(index))
		rows.append(row)
	for index in snapshot.places.size():
		var place: Dictionary = snapshot.places[index]
		var row := rows[index]
		row.text = "%d · %s" % [index + 1, tr(place.label)]
		row.tooltip_text = tr(place.label)
		# Citizen and town proper names intentionally stay the same in both languages.
		if place.kind == "person" or place.label in ["ZONE_TRAETOPPEN", "ZONE_CITY"]:
			row.set_meta("tt_text_same_ok", true)
		elif row.has_meta("tt_text_same_ok"):
			row.remove_meta("tt_text_same_ok")
		if row.has_focus(): view.select(index)
	empty_label.text = tr("MAP_NO_PLACES")
	empty_label.visible = rows.is_empty()
	UiNav.wire_ring(rows + [close_button])
	UiNav.hover_focus(rows + [close_button])
