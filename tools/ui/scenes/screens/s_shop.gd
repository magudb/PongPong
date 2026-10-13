extends RefCounted
## scenes/ui/shop_ui.tscn : "Butik i Hyggebyen" (guide section 07). Script: scripts/ui/shop_ui.gd

const STEPPER := "res://scenes/ui/components/quantity_stepper.tscn"

func build(K) -> void:
	var r = K.begin("Control", "ShopUI", "res://scripts/ui/shop_ui.gd")
	K.full(r)
	# dim + blur whatever is behind (the world); shader reads the screen texture
	var scrim = K.add(r, "ColorRect", "Scrim", {"color": Color.WHITE})
	K.full(scrim)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/blur_scrim.gdshader")
	mat.set_shader_parameter("tint", Color(0.84, 0.80, 0.91, 0.30))   # light lavender veil: the town stays readable behind the shop
	scrim.material = mat

	# ---- shopkeeper (left): speech bubble + half figure with name plate
	var keeper = K.vbox(r, "Keeper", 16, {"ignore": true, "alignment": BoxContainer.ALIGNMENT_END})
	keeper.anchor_left = 0.0; keeper.anchor_right = 0.0; keeper.anchor_top = 1.0; keeper.anchor_bottom = 1.0
	keeper.offset_left = 60.0; keeper.offset_right = 400.0; keeper.offset_top = -560.0; keeper.offset_bottom = 0.0
	var bub = K.panel(keeper, "SpeechBubble", "PanelBubble", {"ignore": true})
	K.lbl(bub, "KeeperSpeech", "Frisk fra regnbuen i morges! Græskarfrø giver gode penge til høstfesten.", "BodyM",
		{"ignore": true, "autowrap_mode": TextServer.AUTOWRAP_WORD_SMART, "min": Vector2(300, 0)}, true)
	var fig = K.add(keeper, "Control", "KeeperFigure", {"min": Vector2(0, 380), "ignore": true, "clip_contents": true})
	var st = K.stripes(fig, "KeeperStripes", Color("#e7b7c6"), Color("#dea9ba"), 14, {"radii": Vector4(16, 16, 0, 0), "border": 2.0})
	K.full(st)
	var face = K.add(fig, "Control", "KeeperFace", {"script": "res://scripts/ui/components/tt_sprite_face.gd", "character_id": "fairy", "direction": 0,
		"sprite_scale": 1.7, "feet_y": 1.04, "clip_contents": true}, true)
	K.full(face)
	var plate = K.lbl(fig, "KeeperName", "Kløvermynte", "NamePlate", {"ignore": true}, true)
	K.pin(plate, "bl", 16, 18)

	# ---- shop panel (right): header + tabs / item grid / footer
	var panel = K.panel(r, "ShopPanel", "PanelParchmentL", {"ignore": true})
	panel.anchor_left = 1.0; panel.anchor_right = 1.0; panel.anchor_top = 0.0; panel.anchor_bottom = 0.0
	panel.offset_left = -840.0; panel.offset_right = -60.0; panel.offset_top = 60.0; panel.offset_bottom = 660.0
	var col = K.vbox(panel, "PanelBody", 0)
	var head = K.panel(col, "Header", "PanelHeader")
	var hh = K.hbox(head, "HeaderRow", 12)
	K.lbl(hh, "ShopNameLabel", "Kløvermyntes Frø", "Display32", {"expand_h": true}, true)
	K.hbox(hh, "TabRow", 6, {"shrink_center_v": true}, true)
	K.btn(hh, "CloseButton", "✕", "ButtonTertiaryS", {"shrink_center_v": true}, true)
	var sc = K.add(col, "ScrollContainer", "ItemScroll", {"expand_v": true, "horizontal_scroll_mode": ScrollContainer.SCROLL_MODE_DISABLED})
	var mg = K.margin(sc, "ItemMargin", 24, 18, 24, 18, {"expand_h": true})
	K.add(mg, "GridContainer", "ItemGrid", {"columns": 2, "hsep": 10, "vsep": 10, "expand_h": true}, true)
	var foot = K.panel(col, "Footer", "PanelFooter")
	var fr = K.hbox(foot, "FooterRow", 14)
	var bal = K.hbox(fr, "Balance", 8, {"expand_h": true})
	K.coin(bal, "Coin", true)
	K.lbl(bal, "GoldLabel", "1.250", "Display24", {}, true)
	K.inst(fr, STEPPER, "Stepper", {"shrink_center_v": true}, true)
	K.lbl(fr, "TotalLabel", "I alt 300", "Bold17Muted", {"shrink_center_v": true}, true)
	K.btn(fr, "BuyButton", "Køb", "ButtonPrimary", {"shrink_center_v": true}, true)
	K.save("res://scenes/ui/shop_ui.tscn")
