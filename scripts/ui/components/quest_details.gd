extends RefCounted
## Data-only quest checklist and reward widgets.
static func step(s: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var box := PanelContainer.new()
	box.theme_type_variation = &"StepBoxDone" if s["done"] else &"StepBox"
	box.custom_minimum_size = Vector2(24, 24)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if s["done"]:
		var ck := Label.new()
		ck.theme_type_variation = &"StepCheck"
		ck.text = "✓"
		ck.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ck.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(ck)
	h.add_child(box)
	var rt := RichTextLabel.new()
	rt.theme_type_variation = &"StepText"
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var txt: String = s["text"]
	if int(s["target"]) > 1:
		txt += "  (%d / %d)" % [s["current"], s["target"]]
	rt.text = "[color=#8d7c66][s]%s[/s][/color]" % txt if s["done"] else txt
	h.add_child(rt)
	return h


static func reward(rw: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.theme_type_variation = &"ChipRewardRose" if rw["kind"] == "heart" else &"ChipReward"
	var l := Label.new()
	l.theme_type_variation = &"Display20" if rw["kind"] == "gold" else &"Heavy18"
	l.text = rw["text"]
	p.add_child(l)
	return p
