class_name DailyFlags
extends Node
var world: Node
static func attach(area: IsoArea) -> Node:
	var existing := area.get_node_or_null("DailyFlags")
	if existing != null:
		return existing
	var flags := DailyFlags.new()
	flags.name = "DailyFlags"
	area.add_child(flags)
	return flags

static func attach_world(target: Node) -> Node:
	var service := DailyFlags.new()
	service.name = "TownServices"
	service.world = target
	target.add_child(service)
	return service

func _enter_tree() -> void:
	if world != null:
		EventBus.game_event.connect(_service_event)
	else:
		EventBus.day_started.connect(_morning)
		refresh()
func _exit_tree() -> void:
	if EventBus.game_event.is_connected(_service_event):
		EventBus.game_event.disconnect(_service_event)
	if EventBus.day_started.is_connected(_morning):
		EventBus.day_started.disconnect(_morning)
func _morning(_day: int, _season: StringName) -> void:
	refresh()
static func refresh() -> void:
	var weekend := TimeManager.weekday_index() in LuaData.arr(GameManager.config_value("traetoppen.stall.weekdays", [5, 6]))
	GameManager.set_flag(&"brumme_at_stall", int(weekend))
	GameManager.set_flag(&"brumme_at_work", int(not weekend))

# Dialogue services belong to the loaded world, so Hoppe can swap seeds while
# visiting the farm as well as at his city basket. Markers own only E-interaction.
func _service_event(id: StringName, _payload: Dictionary) -> void:
	if not is_instance_valid(world) or world.area == null:
		return
	match id:
		&"swap_seeds_request":
			var basket := SeedBasket2D.new()
			basket.interact(world.player)
			basket.free()
		&"bath_request":
			for node in world.area.objects.get_children():
				if node is BathTub2D:
					node.interact(world.player)
					return
			EventBus.whisper_requested.emit("LIFE_BATH_VISIT")
		&"open_post_office":
			if str(world.area.map.id) == "int_postkontoret":
				EventBus.whisper_requested.emit("LIFE_POST_OFFICE")
