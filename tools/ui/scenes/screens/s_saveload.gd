extends RefCounted
## scenes/ui/save_load_ui.tscn : slot browser (6 slots, delete, confirm dialogs). Script: scripts/ui/save_load_ui.gd

func build(K) -> void:
	var r = K.begin("Control", "SaveLoadUI", "res://scripts/ui/save_load_ui.gd")
	K.full(r)
	var scrim = K.add(r, "ColorRect", "Scrim", {"color": Color(0.11, 0.129, 0.22, 0.62)})
	K.full(scrim)
	var panel = K.panel(r, "Panel", "PanelParchmentL24", {"min": Vector2(760, 0)})
	K.pin(panel, "c", 0, 0)
	var v = K.vbox(panel, "Body", 14)
	var head = K.hbox(v, "Header", 12)
	K.lbl(head, "TitleLabel", "Gem spil", "Display32", {"expand_h": true}, true)
	K.btn(head, "CloseButton", "✕", "ButtonTertiaryS", {"shrink_center_v": true}, true)
	K.lbl(v, "InfoLabel", "Vælg en slot at gemme i", "Subtitle", {}, true)
	K.vbox(v, "SlotList", 8, {}, true)
	K.add(r, "ConfirmationDialog", "ConfirmDialog", {"borderless": true, "exclusive": true, "visible": false, "min_size": Vector2i(440, 180)}, true)
	K.add(r, "ConfirmationDialog", "DeleteDialog", {"borderless": true, "exclusive": true, "visible": false, "min_size": Vector2i(440, 180)}, true)
	K.save("res://scenes/ui/save_load_ui.tscn")
