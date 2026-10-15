class_name LevelGlow
extends Node2D
## The lantern light of a levelled area (package V3-levels; the design prototype called it CityGlowNode - the name `Glow` is the global class of
## scripts/world2d/glow.gd and `class Glow` does not compile). Additive HALOS for every hanging lantern and door lamp and AT MOST MAX_LIGHTS
## PointLight2D for the lights that matter (fire pit, tub steam, door lamps of the post office and the Raadhus, one lantern per platform).
## All of them follow the glow curve of the world's DayNight: LevelGlow connects to `day_night.glow_changed` through the `world_2d` group in
## _enter_tree and disconnects in _exit_tree (the connection count is 1 -> 1 after leaving the area), so IsoArea.register_light - whose lists
## are private - is not needed.
##
##   glow.setup(halos, lights)   halos  [{at: Vector2, r: float, color: Color, strength: float}]
##                               lights [{at: Vector2, r: float, color: Color, energy: float}]   (world px; more than MAX_LIGHTS are cut)
##   glow.set_factor(f)          0 = day, 1 = full night: halo alpha = f x strength, light energy = f x energy, hidden below the thresholds
## The node sits above everything (z_index Z), the halos never sort with the actors.

const MAX_LIGHTS := 12
const Z := 190
const HALO_FILE_PX := 128.0
const LIGHT_FILE_PX := 256.0
const ON_THRESHOLD := 0.004
const LIGHT_ON_THRESHOLD := 0.02

var halos: Array[Sprite2D] = []
var lights: Array[PointLight2D] = []
var factor: float = 0.0
var connected_to: Object = null
var light_cut: int = 0                  # lights that were asked for beyond MAX_LIGHTS and dropped

var _halo_strength: Array[float] = []
var _light_energy: Array[float] = []


func _init() -> void:
	z_index = Z
	name = "LevelGlow"


func setup(halo_specs: Array, light_specs: Array) -> void:
	for h in halo_specs:
		var s := Sprite2D.new()
		s.texture = Glow.halo_texture()
		s.material = Glow.additive_material()
		s.position = h["at"]
		var d: float = (h["r"] as float) * 2.0 / HALO_FILE_PX
		s.scale = Vector2(d, d)
		var col: Color = h["color"]
		s.modulate = Color(col.r, col.g, col.b, 0.0)
		s.visible = false
		add_child(s)
		halos.append(s)
		_halo_strength.append(h["strength"])
	for i in light_specs.size():
		if lights.size() >= MAX_LIGHTS:
			light_cut += 1
			continue
		var l: Dictionary = light_specs[i]
		var pl := PointLight2D.new()
		pl.texture = Glow.light_texture()
		pl.texture_scale = (l["r"] as float) * 2.0 / LIGHT_FILE_PX
		pl.color = l["color"]
		pl.energy = 0.0
		pl.shadow_enabled = false
		pl.position = l["at"]
		pl.visible = false
		add_child(pl)
		lights.append(pl)
		_light_energy.append(l["energy"])
	_apply()


func _enter_tree() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var w: Node = tree.get_first_node_in_group("world_2d")
	if w != null and w.get("day_night") != null:
		connected_to = w.get("day_night")
		if not (connected_to as Object).is_connected("glow_changed", _on_glow):
			(connected_to as Object).connect("glow_changed", _on_glow)
		set_factor(float((connected_to as Object).get("glow_factor")))


func _exit_tree() -> void:
	if connected_to != null and is_instance_valid(connected_to):
		if (connected_to as Object).is_connected("glow_changed", _on_glow):
			(connected_to as Object).disconnect("glow_changed", _on_glow)
	connected_to = null


func _on_glow(f: float) -> void:
	set_factor(f)


func set_factor(f: float) -> void:
	factor = clampf(f, 0.0, 1.0)
	_apply()


func _apply() -> void:
	for i in halos.size():
		var s: Sprite2D = halos[i]
		var c: Color = s.modulate
		c.a = factor * _halo_strength[i]
		s.modulate = c
		s.visible = factor > ON_THRESHOLD
	for i in lights.size():
		var pl: PointLight2D = lights[i]
		pl.energy = factor * _light_energy[i]
		pl.visible = factor > LIGHT_ON_THRESHOLD
		pl.enabled = factor > LIGHT_ON_THRESHOLD


## How many halos and lights are visible right now (tests).
func visible_counts() -> Vector2i:
	var h: int = 0
	var l: int = 0
	for s in halos:
		if s.visible:
			h += 1
	for p in lights:
		if p.enabled:
			l += 1
	return Vector2i(h, l)
