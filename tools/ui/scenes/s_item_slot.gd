extends RefCounted
## scenes/ui/components/item_slot.tscn : one inventory / hotbar cell.
## Children: Icon (TTItemIcon, fills the tile), Pips (RarityPips, bottom-left), KeyLabel (top-left), CountLabel (bottom-right).

func build(K) -> void:
	var r: Button = K.begin("Button", "ItemSlot", "res://scripts/ui/components/item_slot.gd")
	r.toggle_mode = true
	r.custom_minimum_size = Vector2(58, 58)
	r.theme_type_variation = &"SlotEmpty"
	r.focus_mode = Control.FOCUS_ALL
	r.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	var icon = K.add(r, "Control", "Icon", {"script": "res://scripts/ui/components/tt_item_icon.gd"}, true)
	K.full(icon)
	var pips = K.add(r, "Control", "Pips", {"script": "res://scripts/ui/components/rarity_pips.gd", "pip_size": 9.0, "gap": 2.0}, true)
	K.pin(pips, "bl", 5, 5)
	var key = K.lbl(r, "KeyLabel", "", "HotkeyDigit", {"ignore": true}, true)
	K.pin(key, "tl", 4, 1)
	var cnt = K.lbl(r, "CountLabel", "", "Display15", {"ignore": true}, true)
	K.pin(cnt, "br", 4, 0)
	K.save("res://scenes/ui/components/item_slot.tscn")
