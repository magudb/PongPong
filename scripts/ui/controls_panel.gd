extends TTScreen
## Styring: a read-only list of every world control on the keyboard / mouse and on a pad (review UX-17), opened from Settings.
## Every key is read from the live InputMap through UiHints, so the page follows the bindings and the pad family in use.
const L := preload("res://scripts/ui/social/social_layout.gd")
## [label key, actions]: the actions of one row (their bindings are listed); rows with a special text are built in _row_texts().
const ROWS := [
	["NAV_CONTROLS_MOVE", []], ["NAV_CONTROLS_RUN", [&"run"]], ["NAV_CONTROLS_INTERACT", [&"interact"]],
	["NAV_CONTROLS_TOOL", [&"use_tool"]], ["NAV_CONTROLS_CLICK", []], ["NAV_CONTROLS_JUMP", [&"jump"]], ["NAV_CONTROLS_DODGE", [&"dodge"]],
	["NAV_CONTROLS_LIGHT", [&"light"]], ["NAV_CONTROLS_DRINK", [&"drink"]], ["NAV_CONTROLS_FLY", [&"fly_toggle"]],
	["NAV_CONTROLS_DESCEND", [&"fly_descend"]], ["NAV_CONTROLS_ZOOM", []], ["NAV_CONTROLS_HOTBAR", []],
	["INV_TITLE", [&"inventory"]], ["MAP_TITLE", [&"map"]], ["QJ_TITLE", [&"journal"]], ["PAUSE_PEOPLE", [&"people"]],
	["PAUSE_BUILD", [&"build_menu"]], ["INDRET_TITLE", [&"decorate"]], ["PAUSE_WARDROBE", [&"wardrobe"]], ["UI_PAUSED", [&"pause"]],
]
var close_button: Button
var _cells: Array = []

func _init() -> void:
	super._init()
	screen_id = &"controls"
	modal_name = &"controls"
	nested_under = &"settings"

func _ready() -> void:
	super._ready()
	L.scrim(self)
	var book := L.panel(self, "PanelBook", Rect2(85, 35, 1110, 650))
	var body := L.box(L.margin(book, 22), true, 12)
	var header := L.box(body, false)
	var title := L.label(header, "NAV_CONTROLS_TITLE", "Display34")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_button = L.button(header, "HINT_CLOSE", "ButtonTertiaryS")
	close_button.name = "ControlsClose"
	close_button.pressed.connect(close)
	var columns := L.box(body, false, 36)
	var half := ceili(ROWS.size() / 2.0)
	for part in [ROWS.slice(0, half), ROWS.slice(half)]:
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 6)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(grid)
		L.label(grid, "", "Heavy17")
		L.label(grid, "NAV_CONTROLS_KEYBOARD", "Heavy17")
		L.label(grid, "NAV_CONTROLS_GAMEPAD", "Heavy17")
		for row in part:
			var name_label := L.label(grid, str(row[0]), "Body")
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var keys := [L.label(grid, "", "Bold15Mono"), L.label(grid, "", "Bold15Mono")]
			for key_label in keys:
				key_label.set_meta(&"tt_text_same_ok", true)            # key names (Shift, Esc, Start): the same in both languages
			_cells.append([row, keys[0], keys[1]])
	UiNav.wire_ring([close_button])
	UiNav.hover_focus([close_button])
	UiNav.watcher().device_changed.connect(func(_device): _refresh_texts())
	_refresh_texts()

func _initial_focus() -> Control:
	return close_button

func _refresh_texts() -> void:
	for cell in _cells:
		var texts := _row_texts(cell[0])
		cell[1].text = texts[0]
		cell[2].text = texts[1]

## [keyboard / mouse, pad] of one row; a screen with no pad button names the pause-menu row that opens it.
func _row_texts(row: Array) -> Array[String]:
	var kb := UiNav.KEYBOARD
	var pad := UiNav.GAMEPAD
	match str(row[0]):
		"NAV_CONTROLS_MOVE":
			return [UiHints.glyph_set([&"move_forward", &"move_left", &"move_back", &"move_right"], kb) + " / " + UiHints.glyph_set([&"ui_up", &"ui_left", &"ui_down", &"ui_right"], kb), tr("NAV_PAD_LSTICK")]
		"NAV_CONTROLS_CLICK":
			# A click works the clicked cell around the hero; the pad and the X key work the cell in front.
			return [tr("NAV_CONTROLS_CLICK_GROUND"), tr("NAV_CONTROLS_TILE_AHEAD")]
		"NAV_CONTROLS_ZOOM":
			return [tr("NAV_CONTROLS_WHEEL"), UiHints.glyph_pair(&"zoom_in", &"zoom_out", pad)]
		"NAV_CONTROLS_HOTBAR":
			return ["%s–%s" % [UiHints.glyph(&"slot_1", kb), UiHints.glyph(&"slot_8", kb)], UiHints.glyph_pair(&"hotbar_previous", &"hotbar_next", pad)]
	var action: StringName = row[1][0]
	var on_pad := UiHints.glyph_all(action, pad)
	return [UiHints.glyph_all(action, kb), on_pad if on_pad != "" else tr("NAV_CONTROLS_PAUSE_ROW")]
