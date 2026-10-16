extends Node
## Owner layouts retain the reference builders as read-only design evidence.
const Kit := preload("res://tools/ui/scene_kit.gd")
const C := preload("res://scripts/ui/theme/tt_colors.gd")
func run() -> void:
	_shop()
	_inventory()
	get_tree().quit()

func _theme() -> Theme:
	var theme := Theme.new()
	var base := load("res://assets/ui/theme.tres") as Theme
	for spec in [["CatalogTooDear", "Display20", C.THORNBERRY], ["CatalogMissing", "Heavy17", C.THORNBERRY], ["CatalogHave", "Heavy17", C.MOSS_DARK], ["CatalogHaveCount", "Display16", C.MOSS_DARK], ["CatalogMissingCount", "Display16", C.THORNBERRY]]:
		theme.set_type_variation(spec[0], "Label")
		theme.set_font("font", spec[0], base.get_font("font", spec[1]))
		theme.set_font_size("font_size", spec[0], base.get_font_size("font_size", spec[1]))
		theme.set_color("font_color", spec[0], spec[2])
	for id in Rarity.IDS:
		var token := "CatalogRarity_" + str(id)
		theme.set_type_variation(token, "Label")
		theme.set_font("font", token, base.get_font("font", "Heavy18"))
		theme.set_font_size("font_size", token, 18)
		theme.set_color("font_color", token, Rarity.ui(id).label)
	return theme

func _root(k, name: String, script: String, tint: Color) -> Control:
	var root: Control = k.begin("Control", name, script)
	k.full(root)
	root.theme = _theme()
	var scrim = k.add(root, "ColorRect", "Scrim", {"color": Color.WHITE})
	k.full(scrim)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/blur_scrim.gdshader")
	material.set_shader_parameter("tint", tint)
	scrim.material = material
	return root

func _shop() -> void:
	var k = Kit.new()
	var root := _root(k, "ShopUI", "res://scripts/ui/shop_ui.gd", Color(0.84, 0.80, 0.91, 0.30))
	var keeper = k.vbox(root, "Keeper", 16, {"ignore": true, "alignment": BoxContainer.ALIGNMENT_END})
	keeper.anchor_top = 1
	keeper.anchor_bottom = 1
	keeper.offset_left = 60
	keeper.offset_right = 400
	keeper.offset_top = -560
	var bubble = k.panel(keeper, "SpeechBubble", "PanelBubble", {"ignore": true})
	k.lbl(bubble, "KeeperSpeech", "", "BodyM", {"ignore": true, "autowrap_mode": TextServer.AUTOWRAP_WORD_SMART, "min": Vector2(300, 0)}, true)
	var figure = k.add(keeper, "Control", "KeeperFigure", {"min": Vector2(0, 380), "ignore": true, "clip_contents": true})
	var stripes = k.stripes(figure, "Stripes", Color("e7b7c6"), Color("dea9ba"), 14, {"radii": Vector4(16,16,0,0), "border": 2.0})
	k.full(stripes)
	var portrait = k.add(figure, "TextureRect", "KeeperFace", {"expand_mode": TextureRect.EXPAND_IGNORE_SIZE, "stretch_mode": TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "ignore": true}, true)
	k.full(portrait)
	var name = k.lbl(figure, "KeeperName", "", "NamePlate", {"ignore": true}, true)
	k.pin(name, "bl", 16, 18)
	var panel = k.panel(root, "ShopPanel", "PanelParchmentL", {}, true)
	panel.anchor_left = 1
	panel.anchor_right = 1
	panel.offset_left = -840
	panel.offset_right = -60
	panel.offset_top = 60
	panel.offset_bottom = 660
	var body = k.vbox(panel, "PanelBody", 0)
	var header = k.panel(body, "Header", "PanelHeader")
	var hv = k.vbox(header, "HeaderBody", 10)
	var row = k.hbox(hv, "TitleRow", 12)
	k.lbl(row, "ShopNameLabel", "", "Display32", {"expand_h": true}, true)
	k.btn(row, "CloseButton", "✕", "ButtonTertiaryS", {}, true)
	var tabs = k.add(hv, "ScrollContainer", "TabsScroll", {"follow_focus": true, "horizontal_scroll_mode": ScrollContainer.SCROLL_MODE_AUTO, "vertical_scroll_mode": ScrollContainer.SCROLL_MODE_DISABLED, "min": Vector2(0, 42)})
	k.hbox(tabs, "TabRow", 6, {}, true)
	var status_margin = k.margin(body, "StatusMargin", 24, 0, 24, 0)
	k.lbl(status_margin, "ClosedLabel", "", "CatalogMissing", {"autowrap_mode": TextServer.AUTOWRAP_WORD_SMART, "visible": false}, true)
	var scroll = k.add(body, "ScrollContainer", "ItemScroll", {"expand_v": true, "follow_focus": true, "horizontal_scroll_mode": ScrollContainer.SCROLL_MODE_DISABLED})
	var im = k.margin(scroll, "ItemMargin", 24, 12, 24, 12, {"expand_h": true})
	var rows = k.vbox(im, "ItemsBody", 6, {"expand_h": true})
	k.lbl(rows, "EmptyLabel", "STORE_EMPTY", "Muted17", {}, true)
	k.add(rows, "GridContainer", "ItemGrid", {"columns": 2, "hsep": 10, "vsep": 10, "expand_h": true}, true)
	var detail_margin = k.margin(body, "DetailMargin", 24, 8, 24, 8)
	var detail = k.hbox(detail_margin, "Detail", 14)
	var image = k.add(detail, "Control", "DetailImage", {"min": Vector2(80, 80), "ignore": true})
	var icon = k.add(image, "Control", "DetailIcon", {"script": "res://scripts/ui/components/tt_item_icon.gd", "ignore": true}, true)
	k.full(icon)
	var preview = k.add(image, "TextureRect", "DetailPreview", {"ignore": true, "expand_mode": TextureRect.EXPAND_IGNORE_SIZE, "stretch_mode": TextureRect.STRETCH_KEEP_ASPECT_CENTERED}, true)
	k.full(preview)
	var dv = k.vbox(detail, "DetailText", 2, {"expand_h": true})
	k.lbl(dv, "DetailName", "", "Heavy18", {}, true)
	k.lbl(dv, "DetailDesc", "", "Muted17", {"autowrap_mode": TextServer.AUTOWRAP_WORD_SMART, "max_lines_visible": 2}, true)
	k.lbl(dv, "DetailState", "", "Muted13", {"autowrap_mode": TextServer.AUTOWRAP_WORD_SMART}, true)
	var footer = k.panel(body, "Footer", "PanelFooter")
	var fr = k.hbox(footer, "FooterRow", 14)
	var balance = k.hbox(fr, "Balance", 8, {"expand_h": true})
	k.coin(balance, "Coin", true)
	k.lbl(balance, "GoldLabel", "", "Display24", {}, true)
	k.inst(fr, "res://scenes/ui/components/quantity_stepper.tscn", "Stepper", {"shrink_center_v": true}, true)
	k.lbl(fr, "TotalLabel", "", "Display20", {"shrink_center_v": true}, true)
	k.btn(fr, "BuyButton", "UI_BUY", "ButtonPrimary", {"shrink_center_v": true}, true)
	var hints = k.add(root, "HBoxContainer", "HintBar", {"script": "res://scripts/ui/components/hint_bar.gd"}, true)
	k.pin(hints, "br", 60, 12)
	k.save("res://scenes/ui/shop_ui.tscn")

func _inventory() -> void:
	var k = Kit.new()
	var root := _root(k, "InventoryUI", "res://scripts/ui/inventory_ui.gd", Color(0.227, 0.192, 0.314, 0.93))
	var backdrop: Theme = root.theme
	var base := load("res://assets/ui/theme.tres") as Theme
	var bag_style := base.get_stylebox("panel", "PanelParchmentL24").duplicate(false) as StyleBox
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		bag_style.set_content_margin(side, 20)
	backdrop.set_type_variation("CatalogBackpack", "PanelContainer")
	backdrop.set_stylebox("panel", "CatalogBackpack", bag_style)
	var margin = k.margin(root, "Margin", 60, 50, 60, 50)
	k.full(margin)
	var cols = k.hbox(margin, "Columns", 28)
	var bag = k.panel(cols, "Backpack", "CatalogBackpack", {"min": Vector2(540, 0)})
	bag.set_meta("tt_gold_ok", "Guide parchment panel rings; tighter padding accommodates the four backpack actions")
	var bv = k.vbox(bag, "BackpackBody", 8)
	var header = k.hbox(bv, "BackpackHeader", 12)
	k.lbl(header, "TitleLabel", "INV_TITLE", "Display32", {"expand_h": true}, true)
	k.lbl(header, "CapacityLabel", "", "Display20", {"shrink_center_v": true}, true)
	var grid_scroll = k.add(bv, "ScrollContainer", "BagScroll", {"min": Vector2(436, 292), "horizontal_scroll_mode": ScrollContainer.SCROLL_MODE_DISABLED, "follow_focus": true})
	var grid_margin = k.margin(grid_scroll, "FocusMargin", 6, 6, 6, 6)
	k.add(grid_margin, "GridContainer", "ItemGrid", {"columns": 6, "hsep": 8, "vsep": 8}, true)
	var detail = k.panel(bv, "Detail", "PanelDetail")
	var dr = k.hbox(detail, "DetailRow", 14)
	var icon_box = k.panel(dr, "DetailIconBox", "FrameInk", {"min": Vector2(72, 72), "shrink_begin_v": true, "ignore": true})
	k.add(icon_box, "Control", "DetailIcon", {"script": "res://scripts/ui/components/tt_item_icon.gd", "ignore": true}, true)
	var dv = k.vbox(dr, "DetailText", 2, {"expand_h": true})
	k.lbl(dv, "DetailName", "", "Heavy19", {"autowrap_mode": TextServer.AUTOWRAP_WORD_SMART, "max_lines_visible": 2}, true)
	k.lbl(dv, "DetailRarity", "", "RareTag", {}, true)
	k.lbl(dv, "DetailDesc", "", "Muted17", {"min": Vector2(260, 0), "autowrap_mode": TextServer.AUTOWRAP_WORD_SMART, "max_lines_visible": 2}, true)
	var actions = k.hbox(bv, "Actions", 6)
	for spec in [["UseButton", "STORE_USE"], ["EquipButton", "STORE_EQUIP_ITEM"], ["AssignButton", "STORE_ASSIGN"], ["DropButton", "STORE_DISCARD"]]:
		k.btn(actions, spec[0], spec[1], "ButtonTertiaryS", {}, true)
	var workshop = k.panel(cols, "Workshop", "PanelParchmentL24", {"expand_h": true})
	var wv = k.vbox(workshop, "WorkshopBody", 12, {"script": "res://scripts/ui/components/workshop_panel.gd"}, true)
	k.lbl(wv, "WorkshopTitle", "WORKSHOP_TITLE", "Display32", {}, true)
	var recipes = k.add(wv, "ScrollContainer", "RecipesScroll", {"expand_v": true, "horizontal_scroll_mode": ScrollContainer.SCROLL_MODE_DISABLED, "follow_focus": true})
	var recipe_margin = k.margin(recipes, "FocusMargin", 6, 6, 6, 6, {"expand_h": true})
	k.vbox(recipe_margin, "RecipeList", 6, {"expand_h": true}, true)
	var card = k.panel(wv, "CraftCard", "CraftCard")
	var cv = k.vbox(card, "CraftBody", 10)
	k.lbl(cv, "RecipeName", "", "Heavy19", {"autowrap_mode": TextServer.AUTOWRAP_WORD_SMART, "max_lines_visible": 2}, true)
	k.hbox(cv, "IngredientRow", 8, {}, true)
	k.lbl(cv, "RecipeStatus", "", "Muted17", {"autowrap_mode": TextServer.AUTOWRAP_WORD_SMART}, true)
	k.btn(cv, "CraftButton", "WORKSHOP_CRAFT", "ButtonPrimaryS", {"shrink_begin_h": true}, true)
	var close = k.btn(root, "CloseButton", "✕", "ButtonTertiaryS", {}, true)
	k.pin(close, "tr", 60, 4)
	var hints = k.add(root, "HBoxContainer", "HintBar", {"script": "res://scripts/ui/components/hint_bar.gd"}, true)
	k.pin(hints, "br", 60, 8)
	var picker = k.add(root, "Control", "HotbarPicker", {"visible": false}, true)
	k.full(picker)
	var picker_scrim = k.add(picker, "ColorRect", "Scrim", {"color": Color(0.11, 0.129, 0.22, 0.7)})
	k.full(picker_scrim)
	var popup = k.panel(picker, "Panel", "PanelParchmentL24")
	k.pin(popup, "c")
	var pb = k.vbox(popup, "Body", 16)
	k.lbl(pb, "PickerTitle", "STORE_ASSIGN_TITLE", "Display28")
	k.hbox(pb, "PickerRow", 12, {}, true)
	k.btn(pb, "PickerCancel", "NAV_CANCEL", "ButtonTertiaryS", {}, true)
	k.save("res://scenes/ui/inventory_ui.tscn")
