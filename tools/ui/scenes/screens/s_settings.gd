extends RefCounted
## scenes/ui/settings_ui.tscn : language + volume + fullscreen. Script: scripts/ui/settings_ui.gd
## Opened by EventBus.ui_panel_toggled(&"settings", true) (title "Indstillinger" and pause "Indstillinger").

func _row(K, parent, nm: String, caption: String):
	var h = K.hbox(parent, nm + "Row", 16)
	K.lbl(h, nm + "Caption", caption, "Heavy18", {"min": Vector2(150, 0), "shrink_center_v": true}, true)
	return h

func build(K) -> void:
	var r = K.begin("Control", "SettingsUI", "res://scripts/ui/settings_ui.gd")
	K.full(r)
	var scrim = K.add(r, "ColorRect", "Scrim", {"color": Color(0.11, 0.129, 0.22, 0.62)})
	K.full(scrim)
	var panel = K.panel(r, "Panel", "PanelParchment", {"min": Vector2(560, 0)})
	K.pin(panel, "c", 0, 0)
	var v = K.vbox(panel, "Body", 16)
	K.lbl(v, "TitleLabel", "Indstillinger", "Display34", {"horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER}, true)
	var lr = _row(K, v, "Language", "Sprog")
	var lg = ButtonGroup.new()
	K.btn(lr, "LangDa", "Dansk", "PillTab", {"toggle_mode": true, "button_group": lg}, true)
	K.btn(lr, "LangEn", "English", "PillTab", {"toggle_mode": true, "button_group": lg}, true)
	for spec in [["Master", "Hovedvolumen"], ["Music", "Musik"], ["Sfx", "Lyde"], ["Voice", "Stemmer"]]:
		var h = _row(K, v, spec[0], spec[1])
		K.add(h, "HSlider", spec[0] + "Slider", {"min_value": 0.0, "max_value": 1.0, "step": 0.05, "value": 0.8, "expand_h": true, "shrink_center_v": true,
			"min": Vector2(260, 28), "focus_mode": Control.FOCUS_ALL}, true)
	K.add(v, "CheckBox", "FullscreenCheck", {"text": "Fuldskærm", "focus_mode": Control.FOCUS_ALL}, true)
	K.btn(v, "CloseButton", "Færdig", "ButtonPrimary", {}, true)
	K.save("res://scenes/ui/settings_ui.tscn")
