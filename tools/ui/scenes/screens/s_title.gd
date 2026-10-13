extends RefCounted
## scenes/main/main_menu.tscn (root MainMenu: tests/playtest.gd and project.godot run/main_scene expect this path+name)  (guide section 04). Script: scripts/ui/main_menu.gd

func build(K) -> void:
	var r = K.begin("Control", "MainMenu", "res://scripts/ui/main_menu.gd")
	K.full(r)
	var art = K.stripes(r, "KeyArt", Color("#b9d7c4"), Color("#aacbb6"), 18)
	K.full(art)
	var note = K.lbl(r, "KeyArtNote", "key art: kæmpetræ med gården i kronen, feer og lanterner, solnedgang", "ArtNote", {"ignore": true})
	K.pin(note, "bl", 24, 20)

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
	var info = K.lbl(cont, "ContinueInfo", "Dag 14", "Bold15Mono", {"ignore": true}, true)
	K.pin(info, "rc", 18, 0)
	K.btn(list, "NewGameButton", "Nyt spil", "MenuRow", {"alignment": HORIZONTAL_ALIGNMENT_LEFT}, true)
	K.btn(list, "SettingsButton", "Indstillinger", "MenuRow", {"alignment": HORIZONTAL_ALIGNMENT_LEFT}, true)
	K.btn(list, "QuitButton", "Afslut", "MenuRow", {"alignment": HORIZONTAL_ALIGNMENT_LEFT}, true)

	var lang = K.btn(r, "LanguageButton", "v0.1 · Dansk", "VersionButton", {}, true)
	K.pin(lang, "br", 40, 30)
	K.save("res://scenes/main/main_menu.tscn")
