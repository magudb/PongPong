extends Node
## Production conversation layouts, adapted from the immutable reference builders.
const Kit := preload("res://tools/ui/scene_kit.gd")
func run() -> void:
	_dialogue()
	_journal()
	get_tree().quit()

func _dialogue() -> void:
	var k := Kit.new()
	_dialogue_layout(k)
	var root: Control = k.root
	root.theme = load("res://assets/ui/theme.tres")
	var box: Control = root.get_node("Box")
	var theme := Theme.new()
	var style := root.theme.get_stylebox("panel", "PanelParchment").duplicate() as StyleBox
	style.set_content_margin(SIDE_BOTTOM, 8)
	theme.set_type_variation("ConversationPanel", "PanelContainer")
	theme.set_stylebox("panel", "ConversationPanel", style)
	root.theme = theme
	box.theme_type_variation = &"ConversationPanel"
	box.set_meta("tt_gold_ok", "Guide dialogue parchment frame; the footer uses an 8px bottom inset")
	box.custom_minimum_size.x = 880
	k.pin(box, "bc", 0, 120)
	root.get_node("Box/Row/Content/SpeakerLabel").text = ""
	root.get_node("Box/Row/Content/TextLabel").text = ""
	root.get_node("Box/Row/Content/TextLabel").bbcode_enabled = false
	root.get_node("Box/Row/Content/TextLabel").custom_minimum_size.y = 72
	root.get_node("Box/Row/Content").add_theme_constant_override("separation", 12)
	root.get_node("Box/Row/Content/Bottom/ChoicesBox").add_theme_constant_override("separation", 6)
	root.get_node("Box/Row/Content/Bottom/Footer/VoiceGroup/VoiceIndicator").text = "DIALOGUE_VOICE_DA"
	root.get_node("Box/Row/Content/Bottom/Footer/NextButton").text = "HINT_CONTINUE"
	k.save("res://scenes/ui/dialogue_ui.tscn")

func _journal() -> void:
	var k := Kit.new()
	_journal_layout(k)
	var root: Control = k.root
	root.theme = load("res://assets/ui/theme.tres")
	var side := root.get_node("Book/Columns/Sidebar/SidebarBody")
	side.add_theme_constant_override("separation", 12)
	side.get_node("SidebarTitle").text = "QJ_TITLE"
	side.get_node("SidebarTitle").theme_type_variation = &"Display32"
	side.get_node("Tabs/ActiveTab").text = "QJ_TAB_ACTIVE"
	side.get_node("Tabs/CompletedTab").text = "QJ_TAB_DONE"
	var tab := k.btn(side.get_node("Tabs"), "TabCalendar", "DLG_JOURNAL_CALENDAR", "PillTab", {"toggle_mode": true, "visible": false}, true)
	tab.button_group = side.get_node("Tabs/ActiveTab").button_group
	var scroll: ScrollContainer = side.get_node("QuestScroll")
	scroll.unique_name_in_owner = true
	scroll.follow_focus = true
	var list := scroll.get_node("QuestList")
	list.owner = null
	scroll.remove_child(list)
	var margin := k.margin(scroll, "FocusMargin", 6, 6, 6, 6, {"expand_h": true})
	margin.add_child(list)
	list.owner = root
	var dm: Control = root.get_node("Book/Columns/DetailMargin")
	dm.unique_name_in_owner = true
	var detail: Control = dm.get_node("DetailBody")
	detail.get_node("DetailText").theme_type_variation = &"Body"
	for path in ["DetailHeader/DetailTitleBox/DetailTitle", "DetailHeader/DetailTitleBox/DetailFrom", "DetailText"]:
		detail.get_node(path).text = ""
	detail.get_node("RewardFooter/RewardBox/RewardHeader").text = "QJ_REWARD"
	detail.get_node("EmptyLabel").text = "QJ_EMPTY"
	var file_caption: Node = detail.get_node("RewardFooter/LuaPathLabel")
	file_caption.get_parent().remove_child(file_caption)
	file_caption.free()
	# Keep Close reachable even when no quest is selected.
	var close: Control = detail.get_node("DetailHeader/CloseButton")
	close.owner = null
	close.get_parent().remove_child(close)
	root.add_child(close)
	close.owner = root
	k.pin(close, "tr", 48, 8)
	var calendar := k.add(root, "MarginContainer", "CalendarHost", {"visible": false}, true)
	k.rect(calendar, 530, 150, 630, 470)
	var hints := k.add(root, "HBoxContainer", "HintBar", {"script": "res://scripts/ui/components/hint_bar.gd"}, true)
	k.pin(hints, "br", 60, 8)
	k.save("res://scenes/ui/quest_journal.tscn")

func _dialogue_layout(K) -> void:
	var r = K.begin("Control", "DialogueUI", "res://scripts/ui/dialogue_ui.gd")
	K.full(r)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box = K.panel(r, "Box", "PanelParchment", {"min": Vector2(900, 0)}, true)
	K.pin(box, "bc", 0, 36)
	var h = K.hbox(box, "Row", 20)
	var pf = K.panel(h, "PortraitFrame", "FramePortrait", {"min": Vector2(150, 150), "shrink_begin_v": true, "ignore": true})
	var m = K.margin(pf, "PortraitMargin", 2, 2, 2, 2, {"ignore": true})
	K.add(m, "TextureRect", "PortraitTexture", {"expand_mode": TextureRect.EXPAND_IGNORE_SIZE, "stretch_mode": TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
		"mouse_filter": Control.MOUSE_FILTER_IGNORE, "texture_filter": CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS}, true)
	var v = K.vbox(h, "Content", 12, {"expand_h": true})
	K.lbl(v, "SpeakerLabel", "Borgmester Hyldeblomst", "NamePlate", {"shrink_begin_h": true}, true)
	K.add(v, "RichTextLabel", "TextLabel", {"variation": "DialogueText", "bbcode_enabled": true, "fit_content": true, "scroll_active": false,
		"min": Vector2(0, 90), "text": "Åh, du må være vinderen af Fekongens lotteri! Velkommen til Hyggebyen. Taget på bageriet er utæt igen. Kan du mon hjælpe?",
		"mouse_filter": Control.MOUSE_FILTER_IGNORE}, true)
	var bottom = K.vbox(v, "Bottom", 6)
	K.vbox(bottom, "ChoicesBox", 6, {"visible": false}, true)
	var foot = K.hbox(bottom, "Footer", 6, {"alignment": BoxContainer.ALIGNMENT_END})
	var vg = K.hbox(foot, "VoiceGroup", 4, {"shrink_center_v": true}, true)
	var sp = K.add(vg, "TextureRect", "SpeakerIcon", {"texture": load("res://assets/ui/icons/speaker.svg"), "expand_mode": TextureRect.EXPAND_IGNORE_SIZE,
		"stretch_mode": TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "min": Vector2(14, 14), "modulate": Color("#6a5a48"), "shrink_center_v": true, "mouse_filter": Control.MOUSE_FILTER_IGNORE})
	K.lbl(vg, "VoiceIndicator", "dansk stemme ·", "Eyebrow", {"ignore": true}, true)
	K.btn(foot, "NextButton", "E for at fortsætte", "HintButton", {"focus_mode": Control.FOCUS_ALL}, true)

func _journal_layout(K) -> void:
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
