extends SceneTree
# Explicit -s compilation and pre-autoload old-kind fallback. Ignored by the
# normal section discoverer because the filename begins with underscore.
const AREA := preload("res://scripts/world2d/iso_area.gd")
var result := false
func _init() -> void:
	var absent := Svc.node("SocialManager") == null and Svc.node("GameManager") == null
	var local := AREA.evaluate_when("!flag:zz_isoarea_standalone") and not AREA.evaluate_when("night") and not AREA.evaluate_when("hearts:pip:4")
	var a := AREA.new()
	var n := Node2D.new()
	a.add_child(n)
	a._track_when({"when":"flag:zz_isoarea_standalone"},[n])
	var instance_ok := not n.visible and n.process_mode == Node.PROCESS_MODE_DISABLED and a.when_total_count() == 1
	result = absent and local and instance_ok
	print("ISOAREA_STANDALONE ",JSON.stringify({"preautoload":absent,"static_local_fallback":local,"offtree_instance":instance_ok,"ok":result}))
	a.free()
func _initialize() -> void:
	quit(0 if result else 1)
