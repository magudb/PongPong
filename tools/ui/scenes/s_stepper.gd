extends RefCounted
## scenes/ui/components/quantity_stepper.tscn

func build(K) -> void:
	var r: PanelContainer = K.begin("PanelContainer", "QuantityStepper", "res://scripts/ui/components/quantity_stepper.gd")
	r.theme_type_variation = &"PanelField"
	var h = K.hbox(r, "Row", 0)
	var m = K.btn(h, "MinusButton", "−", "StepperButton", {}, true)
	var d1 = K.add(h, "ColorRect", "DividerL", {"color": Color("#2b2340"), "min": Vector2(2, 0)})
	var vm = K.margin(h, "ValueMargin", 16, 4, 16, 4)
	K.lbl(vm, "ValueLabel", "1", "Display20", {"min": Vector2(18, 0), "horizontal_alignment": HORIZONTAL_ALIGNMENT_CENTER}, true)
	var d2 = K.add(h, "ColorRect", "DividerR", {"color": Color("#2b2340"), "min": Vector2(2, 0)})
	K.btn(h, "PlusButton", "+", "StepperButton", {}, true)
	K.save("res://scenes/ui/components/quantity_stepper.tscn")
