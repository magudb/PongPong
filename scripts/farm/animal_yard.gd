extends Node2D
var area: IsoArea
var radius := 3.0
var actors: Dictionary = {}
func _enter_tree() -> void:
	if is_node_ready(): refresh.call_deferred()

func _ready() -> void:
	AnimalHusbandry.state_changed.connect(refresh)
	refresh()
func refresh() -> void:
	if not is_inside_tree(): return
	for id in actors.keys():
		if not AnimalHusbandry.animals.has(id):
			actors[id].queue_free()
			actors.erase(id)
	for animal in AnimalHusbandry.animals.values():
		if not actors.has(animal.id):
			var actor := Animal2D.new()
			actor.animal_id = animal.id
			actor.yard = self
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(str(animal.id))
			actor.position = area.objects.to_local(pick_target(rng))
			actors[animal.id] = actor
			area.objects.add_child(actor)
		actors[animal.id].refresh()
func pick_target(rng: RandomNumberGenerator) -> Vector2:
	for _try in 24:
		var offset := Vector2(rng.randf_range(-radius,radius),rng.randf_range(-radius,radius))
		if offset.length() > radius: continue
		var position := global_position + HomeData.cell_to_local(offset)
		var cell := area.global_to_cell(position)
		if area.is_walkable(cell) and not area.is_farmable(cell): return position
	return global_position
