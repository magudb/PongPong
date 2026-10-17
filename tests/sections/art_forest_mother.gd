extends RefCounted
const SECTION := "art_forest_mother"
const TIMEOUT_S := 180.0
func run(t) -> void:
	var folder := "res://assets/iso_props/forest_mother/"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder+"props.json"))
	t.check("four_saved_paintings",manifest.size() == 4)
	for id in manifest:
		var spec: Dictionary = manifest[id]
		var art := ArtCatalog.prop(StringName(id))
		t.check("runtime_art_"+id,art.real and art.texture.resource_path == folder+str(spec.file) and art.size == Vector2(spec.size[0],spec.size[1]))
		t.check("selected_source_"+id,FileAccess.get_sha256("res://"+str(spec.source)) == str(spec.source_sha256))
		t.check("cutout_"+id,art.texture.get_image().get_pixel(0,0).a == 0 and FileAccess.get_file_as_bytes(folder+str(spec.file)).size() <= 204800)
	for row in MotherStory.EVIDENCE:
		if row.has("art"): t.check("evidence_art_"+str(row.id),ArtCatalog.has_real_prop(StringName(str(row.art))))
	var audit: Dictionary = t.run_godot_script("res://tools/art/drawn/coverage.gd",PackedStringArray(["--strict","--details","--report=res://docs/art/style-audit/current/catalog.json"]))
	t.check("complete_effective_catalog",int(audit.code) == 0,str(audit).left(800))
