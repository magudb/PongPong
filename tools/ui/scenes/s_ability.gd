extends RefCounted
## scenes/ui/components/ability_slot.tscn : one forest ability (frame, cooldown veil + number, key cap under it).

func build(K) -> void:
	var r = K.begin("VBoxContainer", "AbilitySlot", "res://scripts/ui/components/ability_slot.gd")
	r.add_theme_constant_override("separation", 6)
	var fr = K.panel(r, "Frame", "PanelAbilityBig", {"min": Vector2(64, 64), "shrink_center_h": true, "ignore": true}, true)
	# a PanelContainer re-lays every direct child over its whole rect, so the veil/label live in a plain Control
	var inner = K.add(fr, "Control", "Inner", {"ignore": true, "clip_contents": true})
	var icon = K.add(inner, "Control", "Icon", {"script": "res://scripts/ui/components/tt_item_icon.gd", "ignore": true}, true)
	K.full(icon)
	var veil = K.add(inner, "ColorRect", "Veil", {"color": Color(0.11, 0.129, 0.22, 0.6), "ignore": true}, true)
	veil.anchor_left = 0.0; veil.anchor_right = 1.0; veil.anchor_top = 1.0; veil.anchor_bottom = 1.0
	veil.offset_left = 0.0; veil.offset_right = 0.0; veil.offset_top = 0.0; veil.offset_bottom = 0.0
	var cd = K.lbl(inner, "CooldownLabel", "", "CooldownNumber", {"ignore": true, "horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER, "vertical_alignment": VERTICAL_ALIGNMENT_CENTER}, true)
	K.full(cd)
	K.lbl(r, "KeyLabel", "Q", "KeyCap", {"ignore": true, "shrink_center_h": true}, true)
	K.save("res://scenes/ui/components/ability_slot.tscn")
