class_name Greenhouse2D
extends Interactable2D
var area: IsoArea
var cell: Vector2i
var action := "door"
var _picture: Node2D
var _built := false

static func create_marker(params: Dictionary, _pos: Vector2, at: Vector2i, target: IsoArea) -> Node:
	var node := Greenhouse2D.new()
	node.area = target
	node.cell = at
	node.action = str(params.get("action", "door"))
	return node

func _ready() -> void:
	super._ready()
	EventBus.game_event.connect(func(event, _data):
		if event == &"greenhouse_changed": refresh())
	EventBus.load_completed.connect(func(_slot): refresh.call_deferred())
	# A Continue enters the farm before the world applies the saved area flags (greenhouse_built): redraw when they arrive.
	var world := FarmEquipment.current_world()
	if world != null and not world.state_applied.is_connected(refresh):
		world.state_applied.connect(refresh)
	refresh()

func _enter_tree() -> void:
	if is_node_ready(): refresh.call_deferred()

func refresh() -> void:
	if not is_inside_tree(): return
	var built := FarmEquipment.greenhouse_built()
	if is_instance_valid(_picture) and built == _built: return
	_built = built
	# The painted door is midway along the front wall, two cells back from
	# the footprint's front corner. Its interaction and return spawn agree.
	var door_cell := cell - Vector2i(2,0) if built and action == "door" else cell
	position = area.objects.to_local(area.cell_to_global(door_cell))
	if is_instance_valid(_picture): area.remove_prop(_picture)
	var prop := &"seed_basket" if action == "seeds" else &"greenhouse" if built else &"build_stake"
	_picture = area.place_prop(prop, cell)

func get_interaction_prompt() -> String:
	if action == "seeds": return tr("FARMSITE_SEED_SHELF")
	if FarmEquipment.greenhouse_built(): return tr("FARMSITE_GREENHOUSE_ENTER")
	return tr("FARMSITE_UPGRADING_FMT") % FarmEquipment.greenhouse_days_left() if FarmEquipment.greenhouse_building() else tr("FARMSITE_GREENHOUSE")

func interact(_player: Node) -> void:
	if not is_enabled(): return
	if action == "seeds":
		ShopSystem.open_shop(&"greenhouse_seeds")
	elif FarmEquipment.greenhouse_built():
		var world := FarmEquipment.current_world()
		if world != null: world.travel(&"greenhouse", &"default")
	else:
		var world := FarmEquipment.current_world()
		if world != null:
			var menu: Node = world.game_ui.get_screen(&"build_menu_ui")
			menu._selected_building = &"greenhouse"
			menu.open()
