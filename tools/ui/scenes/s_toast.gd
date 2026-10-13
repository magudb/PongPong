extends RefCounted
## scenes/ui/components/notification_toast.tscn : title + message, optional item picture on the left (TTItemIcon).
## The scene holds no text: the HUD passes display strings to setup().

func build(K) -> void:
	var r = K.begin("PanelContainer", "NotificationToast", "res://scripts/ui/components/notification_toast.gd")
	r.theme_type_variation = &"PanelToast"
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h = K.hbox(r, "Row", 12, {"ignore": true})
	var frame = K.add(h, "Control", "IconFrame", {"min": Vector2(44, 44), "ignore": true, "visible": false, "shrink_center_v": true}, true)
	var icon = K.add(frame, "Control", "Icon", {"script": "res://scripts/ui/components/tt_item_icon.gd", "ignore": true}, true)
	K.full(icon)
	var v = K.vbox(h, "Body", 2, {"ignore": true, "expand_h": true})
	K.lbl(v, "TitleLabel", "", "Heavy18", {"ignore": true}, true)
	K.lbl(v, "MessageLabel", "", "Muted15", {"ignore": true, "autowrap_mode": TextServer.AUTOWRAP_WORD_SMART, "custom_minimum_size": Vector2(260, 0)}, true)
	K.save("res://scenes/ui/components/notification_toast.tscn")
