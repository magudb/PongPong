class_name PropArt
extends RefCounted
## Placeholder prop painters (the fallback behind ArtCatalog.prop, decision D18). Every painter returns the same shape as an
## entry of assets/iso_props/props.json plus the texture:
##   {"texture": ImageTexture, "pivot": Vector2 (px from the image top-left = the GROUND ORIGIN = footprint centre),
##    "size": Vector2, "footprint": Vector2i, "glow": {...} (optional, same keys as props.json), "blend": "add" (optional)}
## so code written against the placeholder works unchanged on the real art. Nothing here is collision: collision, strips and
## sort rules come from lua/config/props.lua (GameData.prop_def).
##
## Painting cost: see PlaceholderArt (scaled canvas). Big sprites are painted at a lower resolution (quality_for()).

const MOSS := Color("6b9a3e")
const MOSS_D := Color("4d7a2a")
const MOSS_L := Color("8bb85a")
const BARK := Color("7a4e2d")
const HONEY := Color("e8b04a")
const ROSE := Color("e58fa6")
const CREAM := Color("fbf5e6")
const LAV := Color("9b86d6")
const TEAL := Color("6fd6c4")
const SHADOW := Color(0.17, 0.14, 0.25, 0.30)

## Pixels the painters are willing to touch per prop at full size; larger sprites are painted smaller and scaled up.
const BUDGET_PX := 9000.0


static func quality_for(w: int, h: int) -> float:
	return clampf(sqrt(BUDGET_PX / maxf(float(w * h), 1.0)), 0.3, PlaceholderArt.QUALITY)


static func _img(w: int, h: int) -> Image:
	return PlaceholderArt.new_image(w, h, quality_for(w, h))


static func _result(img: Image, pivot: Vector2, footprint: Vector2i = Vector2i(1, 1), extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = {"pivot": pivot, "footprint": footprint}
	var done: Image = PlaceholderArt.finish(img)
	d["size"] = Vector2(done.get_width(), done.get_height())
	d["texture"] = ImageTexture.create_from_image(done)
	d.merge(extra, true)
	return d


static func _id_hash(id: String) -> float:
	return fposmod(float(id.hash() % 100003) / 100003.0, 1.0)


# ----------------------------------------------------------------------------- dispatch by catalogue id

## Placeholder for any prop id: the specific painter when one exists, else a coloured block / boulder of the right footprint.
static func make(id: String, footprint: Vector2i = Vector2i(1, 1)) -> Dictionary:
	var variant: int = 1 if id.ends_with("_b") or id.contains("blossom") or id.contains("berry") else 0
	if id.begins_with("tree_"):
		return tree(variant, id.contains("pine") or id.contains("twisted"), id.contains("hyggebyen"))
	if id.begins_with("bush_"):
		return bush(variant)
	if id.begins_with("rock_"):
		return rock(variant)
	if id.begins_with("ore_"):
		return rock(1, Color("c7a46a") if id.contains("gold") else (Color("b9794a") if id.contains("copper") else Color("8e8a99")))
	if id.begins_with("crystal_"):
		return crystal(Color("d2b4f5") if id.contains("amethyst") else (Color("9be7bc") if id.contains("emerald") else Color("e9f2ff")))
	if id.begins_with("glowmush_") or id == "mushroom_light":
		return mushroom_light()
	if id.begins_with("fence_"):
		return fence(id.ends_with("_z"), id.contains("gate"))
	if id == "bridge_x" or id == "bridge_z":
		return bridge_piece(id == "bridge_z")
	if id == "lantern_post" or id == "lantern_hand":
		return lantern(id == "lantern_hand")
	if id == "scarecrow":
		return scarecrow()
	if id == "signpost" or id == "sign":
		return signpost()
	if id == "warp_gate_stone" or id == "gate" or id.begins_with("warp_gate"):
		return warp_gate()
	if id == "platform_sw" or id == "platform_se" or id == "platform_corner":
		return platform(id.trim_prefix("platform_"))
	if id.begins_with("crop_"):
		var parts: PackedStringArray = id.split("_")
		return crop(parts[1] if parts.size() > 2 else "turnip", int(parts[parts.size() - 1]) if parts[parts.size() - 1].is_valid_int() else 3)
	if id.begins_with("chest_"):
		return chest(id.contains("konge") or id.contains("fe"))
	if id.begins_with("forest_wall") or id.begins_with("cave_wall"):
		return wall_block(id)
	if id.begins_with("house_") or id.begins_with("tower_") or footprint.x > 1 or footprint.y > 1:
		return house(maxi(footprint.x, 1), maxi(footprint.y, 1), id)
	return generic(id)


# ----------------------------------------------------------------------------- nature

static func tree(variant: int = 0, conifer: bool = false, blossom: bool = false) -> Dictionary:
	var w: int = 190
	var h: int = 250
	var img: Image = _img(w, h)
	var ax: float = 95.0
	var ay: float = 226.0
	PlaceholderArt.soft_ellipse(img, Vector2(ax, ay), Vector2(54, 18), SHADOW)
	PlaceholderArt.poly(img, PackedVector2Array([Vector2(ax - 13, ay + 4), Vector2(ax + 14, ay + 4), Vector2(ax + 8, ay - 20), Vector2(ax + 7, ay - 92), Vector2(ax - 7, ay - 92), Vector2(ax - 8, ay - 20)]), BARK.lightened(0.1), BARK.darkened(0.2), 1.6)
	for stroke in 4:
		var bx: float = ax - 8.0 + float(stroke) * 5.0
		PlaceholderArt.line(img, Vector2(bx, ay - 12), Vector2(bx + 2.0, ay - 75 + stroke * 5), 1.2, Color(BARK.darkened(0.3), 0.65))
	var greens: Array[Color] = [MOSS_D, MOSS, MOSS_L]
	if variant == 1:
		greens = [Color("5a8a3a"), Color("77a84a"), Color("9cc86a")]
	if conifer:
		greens = [Color("2f5a46"), Color("3b6b52"), Color("4f8566")]
	if blossom:
		greens = [Color("b79bd6"), Color("d3b7ea"), Color("efd3f3")]
	var spots: Array = [
		[Vector2(ax - 40, ay - 112), Vector2(46, 38), 0], [Vector2(ax + 40, ay - 112), Vector2(46, 38), 0],
		[Vector2(ax, ay - 138), Vector2(58, 48), 1],
		[Vector2(ax - 30, ay - 158), Vector2(40, 34), 1], [Vector2(ax + 30, ay - 158), Vector2(40, 34), 2],
		[Vector2(ax, ay - 184), Vector2(36, 30), 2],
	]
	for s in spots:
		PlaceholderArt.blob(img, s[0] as Vector2, s[1] as Vector2, greens[s[2] as int], 1.6, 1.0)
		var leaf: Vector2 = s[0]
		var leaf_ink := Color(greens[s[2] as int].darkened(0.2), 0.6)
		PlaceholderArt.line(img, leaf + Vector2(-12, 5), leaf + Vector2(-5, -3), 1.3, leaf_ink)
		PlaceholderArt.line(img, leaf + Vector2(-5, -3), leaf + Vector2(3, 3), 1.3, leaf_ink)
		PlaceholderArt.line(img, leaf + Vector2(3, 3), leaf + Vector2(10, -4), 1.3, leaf_ink)
	for i in 7:
		var p := Vector2(ax - 55.0 + 110.0 * PlaceholderArt._hash(float(i), 1.0 + variant), ay - 205.0 + 100.0 * PlaceholderArt._hash(2.0 + variant, float(i)))
		PlaceholderArt.dot(img, p, 2.4, MOSS_L.lightened(0.25) if i % 2 == 0 else Color(0.35, 0.55, 0.22, 0.8))
	if variant == 1 or blossom:
		for i in 5:
			var p2 := Vector2(ax - 50.0 + 100.0 * PlaceholderArt._hash(float(i), 8.0), ay - 190.0 + 90.0 * PlaceholderArt._hash(8.0, float(i)))
			PlaceholderArt.dot(img, p2, 3.0, ROSE)
			PlaceholderArt.dot(img, p2, 1.2, CREAM)
	return _result(img, Vector2(ax, ay))


static func bush(variant: int = 0) -> Dictionary:
	var img: Image = _img(110, 84)
	var ax: float = 55.0
	var ay: float = 70.0
	PlaceholderArt.soft_ellipse(img, Vector2(ax, ay), Vector2(36, 11), Color(0.17, 0.14, 0.25, 0.28))
	PlaceholderArt.blob(img, Vector2(ax - 16, ay - 16), Vector2(22, 17), MOSS_D, 1.6)
	PlaceholderArt.blob(img, Vector2(ax + 16, ay - 16), Vector2(22, 17), MOSS, 1.6)
	PlaceholderArt.blob(img, Vector2(ax, ay - 26), Vector2(24, 19), MOSS_L, 1.6)
	if variant == 1:
		for i in 5:
			PlaceholderArt.dot(img, Vector2(ax - 22.0 + 44.0 * PlaceholderArt._hash(float(i), 4.0), ay - 34.0 + 24.0 * PlaceholderArt._hash(4.0, float(i))), 3.2, Color("b3436b"))
	return _result(img, Vector2(ax, ay))


static func rock(variant: int = 0, tint: Color = Color("a89cc0")) -> Dictionary:
	var img: Image = _img(120, 90)
	var ax: float = 60.0
	var ay: float = 76.0
	PlaceholderArt.soft_ellipse(img, Vector2(ax, ay), Vector2(40, 12), Color(0.17, 0.14, 0.25, 0.28))
	PlaceholderArt.blob(img, Vector2(ax - 12, ay - 18), Vector2(28, 21), tint, 1.6)
	PlaceholderArt.blob(img, Vector2(ax + 16, ay - 12), Vector2(20, 15), tint.lightened(0.18), 1.6)
	if variant == 0:
		PlaceholderArt.dot(img, Vector2(ax - 8, ay - 28), 4.0, Color(0.37, 0.54, 0.23, 0.8))
	return _result(img, Vector2(ax, ay))


static func crystal(col: Color) -> Dictionary:
	var img: Image = _img(110, 120)
	var ax: float = 55.0
	var ay: float = 100.0
	PlaceholderArt.soft_ellipse(img, Vector2(ax, ay), Vector2(30, 10), Color(0.0, 0.05, 0.1, 0.30))
	PlaceholderArt.poly(img, PackedVector2Array([Vector2(ax - 14, ay), Vector2(ax - 8, ay - 62), Vector2(ax, ay - 74), Vector2(ax + 8, ay - 58), Vector2(ax + 14, ay)]), col.lightened(0.15), col.darkened(0.2), 1.6)
	PlaceholderArt.poly(img, PackedVector2Array([Vector2(ax + 8, ay), Vector2(ax + 14, ay - 40), Vector2(ax + 24, ay - 46), Vector2(ax + 26, ay)]), col, col.darkened(0.3), 1.6)
	PlaceholderArt.poly(img, PackedVector2Array([Vector2(ax - 30, ay), Vector2(ax - 26, ay - 34), Vector2(ax - 16, ay - 40), Vector2(ax - 12, ay)]), col.darkened(0.1), col.darkened(0.35), 1.6)
	return _result(img, Vector2(ax, ay), Vector2i(1, 1), {"glow": _halo_entry(Vector2(ax, ay - 40), col, 104.0)})


static func mushroom_light() -> Dictionary:
	var img: Image = _img(120, 110)
	var ax: float = 60.0
	var ay: float = 92.0
	PlaceholderArt.soft_ellipse(img, Vector2(ax, ay), Vector2(34, 10), Color(0.0, 0.05, 0.08, 0.35))
	var caps: Array = [[Vector2(ax - 18, ay - 18), 20.0, 0.7], [Vector2(ax + 14, ay - 26), 24.0, 1.0], [Vector2(ax + 2, ay - 8), 14.0, 0.6]]
	for c in caps:
		var p: Vector2 = c[0]
		var r: float = c[1]
		PlaceholderArt.poly(img, PackedVector2Array([p + Vector2(-5, 2), p + Vector2(5, 2), p + Vector2(4, r * 0.9), p + Vector2(-4, r * 0.9)]), CREAM, Color("cdb98f"), 1.5)
		PlaceholderArt.blob(img, p + Vector2(0, -2), Vector2(r, r * 0.72), TEAL.darkened(0.1 * (1.0 - float(c[2]))), 1.6, 1.3)
		PlaceholderArt.dot(img, p + Vector2(-r * 0.3, -r * 0.35), 2.2, CREAM)
	return _result(img, Vector2(ax, ay), Vector2i(1, 1), {"glow": _halo_entry(Vector2(ax, ay - 30), TEAL, 120.0)})


# ----------------------------------------------------------------------------- built things

static func fence(along_z: bool, gate: bool = false) -> Dictionary:
	var img: Image = _img(110, 122)
	var ax: float = 50.0
	var ay: float = 96.0
	PlaceholderArt.soft_ellipse(img, Vector2(ax, ay), Vector2(40, 11), Color(0.17, 0.14, 0.25, 0.26))
	# fence_x runs towards the screen lower-right, fence_z towards the lower-left
	var dirv: Vector2 = Vector2(-1.0, Iso.squash()) if along_z else Vector2(1.0, Iso.squash())
	var a: Vector2 = Vector2(ax, ay) - dirv * 34.0
	var b: Vector2 = Vector2(ax, ay) + dirv * 34.0
	for p in [a, b]:
		var pp: Vector2 = p
		PlaceholderArt.poly(img, PackedVector2Array([pp + Vector2(-6, 4), pp + Vector2(6, 4), pp + Vector2(6, -56), pp + Vector2(0, -64), pp + Vector2(-6, -56)]), BARK.lightened(0.15), BARK.darkened(0.1), 1.6)
	var rails: Array = [-22.0] if gate else [-30.0, -46.0]
	for lift in rails:
		var lf: float = lift
		PlaceholderArt.line(img, a + Vector2(0, lf), b + Vector2(0, lf), 5.0, PlaceholderArt.INK)
		PlaceholderArt.line(img, a + Vector2(0, lf), b + Vector2(0, lf), 3.0, BARK.lightened(0.25))
	return _result(img, Vector2(ax, ay))


static func bridge_piece(along_z: bool) -> Dictionary:
	## One plank cell with a post at each side (the real art carries the rope rails too).
	var img: Image = _img(138, 142)
	var ax: float = 69.0
	var ay: float = 100.0
	var d: PackedVector2Array = Iso.iso_diamond(Vector2i.ZERO)
	var c0: Vector2 = Iso.iso_center(Vector2i.ZERO)
	var pts := PackedVector2Array()
	for p in d:
		pts.append(p - c0 + Vector2(ax, ay))
	PlaceholderArt.poly(img, pts, Color("d1a468"), Color("b98a52"), 1.6)
	var along: Vector2 = (Vector2(-1, 0.59) if along_z else Vector2(1, 0.59)).normalized()
	var side: Vector2 = Vector2(along.y, -along.x) if not along_z else Vector2(-along.y, along.x)
	for i in 5:
		var t: float = -0.4 + 0.2 * float(i)
		var a0: Vector2 = Vector2(ax, ay) + along * (t * 64.0) - side * 22.0
		var a1: Vector2 = Vector2(ax, ay) + along * (t * 64.0) + side * 22.0
		PlaceholderArt.line(img, a0, a1, 1.4, Color(0.37, 0.24, 0.13, 0.7))
	for sgn in [-1.0, 1.0]:
		var p: Vector2 = Vector2(ax, ay) + (side if not along_z else -side) * 36.0 * sgn + along * 10.0
		PlaceholderArt.poly(img, PackedVector2Array([p + Vector2(-4, 2), p + Vector2(4, 2), p + Vector2(4, -50), p + Vector2(-4, -50)]), BARK.lightened(0.2), BARK, 1.6)
		PlaceholderArt.blob(img, p + Vector2(0, -54), Vector2(6, 6), Color("c9a46a"), 1.6, 1.0)
	return _result(img, Vector2(ax, ay))


static func lantern(hand: bool = false) -> Dictionary:
	var w: int = 64 if hand else 90
	var h: int = 70 if hand else 176
	var img: Image = _img(w, h)
	var ax: float = w * 0.5 if hand else 38.0
	var ay: float = h - 12.0 if hand else 157.0
	if not hand:
		PlaceholderArt.soft_ellipse(img, Vector2(ax, ay), Vector2(20, 7), Color(0.17, 0.14, 0.25, 0.28))
		PlaceholderArt.poly(img, PackedVector2Array([Vector2(ax - 3, ay), Vector2(ax + 3, ay), Vector2(ax + 3, ay - 140), Vector2(ax - 3, ay - 140)]), BARK, BARK.darkened(0.2), 1.6)
	var lamp: Vector2 = Vector2(ax + 16, ay - 128) if not hand else Vector2(ax, ay - 20)
	PlaceholderArt.blob(img, lamp, Vector2(9, 11), Color("fff0c4"), 1.6, 1.4)
	PlaceholderArt.poly(img, PackedVector2Array([lamp + Vector2(-9, -9), lamp + Vector2(9, -9), lamp + Vector2(0, -19)]), Color("5a4660"), Color("3d2f45"), 1.4)
	return _result(img, Vector2(ax, ay), Vector2i(1, 1), {"glow": _halo_entry(lamp, Color("ffd98a"), 184.0)})


static func scarecrow() -> Dictionary:
	var img: Image = _img(122, 189)
	var ax: float = 55.0
	var ay: float = 166.0
	PlaceholderArt.soft_ellipse(img, Vector2(ax, ay), Vector2(26, 9), Color(0.17, 0.14, 0.25, 0.28))
	PlaceholderArt.poly(img, PackedVector2Array([Vector2(ax - 4, ay), Vector2(ax + 4, ay), Vector2(ax + 4, ay - 100), Vector2(ax - 4, ay - 100)]), BARK, BARK.darkened(0.2), 1.6)
	PlaceholderArt.line(img, Vector2(ax - 44, ay - 92), Vector2(ax + 44, ay - 96), 5.0, PlaceholderArt.INK)
	PlaceholderArt.line(img, Vector2(ax - 44, ay - 92), Vector2(ax + 44, ay - 96), 3.0, BARK.lightened(0.2))
	PlaceholderArt.blob(img, Vector2(ax, ay - 80), Vector2(22, 28), Color("8fa6d6"), 1.8, 1.0)
	PlaceholderArt.blob(img, Vector2(ax, ay - 118), Vector2(17, 17), Color("f6d9a8"), 1.8, 1.0)
	PlaceholderArt.blob(img, Vector2(ax, ay - 132), Vector2(30, 8), HONEY, 1.8, 1.0)
	PlaceholderArt.blob(img, Vector2(ax, ay - 140), Vector2(15, 11), HONEY.darkened(0.1), 1.8, 1.0)
	return _result(img, Vector2(ax, ay))


static func signpost() -> Dictionary:
	var img: Image = _img(90, 110)
	var ax: float = 45.0
	var ay: float = 96.0
	PlaceholderArt.soft_ellipse(img, Vector2(ax, ay), Vector2(20, 7), Color(0.17, 0.14, 0.25, 0.28))
	PlaceholderArt.poly(img, PackedVector2Array([Vector2(ax - 4, ay), Vector2(ax + 4, ay), Vector2(ax + 4, ay - 60), Vector2(ax - 4, ay - 60)]), BARK, BARK.darkened(0.2), 1.6)
	PlaceholderArt.poly(img, PackedVector2Array([Vector2(ax - 30, ay - 78), Vector2(ax + 28, ay - 82), Vector2(ax + 34, ay - 66), Vector2(ax - 28, ay - 62)]), Color("d1a468"), Color("b98a52"), 1.6)
	PlaceholderArt.line(img, Vector2(ax - 20, ay - 71), Vector2(ax + 20, ay - 73), 1.6, PlaceholderArt.INK)
	return _result(img, Vector2(ax, ay))


static func warp_gate() -> Dictionary:
	var img: Image = _img(220, 230)
	var ax: float = 110.0
	var ay: float = 202.0
	PlaceholderArt.soft_ellipse(img, Vector2(ax, ay), Vector2(78, 22), Color(0.17, 0.14, 0.25, 0.32))
	PlaceholderArt.poly(img, PackedVector2Array([Vector2(ax - 70, ay), Vector2(ax - 40, ay), Vector2(ax - 44, ay - 120), Vector2(ax - 66, ay - 120)]), Color("c4bad6"), Color("8f7fa6"), 1.6)
	PlaceholderArt.poly(img, PackedVector2Array([Vector2(ax + 40, ay), Vector2(ax + 70, ay), Vector2(ax + 66, ay - 120), Vector2(ax + 44, ay - 120)]), Color("c4bad6"), Color("8f7fa6"), 1.6)
	PlaceholderArt.blob(img, Vector2(ax, ay - 122), Vector2(66, 26), Color("a89cc0"), 1.6, 0.9)
	PlaceholderArt.blob(img, Vector2(ax, ay - 66), Vector2(30, 44), Color(0.30, 0.58, 0.55, 0.9), 1.6, 1.5)
	PlaceholderArt.dot(img, Vector2(ax - 8, ay - 90), 3.0, CREAM)
	return _result(img, Vector2(ax, ay), Vector2i(1, 1), {"glow": _halo_entry(Vector2(ax, ay - 66), TEAL, 120.0)})


static func chest(magic: bool = false) -> Dictionary:
	var img: Image = _img(138, 102)
	var ax: float = 62.0
	var ay: float = 75.0
	PlaceholderArt.soft_ellipse(img, Vector2(ax, ay), Vector2(40, 12), Color(0.17, 0.14, 0.25, 0.28))
	PlaceholderArt.poly(img, PackedVector2Array([Vector2(ax - 36, ay - 6), Vector2(ax, ay + 12), Vector2(ax, ay - 30), Vector2(ax - 36, ay - 44)]), BARK.lightened(0.1), BARK.darkened(0.15), 1.6)
	PlaceholderArt.poly(img, PackedVector2Array([Vector2(ax, ay + 12), Vector2(ax + 36, ay - 6), Vector2(ax + 36, ay - 44), Vector2(ax, ay - 30)]), BARK.lightened(0.25), BARK, 1.6)
	PlaceholderArt.blob(img, Vector2(ax, ay - 34), Vector2(38, 14), HONEY if magic else BARK.lightened(0.3), 1.6, 1.0)
	return _result(img, Vector2(ax, ay))


## An ortho wall cell of the dark forest / the cave: a mass of foliage (or rock) blobs rising `up` px above its floor cell.
## Pivot = the cell centre; `proj: ortho` like the real forest_wall_* props.
static func wall_block(id: String) -> Dictionary:
	var up: int = 70
	var w: int = Iso.ORTHO_W
	var h: int = Iso.ORTHO_H
	var cave: bool = id.begins_with("cave")
	var img: Image = _img(w, h + up)
	var base: Color = Color("2b2f45") if cave else Color("162a22")
	PlaceholderArt.poly(img, PackedVector2Array([Vector2(0, up), Vector2(w, up), Vector2(w, up + h), Vector2(0, up + h)]), base.lightened(0.05), base, 0.0)
	var cols: Array = [Color("3a3a58"), Color("4a4a6c"), Color("5a5a7c"), Color("44445f")] if cave else [Color("24402f"), Color("2f5a46"), Color("3b6b52"), Color("2b4f40")]
	var h01: float = _id_hash(id)
	for i in 7:
		var cx: float = w * (0.15 + 0.7 * PlaceholderArt._hash(float(i) + h01, 3.0))
		var cy: float = up + h * 0.3 + (h * 0.5) * PlaceholderArt._hash(5.0, float(i) + h01) - up * 0.9 * (1.0 - float(i) / 7.0)
		cy = clampf(cy, 20.0, float(h + up) - 10.0)
		var r: float = 20.0 + 14.0 * PlaceholderArt._hash(float(i), 9.0 + h01)
		PlaceholderArt.blob(img, Vector2(cx, cy), Vector2(r * 1.15, r), cols[i % cols.size()], 2.0, 0.6)
	return _result(img, Vector2(w * 0.5, up + h * 0.5), Vector2i(1, 1), {"proj": &"ortho"})


## Platform skirt pieces (R.10): the bark wall under one edge cell. Pivot = the cell centre, exactly like the real props:
## platform_sw 79 x 143 pivot (73, 13), platform_se pivot (6, 13), platform_corner 146 x 146 pivot (73, 13).
static func platform(face: String) -> Dictionary:
	var half_w: int = Iso.TILE_W / 2
	var wall_h: int = 84
	var w: int = 146 if face == "corner" else 79
	var h: int = 146 if face == "corner" else 143
	var img: Image = _img(w, h)
	var piv: Vector2 = Vector2(73, 13) if face != "se" else Vector2(6, 13)
	if face == "sw" or face == "corner":
		_wall_face(img, piv, -1, half_w, wall_h)
	if face == "se" or face == "corner":
		_wall_face(img, piv, 1, half_w, wall_h)
	return _result(img, piv)


## One bark face under the lower-left (side -1) or lower-right (side +1) edge of the diamond centred at `piv`.
static func _wall_face(img: Image, piv: Vector2, side: int, half_w: int, wall_h: int) -> void:
	var half_h: float = Iso.TILE_H * 0.5
	var bark_a: Color = Color("8a5a35") if side < 0 else Color("9a6740")
	var bark_b: Color = Color("6a4426") if side < 0 else Color("7a4e2d")
	var p_bottom := piv + Vector2(0, half_h)
	var p_end := piv + Vector2(float(side) * half_w, 0)
	var pts := PackedVector2Array([p_end, p_bottom, p_bottom + Vector2(0, wall_h), p_end + Vector2(0, wall_h)])
	PlaceholderArt.poly(img, pts, bark_a, bark_b, 1.8)
	for i in 4:
		var t: float = (float(i) + 0.5) / 4.0
		var top: Vector2 = p_bottom.lerp(p_end, t)
		PlaceholderArt.line(img, top + Vector2(0, 6), top + Vector2(0, wall_h - 8), 1.6, Color(0.30, 0.19, 0.10, 0.35))
	var moss_y: float = 8.0
	PlaceholderArt.line(img, p_bottom + Vector2(0, moss_y), p_end + Vector2(0, moss_y), 7.0, Color(0.30, 0.48, 0.16, 0.55))


## House with an iso footprint of fx x fy cells. Pivot = footprint centre (like the real props), so the node sits where the
## art contract says; the sprite is painted around it.
static func house(fx: int, fy: int, id: String = "house") -> Dictionary:
	var h01: float = _id_hash(id)
	var fp: PackedVector2Array = Iso.iso_footprint(Vector2i(fx - 1, fy - 1), fx, fy)
	var centre: Vector2 = (fp[0] + fp[2]) * 0.5
	var wall_h: float = 92.0
	var roof_h: float = 78.0
	var pad: float = 40.0
	var minx: float = 1e9
	var maxx: float = -1e9
	var miny: float = 1e9
	var maxy: float = -1e9
	for p in fp:
		minx = minf(minx, p.x)
		maxx = maxf(maxx, p.x)
		miny = minf(miny, p.y)
		maxy = maxf(maxy, p.y)
	var w: int = int(maxx - minx + pad * 2.0)
	var h: int = int(maxy - miny + wall_h + roof_h + pad * 1.5)
	var off := Vector2(pad - minx, float(h) - pad * 0.6 - maxy)
	var T: Vector2 = fp[0] + off
	var R: Vector2 = fp[1] + off
	var B: Vector2 = fp[2] + off
	var L: Vector2 = fp[3] + off
	var up := Vector2(0, -wall_h)
	var mushroom: bool = id.contains("mushroom")
	var wall_a: Color = Color("d9b98a")
	var wall_b: Color = Color("ecd0a0")
	var roof_a: Color = MOSS
	var roof_b: Color = MOSS_L
	if mushroom:
		var palettes: Array = [[Color("f1d3dd"), Color("f8e4ea"), ROSE, ROSE.lightened(0.2)], [Color("d9d0f0"), Color("e8e2f8"), LAV, LAV.lightened(0.2)], [Color("cfeee6"), Color("e2f6f0"), TEAL, TEAL.lightened(0.2)]]
		var pal: Array = palettes[0 if id.contains("rose") else (1 if id.contains("lavender") else (2 if id.contains("mint") else int(h01 * 3.0) % 3))]
		wall_a = pal[0]
		wall_b = pal[1]
		roof_a = pal[2]
		roof_b = pal[3]
	var img: Image = _img(w, h)
	PlaceholderArt.soft_ellipse(img, (L + R) * 0.5 + Vector2(0, 6), Vector2((R.x - L.x) * 0.62, (B.y - T.y) * 0.55), Color(0.17, 0.14, 0.25, 0.26))
	PlaceholderArt.poly(img, PackedVector2Array([L, B, B + up, L + up]), wall_a, wall_a.darkened(0.14), 1.6)
	PlaceholderArt.poly(img, PackedVector2Array([B, R, R + up, B + up]), wall_b, wall_b.darkened(0.12), 1.6)
	PlaceholderArt.line(img, L + up * 0.5, B + up * 0.5, 3.0, BARK)
	PlaceholderArt.line(img, B + up * 0.5, R + up * 0.5, 3.0, BARK)
	var door_c: Vector2 = B.lerp(R, 0.45) + Vector2(0, -22)
	PlaceholderArt.blob(img, door_c, Vector2(15, 22), Color("8a5a35"), 1.6, 0.5)
	PlaceholderArt.dot(img, door_c + Vector2(6, 2), 1.6, HONEY)
	var win_c: Vector2 = L.lerp(B, 0.5) + Vector2(0, -52)
	PlaceholderArt.blob(img, win_c, Vector2(12, 14), Color("a9d3e0"), 1.6, 1.0)
	var apex: Vector2 = (T + B) * 0.5 + up + Vector2(0, -roof_h)
	var ov: float = 14.0
	var Lr: Vector2 = L + up + Vector2(-ov, ov * 0.2)
	var Br: Vector2 = B + up + Vector2(0, ov * 0.7)
	var Rr: Vector2 = R + up + Vector2(ov, ov * 0.2)
	PlaceholderArt.poly(img, PackedVector2Array([Lr, Br, apex]), roof_a.lightened(0.05), roof_a.darkened(0.2), 1.6)
	PlaceholderArt.poly(img, PackedVector2Array([Br, Rr, apex]), roof_b, roof_a, 1.6)
	var chim: Vector2 = apex.lerp(Rr, 0.35) + Vector2(0, -6)
	PlaceholderArt.poly(img, PackedVector2Array([chim + Vector2(-7, 6), chim + Vector2(7, 6), chim + Vector2(7, -24), chim + Vector2(-7, -24)]), Color("b0a0c0"), Color("8f7fa6"), 1.6)
	return _result(img, centre + off, Vector2i(fx, fy), {"glow": _halo_entry(win_c, Color("ffd98a"), 80.0)})


## Coloured block / boulder of any id: the fallback for ids with no painter (the colour comes from the id, so two unknown
## props can be told apart on a screenshot).
static func generic(id: String) -> Dictionary:
	var h01: float = _id_hash(id)
	var col: Color = Color.from_hsv(h01, 0.28, 0.78)
	var img: Image = _img(110, 110)
	var ax: float = 55.0
	var ay: float = 88.0
	PlaceholderArt.soft_ellipse(img, Vector2(ax, ay), Vector2(34, 11), Color(0.17, 0.14, 0.25, 0.28))
	PlaceholderArt.blob(img, Vector2(ax, ay - 30), Vector2(28, 30), col, 1.8, 1.0)
	PlaceholderArt.blob(img, Vector2(ax + 8, ay - 52), Vector2(14, 12), col.lightened(0.2), 1.6, 1.0)
	return _result(img, Vector2(ax, ay))


# ----------------------------------------------------------------------------- crops, orbs, icons

## Crop sprite: stage 0..3 (the art spike has four stages; 0 = seed mound). Pivot = soil centre.
static func crop(crop_id: String, stage: int) -> Dictionary:
	var img: Image = _img(84, 96)
	var ax: float = 42.0
	var ay: float = 72.0
	var fruit: Color = Color("c47ad6")
	var leaf: Color = MOSS
	match crop_id:
		"turnip": fruit = Color("d9a0e0")
		"carrot": fruit = Color("e8863a")
		"pumpkin": fruit = Color("e8863a")
		"moonflower": fruit = Color("b9c3e3")
		"strawberry": fruit = Color("d9506b")
		"sunflower": fruit = Color("f2c14e")
		"catnip": fruit = Color("b7a3ec")
	stage = clampi(stage, 0, 3)
	if stage == 0:
		PlaceholderArt.blob(img, Vector2(ax, ay - 4), Vector2(11, 6), Color("5a3a22"), 1.5, 0.4)
		return _result(img, Vector2(ax, ay))
	var hgt: float = 14.0 + 14.0 * float(stage)
	var ns: int = 2 + stage
	for i in ns:
		var a: float = -0.9 + 1.8 * float(i) / float(maxi(ns - 1, 1))
		var tip := Vector2(ax + sin(a) * (10.0 + 4.0 * stage), ay - 6.0 - hgt * cos(a * 0.5))
		var base := Vector2(ax + sin(a) * 2.0, ay - 4.0)
		PlaceholderArt.line(img, base, tip, 5.0, PlaceholderArt.INK)
		PlaceholderArt.line(img, base, tip, 2.6, leaf.lightened(0.1 * float(i % 2)))
		PlaceholderArt.blob(img, tip, Vector2(5.0 + stage, 3.5 + stage * 0.7), leaf.lightened(0.15), 1.5, 0.8)
	if stage >= 2:
		var fr: float = 7.0 + 3.0 * float(stage - 1)
		if crop_id == "moonflower" or crop_id == "sunflower":
			PlaceholderArt.blob(img, Vector2(ax, ay - hgt - 8), Vector2(fr, fr), fruit, 1.6)
			PlaceholderArt.dot(img, Vector2(ax, ay - hgt - 8), 3.0, HONEY)
		elif crop_id == "pumpkin":
			PlaceholderArt.blob(img, Vector2(ax + 4, ay - 10), Vector2(fr + 4, fr + 1), fruit, 1.6)
		else:
			PlaceholderArt.blob(img, Vector2(ax, ay - 8), Vector2(fr * 0.8, fr), fruit, 1.6)
	var extra: Dictionary = {}
	if crop_id == "moonflower" and stage >= 3:
		extra["glow"] = _halo_entry(Vector2(ax, ay - hgt - 8), Color("cfe0ff"), 104.0)
	return _result(img, Vector2(ax, ay), Vector2i(1, 1), extra)


## Soft glowing orb used for loot drops (colour per item).
static func orb(col: Color) -> Dictionary:
	var img: Image = PlaceholderArt.new_image(48, 48)
	PlaceholderArt.soft_ellipse(img, Vector2(24, 24), Vector2(22, 22), Color(col.r, col.g, col.b, 0.35))
	PlaceholderArt.blob(img, Vector2(24, 24), Vector2(10, 10), col, 1.6, 1.4)
	PlaceholderArt.dot(img, Vector2(20, 20), 2.2, Color(1, 1, 1, 0.9))
	return _result(img, Vector2(24, 24))


static func shadow_blob(w: int = 96, h: int = 36, a: float = 0.32) -> ImageTexture:
	var img: Image = PlaceholderArt.new_image(w, h)
	PlaceholderArt.soft_ellipse(img, Vector2(w * 0.5, h * 0.5), Vector2(w * 0.5 - 1, h * 0.5 - 1), Color(0.17, 0.14, 0.25, a))
	return PlaceholderArt.tex(img)


## Round badge of an item id (the fallback of ArtCatalog.icon): a coloured disc with ink outline, 128 x 128.
static func icon_badge(id: String) -> ImageTexture:
	var h01: float = _id_hash(id)
	var img: Image = PlaceholderArt.new_image(128, 128, 0.5)
	PlaceholderArt.blob(img, Vector2(64, 64), Vector2(48, 48), Color.from_hsv(h01, 0.32, 0.86), 2.0, 1.0)
	PlaceholderArt.blob(img, Vector2(48, 46), Vector2(14, 12), Color(1, 1, 1, 0.55), 0.0, 0.0)
	return PlaceholderArt.tex(img)


## Bust of a character id (the fallback of ArtCatalog.portrait): a soft face disc on a shoulder blob, 256 x 256.
static func portrait_badge(id: String) -> ImageTexture:
	var h01: float = _id_hash(id)
	var img: Image = PlaceholderArt.new_image(256, 256, 0.35)
	var body: Color = Color.from_hsv(h01, 0.35, 0.80)
	PlaceholderArt.blob(img, Vector2(128, 230), Vector2(92, 66), body.darkened(0.1), 2.5, 0.8)
	PlaceholderArt.blob(img, Vector2(128, 120), Vector2(70, 66), body, 2.5, 1.0)
	PlaceholderArt.dot(img, Vector2(104, 112), 7.0, Color("2b2340"))
	PlaceholderArt.dot(img, Vector2(152, 112), 7.0, Color("2b2340"))
	return PlaceholderArt.tex(img)


## Far canopy haze seen below the treetop platform (the fallback of ArtCatalog.backdrop(theme)["far"]): painted at 128 x 128
## and shown scaled up, so it is a soft haze; the blobs are wrapped, so the texture tiles seamlessly in both axes.
static func canopy_far(top: Color, bottom: Color, mist: Color) -> ImageTexture:
	var w: int = 256
	var h: int = 512   # twice as tall as wide: the haze must reach the bottom of the screen at the widest zoom-out
	var img: Image = PlaceholderArt.new_image(w, h, 0.25)
	for i in 92:
		var cx: float = w * PlaceholderArt._hash(float(i), 1.3)
		var cy: float = h * PlaceholderArt._hash(7.1, float(i))
		var r: float = 12.0 + 20.0 * PlaceholderArt._hash(float(i), 5.5)
		var g: Color = top.lerp(bottom, PlaceholderArt._hash(float(i), 9.9))
		if PlaceholderArt._hash(float(i), 3.3) > 0.72:
			g = mist
		for ox in [-w, 0, w]:
			if cx + ox + r * 1.3 < 0.0 or cx + ox - r * 1.3 > float(w):
				continue
			for oy in [-h, 0, h]:
				if cy + oy + r * 0.8 < 0.0 or cy + oy - r * 0.8 > float(h):
					continue
				PlaceholderArt.soft_ellipse(img, Vector2(cx + ox, cy + oy), Vector2(r * 1.3, r * 0.8), Color(g.r, g.g, g.b, 0.42))
	# the canopy fades in from the top: the sky stays visible above the treetops (the layer repeats horizontally only)
	var bh: int = img.get_height()
	for y in bh:
		var ramp: float = smoothstep(0.0, 0.3, float(y) / float(bh))
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			c.a *= ramp
			img.set_pixel(x, y, c)
	# mirrored copy to the right: the left and right edge columns are then the SAME column, so the repeat has no seam
	var one: Image = PlaceholderArt.finish(img)
	var both: Image = Image.create_empty(one.get_width() * 2, one.get_height(), false, Image.FORMAT_RGBA8)
	var flipped: Image = one.duplicate() as Image
	flipped.flip_x()
	both.blit_rect(one, Rect2i(0, 0, one.get_width(), one.get_height()), Vector2i(0, 0))
	both.blit_rect(flipped, Rect2i(0, 0, one.get_width(), one.get_height()), Vector2i(one.get_width(), 0))
	return ImageTexture.create_from_image(both)


# ----------------------------------------------------------------------------- shared

## A glow entry in the shape of props.json ("glow": {file, center, color, size, blend}) for a placeholder: `texture` replaces `file`.
static func _halo_entry(center: Vector2, col: Color, size_px: float) -> Dictionary:
	return {"texture": Glow.halo_texture(), "center": center, "color": col, "size": Vector2(size_px, size_px), "blend": "add"}
