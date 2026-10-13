extends RefCounted
## scenes/ui/inventory_ui.tscn : "Rygsæk og værksted" (guide section 09). Script: scripts/ui/inventory_ui.gd

func build(K) -> void:
	var r = K.begin("Control", "InventoryUI", "res://scripts/ui/inventory_ui.gd")
	K.full(r)
	var scrim = K.add(r, "ColorRect", "Scrim", {"color": Color.WHITE})
	K.full(scrim)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/blur_scrim.gdshader")
	mat.set_shader_parameter("tint", Color(0.227, 0.192, 0.314, 0.93))   # guide: book/backpack sit on a #3a3150 night-violet dim
	scrim.material = mat
	var m = K.margin(r, "Margin", 60, 50, 60, 50)
	K.full(m)
	var cols = K.hbox(m, "Columns", 28)

	# ---- backpack
	var bp = K.panel(cols, "Backpack", "PanelParchmentL24")
	var bv = K.vbox(bp, "BackpackBody", 16)
	var bh = K.hbox(bv, "BackpackHeader", 0)
	K.lbl(bh, "TitleLabel", "Rygsæk", "Display32", {"expand_h": true}, true)
	K.lbl(bh, "CapacityLabel", "18 / 24", "Bold17Muted", {"shrink_end_v": true}, true)
	K.add(bv, "GridContainer", "ItemGrid", {"columns": 6, "hsep": 8, "vsep": 8}, true)
	var dp = K.panel(bv, "Detail", "PanelDetail")
	var dh = K.hbox(dp, "DetailRow", 14)
	var ib = K.panel(dh, "DetailIconBox", "FrameInk", {"min": Vector2(72, 72), "shrink_begin_v": true, "ignore": true})
	K.add(ib, "Control", "DetailIcon", {"script": "res://scripts/ui/components/tt_item_icon.gd"}, true)
	var dv = K.vbox(dh, "DetailText", 2, {"expand_h": true})
	var nr = K.hbox(dv, "NameRow", 8)
	K.lbl(nr, "DetailName", "Månesten", "Heavy19", {}, true)
	K.lbl(nr, "DetailRarity", "· Sjælden", "RareTag", {"shrink_end_v": true}, true)
	K.lbl(dv, "DetailDesc", "Lyser svagt i mørke. Fundet dybt i Mørkeskoven. Sælges for 220.", "Muted15",
		{"autowrap_mode": TextServer.AUTOWRAP_WORD_SMART, "custom_minimum_size": Vector2(260, 0)}, true)

	# ---- workshop
	var ws = K.panel(cols, "Workshop", "PanelParchmentL24", {"expand_h": true})
	var wv = K.vbox(ws, "WorkshopBody", 16)
	K.lbl(wv, "WorkshopTitle", "Værksted", "Display32", {}, true)
	K.vbox(wv, "RecipeList", 6, {}, true)
	K.spacer(wv, "Spacer", 0, 0, false, true)
	var cc = K.panel(wv, "CraftCard", "CraftCard")
	var cv = K.vbox(cc, "CraftBody", 12)
	K.lbl(cv, "RecipeName", "Lygte med svampelys", "Heavy19", {}, true)
	K.hbox(cv, "IngredientRow", 10, {}, true)
	K.btn(cv, "CraftButton", "Lav", "ButtonPrimaryS", {"shrink_begin_h": true}, true)
	K.btn(r, "CloseButton", "✕", "ButtonTertiaryS", {}, true)
	var cb = r.get_node("%CloseButton")
	cb.anchor_left = 1.0; cb.anchor_right = 1.0; cb.anchor_top = 0.0; cb.anchor_bottom = 0.0
	cb.offset_left = -104.0; cb.offset_right = -60.0; cb.offset_top = 8.0; cb.offset_bottom = 48.0
	K.save("res://scenes/ui/inventory_ui.tscn")
