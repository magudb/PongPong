class_name MotherStoryDirector
extends Node
## Authored evidence is attached after physics has registered the real floor.
## The generator's deterministic text and save-cell identities stay unchanged.
var world: WorldRoot2D
var _generation := 0
var anchors: Array[Dictionary] = []
static func attach(target: WorldRoot2D) -> Node:
	var existing := target.get_node_or_null("MotherStory")
	if existing != null: return existing
	var director := MotherStoryDirector.new()
	director.name = "MotherStory"
	director.world = target
	target.add_child(director)
	return director
func _ready() -> void:
	world.area_ready.connect(_area_ready)
	EventBus.quest_completed.connect(_quest)
	EventBus.quest_objective_updated.connect(_objective)
	EventBus.game_event.connect(_event)
	EventBus.load_completed.connect(_loaded)
func _quest(_id: StringName) -> void:
	MotherStory.sync()
	_refresh()
func _objective(_quest_id: StringName,_id: StringName,_current: int,_target: int) -> void:
	if _quest_id == SecretGardenStory.QUEST:
		MotherStory.sync()
		_refresh()
func _event(id: StringName,_data: Dictionary) -> void:
	if id in [&"dungeon_boss_defeated",&"forest_mother_evidence",&"forest_mother_work"]:
		MotherStory.sync()
		_refresh()
func _loaded(_slot: int) -> void:
	MotherStory.sync()
	if world.area != null: _area_ready(world.area.map.id)
func _refresh() -> void:
	if world.area == null: return
	for node in world.area.objects.get_children():
		if node is MotherEvidenceMarker: node.refresh()
func _area_ready(_id: StringName) -> void:
	_generation += 1
	var token := _generation
	var area := world.area
	anchors.clear()
	MotherStory.sync()
	if not MotherStory.enabled(): return
	await get_tree().physics_frame
	await get_tree().physics_frame
	if token != _generation or not is_instance_valid(area) or world.area != area: return
	var number := DungeonFloors.floor_of(area)
	var wanted: Array[Dictionary] = []
	for row in MotherStory.EVIDENCE:
		if int(row.get("floor",0)) == number and number > 0: wanted.append(row)
		elif str(row.get("area","")) == str(area.map.id): wanted.append(row)
	if wanted.is_empty(): return
	var nav := NavGrid.bake_area(area)
	var start := area.global_to_cell(area.get_spawn("default"))
	var path: Array[Vector2i] = []
	if number > 0:
		for marker in area.find_markers("warp"):
			if DungeonFloors.floor_of_id(marker.params.get("to","")) > number:
				path = nav.astar.get_id_path(nav.nearest_free(start),nav.nearest_free(marker.cell))
				break
	if path.size() < wanted.size()+3:
		# A sealed boss exit may not be traversable yet. The arrival route is
		# required too: select reachable cells next to the actual spawn.
		path = _arrival_path(nav,start,wanted.size()+5)
	if str(area.map.id) == "secret_garden":
		for marker in area.find_markers("secret_garden"):
			if str(marker.params.get("kind","")) == "bench":
				var route: Array[Vector2i] = nav.astar.get_id_path(nav.nearest_free(start),nav.nearest_free(marker.cell+Vector2i(1,0)))
				if not route.is_empty(): path = route.slice(maxi(0,route.size()-6))
	var used := {}
	for index in wanted.size():
		var existing: MotherEvidenceMarker
		for node in area.objects.get_children():
			if node is MotherEvidenceMarker and node.evidence_id == wanted[index].id:
				existing = node
				break
		if existing != null:
			existing.refresh()
			used[existing.cell] = true
			anchors.append({"id":wanted[index].id,"cell":existing.cell,"node":existing})
			continue
		var at := _pick_cell(path,index,wanted.size(),used,area,nav)
		if at == Vector2i(-1,-1):
			area.map.errors.append("forest_mother_anchor: no reachable arrival-route cell for "+str(wanted[index].id))
			continue
		used[at] = true
		var marker := MotherEvidenceMarker.new()
		marker.evidence_id = wanted[index].id
		marker.area = area
		marker.cell = at
		marker.position = area.objects.to_local(area.cell_to_global(at))
		area.objects.add_child(marker)
		anchors.append({"id":wanted[index].id,"cell":at,"node":marker})
func _arrival_path(nav: NavGrid,start: Vector2i,minimum: int) -> Array[Vector2i]:
	var best: Array[Vector2i] = [nav.nearest_free(start)]
	for y in nav.size.y:
		for x in nav.size.x:
			var at := Vector2i(x,y)
			if nav.blocked.has(at) or str(nav.area.map.ground_at(at)) not in ["p","x","m"]: continue
			var candidate: Array[Vector2i] = nav.astar.get_id_path(best[0],at)
			if candidate.size() >= minimum: return candidate
			if candidate.size() > best.size(): best = candidate
	return best
func _pick_cell(path: Array[Vector2i],index: int,total: int,used: Dictionary,area: IsoArea,nav: NavGrid) -> Vector2i:
	if path.is_empty(): return Vector2i(-1,-1)
	if total == 4:
		# The four kitchen memories share a room-like pocket beside the route.
		# A narrow layout falls back to neighbouring route cells below.
		var center := path[path.size()/2]
		var offsets := [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]
		var preferred: Vector2i = center+offsets[index]
		if nav.astar.is_in_boundsv(preferred) and not nav.blocked.has(preferred) and not used.has(preferred) and area.map.object_at(preferred) in ["."," "] and not _under_canopy(area,preferred) and not nav.astar.get_id_path(path[0],preferred).is_empty(): return preferred
	var desired := clampi(roundi((index+1.0)/(total+1.0)*(path.size()-1)),1,maxi(1,path.size()-2))
	if total == 4: desired = clampi(path.size()/2-2+index,0,path.size()-1)
	if str(area.map.id) == "secret_garden" and total == 2: desired = 1 if index == 0 else maxi(1,path.size()-2)
	for offset in path.size():
		var at := path[posmod(desired+offset,path.size())]
		if not used.has(at) and area.map.object_at(at) in ["."," "] and not _under_canopy(area,at): return at
	return Vector2i(-1,-1)
func _under_canopy(area: IsoArea,at: Vector2i) -> bool:
	for record in area.prop_nodes:
		var id := str(record.id)
		if not id.begins_with("crown_"): continue
		var cls := 0 if id.begins_with("crown_s") else 1 if id.begins_with("crown_m") else 2
		if DungeonGen.crown_covers(cls,record.cell.x,record.cell.y,at.x,at.y): return true
	return false
