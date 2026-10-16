extends Node
## Owner compiler for M1b menus. Reference builders remain untouched.
const Kit := preload("res://tools/ui/scene_kit.gd")

func run() -> void:
	_settings()
	_saveload()
	_title()
	_select()
	_pause()
	get_tree().quit()

func _root(kit, name: String, script: String) -> Control:
	var root: Control = kit.begin("Control", name, script)
	kit.full(root)
	root.theme = load("res://assets/ui/theme.tres")
	return root

func _panel(kit, root: Control, width: float) -> VBoxContainer:
	var scrim = kit.add(root, "ColorRect", "Scrim", {"color": Color(0.11, 0.129, 0.22, 0.62), "ignore": true})
	kit.full(scrim)
	var panel = kit.panel(root, "Panel", "PanelParchment", {"min": Vector2(width, 0)})
	kit.pin(panel, "c")
	return kit.vbox(panel, "Body", 12)

func _hints(kit, parent: Node) -> void:
	kit.add(parent, "HBoxContainer", "HintBar", {"script": "res://scripts/ui/components/hint_bar.gd"}, true)

func _settings() -> void:
	var kit = Kit.new()
	var root := _root(kit, "SettingsUI", "res://scripts/ui/settings_ui.gd")
	var body := _panel(kit, root, 640)
	kit.lbl(body, "TitleLabel", "MENU_SETTINGS", "Display34", {"horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER}, true)
	var language = kit.hbox(body, "LanguageRow", 12)
	kit.lbl(language, "LanguageCaption", "SETTINGS_LANGUAGE", "Heavy18", {"min": Vector2(160, 0), "shrink_center_v": true})
	var languages := ButtonGroup.new()
	for spec in [["LangDa", "SETTINGS_DA"], ["LangEn", "SETTINGS_EN"]]:
		kit.btn(language, spec[0], spec[1], "PillTab", {"toggle_mode": true, "button_group": languages}, true)
	for bus in SettingsUI.BUSES:
		var row = kit.hbox(body, bus + "Row", 16)
		kit.lbl(row, bus + "Caption", "SET_" + bus.to_upper(), "Heavy18", {"min": Vector2(160, 0), "shrink_center_v": true})
		kit.add(row, "HSlider", bus + "Slider", {"script": "res://scripts/ui/components/tt_slider.gd", "min": Vector2(320, 32), "min_value": 0.0, "max_value": 1.0, "step": 0.05, "value": 0.8, "focus_mode": Control.FOCUS_ALL, "expand_h": true}, true)
	kit.add(body, "CheckBox", "FullscreenCheck", {"text": "SET_FULLSCREEN", "focus_mode": Control.FOCUS_ALL}, true)
	var sizes = kit.hbox(body, "Sizes", 12)
	kit.lbl(sizes, "SizeCaption", "SETTINGS_SIZE", "Heavy18", {"shrink_center_v": true})
	var group := ButtonGroup.new()
	for index in SettingsUI.SIZES.size():
		var size: Vector2i = SettingsUI.SIZES[index]
		kit.btn(sizes, "Size%d" % index, "%d × %d" % [size.x, size.y], "Chip", {"toggle_mode": true, "button_group": group}, true)
	kit.btn(body, "CloseButton", "SET_DONE", "ButtonPrimary", {}, true)
	_hints(kit, body)
	kit.save("res://scenes/ui/settings_ui.tscn")

func _saveload() -> void:
	var kit = Kit.new()
	var root := _root(kit, "SaveLoadUI", "res://scripts/ui/save_load_ui.gd")
	var body := _panel(kit, root, 940)
	kit.lbl(body, "TitleLabel", "UI_LOAD_GAME", "Display34", {"horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER}, true)
	kit.vbox(body, "SlotList", 4, {}, true)
	kit.btn(body, "CloseButton", "HINT_BACK", "ButtonTertiary", {}, true)
	_hints(kit, body)
	kit.save("res://scenes/ui/save_load_ui.tscn")

func _title() -> void:
	var kit = Kit.new()
	var root := _root(kit, "MainMenu", "res://scripts/ui/main_menu.gd")
	var art = kit.add(root, "TextureRect", "KeyArt", {"texture": load("res://assets/ui/keyart/title.png"), "expand_mode": TextureRect.EXPAND_IGNORE_SIZE, "stretch_mode": TextureRect.STRETCH_KEEP_ASPECT_COVERED, "ignore": true})
	kit.full(art)
	var title = kit.vbox(root, "TitleBlock", -27, {"ignore": true})
	kit.pin(title, "tl", 110, 94)
	kit.lbl(title, "TitleLabel", "GAME_TITLE", "HeroTitle", {}, true)
	var margin = kit.margin(title, "TaglineMargin", 8, 0, 0, 0, {"shrink_begin_h": true})
	kit.lbl(margin, "SubtitleLabel", "GAME_SUBTITLE", "Tagline", {}, true)
	var panel = kit.panel(root, "MenuPanel", "PanelMenu", {"min": Vector2(320, 0)})
	kit.pin(panel, "bl", 116, 96)
	var rows = kit.vbox(panel, "MenuList", 4)
	var cont = kit.btn(rows, "ContinueButton", "MENU_CONTINUE", "MenuRow", {"alignment": HORIZONTAL_ALIGNMENT_LEFT}, true)
	var info = kit.lbl(cont, "ContinueInfo", "", "Bold15Mono", {"ignore": true}, true)
	kit.pin(info, "rc", 18, 0)
	kit.btn(rows, "LoadButton", "MENU_LOAD_GAME", "MenuRow", {"alignment": HORIZONTAL_ALIGNMENT_LEFT, "visible": false}, true)
	kit.btn(rows, "NewGameButton", "MENU_NEW_GAME", "MenuRow", {"alignment": HORIZONTAL_ALIGNMENT_LEFT}, true)
	kit.btn(rows, "SettingsButton", "MENU_SETTINGS", "MenuRow", {"alignment": HORIZONTAL_ALIGNMENT_LEFT}, true)
	kit.btn(rows, "QuitButton", "MENU_QUIT", "MenuRow", {"alignment": HORIZONTAL_ALIGNMENT_LEFT}, true)
	var language = kit.btn(root, "LanguageButton", "MENU_VERSION_TAG", "VersionButton", {}, true)
	kit.pin(language, "br", 40, 30)
	_hints(kit, root)
	kit.pin(root.get_node("HintBar"), "bl", 116, 60)
	var toasts = kit.add(root, "Control", "ToastStack", {"script": "res://scripts/ui/components/toast_stack.gd", "z_index": 100, "ignore": true}, true)
	kit.full(toasts)
	kit.save("res://scenes/main/main_menu.tscn")

func _select() -> void:
	var kit = Kit.new()
	var root := _root(kit, "CharacterSelect", "res://scripts/ui/character_select.gd")
	var background = kit.add(root, "ColorRect", "Background", {"color": Color("e7d8b6"), "ignore": true})
	kit.full(background)
	kit.rect(kit.lbl(root, "TitleLabel", "SELECT_TITLE", "Display48", {}, true), 64, 42, 1000, 60)
	kit.rect(kit.lbl(root, "SubtitleLabel", "CHAR_SELECT_SUBTITLE", "Subtitle", {}, true), 64, 108, 1040, 32)
	kit.rect(kit.lbl(root, "PageLabel", "1 / 2", "EyebrowL", {"horizontal_alignment": HORIZONTAL_ALIGNMENT_RIGHT}, true), 1110, 86, 106, 28)
	var page = kit.add(root, "Control", "PageRace", {}, true)
	kit.full(page)
	var group := ButtonGroup.new()
	var specs := [
		["Animal", "fox", "e8cfa6", "dfc293"], ["Fairy", "fairy", "e2d8f4", "d3c6ee"],
		["Hobbit", "hobbit_pip", "d4e4b4", "c7dba2"], ["Ghost", "ghost_bu", "cfe6f2", "c0dceb"]]
	for index in specs.size():
		var spec: Array = specs[index]
		var slot = kit.add(page, "Control", spec[0] + "Slot")
		kit.rect(slot, 64 + index * 294, 153, 270, 434)
		var card = kit.btn(slot, spec[0] + "Button", "", "CardButton", {"toggle_mode": true, "button_group": group}, true)
		kit.rect(card, 0, 0, 270, 434)
		var frame = kit.add(card, "Control", "Art", {"ignore": true})
		kit.rect(frame, 16, 16, 238, 304.4)
		var stripes = kit.stripes(frame, "Stripes", Color(spec[2]), Color(spec[3]), 14, {"radii": Vector4(12, 12, 12, 12), "border": 2.0})
		kit.full(stripes)
		var face = kit.add(frame, "Control", spec[0] + "Face", {"script": "res://scripts/ui/components/tt_sprite_face.gd", "character_id": spec[1], "direction": 7, "sprite_scale": 1.25, "feet_y": 0.93}, true)
		kit.full(face)
		kit.rect(kit.lbl(card, spec[0] + "Name", "", "Display32", {"ignore": true}, true), 16, 328, 238, 42)
		kit.rect(kit.lbl(card, spec[0] + "Perk", "", "Muted17", {"ignore": true, "autowrap_mode": TextServer.AUTOWRAP_WORD_SMART, "max_lines_visible": 2}, true), 16, 374, 238, 50)
	var footer = kit.add(page, "Control", "Footer", {"ignore": true})
	kit.rect(footer, 64, 615, 1152, 53)
	kit.rect(kit.lbl(footer, "HeroPrefix", "SELECT_HERO_PREFIX", "Heavy18", {"vertical_alignment": VERTICAL_ALIGNMENT_CENTER}), 0, 0, 80, 53)
	var chips = kit.hbox(footer, "Heroes", 10, {}, true)
	kit.rect(chips, 87, 0, 190, 53)
	var heroes := ButtonGroup.new()
	for index in 2:
		var chip = kit.btn(chips, "HeroChip%d" % (index + 1), "", "Chip", {"toggle_mode": true, "button_group": heroes, "min": Vector2(78 if index == 0 else 102, 53)}, true)
		var name = kit.lbl(chip, "Name", "", "Display20", {"ignore": true, "horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER})
		kit.full(name)
		name.offset_left = 12
		name.offset_right = -12
		name.anchor_bottom = 0
		name.offset_top = 3
		name.offset_bottom = 28
		var kind = kit.lbl(chip, "Kind", "", "Muted13", {"ignore": true, "horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER})
		kit.full(kind)
		kind.offset_left = 12
		kind.offset_right = -12
		kind.anchor_bottom = 0
		kind.offset_top = 28
		kind.offset_bottom = 48
	kit.rect(kit.lbl(footer, "HeroBlurb", "", "Muted17", {"autowrap_mode": TextServer.AUTOWRAP_WORD_SMART, "max_lines_visible": 2, "ignore": true}, true), 301, 0, 541, 53)
	kit.rect(kit.btn(footer, "BackButton", "HINT_BACK", "ButtonTertiary", {}, true), 856, 0, 120, 53)
	kit.rect(kit.btn(footer, "NextButton", "CHAR_NEXT", "ButtonPrimaryL", {}, true), 988, 0, 164, 53)
	var names = kit.add(root, "Control", "PageNames", {"visible": false}, true)
	kit.full(names)
	var form = kit.panel(names, "FormPanel", "PanelParchment")
	kit.rect(form, 64, 180, 744, 340)
	var column = kit.vbox(form, "FormBody", 16)
	kit.lbl(column, "NameCaption", "CHAR_NAME_CAPTION", "Heavy18")
	kit.add(column, "LineEdit", "NameInput", {"max_length": 20, "min": Vector2(0, 48)}, true)
	kit.lbl(column, "FarmCaption", "CHAR_FARM_CAPTION", "Heavy18")
	kit.add(column, "LineEdit", "FarmNameInput", {"max_length": 24, "min": Vector2(0, 48)}, true)
	var preview = kit.panel(names, "Preview", "PanelParchment", {"mouse_filter": Control.MOUSE_FILTER_IGNORE})
	kit.rect(preview, 896, 153, 320, 434)
	var content = kit.vbox(preview, "Body", 8)
	kit.add(content, "Control", "PreviewFace", {"script": "res://scripts/ui/components/tt_sprite_face.gd", "character_id": "fox", "sprite_scale": 1.0, "expand_v": true, "min": Vector2(0, 240)}, true)
	kit.lbl(content, "PreviewName", "", "Display28", {}, true)
	kit.lbl(content, "PreviewPerk", "", "Muted17", {"autowrap_mode": TextServer.AUTOWRAP_WORD_SMART}, true)
	kit.rect(kit.btn(names, "BackToRaceButton", "HINT_BACK", "ButtonTertiary", {}, true), 64, 615, 120, 53)
	kit.rect(kit.btn(names, "ConfirmButton", "CHAR_START", "ButtonPrimaryL", {}, true), 1052, 615, 164, 53)
	_hints(kit, root)
	kit.pin(root.get_node("HintBar"), "bc", 0, 8)
	var toasts = kit.add(root, "Control", "ToastStack", {"script": "res://scripts/ui/components/toast_stack.gd", "z_index": 100, "ignore": true}, true)
	kit.full(toasts)
	kit.save("res://scenes/ui/character_select.tscn")

func _pause() -> void:
	var kit = Kit.new()
	var root := _root(kit, "PauseMenu", "res://scripts/ui/pause_menu.gd")
	var body := _panel(kit, root, 440)
	kit.lbl(body, "TitleLabel", "UI_PAUSED", "Display34", {"horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER}, true)
	kit.vbox(body, "MenuList", 2, {}, true)
	_hints(kit, body)
	kit.save("res://scenes/ui/pause_menu.tscn")
