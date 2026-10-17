extends Interactable2D
var activity: Dictionary = {}
var stage: FestivalStage
func _ready() -> void:
	radius = Vector2(64,36)
	super._ready()
	var label := Label.new()
	label.theme = preload("res://assets/ui/theme.tres")
	label.theme_type_variation = &"Heavy16"
	label.add_theme_color_override("font_color",Color("fbf5e6"))
	label.add_theme_color_override("font_shadow_color",Color("2b2340"))
	label.add_theme_constant_override("shadow_outline_size",5)
	label.text = tr(str(activity.get("name_key","SOC_EV_TITLE")))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-125,-55)
	label.size = Vector2(250,40)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
func get_interaction_prompt() -> String:
	return UiHints.glyph(&"interact")+" · "+tr(str(activity.get("name_key","SOC_EV_TITLE")))
func interact(_player: Node) -> void:
	if is_enabled() and is_instance_valid(stage): stage.perform(activity)
