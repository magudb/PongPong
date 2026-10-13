extends RefCounted
## scenes/ui/quest_journal.tscn : "Opgavebog" (guide section 08). Script: scripts/ui/quest_journal.gd

func build(K) -> void:
	var r = K.begin("Control", "QuestJournal", "res://scripts/ui/quest_journal.gd")
	K.full(r)
	var scrim = K.add(r, "ColorRect", "Scrim", {"color": Color.WHITE})
	K.full(scrim)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/blur_scrim.gdshader")
	mat.set_shader_parameter("tint", Color(0.227, 0.192, 0.314, 0.93))   # guide: book/backpack sit on a #3a3150 night-violet dim
	scrim.material = mat

	var book = K.panel(r, "Book", "PanelBook", {"min": Vector2(1120, 620)}, true)
	K.pin(book, "c", 0, 0)
	var cols = K.hbox(book, "Columns", 0)

	# ---- sidebar
	var side = K.panel(cols, "Sidebar", "PanelSidebar", {"min": Vector2(420, 0)})
	var sv = K.vbox(side, "SidebarBody", 16)
	K.lbl(sv, "SidebarTitle", "Opgaver", "Display34", {}, true)
	var tabs = K.hbox(sv, "Tabs", 6)
	var tg = ButtonGroup.new()
	K.btn(tabs, "ActiveTab", "Aktive · 4", "PillTab", {"toggle_mode": true, "button_group": tg, "button_pressed": true}, true)
	K.btn(tabs, "CompletedTab", "Fuldført · 11", "PillTab", {"toggle_mode": true, "button_group": tg}, true)
	var sc = K.add(sv, "ScrollContainer", "QuestScroll", {"expand_v": true, "horizontal_scroll_mode": ScrollContainer.SCROLL_MODE_DISABLED})
	K.vbox(sc, "QuestList", 8, {"expand_h": true}, true)

	# ---- detail
	var dm = K.margin(cols, "DetailMargin", 40, 32, 40, 28, {"expand_h": true})
	var dv = K.vbox(dm, "DetailBody", 20, {}, true)
	var top = K.hbox(dv, "DetailHeader", 20)
	var gf = K.panel(top, "GiverFrame", "FramePortraitRound", {"min": Vector2(96, 96), "shrink_center_v": true, "ignore": true}, true)
	var gm = K.margin(gf, "GiverMargin", 3, 3, 3, 3, {"ignore": true})
	K.add(gm, "TextureRect", "GiverPortrait", {"expand_mode": TextureRect.EXPAND_IGNORE_SIZE, "stretch_mode": TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
		"mouse_filter": Control.MOUSE_FILTER_IGNORE, "texture_filter": CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS}, true)
	var tv = K.vbox(top, "DetailTitleBox", 4, {"shrink_center_v": true, "expand_h": true})
	K.lbl(tv, "DetailTitle", "Find Pippins kat", "Display40", {"autowrap_mode": TextServer.AUTOWRAP_WORD_SMART}, true)
	K.lbl(tv, "DetailFrom", "Fra Pippin Bøgeknop · Hyggebyen", "Subtitle", {}, true)
	K.btn(top, "CloseButton", "✕", "ButtonTertiaryS", {"shrink_begin_v": true}, true)
	K.lbl(dv, "DetailText", "Morfar Mis er forsvundet igen. Han blev sidst set på vej mod Mørkeskoven med en sardin i munden.", "BodyL",
		{"autowrap_mode": TextServer.AUTOWRAP_WORD_SMART}, true)
	K.vbox(dv, "StepList", 10, {}, true)
	K.spacer(dv, "Spacer", 0, 0, false, true)
	K.add(dv, "Control", "RewardDivider", {"script": "res://scripts/ui/components/tt_dashed_line.gd"})
	var fr = K.hbox(dv, "RewardFooter", 12, {"shrink_end_v": true})
	var rv = K.vbox(fr, "RewardBox", 8, {"expand_h": true}, true)
	K.lbl(rv, "RewardHeader", "BELØNNING", "Eyebrow", {}, true)
	K.add(rv, "HFlowContainer", "RewardRow", {"hsep": 10, "vsep": 8}, true)   # flow: the chips wrap instead of widening the book
	K.lbl(fr, "LuaPathLabel", "quests/pippins_kat.lua", "FilePath", {"shrink_end_v": true}, true)
	K.lbl(dv, "EmptyLabel", "Ingen opgaver endnu.", "BodyL", {"visible": false, "horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER}, true)
	K.save("res://scenes/ui/quest_journal.tscn")
