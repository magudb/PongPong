extends RefCounted
## scenes/main/main_menu.tscn (root MainMenu: tests/playtest.gd and project.godot run/main_scene expect this path+name)  (guide section 04). Script: scripts/ui/main_menu.gd

func build(K) -> void:
	var r = K.begin("Control", "MainMenu", "res://scripts/ui/main_menu.gd")
	K.full(r)
	var art = K.add(r, "TextureRect", "KeyArt", {"texture": load("res://assets/ui/keyart/title.png"), "expand_mode": TextureRect.EXPAND_IGNORE_SIZE, "stretch_mode": TextureRect.STRETCH_KEEP_ASPECT_COVERED, "ignore": true})
	K.full(art)

	# CSS line-height .9 vs Godot's font-height line box: lift the block 16 px and tighten the gap by 33 px
	# (Caprasimo 132px: content area 151 px, CSS line box 119 px -> glyphs sit 16 px higher in the HTML)
	var block = K.vbox(r, "TitleBlock", -27, {"ignore": true})
	K.pin(block, "tl", 110, 94)
	K.lbl(block, "TitleLabel", "Trætoppen", "HeroTitle", {}, true)
	var tm = K.margin(block, "TaglineMargin", 8, 0, 0, 0, {"shrink_begin_h": true})
	K.lbl(tm, "SubtitleLabel", "En gård i Fekongens skov", "Tagline", {}, true)

	var mp = K.panel(r, "MenuPanel", "PanelMenu", {"min": Vector2(320, 0)})
	K.pin(mp, "bl", 116, 96)
	var list = K.vbox(mp, "MenuList", 4)
	var cont = K.btn(list, "ContinueButton", "Fortsæt", "MenuRow", {"alignment": HORIZONTAL_ALIGNMENT_LEFT}, true)
	var info = K.lbl(cont, "ContinueInfo", "", "Bold15Mono", {"ignore": true}, true)
	K.pin(info, "rc", 18, 0)
	K.btn(list, "NewGameButton", "Nyt spil", "MenuRow", {"alignment": HORIZONTAL_ALIGNMENT_LEFT}, true)
	K.btn(list, "SettingsButton", "Indstillinger", "MenuRow", {"alignment": HORIZONTAL_ALIGNMENT_LEFT}, true)
	K.btn(list, "QuitButton", "Afslut", "MenuRow", {"alignment": HORIZONTAL_ALIGNMENT_LEFT}, true)

	var lang = K.btn(r, "LanguageButton", "v0.1 · Dansk", "VersionButton", {}, true)
	K.pin(lang, "br", 40, 30)
	# The current menu controller uses the existing screen lifecycle. Apply the artwork's
	# typography and box styles as local overrides on that menu.
	_apply_menu_styles(r, load("res://assets/ui/theme.tres") as Theme)
	K.save("res://scenes/main/main_menu.tscn")


func _apply_menu_styles(node: Node, palette: Theme) -> void:
	if node is Control:
		var control := node as Control
		var style := control.theme_type_variation
		if style != &"":
			for key in palette.get_color_list(style):
				control.add_theme_color_override(key, palette.get_color(key, style))
			for key in palette.get_constant_list(style):
				control.add_theme_constant_override(key, palette.get_constant(key, style))
			for key in palette.get_font_list(style):
				control.add_theme_font_override(key, palette.get_font(key, style))
			for key in palette.get_font_size_list(style):
				control.add_theme_font_size_override(key, palette.get_font_size(key, style))
			for key in palette.get_stylebox_list(style):
				control.add_theme_stylebox_override(key, palette.get_stylebox(key, style))
			control.theme_type_variation = &""
	for child in node.get_children():
		_apply_menu_styles(child, palette)
