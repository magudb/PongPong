extends Node2D
## Art fixture on installed native town geometry, without a live festival state.
var area: IsoArea
var decor: Node2D
var posts: Dictionary = {}
var camera: Camera2D

static func standard_posts(origin: Vector2) -> Dictionary:
	var roles: Dictionary = {"host": [0, 0], "judge": [2, 0], "stall_1": [-4, -2], "stall_2": [-2, -2], "stall_3": [2, -2], "stall_4": [4, -2], "table_1": [-3, 1], "table_2": [3, 1]}
	for k in 16:
		roles["gather_%d" % (k + 1)] = [k % 4 - 1, 2 + floori(k / 4.0)]
	var out: Dictionary = {}
	for name_ in roles:
		var c: Array = roles[name_]
		out[name_] = origin + Vector2((float(c[0]) - float(c[1])) * 64, (float(c[0]) + float(c[1])) * 38)
	return out

func setup(town: String, festival_id: String, evening: bool = false, dressed: bool = true) -> void:
	area = IsoArea.new()
	add_child(area)
	area.setup(AreaMap.load_file("res://data/maps/" + town + ".map"))
	area.process_mode = Node.PROCESS_MODE_DISABLED
	var rank := 0
	var origin := Vector2.ZERO
	var doors: Array = []
	if town == "traetoppen":
		# Fixture anchor follows the design post-set's screen coordinates. Live
		# post snapping/routing is owned by the unfinished TownDirector package.
		origin = Vector2(2640, 2205)
		rank = CityData.rank_of(CityData.load_data(), "torvet")
		var city := CityBuilder.of(area)
		city.night.set_factor(1.0 if evening else 0.0)
		for id in ["h7", "h8", "h9"]:
			var building := CityData.record(CityData.load_data(), "buildings", id)
			if building.has("door"):
				var d: Dictionary = building["door"]
				doors.append({"at": Vector2(d["x"], d["y"]) * 3, "rot": 0})
	else:
		for z in area.map.height:
			for x in area.map.width:
				if area.map.objects[z][x] == "Z":
					origin = Iso.iso_center(Vector2i(x, z))
		for marker in area.find_markers("door"):
			doors.append({"at": area.cell_to_global(marker["cell"]), "rot": 0})
	posts = standard_posts(origin)
	if town == "traetoppen":
		# Artist-authored study positions on this existing platform, not a
		# substitute for the director's future routed/snap-resolved post set.
		# Two temporary stalls and four guests leave the bridge approaches open.
		posts.merge({"host": Vector2(2380, 2110), "judge": Vector2(3000, 2115),
			"stall_1": Vector2(2010, 1990), "stall_4": Vector2(3250, 2090),
			"table_1": Vector2(2160, 2200), "table_2": Vector2(3060, 2220),
			"gather_1": Vector2(2220, 2110.4), "gather_4": Vector2(2412, 2224.4),
			"gather_13": Vector2(2780, 2114.4), "gather_16": Vector2(2972, 2228.4),
			"gather_2": Vector2(2450, 2250), "gather_6": Vector2(2700, 2310),
			"gather_10": Vector2(2870, 2220), "gather_14": Vector2(2270, 2140)}, true)
		posts.erase("stall_2")
		posts.erase("stall_3")
	if dressed:
		decor = PaintedFestivalArt.create(area.objects, festival_id, posts, doors, rank, evening)
	var characters := ["fox", "fairy_shopkeeper", "hedgehog_pip", "raccoon_smith"]
	for k in characters.size():
		var actor := IsoChibiSprite2D.create(characters[k])
		actor.name = "FestivalReviewGuest_%d" % k
		actor.position = posts["gather_%d" % ([2, 6, 10, 14][k] if town == "traetoppen" else [2, 4, 9, 15][k])]
		actor.z_index = rank
		actor.process_mode = Node.PROCESS_MODE_DISABLED
		area.objects.add_child(actor)
	var host := IsoChibiSprite2D.create("fairy_mayor")
	host.name = "FestivalReviewHost"
	host.position = posts["host"]
	host.z_index = rank
	host.process_mode = Node.PROCESS_MODE_DISABLED
	area.objects.add_child(host)
	if evening:
		area.modulate = Color(.65, .66, .8)
	camera = Camera2D.new()
	camera.position = origin + Vector2(0, 70)
	camera.zoom = Vector2.ONE * .7
	add_child(camera)
	camera.make_current()
	camera.reset_smoothing()
