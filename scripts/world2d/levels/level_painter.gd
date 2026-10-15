class_name LevelPainter
extends RefCounted
## STAND-IN art of the treetop city (package V3-levels): flat vector shapes in the colours and proportions of the Style Guide v2 sketch, drawn
## from the same data the colliders use. It exists so the levelled framework can be LOOKED AT (windowed shots, the draw-order probes) before
## V5's baked art lands; V4's CityBuilder replaces these nodes with ArtCatalog sprites without touching the levels. Everything is Polygon2D /
## Line2D / Sprite2D with a tiny generated texture - no ArtCatalog call, so ArtCatalog.missing() stays what the other packages made it.
## Textures are created per LevelStage instance (a dictionary kept with the area), never in static variables.

const INK := Color("2b2340")
const PLANK := Color("c9925a")
const PLANK_DARK := Color("a06a3a")
const BARK := Color("8a5a32")
const BARK_DARK := Color("6e4626")
const WALL := Color("b98657")
const DOOR := Color("4a2d22")
const LANTERN := Color("f2c14e")
const LEAF := Color("6b9a3e")
const OUTLINE_W := 8.0


# ------------------------------------------------------------------ textures

## Plank texture (planks across the line / vertical stripes), used for the decks and the platform floors.
static func plank_texture() -> ImageTexture:
	var img := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	img.fill(PLANK)
	var shades: Array[Color] = [Color("c9925a"), Color("bf8850"), Color("d39c64"), Color("c48d55")]
	for k in 4:
		img.fill_rect(Rect2i(k * 64, 0, 62, 128), shades[k])
		img.fill_rect(Rect2i(k * 64 + 62, 0, 2, 128), PLANK_DARK)
		for g in 5:
			img.fill_rect(Rect2i(k * 64 + 8 + g * 11, (k * 37 + g * 29) % 100, 1, 20 + (g * 7) % 16), shades[(k + 1) % 4].darkened(0.08))
	img.fill_rect(Rect2i(0, 0, 256, 2), PLANK_DARK)
	img.fill_rect(Rect2i(0, 126, 256, 2), PLANK_DARK)
	return ImageTexture.create_from_image(img)


## A rail post: ink outline, bark body, a lighter cap. 16 x 72 world px, the pivot is the foot.
static func post_texture() -> ImageTexture:
	var img := Image.create(16, 72, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(3, 4, 10, 68), INK)
	img.fill_rect(Rect2i(5, 6, 6, 64), BARK)
	img.fill_rect(Rect2i(8, 6, 3, 64), BARK_DARK)
	img.fill_rect(Rect2i(2, 0, 12, 8), INK)
	img.fill_rect(Rect2i(4, 2, 8, 4), Color("a9744a"))
	return ImageTexture.create_from_image(img)


## A hanging lantern: rope, ink outline, gold body with a light centre. 28 x 56 world px, the pivot is the hook at the top centre.
static func lantern_texture() -> ImageTexture:
	var w: int = 28
	var h: int = 56
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(13, 0, 2, 22), INK)
	var c := Vector2(14.0, 38.0)
	for y in h:
		for x in w:
			var d: float = Vector2((float(x) + 0.5 - c.x) / 11.0, (float(y) + 0.5 - c.y) / 15.0).length()
			if d <= 1.0:
				var col: Color = INK if d > 0.74 else LANTERN.lerp(Color("fff2c0"), clampf(1.0 - d * 1.4, 0.0, 1.0))
				col.a = clampf((1.0 - d) * 14.0, 0.0, 1.0)
				img.set_pixel(x, y, col)
	return ImageTexture.create_from_image(img)


## The stand-in art dictionary every builder piece takes ({"deck": Texture2D, "post": Texture2D, "planks": Texture2D, "lantern": Texture2D}).
static func make_art() -> Dictionary:
	var planks: ImageTexture = plank_texture()
	return {"deck": planks, "planks": planks, "post": post_texture(), "lantern": lantern_texture()}


# ------------------------------------------------------------------ small shapes

static func arc(c: Vector2, rx: float, ry: float, a0: float, a1: float, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var a: float = lerpf(a0, a1, float(i) / float(n))
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


static func poly(points: PackedVector2Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	return p


static func line(points: PackedVector2Array, color: Color = INK, width: float = OUTLINE_W, closed: bool = false) -> Line2D:
	var l := Line2D.new()
	l.points = points
	l.width = width
	l.default_color = color
	l.closed = closed
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	return l


static func ellipse_node(c: Vector2, rx: float, ry: float, fill: Color, outline_w: float = OUTLINE_W) -> Node2D:
	var n := Node2D.new()
	var pts: PackedVector2Array = LevelRegistry.ellipse_points(c, rx, ry, 24)
	n.add_child(poly(pts, fill))
	if outline_w > 0.0:
		n.add_child(line(pts, INK, outline_w, true))
	return n


# ------------------------------------------------------------------ platform disc, trunks

## The floor of a platform: rim skirt, planked top, ink outline. Added to `parent` (the non-sorted Floors node) at z = rank - 4.
static func add_disc(parent: Node2D, lv: Level, art: Dictionary) -> void:
	var z: int = lv.rank - 4
	var lower: PackedVector2Array = arc(lv.centre, lv.rx, lv.ry, 0.0, PI, 32)
	var back: PackedVector2Array = arc(lv.centre + Vector2(0, lv.rim), lv.rx, lv.ry, PI, 0.0, 32)
	var skirt_pts := PackedVector2Array()
	skirt_pts.append_array(lower)
	skirt_pts.append_array(back)
	var skirt: Polygon2D = poly(skirt_pts, BARK)
	skirt.name = "Skirt_%s" % lv.id
	skirt.z_index = z
	parent.add_child(skirt)
	var top_pts: PackedVector2Array = LevelRegistry.ellipse_points(lv.centre, lv.rx, lv.ry, 64)
	var top: Polygon2D = poly(top_pts, PLANK)
	top.name = "Floor_%s" % lv.id
	top.z_index = z
	var tex: Texture2D = art.get("planks", null)
	if tex != null:
		top.texture = tex
		top.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		var uv := PackedVector2Array()
		for p in top_pts:
			uv.append((p - lv.centre) * 0.25)
		top.uv = uv
	parent.add_child(top)
	# ONE outline for the disc: the top ellipse, a drop to the skirt, the skirt's lower arc, and back up (retracing a short vertical piece)
	var outline_pts := PackedVector2Array()
	outline_pts.append_array(top_pts)
	outline_pts.append(top_pts[0])
	outline_pts.append(lv.centre + Vector2(lv.rx, lv.rim))
	var drop: PackedVector2Array = arc(lv.centre + Vector2(0, lv.rim), lv.rx, lv.ry, 0.0, PI, 32)
	outline_pts.append_array(drop)
	outline_pts.append(lv.centre + Vector2(-lv.rx, 0))
	var outline_line: Line2D = line(outline_pts, INK, OUTLINE_W)
	outline_line.z_index = z
	parent.add_child(outline_line)


## A trunk segment as a node positioned at its pivot: a cylinder from `top_rel` to `bottom_rel` (relative y, world px) with a half-ellipse foot.
static func trunk_node(rx: float, ry: float, top_rel: float, bottom_rel: float) -> Node2D:
	var n := Node2D.new()
	var body := PackedVector2Array()
	body.append(Vector2(-rx, top_rel))
	body.append(Vector2(rx, top_rel))
	body.append_array(arc(Vector2(0, bottom_rel), rx, ry, 0.0, PI, 20))
	n.add_child(poly(body, BARK))
	var band := PackedVector2Array()
	band.append(Vector2(rx * 0.3, top_rel))
	band.append(Vector2(rx, top_rel))
	band.append_array(arc(Vector2(0, bottom_rel), rx, ry, 0.0, acos(0.3), 8))
	n.add_child(poly(band, BARK_DARK))
	var edge := PackedVector2Array()
	edge.append(Vector2(-rx, top_rel))
	edge.append_array(arc(Vector2(0, bottom_rel), rx, ry, PI, 0.0, 20))
	edge.append(Vector2(rx, top_rel))
	n.add_child(line(edge, INK, OUTLINE_W))
	return n


# ------------------------------------------------------------------ buildings and props

## A round hut at its base point (the node origin = the centre of the wall's ground circle).
static func hut_node(b: Dictionary, scale: float) -> Node2D:
	var n := Node2D.new()
	var wr: float = LuaData.num(b["wall_r"]) * scale
	var wh: float = LuaData.num(b["wall_h"]) * scale
	var ry: float = wr * LevelRegistry.SKETCH_SQUASH
	var wall := PackedVector2Array()
	wall.append(Vector2(-wr, -wh))
	wall.append(Vector2(wr, -wh))
	wall.append_array(arc(Vector2.ZERO, wr, ry, 0.0, PI, 20))
	n.add_child(poly(wall, WALL))
	var wall_edge := PackedVector2Array()
	wall_edge.append(Vector2(-wr, -wh))
	wall_edge.append_array(arc(Vector2.ZERO, wr, ry, PI, 0.0, 20))
	wall_edge.append(Vector2(wr, -wh))
	n.add_child(line(wall_edge, INK, OUTLINE_W))
	var roof: Dictionary = b["roof"]
	var rrx: float = LuaData.num(roof["rx"]) * scale
	var rry: float = LuaData.num(roof["ry"]) * scale
	var rh: float = LuaData.num(roof["h"]) * scale
	var eave_y: float = -wh + 6.0 * scale
	var roof_pts := PackedVector2Array()
	roof_pts.append_array(arc(Vector2(0, eave_y), rrx, rry, PI, 0.0, 24))
	roof_pts.append(Vector2(0, eave_y - rh))
	n.add_child(poly(roof_pts, Color.from_string(str(roof["fill"]), Color("c9a052"))))
	n.add_child(line(roof_pts, INK, OUTLINE_W, true))
	# the door: an arch of 20 x 30 sketch px, x is its left edge, y its bottom (sketch px), relative to the hut origin
	var door: Dictionary = b["door"]
	var dx: float = (LuaData.num(door["x"]) - LuaData.num(b["cx"])) * scale
	var dy: float = (LuaData.num(door["y"]) - LuaData.num(b["base_y"])) * scale
	var dw: float = 20.0 * scale
	var door_pts := PackedVector2Array()
	door_pts.append(Vector2(dx, dy))
	door_pts.append(Vector2(dx, dy - 20.0 * scale))
	door_pts.append_array(arc(Vector2(dx + dw * 0.5, dy - 20.0 * scale), dw * 0.5, dw * 0.5, PI, TAU, 8))
	door_pts.append(Vector2(dx + dw, dy))
	n.add_child(poly(door_pts, DOOR))
	if b.has("pennant"):
		var apex: Vector2 = Vector2(0, eave_y - rh)
		n.add_child(line(PackedVector2Array([apex, apex + Vector2(0, -34.0 * scale)]), INK, 5.0))
		var flag := PackedVector2Array([apex + Vector2(0, -34.0 * scale), apex + Vector2(22.0 * scale, -28.0 * scale), apex + Vector2(0, -20.0 * scale)])
		n.add_child(poly(flag, Color.from_string(str(b["pennant"]), Color("e58fa6"))))
	return n


## A hanging lantern: a short rope and a gold body. The node origin is the rope's hook.
static func lantern_node(scale: float) -> Node2D:
	var n := Node2D.new()
	n.add_child(line(PackedVector2Array([Vector2(0, -16.0 * scale), Vector2(0, 0)]), INK, 4.0))
	var body: PackedVector2Array = LevelRegistry.ellipse_points(Vector2(0, 8.0 * scale), 5.5 * scale, 7.0 * scale, 12)
	n.add_child(poly(body, LANTERN))
	n.add_child(line(body, INK, 4.0, true))
	return n


## A flat prop by id (the sketch's stall, fire pit, tub, log stack, mailbox, notice board, seed basket, planters). Node origin = ground centre.
static func prop_node(rec: Dictionary, scale: float) -> Node2D:
	var n := Node2D.new()
	var id: String = str(rec.get("id", ""))
	var keep: Array = LuaData.arr(rec.get("keep", [10, 6]))
	var rx: float = LuaData.num(keep[0]) * scale
	var ry: float = LuaData.num(keep[1]) * scale
	if id == "stall":
		var box := PackedVector2Array([Vector2(-rx, -ry * 1.2), Vector2(rx, -ry * 1.2), Vector2(rx, ry * 0.6), Vector2(-rx, ry * 0.6)])
		n.add_child(poly(box, Color("d9b27c")))
		n.add_child(line(box, INK, OUTLINE_W, true))
		var awning := PackedVector2Array([Vector2(-rx - 10, -ry * 3.0), Vector2(rx + 10, -ry * 3.0), Vector2(rx + 20, -ry * 1.1), Vector2(-rx - 20, -ry * 1.1)])
		n.add_child(poly(awning, Color("c4506a")))
		for k in range(-1, 2):
			n.add_child(line(PackedVector2Array([Vector2(float(k) * rx * 0.55, -ry * 3.0), Vector2(float(k) * rx * 0.62, -ry * 1.1)]), Color("fbf5e6"), 20.0))
		n.add_child(line(awning, INK, OUTLINE_W, true))
	elif id == "fire_pit":
		n.add_child(ellipse_node(Vector2.ZERO, rx, ry, Color("7d8494")))
		n.add_child(ellipse_node(Vector2(0, -4), rx * 0.72, ry * 0.66, INK, 0.0))
		var flame := PackedVector2Array([Vector2(-rx * 0.34, 0), Vector2(-rx * 0.08, -ry * 1.6), Vector2(0, -ry * 2.6), Vector2(rx * 0.1, -ry * 1.5), Vector2(rx * 0.34, 0)])
		n.add_child(poly(flame, Color("e07b3c")))
		n.add_child(line(flame, INK, 5.0, true))
		var core := PackedVector2Array([Vector2(-rx * 0.16, 0), Vector2(0, -ry * 1.6), Vector2(rx * 0.16, 0)])
		n.add_child(poly(core, Color("f2c14e")))
	elif id == "bath_tub":
		n.add_child(ellipse_node(Vector2.ZERO, rx, ry, PLANK_DARK))
		n.add_child(ellipse_node(Vector2(0, -8), rx * 0.82, ry * 0.78, Color("9fd3e0"), 6.0))
	elif id == "log_stack":
		for k in 3:
			n.add_child(ellipse_node(Vector2(float(k) * 12.0, -float(k) * 36.0), rx * 0.9, ry * 0.42, WALL))
	elif id == "mailbox":
		n.add_child(line(PackedVector2Array([Vector2(0, 0), Vector2(0, -90)]), INK, 12.0))
		var mb := PackedVector2Array([Vector2(-24, -126), Vector2(24, -126), Vector2(24, -86), Vector2(-24, -86)])
		n.add_child(poly(mb, Color("c4506a")))
		n.add_child(line(mb, INK, 6.0, true))
	elif id == "notice_board":
		n.add_child(line(PackedVector2Array([Vector2(-34, 0), Vector2(-34, -100)]), INK, 10.0))
		n.add_child(line(PackedVector2Array([Vector2(34, 0), Vector2(34, -100)]), INK, 10.0))
		var bb := PackedVector2Array([Vector2(-60, -170), Vector2(60, -170), Vector2(60, -90), Vector2(-60, -90)])
		n.add_child(poly(bb, Color("f4e6c4")))
		n.add_child(line(bb, INK, 6.0, true))
	elif id == "seed_basket":
		n.add_child(ellipse_node(Vector2(0, -10), rx * 1.2, ry * 1.2, Color("a9744a"), 5.0))
	elif id.begins_with("planter"):
		var box2 := PackedVector2Array([Vector2(-rx, 0), Vector2(0, -ry), Vector2(rx, 0), Vector2(0, ry)])
		n.add_child(poly(box2, Color("7a4e2d")))
		n.add_child(line(box2, INK, 6.0, true))
		for k in 3:
			n.add_child(ellipse_node(Vector2(float(k - 1) * rx * 0.5, -16.0), 12.0, 14.0, LEAF, 4.0))
	else:
		n.add_child(ellipse_node(Vector2.ZERO, rx, ry, Color("c9925a")))
	return n


## An owl hole in a trunk: a dark ellipse with a small shelf.
static func owl_hole_node(scale: float) -> Node2D:
	var n := Node2D.new()
	n.add_child(ellipse_node(Vector2(0, -38.0 * scale), 30.0 * scale, 38.0 * scale, Color("3a2418")))
	n.add_child(ellipse_node(Vector2(0, 0), 36.0 * scale, 8.0 * scale, Color("a9744a"), 5.0))
	return n


## A bat house hanging from a rope: an upside-down cone with a door; origin = the tip.
static func bat_house_node(w: float, h: float, scale: float) -> Node2D:
	var n := Node2D.new()
	var hw: float = w * 0.5 * scale
	var cone := PackedVector2Array([Vector2(0, 0), Vector2(hw, -h * scale * 0.55), Vector2(hw * 0.7, -h * scale * 0.7), Vector2(-hw * 0.7, -h * scale * 0.7), Vector2(-hw, -h * scale * 0.55)])
	n.add_child(poly(cone, Color("8c7aa8")))
	n.add_child(line(cone, INK, OUTLINE_W, true))
	n.add_child(line(PackedVector2Array([Vector2(0, -h * scale * 0.7), Vector2(0, -h * scale * 1.0)]), INK, 5.0))
	n.add_child(ellipse_node(Vector2(0, -h * scale * 0.4), hw * 0.28, hw * 0.34, INK, 0.0))
	n.add_child(ellipse_node(Vector2(0, 30.0), 10.0 * scale, 8.0 * scale, Color("6b5b8a"), 4.0))
	return n


## A clump of foliage: translucent green circles.
static func foliage_node(rx: float, ry: float, alpha: float) -> Node2D:
	var n := Node2D.new()
	for k in 5:
		var a: float = TAU * float(k) / 5.0
		var c := Vector2(cos(a) * rx * 0.45, sin(a) * ry * 0.4)
		var e := poly(LevelRegistry.ellipse_points(c, rx * 0.5, ry * 0.55, 20), Color(0.42, 0.6, 0.24, 1.0))
		n.add_child(e)
	n.modulate = Color(1, 1, 1, alpha)
	return n


## The sky: a vertical gradient quad over `rect` (world px).
static func sky_node(rect: Rect2) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	p.vertex_colors = PackedColorArray([Color("cfe0a8"), Color("cfe0a8"), Color("8fb069"), Color("8fb069")])
	return p


## The ground strip at the bottom of the sketch (y >= 1140 sketch px) with a wavy edge.
static func ground_strip_node(rect: Rect2, scale: float) -> Node2D:
	var n := Node2D.new()
	var top: float = 1140.0 * scale
	var pts := PackedVector2Array()
	var steps: int = 24
	for i in steps + 1:
		var x: float = lerpf(rect.position.x, rect.end.x, float(i) / float(steps))
		pts.append(Vector2(x, top + sin(float(i) * 0.9) * 14.0 * scale))
	pts.append(Vector2(rect.end.x, rect.end.y))
	pts.append(Vector2(rect.position.x, rect.end.y))
	n.add_child(poly(pts, Color("3f5a2e")))
	return n


## Far trunk bars of the sketch backdrop (x, width in sketch px): ONE Polygon2D with nine polygons (vertex colours), one draw call.
static func far_bars_node(rect: Rect2, scale: float) -> Node2D:
	var n := Node2D.new()
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var polys: Array = []
	for bar in [[120, 60], [380, 44], [760, 52], [1080, 40], [1420, 58], [1680, 46], [260, 80], [1560, 90], [60, 70]]:
		var x: float = float(bar[0]) * scale
		var w: float = float(bar[1]) * scale
		var col: Color = Color("86a866") if bar[1] < 62 else Color("6f9152")
		col.a = 0.55
		var base: int = verts.size()
		verts.append_array(PackedVector2Array([Vector2(x, rect.position.y), Vector2(x + w, rect.position.y), Vector2(x + w, rect.end.y), Vector2(x, rect.end.y)]))
		for i in 4:
			cols.append(col)
		polys.append(PackedInt32Array([base, base + 1, base + 2, base + 3]))
	var p := Polygon2D.new()
	p.polygon = verts
	p.polygons = polys
	p.vertex_colors = cols
	n.add_child(p)
	return n


## The leafy frame at the top edge of the screen (a screen-space strip for a CanvasLayer): a dark green band with round leaf bumps, ONE Polygon2D
## (an outer and an inner polygon with vertex colours).
static func canopy_strip(width: float, height: float) -> Node2D:
	var n := Node2D.new()
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var bumps: int = 26
	var outer_ids := PackedInt32Array()
	verts.append(Vector2(0, 0))
	verts.append(Vector2(width, 0))
	for i in bumps + 1:
		verts.append(Vector2(width * (1.0 - float(i) / float(bumps)), height * (0.62 + 0.38 * absf(sin(float(i) * 1.7)))))
	for i in verts.size():
		outer_ids.append(i)
		cols.append(Color("6b9a3e"))
	var inner_ids := PackedInt32Array()
	var base: int = verts.size()
	verts.append(Vector2(0, 0))
	verts.append(Vector2(width, 0))
	for i in bumps + 1:
		verts.append(Vector2(width * (1.0 - float(i) / float(bumps)), height * (0.3 + 0.28 * absf(sin(float(i) * 1.3)))))
	for i in range(base, verts.size()):
		inner_ids.append(i)
		cols.append(Color("4f7a2c"))
	var p := Polygon2D.new()
	p.polygon = verts
	p.polygons = [outer_ids, inner_ids]
	p.vertex_colors = cols
	n.add_child(p)
	return n
