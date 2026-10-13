extends RefCounted
## scenes/ui/dialogue_ui.tscn : dialogue box (guide section 03 "Dialogboks"). Script: scripts/ui/dialogue_ui.gd

func build(K) -> void:
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
	K.vbox(v, "ChoicesBox", 6, {"visible": false}, true)
	var foot = K.hbox(v, "Footer", 6, {"alignment": BoxContainer.ALIGNMENT_END})
	var vg = K.hbox(foot, "VoiceGroup", 4, {"shrink_center_v": true}, true)
	var sp = K.add(vg, "TextureRect", "SpeakerIcon", {"texture": load("res://assets/ui/icons/speaker.svg"), "expand_mode": TextureRect.EXPAND_IGNORE_SIZE,
		"stretch_mode": TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "min": Vector2(14, 14), "modulate": Color("#6a5a48"), "shrink_center_v": true, "mouse_filter": Control.MOUSE_FILTER_IGNORE})
	K.lbl(vg, "VoiceIndicator", "dansk stemme ·", "Eyebrow", {"ignore": true}, true)
	K.btn(foot, "NextButton", "E for at fortsætte", "HintButton", {"focus_mode": Control.FOCUS_ALL}, true)
	K.save("res://scenes/ui/dialogue_ui.tscn")
