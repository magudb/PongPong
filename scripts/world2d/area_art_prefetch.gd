class_name AreaArtPrefetch
extends Node
## World-owned requests overlap a bridge approach/fade. Sprites own residency
## after entry; turning away or disposing the world releases the staging refs.
var world: Node
var pending: Array[String] = []
var staged: Dictionary = {}
## Loads of a destination the player turned away from: nobody waits for them, _poll only collects their results.
var abandoned: Array[String] = []
var _clock := 0.0
var _target: StringName

func request(id: StringName) -> void:
	if _target == id:
		return
	# A new destination: the old one's loads must not hold this fade (finish() waits only for `pending`).
	abandoned.append_array(pending)
	pending.clear()
	release()
	if id not in [&"traetoppen", &"hyggebyen"] and not str(id).begins_with("int_"):
		return
	# A parked area kept its nodes and with them its textures: nothing to parse or stage.
	if world is WorldRoot2D and (world as WorldRoot2D).is_parked(id):
		return
	_target = id
	var paths: Dictionary = {}
	var art_ids: Array = []
	if str(id).begins_with("int_"):
		for path in InteriorRoom.art_paths(str(id)):
			paths[path]=true
	elif id == &"traetoppen":
		art_ids = CityData.art_ids(CityData.load_data())
	else:
		var map := WorldRoot2D.load_map(id)
		art_ids = map.props.values().map(func(row): return str(row.prop))
		var terrain := {}
		var chars := "".join(map.ground)
		for ch in chars:
			var atlas := IsoArea.terrain_id(ch,map.projection,map.theme)
			if atlas!=&"":terrain[atlas]=true
		if terrain.has(&"water_0"):
			for frame in 4:terrain[StringName("water_%d" % frame)]=true
		for atlas in terrain:
			var meta := ArtCatalog.terrain_metadata(atlas)
			if meta.has("file"):paths[str(meta._dir)+str(meta.file)]=true
		if chars.contains("="):
			art_ids.append_array(["bridge_x","bridge_z"])
		for marker in map.markers.values():
			if str(marker.get("prop",""))!="":art_ids.append(str(marker.prop))
	if not str(id).begins_with("int_"):
		art_ids.append("backdrop_%s_far" % ("treetop" if id == &"traetoppen" else "hyggebyen"))
	for art in art_ids:
		var meta := ArtCatalog.prop_metadata(StringName(art))
		var folder := str(meta.get("_dir", ""))
		for part in [meta, meta.get("glow", {}), meta.get("ground", {})]:
			if part.has("file"):
				paths[folder + str(part.file)] = true
	if not str(id).begins_with("int_"):
		paths["res://assets/backdrops/%s_sky.png" % ("treetop" if id == &"traetoppen" else "hyggebyen")] = true
	# Stage the scheduled residents during the same fade as their scenery.
	# Keepers need two clips; walkers need their movement sheet as well.
	if DisplayServer.get_name() != "headless":
		if id==&"traetoppen":
			for marker in CityData.markers_of(CityData.load_data(),"ambient_owl"):
				var visual := IsoChibiSprite2D.resolve_id(str(marker.params.get("visual",CityData.AMBIENT_OWL_VISUAL)))
				var meta := IsoChibiSprite2D.meta_for(visual)
				if meta.animations.has("idle"):
					paths["res://assets/isometric_characters/"+visual+"/"+str(meta.animations.idle.sheet)]=true
		var ctx := Routines.now_ctx()
		var festival := str(LuaData.dict(ctx.get("fest",{})).get("area",""))==str(id)
		var cap := maxi(1,int(GameData.cfg("towns.max_live_visuals_festival" if festival else "towns.max_live_visuals",20 if festival else 16)))
		var room := str(id).begins_with("int_")
		var building := Hours.building(str(id).trim_prefix("int_")) if room else {}
		var keeper := str(building.get("keeper",building.get("owner","")))
		var selected := NpcDirector.select_presences(Routines.present_in(str(id),ctx),cap,keeper,4 if room else -1)
		for presence in selected.rows:
			var npc := str(presence.npc)
			var row: Dictionary = GameData.lua().get_npc(str(npc))
			var art := IsoChibiSprite2D.resolve_id(str(row.get("visual","fairy")))
			var meta := IsoChibiSprite2D.meta_for(art)
			var clips := ["idle","talk"] if room and str(npc)==str(building.get("keeper","")) else (["idle","talk","hover"] if meta.flyer else ["idle","talk","walk"])
			for clip in clips:
				if meta.animations.has(clip):
					paths["res://assets/isometric_characters/"+art+"/"+str(meta.animations[clip].sheet)] = true
	for path in paths:
		if DisplayServer.get_name() == "headless":
			# Dummy textures must be created on the main thread.
			if ResourceLoader.exists(path):staged[path]=load(path)
			continue
		if ResourceLoader.exists(path) and ResourceLoader.load_threaded_request(path, "Texture2D", true) == OK:
			pending.append(path)

func _poll() -> void:
	for path in abandoned.duplicate():
		var done := ResourceLoader.load_threaded_get_status(path)
		if done == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(path)
		if done != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			abandoned.erase(path)
	for path in pending.duplicate():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			staged[path] = ResourceLoader.load_threaded_get(path)
			pending.erase(path)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			pending.erase(path)

func finish() -> void:
	while not pending.is_empty():
		_poll()
		if not pending.is_empty():
			await get_tree().process_frame

func release() -> void:
	staged.clear()
	_target = &""

func _process(delta: float) -> void:
	_poll()
	_clock += delta
	if _clock < 0.5 or world == null or world.area == null or world.player == null or world.traveling:
		return
	_clock = 0
	var near := false
	for node in world.area.triggers.get_children():
		if node is Warp2D and node.to_area == &"traetoppen":
			var toward := Iso.to_ground(node.global_position-world.player.global_position)
			var motion := Iso.to_ground(world.player.velocity)
			if toward.length()<1000 and motion.dot(toward.normalized())>10:
				near=true
	if near:
		request(&"traetoppen")
	elif pending.is_empty():
		release()

func _exit_tree() -> void:
	# Join the engine's outstanding requests; no orphan coroutine or retained
	# loader result survives a cancelled approach/world.
	for path in pending + abandoned:
		ResourceLoader.load_threaded_get(path)
	pending.clear()
	abandoned.clear()
	release()
