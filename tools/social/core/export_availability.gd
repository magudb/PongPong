extends SceneTree
## Exact spans from the live routine compiler, including newly added citizens.
const COUNTERS := [".counter",".tub",".throne",".t_stall",".e_bat_window",".mayor_desk"]
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	await process_frame
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): path = arg.trim_prefix("--out=")
	if path == "":
		print("AVAILABILITY missing --out")
		quit(1)
		return
	RouteTable.load_table()
	Routines.clear_cache()
	var hearts := {}
	for npc in SocialData.friend_ids(): hearts[npc] = 5
	var npcs := {}
	for npc in SocialData.friend_ids():
		var days := {}
		for weekday in 7:
			var weathers := {}
			for weather in ["klart","regn"]:
				var ctx := Routines.make_ctx(weekday,12.0,weather,{"hearts":hearts,"hero":"","total_day":113+weekday,"festival":""})
				var spans: Array = []
				var plan := Routines.plan_name(npc,ctx)
				for segment in _accessible_spans(npc,plan,weather == "regn",ctx):
					var start := maxf(6.0,float(segment.t0))
					var end := minf(26.0,float(segment.t1))
					if end <= start: continue
					var kind := _kind(segment)
					if not spans.is_empty() and str(spans[-1][0]) == kind and is_equal_approx(float(spans[-1][2]),start): spans[-1][2] = end
					else: spans.append([kind,start,end])
				weathers[weather] = spans
			days[str(weekday)] = weathers
		npcs[npc] = days
	var inputs := {}
	var collected := collect_inputs(["res://lua/social/citizens.lua","res://lua/config/npcs.lua","res://data/towns/routes.json","res://scripts/towns/routines.gd","res://scripts/towns/route_table.gd","res://lua/towns.lua","res://lua/config/game_balance.lua","res://scripts/towns/hours.gd","res://scripts/towns/interior_room.gd","res://tools/social/core/export_availability.gd"], ["res://lua/routines","res://lua/buildings","res://data/interiors"])
	if not collected.ok:
		print("AVAILABILITY ", collected.error)
		quit(1)
		return
	inputs = collected.inputs
	var result := {"version":1,"source":"Live Routines.timeline, exact spans; all citizens, hearts 5, no absent hero twin, ordinary week, raw 06:00–02:00","talkable_kinds":["outdoor","walk","counter","public"],"assumptions":{"hearts":5,"hero":"","total_days":[113,119],"festival":false,"home_entry":"one heart with the owner, owner home and awake; tested dynamically by the simulation"},"inputs":inputs,"npcs":npcs}
	var error := write_result(path, result)
	if error != "":
		print("AVAILABILITY ", error)
		quit(1)
		return
	print("AVAILABILITY exported ",npcs.size()," live citizens; compile problems ",Routines.compile_problems)
	quit(0 if Routines.compile_problems.is_empty() else 1)

func _kind(row: Dictionary) -> String:
	if str(row.kind) == "move":
		if str(row.get("from","")).begins_with("away:") or str(row.get("to","")).begins_with("away:"): return "away"
		return "walk"
	var place := str(row.get("place","nowhere"))
	var act := str(row.get("act",""))
	if place == "nowhere" or place.begins_with("away:") or act == "sleep": return "away"
	if row.has("access_kind"): return str(row.access_kind)
	if COUNTERS.any(func(suffix):return place.ends_with(suffix)): return "counter"
	if place.begins_with("int_"): return "room"
	return "inside" if act == "inside" else "outdoor"

static func _hash_file(path: String, out: Dictionary) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return "unreadable input: " + path
	file.close()
	var digest := FileAccess.get_sha256(path)
	if not _valid_digest(digest): return "invalid SHA256: " + path
	out[path] = digest
	return ""

static func _valid_digest(digest: Variant) -> bool:
	if not digest is String or digest.length() != 64: return false
	for character in digest:
		if not character in "0123456789abcdef": return false
	return true

static func _hashes(folder: String, out: Dictionary) -> String:
	var directory := DirAccess.open(folder)
	if directory == null: return "unreadable directory: " + folder
	var error: Error = directory.list_dir_begin()
	if error != OK: return "unreadable directory: " + folder
	var name := directory.get_next()
	while name != "":
		var path := folder + "/" + name
		var problem := ""
		if directory.current_is_dir(): problem = _hashes(path, out)
		elif name.ends_with(".lua") or name.ends_with(".json"): problem = _hash_file(path, out)
		if problem != "":
			directory.list_dir_end()
			return problem
		name = directory.get_next()
	directory.list_dir_end()
	return ""

static func collect_inputs(files: Array, folders: Array) -> Dictionary:
	var inputs := {}
	for folder in folders:
		var error := _hashes(str(folder), inputs)
		if error != "": return {"ok": false, "error": error, "inputs": {}}
	for path in files:
		var error := _hash_file(str(path), inputs)
		if error != "": return {"ok": false, "error": error, "inputs": {}}
	return {"ok": true, "error": "", "inputs": inputs}

static func validate_inputs(inputs: Dictionary) -> String:
	if inputs.is_empty(): return "empty declared inputs"
	for path in inputs:
		if not _valid_digest(inputs[path]): return "invalid SHA256: " + str(path)
		var actual := {}
		var error := _hash_file(str(path), actual)
		if error != "": return error
		if actual[str(path)] != inputs[path]: return "SHA256 mismatch: " + str(path)
	return ""

static func write_result(path: String, result: Dictionary) -> String:
	var error := validate_inputs(result.get("inputs", {}))
	if error != "": return error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return "cannot write " + path
	file.store_string(JSON.stringify(result, "", true) + "\n")
	var write_error: Error = file.get_error()
	file.close()
	return "" if write_error == OK else "cannot write " + path

func _accessible_spans(npc: String,plan: String,rain: bool,ctx: Dictionary) -> Array:
	var out: Array = []
	for segment in Routines.timeline(npc,plan,rain):
		var place := str(segment.get("place",""))
		if str(segment.kind) != "stay" or not place.begins_with("int_"):
			out.append(segment)
			continue
		var building := place.get_slice(".",0).trim_prefix("int_")
		var def := Hours.building(building)
		var post := place.get_slice(".",1)
		var spec: Dictionary = {}
		for folder in ["core","ext"]:
			var path: String = "res://data/interiors/"+str(folder)+"/int_"+building+".json"
			if FileAccess.file_exists(path): spec = LuaData.dict(JSON.parse_string(FileAccess.get_file_as_string(path)))
		var kind := "room"
		for anchor in LuaData.arr(spec.get("posts",[])):
			if str(anchor.id) == post and str(anchor.get("kind","")) in ["customer","seat","stage"]: kind = "public"
		if _kind(segment) == "counter": kind = "counter"
		if str(def.get("kind","")) == "home":
			var owner := str(def.get("owner",""))
			var owner_plan := Routines.plan_name(owner,ctx)
			for awake in Routines.timeline(owner,owner_plan,rain):
				if str(awake.kind) != "stay" or str(awake.get("act","")) in ["sleep","inside"] or not str(awake.get("place","")).begins_with("int_"+building+"."): continue
				_append_clip(out,segment,maxf(float(segment.t0),float(awake.t0)),minf(float(segment.t1),float(awake.t1)),"home:"+owner)
		elif def.has("hours"):
			var weekday := int(ctx.weekday)
			if weekday in Hours.closed_days(def): continue
			var hours := Hours.hours_on(def,weekday)
			_append_clip(out,segment,maxf(float(segment.t0),float(hours[0])),minf(float(segment.t1),float(hours[1])),kind)
	return out

func _append_clip(out: Array,segment: Dictionary,start: float,end: float,kind: String) -> void:
	if end <= start: return
	var clipped := segment.duplicate()
	clipped.t0 = start
	clipped.t1 = end
	clipped.access_kind = kind
	out.append(clipped)
