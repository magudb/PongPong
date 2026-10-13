extends RefCounted
## scenes/ui/forest_hud.tscn : Mørkeskoven HUD (guide section 10). Script: scripts/ui/forest_hud.gd

const ABILITY := "res://scenes/ui/components/ability_slot.tscn"

func build(K) -> void:
	var r = K.begin("Control", "ForestHUD", "res://scripts/ui/forest_hud.gd")
	K.full(r)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# top left: hearts + lantern oil
	var tl = K.vbox(r, "TopLeft", 10, {"ignore": true})
	K.pin(tl, "tl", 40, 40)
	var hp = K.panel(tl, "HeartsPanel", "PanelHearts", {"shrink_begin_h": true, "ignore": true})
	K.add(hp, "Control", "Hearts", {"script": "res://scripts/ui/components/tt_hearts.gd", "max_hearts": 5, "half_hearts": 7, "mouse_filter": Control.MOUSE_FILTER_IGNORE}, true)
	var op = K.panel(tl, "OilPill", "PillNight", {"shrink_begin_h": true, "ignore": true})
	var oh = K.hbox(op, "OilRow", 10, {"ignore": true})
	K.lbl(oh, "OilLabel", "Lygteolie", "OwlEye15", {"ignore": true}, true)
	K.add(oh, "ProgressBar", "OilBar", {"variation": "MeterNight", "min": Vector2(180, 12), "show_percentage": false, "value": 58, "shrink_center_v": true, "mouse_filter": Control.MOUSE_FILTER_IGNORE}, true)

	# top right: round minimap + zone chip, loot feed below it
	var mm = K.add(r, "Control", "MinimapBox", {"min": Vector2(184, 184), "ignore": true})
	K.pin(mm, "tr", 40, 40)
	var rp = K.panel(mm, "MinimapFrame", "PanelRound", {"ignore": true})
	K.full(rp)
	var ms = K.stripes(rp, "MinimapView", Color("#2f4a3f"), Color("#29413a"), 10, {"radii": Vector4(88, 88, 88, 88)}, )
	ms.name = "MinimapView"
	ms.unique_name_in_owner = true
	K.add(rp, "TextureRect", "MinimapTexture", {"expand_mode": TextureRect.EXPAND_IGNORE_SIZE, "stretch_mode": TextureRect.STRETCH_SCALE,
		"mouse_filter": Control.MOUSE_FILTER_IGNORE, "material": _circle_mat(), "visible": false}, true)
	K.lbl(rp, "MinimapNote", "minikort", "Eyebrow", {"ignore": true, "horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER, "vertical_alignment": VERTICAL_ALIGNMENT_CENTER})
	var note = rp.get_node("MinimapNote")
	K.full(note)
	note.add_theme_color_override("font_color", Color("#fbf5e6"))
	var chip = K.lbl(mm, "ZoneLabel", "Dybe Bregner · 2", "ZoneChip", {"ignore": true, "horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER}, true)
	chip.anchor_left = 0.5; chip.anchor_right = 0.5; chip.anchor_top = 0.0; chip.anchor_bottom = 0.0
	chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	chip.offset_top = -14.0

	var loot = K.vbox(r, "LootFeed", 8, {"ignore": true, "alignment": BoxContainer.ALIGNMENT_BEGIN}, true)
	loot.anchor_left = 1.0; loot.anchor_right = 1.0; loot.anchor_top = 0.0; loot.anchor_bottom = 0.0
	loot.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	loot.offset_left = -40.0; loot.offset_right = -40.0; loot.offset_top = 262.0; loot.offset_bottom = 262.0

	# top centre: boss bar (hidden unless a boss is engaged)
	var bb = K.vbox(r, "BossBox", 6, {"ignore": true, "min": Vector2(420, 0), "visible": false}, true)
	K.pin(bb, "tc", 0, 40)
	K.lbl(bb, "BossName", "Snurresvampen", "DisplayCream24", {"ignore": true, "horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER}, true)
	K.add(bb, "ProgressBar", "BossBar", {"variation": "MeterBoss", "min": Vector2(420, 16), "show_percentage": false, "value": 64, "mouse_filter": Control.MOUSE_FILTER_IGNORE}, true)

	# bottom centre: abilities
	var ab = K.hbox(r, "AbilityRow", 12, {"ignore": true, "alignment": BoxContainer.ALIGNMENT_CENTER}, true)
	K.pin(ab, "bc", 0, 30)
	for spec in [["slag", &"attack", 78.0], ["undvig", &"dodge", 64.0], ["fe-lys", &"fe_light", 64.0], ["drik", &"drink", 64.0]]:
		K.inst(ab, ABILITY, "Ability_" + spec[0].replace("-", "_"), {"shrink_end_v": true})

	# bottom left: whispered flavour text
	var wp = K.panel(r, "WhisperPanel", "PanelWhisper", {"ignore": true, "min": Vector2(0, 0), "visible": false}, true)
	K.pin(wp, "bl", 40, 40)
	K.lbl(wp, "WhisperLabel", "Noget rasler i bregnerne…", "Whisper", {"ignore": true, "autowrap_mode": TextServer.AUTOWRAP_WORD_SMART, "custom_minimum_size": Vector2(300, 0)}, true)
	K.save("res://scenes/ui/forest_hud.tscn")

func _circle_mat() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/circle_mask.gdshader")
	return m
