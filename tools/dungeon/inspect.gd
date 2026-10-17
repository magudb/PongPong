extends SceneTree
## Export the live floor table, never a generated or separately maintained draft.
func _initialize() -> void:
	await process_frame
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if str(arg).begins_with("out="): output = str(arg).trim_prefix("out=")
	if output.is_empty():
		printerr("inspect requires out=<absolute directory>")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output)
	var cfg := LuaData.dict(GameData.cfg("dungeon",{}))
	var counts := {}
	var failed := false
	for n in range(1,int(cfg.max_floor)+1):
		var row := DungeonSpec.spec_for(cfg,n)
		var seed_value := DungeonRng.hash_key("gallery",1,n)
		var result := DungeonGen.build_text(cfg,n,seed_value,{"day":1,"seed_text":str(seed_value),"prev_id":"moerkeskoven_f%d" % (n-1),"next_id":"moerkeskoven_f%d" % (n+1)})
		if not result.ok:
			failed = true
			continue
		var file := FileAccess.open(output.path_join("floor_%02d.map" % n),FileAccess.WRITE)
		if file == null:
			failed = true
			continue
		file.store_string(result.text)
		file.close()
		var parsed := AreaMap.parse_text(result.text)
		var band := str(row.band)
		if not counts.has(band): counts[band] = {"floors":[],"markers":{},"props":0}
		counts[band].floors.append(n)
		for cells in parsed.objects:
			for symbol in str(cells):
				if parsed.markers.has(symbol):
					var kind := str(parsed.markers[symbol].get("marker",""))
					counts[band].markers[kind] = int(counts[band].markers.get(kind,0))+1
				elif parsed.props.has(symbol): counts[band].props += 1

	var report := FileAccess.open(output.path_join("band_counts.json"),FileAccess.WRITE)
	if report != null: report.store_string(JSON.stringify(counts,"\t")+"\n")
	else: failed = true
	print(JSON.stringify(counts))
	quit(1 if failed else 0)
