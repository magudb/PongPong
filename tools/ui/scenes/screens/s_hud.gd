extends RefCounted
## scenes/ui/hud.tscn : farm HUD (guide section 06). Script: scripts/ui/hud.gd

const SLOT := "res://scenes/ui/components/item_slot.tscn"

func build(K) -> void:
	var r = K.begin("Control", "HUD", "res://scripts/ui/hud.gd")
	K.full(r)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# ---- top left: date/time/weather, money pill, (hidden) health bar
	var tl = K.vbox(r, "TopLeft", 12, {"ignore": true})
	K.pin(tl, "tl", 40, 40)
	var dp = K.panel(tl, "DatePanel", "PanelHud", {"shrink_begin_h": true, "ignore": true})
	var dv = K.vbox(dp, "DateBody", 2, {"ignore": true})
	K.lbl(dv, "DayLabel", "Tirsdag 14. Blomstermåned", "Heavy17", {"ignore": true}, true)
	var trow = K.hbox(dv, "TimeRow", 6, {"ignore": true})
	K.lbl(trow, "TimeLabel", "10:40", "Display30", {"ignore": true}, true)
	K.lbl(trow, "WeatherLabel", "· Solskin", "Bold17Muted", {"ignore": true, "shrink_end_v": true}, true)
	var mp = K.panel(tl, "MoneyPill", "PillGold", {"shrink_begin_h": true, "ignore": true})
	var mr = K.hbox(mp, "MoneyRow", 8, {"ignore": true})
	var coin = K.coin(mr, "Coin")
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	K.lbl(mr, "GoldLabel", "1.250", "MoneyPill", {"ignore": true}, true)
	K.lbl(mr, "GoldUnitLabel", "guldagern", "Bold15Gold", {"ignore": true, "shrink_end_v": true}, true)
	K.add(tl, "ProgressBar", "HealthBar", {"variation": "MeterRose", "min": Vector2(180, 18), "show_percentage": false,
		"visible": false, "value": 100, "shrink_begin_h": true, "mouse_filter": Control.MOUSE_FILTER_IGNORE}, true)

	# ---- top right: tracked quests
	var qc = K.panel(r, "QuestCard", "PanelCard", {"min": Vector2(300, 0), "ignore": true}, true)
	K.pin(qc, "tr", 40, 40)
	var qv = K.vbox(qc, "QuestBody", 10, {"ignore": true})
	K.lbl(qv, "QuestHeader", "AKTIVE OPGAVER", "Eyebrow", {"ignore": true}, true)
	K.vbox(qv, "QuestTracker", 10, {"ignore": true}, true)

	# ---- bottom right: vertical Energi meter
	var eb = K.vbox(r, "EnergyBox", 6, {"ignore": true})
	K.pin(eb, "br", 40, 40)
	K.add(eb, "ProgressBar", "StaminaBar", {"variation": "MeterVertical", "min": Vector2(30, 150), "show_percentage": false,
		"fill_mode": ProgressBar.FILL_BOTTOM_TO_TOP, "value": 72, "shrink_center_h": true, "mouse_filter": Control.MOUSE_FILTER_IGNORE}, true)
	K.lbl(eb, "StaminaTag", "Energi", "EnergyTag", {"ignore": true, "shrink_center_h": true}, true)

	# ---- bottom centre: hotbar (1..0), tool name above, interaction prompt above that
	var tray = K.panel(r, "HotbarTray", "PanelHotbar", {"ignore": true})
	K.pin(tray, "bc", 0, 30)
	var hb = K.hbox(tray, "Hotbar", 6, {}, true)
	for i in 10:
		K.inst(hb, SLOT, "Slot%d" % (i + 1), {"min": Vector2(58, 58)})
	var tn = K.lbl(r, "ToolNameLabel", "Vandkande", "ToolName", {"ignore": true, "horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER}, true)
	K.pin(tn, "bc", 0, 118)
	var pr = K.lbl(r, "InteractionPrompt", "E  Tal med Pippin", "PromptPill", {"ignore": true, "visible": false, "horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER}, true)
	K.pin(pr, "bc", 0, 156)

	# ---- bottom left: toasts stack upwards
	var nb = K.vbox(r, "NotificationBox", 8, {"ignore": true}, true)
	K.pin(nb, "bl", 40, 40)
	K.save("res://scenes/ui/hud.tscn")
