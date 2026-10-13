extends StaticBody3D
## Makes a farm plot interactable: till / plant / water / harvest.

var plot_id: StringName = &""


func _ready() -> void:
	plot_id = get_meta("plot_id", &"")
	collision_layer = 32
	collision_mask = 0


func get_interaction_prompt() -> String:
	var farm := get_parent().get_parent() as Node3D
	if farm == null:
		return ""
	# Find farm system
	var farm_sys := get_tree().get_first_node_in_group("farm_system")
	if farm_sys == null:
		return tr("FARM_PLOT_EMPTY")

	var plot = farm_sys._find_plot(plot_id)
	if plot == null:
		return tr("FARM_PLOT_EMPTY")

	match plot.state:
		0: return tr("FARM_TILL")
		1: return tr("FARM_PLANT")
		2: return tr("FARM_WATER")
		3: return tr("FARM_WATER")
		4: return tr("FARM_HARVEST")
	return ""


func interact(player: Node3D) -> void:
	var farm_sys := get_tree().get_first_node_in_group("farm_system")
	if farm_sys == null:
		return

	var plot = farm_sys._find_plot(plot_id)
	if plot == null:
		return

	match plot.state:
		0:
			farm_sys.till_plot(plot_id)
			EventBus.notification_posted.emit(tr("FARM_TILL"), tr("FARM_PLOT_TILLED"), "farm")
		1:
			# Auto-plant first available seed
			for seed_id in [&"turnip_seeds", &"carrot_seeds", &"moonflower_seeds", &"pumpkin_seeds"]:
				if EconomyManager.has_item(seed_id, 1):
					var crop_name := String(seed_id).replace("_seeds", "")
					if farm_sys.plant_crop(plot_id, StringName(crop_name)):
						EventBus.notification_posted.emit(tr("FARM_PLANT"), tr("ITEM_%s" % crop_name.to_upper()), "farm")
						return
			EventBus.notification_posted.emit(tr("NOTIF_ITEM_GAINED_TITLE"), tr("NOTIF_INVENTORY_FULL_MSG"), "farm")
		2, 3:
			farm_sys.water_plot(plot_id)
		4:
			var amount: int = farm_sys.harvest_plot(plot_id)
			if amount > 0:
				EventBus.notification_posted.emit(tr("FARM_HARVEST"), "x%d" % amount, "farm")
