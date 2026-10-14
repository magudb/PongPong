class_name PlaceholderArt
extends RefCounted
## Runtime-generated PLACEHOLDER art (no external files, not pixel art): analytic anti-aliased shapes, soft noise mottling,
## a 2 px ink outline everywhere (style guide rule "Blaek omkring alt"). ArtCatalog falls back to these painters whenever a
## terrain / prop has no real asset (decision D18): missing keys never crash and never warn, the id is recorded in
## ArtCatalog.missing(), and the real art drops in later without a code change.
##
## COST (the spike measured 0.65 s of boot): everything is painted LAZILY (only what an area asks for), CACHED by ArtCatalog,
## and painted on a SCALED CANVAS: new_image() allocates a buffer of QUALITY x the design size and every primitive takes design
## coordinates, scales them itself, and finish() resizes the result back to the design size (bilinear = a soft painted look,
## a quarter of the pixels). Painters therefore keep thinking in design pixels (the pivots, sizes and footprints they report
## are exactly those of the real art contract 6.2).
##
## Terrain ids are the art-spike catalogue ids of plan 6.2 (grass, grass_flowers, ..., water_0..3, ortho ids forest_floor_o ...).

const INK := Color(0.29, 0.21, 0.25, 0.86)   # warm plum pencil, legible against the night palette
const LIGHT_DIR := Vector3(-0.45, -0.70, 0.55)
## Painting resolution as a fraction of the design size (1.0 = full size, slow).
const QUALITY := 0.4
## Terrains are smooth noise: painted at a quarter of the resolution.
const TERRAIN_QUALITY := 0.25

## Tests only: paint at full resolution (what the world spike did) to measure how much the scaled canvas saves.
static var full_quality: bool = false

const META_K := &"pa_k"
const META_W := &"pa_w"
const META_H := &"pa_h"


# ----------------------------------------------------------------------------- maths helpers

static func _hash(x: float, y: float) -> float:
	return fposmod(sin(x * 12.9898 + y * 78.233) * 43758.5453, 1.0)


static func _vnoise(x: float, y: float) -> float:
	var xi: float = floorf(x)
	var yi: float = floorf(y)
	var xf: float = x - xi
	var yf: float = y - yi
	var u: float = xf * xf * (3.0 - 2.0 * xf)
	var v: float = yf * yf * (3.0 - 2.0 * yf)
	var a: float = _hash(xi, yi)
	var b: float = _hash(xi + 1.0, yi)
	var c: float = _hash(xi, yi + 1.0)
	var d: float = _hash(xi + 1.0, yi + 1.0)
	return lerpf(lerpf(a, b, u), lerpf(c, d, u), v)


static func _put(img: Image, x: int, y: int, r: float, g: float, b: float, a: float) -> void:
	## Straight-alpha "over" of one source pixel (inputs are inside the image: callers clamp their loops).
	var d: Color = img.get_pixel(x, y)
	if d.a <= 0.0001:
		img.set_pixel(x, y, Color(r, g, b, a))
		return
	var oa: float = a + d.a * (1.0 - a)
	var k: float = d.a * (1.0 - a)
	img.set_pixel(x, y, Color((r * a + d.r * k) / oa, (g * a + d.g * k) / oa, (b * a + d.b * k) / oa, oa))


static func _blend_px(img: Image, x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height() or c.a <= 0.0:
		return
	_put(img, x, y, c.r, c.g, c.b, c.a)


# ----------------------------------------------------------------------------- the scaled canvas

## A transparent canvas of `w` x `h` DESIGN pixels, stored at `quality` x that size. Primitives take design coordinates.
static func new_image(w: int, h: int, quality: float = QUALITY) -> Image:
	var k: float = 1.0 if full_quality else clampf(quality, 0.1, 1.0)
	var img: Image = Image.create_empty(maxi(int(round(w * k)), 1), maxi(int(round(h * k)), 1), false, Image.FORMAT_RGBA8)
	img.set_meta(META_K, k)
	img.set_meta(META_W, w)
	img.set_meta(META_H, h)
	return img


static func k_of(img: Image) -> float:
	return float(img.get_meta(META_K, 1.0))


## The finished image at design size (a plain Image without bookkeeping is returned unchanged).
static func finish(img: Image) -> Image:
	if not img.has_meta(META_W):
		return img
	var w: int = int(img.get_meta(META_W))
	var h: int = int(img.get_meta(META_H))
	if img.get_width() != w or img.get_height() != h:
		img.resize(w, h, Image.INTERPOLATE_BILINEAR)
	img.remove_meta(META_K)
	img.remove_meta(META_W)
	img.remove_meta(META_H)
	img.fix_alpha_edges()   # colour of the transparent texels next to the figure, like the importer's fix_alpha_border (no dark halo)
	return img


static func tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(finish(img))


static func transparent_texture(w: int, h: int) -> ImageTexture:
	return ImageTexture.create_from_image(Image.create_empty(w, h, false, Image.FORMAT_RGBA8))


# ----------------------------------------------------------------------------- AA primitives (ink-outlined, design coordinates)

## Shaded ellipse "blob" with an ink outline of `ink` px (outside the ellipse), top-left light.
static func blob(img: Image, c: Vector2, r: Vector2, col: Color, ink: float = 2.0, glow: float = 1.0) -> void:
	var k: float = k_of(img)
	var cx: float = c.x * k
	var cy: float = c.y * k
	var rx: float = maxf(r.x * k, 0.5)
	var ry: float = maxf(r.y * k, 0.5)
	var ik: float = ink * k
	var x0: int = maxi(int(floorf(cx - rx - ik - 2.0)), 0)
	var x1: int = mini(int(ceilf(cx + rx + ik + 2.0)), img.get_width() - 1)
	var y0: int = maxi(int(floorf(cy - ry - ik - 2.0)), 0)
	var y1: int = mini(int(ceilf(cy + ry + ik + 2.0)), img.get_height() - 1)
	var rm: float = minf(rx, ry)
	var dark: Color = col.darkened(0.18)
	var lit: Color = col.lightened(0.12 * glow)
	var dr: float = col.r - dark.r
	var dg: float = col.g - dark.g
	var db: float = col.b - dark.b
	for y in range(y0, y1 + 1):
		var ny: float = (y + 0.5 - cy) / ry
		for x in range(x0, x1 + 1):
			var nx: float = (x + 0.5 - cx) / rx
			var len2: float = nx * nx + ny * ny
			var len: float = sqrt(len2)
			# A fixed, slight wandering edge keeps the illustrator's hand in every shape.
			var d: float = (len - 1.0) * rm + sin(nx * 8.0 + ny * 5.0) * k * 0.55
			var a_out: float = clampf(0.5 - (d - ik), 0.0, 1.0)
			if a_out <= 0.0:
				continue
			_put(img, x, y, INK.r, INK.g, INK.b, a_out * INK.a)
			var a_in: float = clampf(0.5 - d, 0.0, 1.0)
			if a_in <= 0.0:
				continue
			# Broad gouache washes instead of spherical specular shading.
			var diff: float = clampf(0.62 - nx * 0.16 - ny * 0.22, 0.0, 1.0)
			var t1: float = smoothstep(0.15, 0.55, diff)
			var t2: float = smoothstep(0.66, 0.84, diff)
			var grain: float = (_hash(float(x), float(y)) - 0.5) * 0.045
			var rr: float = dark.r + dr * t1
			var gg: float = dark.g + dg * t1
			var bb: float = dark.b + db * t1
			_put(img, x, y, rr + (lit.r - rr) * t2 + grain, gg + (lit.g - gg) * t2 + grain, bb + (lit.b - bb) * t2 + grain, a_in)


static func soft_ellipse(img: Image, c: Vector2, r: Vector2, col: Color) -> void:
	var k: float = k_of(img)
	var cx: float = c.x * k
	var cy: float = c.y * k
	var rx: float = maxf(r.x * k, 0.5)
	var ry: float = maxf(r.y * k, 0.5)
	var x0: int = maxi(int(floorf(cx - rx - 1.0)), 0)
	var x1: int = mini(int(ceilf(cx + rx + 1.0)), img.get_width() - 1)
	var y0: int = maxi(int(floorf(cy - ry - 1.0)), 0)
	var y1: int = mini(int(ceilf(cy + ry + 1.0)), img.get_height() - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var nx: float = (x + 0.5 - cx) / rx
			var ny: float = (y + 0.5 - cy) / ry
			var a: float = (1.0 - smoothstep(0.35, 1.0, sqrt(nx * nx + ny * ny))) * col.a
			if a > 0.0:
				_blend_px(img, x, y, Color(col.r, col.g, col.b, a))


static func _dist_to_poly(p: Vector2, pts: PackedVector2Array) -> float:
	## Signed distance, negative inside (convex or concave simple polygon).
	var n: int = pts.size()
	var dmin: float = 1e9
	var inside: bool = false
	var j: int = n - 1
	for i in n:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[j]
		var e: Vector2 = b - a
		var w: Vector2 = p - a
		var t: float = clampf(w.dot(e) / maxf(e.length_squared(), 0.0001), 0.0, 1.0)
		dmin = minf(dmin, (w - e * t).length())
		if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		j = i
	return -dmin if inside else dmin


## Filled polygon with vertical gradient top->bottom, AA edge and ink outline (drawn outside by `ink` px). Convex polygons (every
## wall, roof and plank of the painters) take a fast path of half-plane distances; concave ones use the exact point-to-polygon distance.
static func poly(img: Image, pts_design: PackedVector2Array, col_top: Color, col_bot: Color, ink: float = 2.0, ink_col: Color = INK) -> void:
	var k: float = k_of(img)
	var pts := PackedVector2Array()
	for p in pts_design:
		pts.append(p * k)
	var n: int = pts.size()
	var ik: float = ink * k
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for p in pts:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.y))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.y))
	var x0: int = maxi(int(floorf(mn.x - ik - 2.0)), 0)
	var x1: int = mini(int(ceilf(mx.x + ik + 2.0)), img.get_width() - 1)
	var y0: int = maxi(int(floorf(mn.y - ik - 2.0)), 0)
	var y1: int = mini(int(ceilf(mx.y + ik + 2.0)), img.get_height() - 1)
	var hspan: float = maxf(mx.y - mn.y, 1.0)
	# half-plane form (outward unit normal + offset per edge) when the polygon is convex
	var area2: float = 0.0
	for i in n:
		var a0: Vector2 = pts[i]
		var b0: Vector2 = pts[(i + 1) % n]
		area2 += a0.x * b0.y - b0.x * a0.y
	var sgn: float = 1.0 if area2 >= 0.0 else -1.0
	var convex: bool = true
	var nxs := PackedFloat32Array()
	var nys := PackedFloat32Array()
	var cs := PackedFloat32Array()
	for i in n:
		var a1: Vector2 = pts[i]
		var b1: Vector2 = pts[(i + 1) % n]
		var c1: Vector2 = pts[(i + 2) % n]
		var e: Vector2 = b1 - a1
		if (e.x * (c1.y - b1.y) - e.y * (c1.x - b1.x)) * sgn < -0.0001:
			convex = false
			break
		var len: float = maxf(e.length(), 0.0001)
		# outward normal of a polygon with positive signed area (y down, "clockwise" on screen): (e.y, -e.x) / len, flipped by sgn
		var nx: float = e.y / len * sgn
		var ny: float = -e.x / len * sgn
		nxs.append(nx)
		nys.append(ny)
		cs.append(nx * a1.x + ny * a1.y)
	for y in range(y0, y1 + 1):
		var py: float = y + 0.5
		var tcol: float = 0.25 + 0.5 * clampf((py - mn.y) / hspan, 0.0, 1.0)
		var c_row: Color = col_top.lerp(col_bot, tcol)
		for x in range(x0, x1 + 1):
			var px: float = x + 0.5
			var d: float = -1e9
			if convex:
				for i in n:
					d = maxf(d, nxs[i] * px + nys[i] * py - cs[i])
			else:
				d = _dist_to_poly(Vector2(px, py), pts)
			d += sin(px * 0.62 + py * 0.31) * k * 0.4
			var a_out: float = clampf(0.5 - (d - ik), 0.0, 1.0)
			if a_out <= 0.0:
				continue
			if ink > 0.0:
				_put(img, x, y, ink_col.r, ink_col.g, ink_col.b, a_out * ink_col.a)
			var a_in: float = clampf(0.5 - d, 0.0, 1.0)
			if a_in > 0.0:
				var grain: float = (_hash(px, py) - 0.5) * 0.04
				_put(img, x, y, c_row.r + grain, c_row.g + grain, c_row.b + grain, a_in)


static func line(img: Image, p0_design: Vector2, p1_design: Vector2, width: float, c: Color) -> void:
	var k: float = k_of(img)
	var p0: Vector2 = p0_design * k
	var p1: Vector2 = p1_design * k
	var wk: float = maxf(width * k, 0.6)
	var minp := Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)) - Vector2.ONE * (wk + 1.0)
	var maxp := Vector2(maxf(p0.x, p1.x), maxf(p0.y, p1.y)) + Vector2.ONE * (wk + 1.0)
	var seg: Vector2 = p1 - p0
	var l2: float = maxf(seg.length_squared(), 0.0001)
	var normal: Vector2 = Vector2(-seg.y, seg.x).normalized()
	for y in range(maxi(int(minp.y), 0), mini(int(maxp.y) + 1, img.get_height())):
		for x in range(maxi(int(minp.x), 0), mini(int(maxp.x) + 1, img.get_width())):
			var p := Vector2(x + 0.5, y + 0.5)
			var t: float = clampf((p - p0).dot(seg) / l2, 0.0, 1.0)
			var wander: float = sin(t * TAU * 1.4 + p0.x * 0.07) * sin(t * PI) * 0.8 * k
			var pressure: float = 0.85 + 0.15 * sin(t * PI)
			var d: float = p.distance_to(p0 + seg * t + normal * wander) - wk * pressure * 0.5
			var al: float = clampf(0.5 - d, 0.0, 1.0)
			if al > 0.0:
				_blend_px(img, x, y, Color(c.r, c.g, c.b, c.a * al))


static func dot(img: Image, c_design: Vector2, r: float, col: Color) -> void:
	var k: float = k_of(img)
	var c: Vector2 = c_design * k
	var rk: float = maxf(r * k, 0.45)
	var x0: int = maxi(int(floorf(c.x - rk - 1.0)), 0)
	var x1: int = mini(int(ceilf(c.x + rk + 1.0)), img.get_width() - 1)
	var y0: int = maxi(int(floorf(c.y - rk - 1.0)), 0)
	var y1: int = mini(int(ceilf(c.y + rk + 1.0)), img.get_height() - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var d: float = Vector2(x + 0.5 - c.x, y + 0.5 - c.y).length() - rk
			var al: float = clampf(0.5 - d, 0.0, 1.0)
			if al > 0.0:
				_blend_px(img, x, y, Color(col.r, col.g, col.b, col.a * al))


# ----------------------------------------------------------------------------- terrain

## Terrain id -> painter parameters. Palette: the guide's zone swatches (moss #6b9a3e, honey #e8b04a, bark #7a4e2d,
## lavender #9b86d6, rose #e58fa6, night blue #1c2138, mushroom light #6fd6c4).
const TERRAIN := {
	# iso terrains (asset contract 6.2)
	&"grass": {"style": "grass", "c0": Color("9bc468"), "c1": Color("b6d97c"), "seed": 1.0},
	&"grass_flowers": {"style": "grass", "c0": Color("a3cb6e"), "c1": Color("bdde83"), "seed": 2.0, "flower": Color("fbf5e6")},
	&"grass_hyggebyen": {"style": "grass", "c0": Color("a7d8b4"), "c1": Color("c2e7c9"), "seed": 3.0},
	&"grass_hyggebyen_flowers": {"style": "grass", "c0": Color("a3d4b0"), "c1": Color("bfe4c7"), "seed": 4.0, "flower": Color("e58fa6")},
	&"soil_tilled": {"style": "soil", "c0": Color("7a4e2d"), "c1": Color("8f5f3a"), "seed": 6.0},
	&"soil_watered": {"style": "soil", "c0": Color("56391f"), "c1": Color("694628"), "seed": 7.0},
	&"path_dirt": {"style": "path", "c0": Color("d9c08c"), "c1": Color("e8d3a4"), "seed": 5.0},
	&"deck_farm": {"style": "plank", "c0": Color("b98a52"), "c1": Color("d1a468"), "seed": 9.0},
	&"deck_hyggebyen": {"style": "plank", "c0": Color("d8c4ee"), "c1": Color("ebdff8"), "seed": 12.0},
	&"cobble_hyggebyen": {"style": "cobble", "c0": Color("c9bfe0"), "c1": Color("ded6f0"), "seed": 10.0},
	&"forest_floor": {"style": "moss", "c0": Color("2f4a3f"), "c1": Color("3b5b4b"), "seed": 11.0},
	&"forest_floor_glow": {"style": "glowpath", "c0": Color("3d6a63"), "c1": Color("5fa597"), "seed": 14.0},
	&"void_haze": {"style": "haze", "c0": Color("cfe3ee"), "c1": Color("e4f0f6"), "seed": 17.0},
	&"water_0": {"style": "water", "c0": Color("7ec1d8"), "c1": Color("a9d3e0"), "seed": 8.0, "phase": 0.0},
	&"water_1": {"style": "water", "c0": Color("7ec1d8"), "c1": Color("a9d3e0"), "seed": 8.0, "phase": 1.0},
	&"water_2": {"style": "water", "c0": Color("7ec1d8"), "c1": Color("a9d3e0"), "seed": 8.0, "phase": 2.0},
	&"water_3": {"style": "water", "c0": Color("7ec1d8"), "c1": Color("a9d3e0"), "seed": 8.0, "phase": 3.0},
	# interior floors of the home (A1 art)
	&"floor_stone": {"style": "cobble", "c0": Color("b4aab8"), "c1": Color("cdc4d0"), "seed": 21.0},
	&"floor_plank": {"style": "plank", "c0": Color("c79b64"), "c1": Color("dcb47c"), "seed": 22.0},
	&"floor_parquet": {"style": "plank", "c0": Color("a8743f"), "c1": Color("c28a52"), "seed": 23.0},
	&"floor_marble": {"style": "path", "c0": Color("e6e2ee"), "c1": Color("f6f2fa"), "seed": 24.0},
	# ortho terrains (plan 6.3: forest_floor_o ... saved as ortho_*.png)
	&"forest_floor_o": {"style": "moss", "c0": Color("2f4a3f"), "c1": Color("3b5b4b"), "seed": 31.0, "rect": true},
	&"forest_floor_glow_o": {"style": "glowpath", "c0": Color("3d6a63"), "c1": Color("5fa597"), "seed": 32.0, "rect": true},
	&"moss_path_o": {"style": "path", "c0": Color("4d6a52"), "c1": Color("6c8a68"), "seed": 33.0, "rect": true},
	&"bog_o": {"style": "bog", "c0": Color("1c2b33"), "c1": Color("2d4a52"), "seed": 34.0, "rect": true},
	&"cave_floor_o": {"style": "moss", "c0": Color("3a3550"), "c1": Color("4b4666"), "seed": 35.0, "rect": true},
	&"crystal_floor_o": {"style": "glowpath", "c0": Color("46407a"), "c1": Color("7f77c4"), "seed": 36.0, "rect": true},
	&"wall_void_o": {"style": "canopy", "c0": Color("162a22"), "c1": Color("1f3a31"), "seed": 37.0, "rect": true},
}

## Terrain ids with an ortho (rectangular) tile.
static func is_ortho_terrain(id: StringName) -> bool:
	return bool((TERRAIN.get(id, {}) as Dictionary).get("rect", false))


static func has_terrain(id: StringName) -> bool:
	return TERRAIN.has(id)


static func _diamond_alpha(px: float, py: float, a: float, b: float, grow: float) -> float:
	var d: float = absf(px - a) / a + absf(py - b) / b
	var kk: float = 1.0 / sqrt(1.0 / (a * a) + 1.0 / (b * b))
	return clampf((1.0 - d) * kk + 0.5 + grow, 0.0, 1.0)


static var _diamond_masks: Dictionary = {}


## Cached alpha mask of the overscanned diamond of a cell `w` x `h` (the diamond itself is Iso.TILE_W x Iso.TILE_H). Built by spans:
## the inside of every row is one fill_rect, only the soft edge pixels are computed one by one.
static func diamond_mask(w: int, h: int) -> Image:
	var key: String = "%dx%d" % [w, h]
	if _diamond_masks.has(key):
		return _diamond_masks[key]
	var m: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var a: float = Iso.TILE_W * 0.5
	var b: float = Iso.TILE_H * 0.5
	var ox: float = (w - Iso.TILE_W) * 0.5
	var oy: float = (h - Iso.TILE_H) * 0.5
	for y in h:
		var py: float = y + 0.5 - oy
		# |px - a| / a + |py - b| / b <= 1 - (0.5 - 1.4 - ...) : the alpha is 1 where (1 - d) * kk + 1.9 >= 1, so the soft edge is a few px wide
		var half: float = a * (1.0 - absf(py - b) / b)
		var x_in0: int = int(ceilf(ox + a - half + 3.0))
		var x_in1: int = int(floorf(ox + a + half - 3.0))
		if x_in1 >= x_in0:
			m.fill_rect(Rect2i(x_in0, y, x_in1 - x_in0 + 1, 1), Color(1, 1, 1, 1))
		var x_lo: int = maxi(int(floorf(ox + a - half - 4.0)), 0)
		var x_hi: int = mini(int(ceilf(ox + a + half + 4.0)), w - 1)
		for x in range(x_lo, x_hi + 1):
			if x >= x_in0 and x <= x_in1:
				continue
			var al: float = _diamond_alpha(x + 0.5 - ox, py, a, b, 1.4)
			if al > 0.0:
				m.set_pixel(x, y, Color(1, 1, 1, al))
	_diamond_masks[key] = m
	return m


## Value noise that WRAPS with period `n` in both lattice coordinates, so a texture built from it tiles seamlessly across the cell
## lattice of the floor (the diamond lattice of iso tiles, the plain grid of ortho tiles).
static func _pnoise(s: float, t: float, n: int, sd: float) -> float:
	var x: float = s * float(n)
	var y: float = t * float(n)
	var xi: float = floorf(x)
	var yi: float = floorf(y)
	var xf: float = x - xi
	var yf: float = y - yi
	var u: float = xf * xf * (3.0 - 2.0 * xf)
	var v: float = yf * yf * (3.0 - 2.0 * yf)
	var x0: float = float(posmod(int(xi), n))
	var x1: float = float(posmod(int(xi) + 1, n))
	var y0: float = float(posmod(int(yi), n))
	var y1: float = float(posmod(int(yi) + 1, n))
	return lerpf(lerpf(_hash(x0 + sd * 13.0, y0), _hash(x1 + sd * 13.0, y0), u), lerpf(_hash(x0 + sd * 13.0, y1), _hash(x1 + sd * 13.0, y1), u), v)


## Colour of a terrain at lattice coordinates (s, t): both are periodic with period 1 per tile, so every cell of an atlas is identical
## AND neighbouring tiles meet without a visible step (the windowed filter_seams probe). `phase` animates the water frames.
static func _surface(style: String, s: float, t: float, c0: Color, c1: Color, sd: float, phase: float) -> Color:
	var m: float = 0.5
	match style:
		"grass", "moss":
			m = _pnoise(s, t, 3, sd) * 0.65 + _pnoise(s, t, 8, sd + 1.0) * 0.35
		"path", "glowpath", "haze":
			m = _pnoise(s, t, 4, sd) * 0.6 + _pnoise(s, t, 11, sd + 2.0) * 0.4
		"soil":
			var fur: float = 0.5 + 0.5 * sin(TAU * s * 6.0 + 1.0)
			m = clampf(fur * 0.75 + _pnoise(s, t, 9, sd) * 0.35, 0.0, 1.0)
		"water", "bog":
			var wv: float = 0.5 + 0.5 * sin(TAU * (s * 2.0 + 0.25 * phase) + sin(TAU * t) * 0.9)
			m = clampf(_pnoise(s, t, 3, sd) * 0.55 + wv * 0.4, 0.0, 1.0)
		"plank":
			var across: float = t * 6.0
			var pi_: float = floorf(across)
			var pf: float = across - pi_
			m = clampf(0.35 + 0.4 * _hash(float(posmod(int(pi_), 6)), sd) + 0.12 * (0.5 + 0.5 * sin(TAU * s * 3.0 + pi_)), 0.0, 1.0)
			var col_p: Color = c0.lerp(c1, m)
			if pf < 0.07 or pf > 0.93:
				col_p = col_p.darkened(0.45)
			return col_p
		"cobble":
			var gs: float = s * 3.0
			var gt: float = t * 3.0
			var row: float = floorf(gt)
			var shifted: float = gs + 0.5 * fmod(row, 2.0)
			var ci: float = floorf(shifted)
			m = _hash(float(posmod(int(ci), 3)), float(posmod(int(row), 3)) + sd)
			var col_c: Color = c0.lerp(c1, m)
			var fx: float = shifted - ci
			var fy: float = gt - row
			var edge: float = minf(minf(fx, 1.0 - fx) * 1.3, minf(fy, 1.0 - fy))
			return col_c.darkened(0.22 * (1.0 - smoothstep(0.03, 0.14, edge)))
		"canopy":
			m = _pnoise(s, t, 5, sd) * 0.7 + _pnoise(s, t, 12, sd + 3.0) * 0.3
	return c0.lerp(c1, m)


## One painted cell of a terrain (design size w x h, alpha 0 outside the overscanned diamond for iso terrains).
static func paint_cell(id: StringName, w: int, h: int, variant: int = 0) -> Image:
	var def: Dictionary = TERRAIN.get(id, TERRAIN[&"grass"])
	var style: String = def["style"]
	var c0: Color = def["c0"]
	var c1: Color = def["c1"]
	var sd: float = float(def["seed"]) + 5.7 * float(variant)
	var rect: bool = bool(def.get("rect", false))
	var phase: float = float(def.get("phase", 0.0))
	var img: Image = new_image(w, h, TERRAIN_QUALITY)
	var k: float = k_of(img)
	var bw: int = img.get_width()
	var bh: int = img.get_height()
	var inv: float = 1.0 / k
	# lattice coordinates: the diamond of an iso cell sits centred in the (overscanned) cell; ortho tiles are plain rectangles
	var tw: float = float(Iso.ORTHO_W) if rect else float(Iso.TILE_W)
	var th: float = float(Iso.ORTHO_H) if rect else float(Iso.TILE_H)
	var ox: float = (w - tw) * 0.5
	var oy: float = (h - th) * 0.5
	for y in bh:
		var dy: float = (y + 0.5) * inv - oy
		for x in bw:
			var dx: float = (x + 0.5) * inv - ox
			var ls: float
			var lt: float
			if rect:
				ls = dx / tw
				lt = dy / th
			else:
				var qa: float = dx / (tw * 0.5)
				var qb: float = dy / (th * 0.5)
				ls = (qa + qb) * 0.5
				lt = (qa - qb) * 0.5
			var col: Color = _surface(style, ls, lt, c0, c1, sd, phase)
			if style == "haze":
				col.a = 0.55
			img.set_pixel(x, y, col)
	# soft decoration painted on the canvas; the diamond clip comes afterwards, so nothing needs to stay inside
	var a: float = w * 0.5
	var b: float = h * 0.5
	match style:
		"grass":
			for i in 5:
				var rx: float = 24.0 + _hash(sd, float(i) * 3.1) * (w - 48.0)
				var ry: float = 12.0 + _hash(float(i) * 1.7, sd) * (h - 24.0)
				if not rect and absf(rx - a) / (a - 14.0) + absf(ry - b) / (b - 8.0) > 1.0:
					continue
				var tuft: Color = c0.darkened(0.18)
				line(img, Vector2(rx, ry), Vector2(rx - 2.5, ry - 5.0), 1.4, tuft)
				line(img, Vector2(rx, ry), Vector2(rx + 0.5, ry - 6.5), 1.4, tuft)
				line(img, Vector2(rx, ry), Vector2(rx + 3.0, ry - 4.5), 1.4, tuft)
			if def.has("flower"):
				var pet: Color = def["flower"]
				for fi in 2:
					var fx: float = 36.0 + _hash(sd, 9.0 + fi) * (w - 72.0)
					var fy: float = 20.0 + _hash(9.0 + fi, sd) * (h - 40.0)
					if absf(fx - a) / (a - 20.0) + absf(fy - b) / (b - 10.0) < 1.0:
						for kk in 5:
							var ang: float = float(kk) * TAU / 5.0
							dot(img, Vector2(fx + cos(ang) * 2.2, fy + sin(ang) * 1.4), 1.5, pet)
						dot(img, Vector2(fx, fy), 1.3, Color("e8b04a"))
		"path":
			for i in 6:
				var rx2: float = 24.0 + _hash(sd, float(i) * 2.3) * (w - 48.0)
				var ry2: float = 10.0 + _hash(float(i) * 4.1, sd) * (h - 20.0)
				if not rect and absf(rx2 - a) / (a - 16.0) + absf(ry2 - b) / (b - 8.0) > 1.0:
					continue
				soft_ellipse(img, Vector2(rx2, ry2), Vector2(4.0, 2.4), Color(0.725, 0.604, 0.384, 0.55))
		"water":
			for i in 3:
				var rx3: float = 30.0 + _hash(sd + phase, float(i) * 1.9) * (w - 60.0)
				var ry3: float = 14.0 + _hash(float(i) * 2.9, sd + phase) * (h - 28.0)
				if absf(rx3 - a) / (a - 20.0) + absf(ry3 - b) / (b - 10.0) > 1.0:
					continue
				line(img, Vector2(rx3 - 8, ry3), Vector2(rx3 + 8, ry3), 1.6, Color(0.984, 0.961, 0.902, 0.55))
		"moss":
			for i in 4:
				var rx4: float = 10.0 + _hash(sd, float(i) * 3.3) * (w - 20.0)
				var ry4: float = 7.0 + _hash(float(i) * 2.1, sd) * (h - 14.0)
				soft_ellipse(img, Vector2(rx4, ry4), Vector2(5.0, 2.6), Color(c1.lightened(0.15), 0.55))
		"glowpath":
			for i in 5:
				var rx5: float = 10.0 + _hash(sd, float(i) * 2.7) * (w - 20.0)
				var ry5: float = 7.0 + _hash(float(i) * 4.4, sd) * (h - 14.0)
				soft_ellipse(img, Vector2(rx5, ry5), Vector2(3.6, 2.0), Color(0.435, 0.839, 0.769, 0.45))
	var done: Image = finish(img)
	if rect:
		return done
	# clip to the overscanned diamond through the cached mask (C++ blend, no per-pixel script)
	var out: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	out.blend_rect_mask(done, diamond_mask(w, h), Rect2i(0, 0, w, h), Vector2i.ZERO)
	out.fix_alpha_edges()
	return out


## The periodic atlas of a terrain: `variants.x` x `variants.y` cells of `cell`. ONE painted cell is laid into every slot: the
## surface functions are periodic over the tile lattice, so identical cells tile without a visible step (the real art gets its
## variety from the 4 x 4 variants; the placeholder is honest about being repetitive).
static func paint_atlas(id: StringName, cell: Vector2i, variants: Vector2i) -> Image:
	var atlas: Image = Image.create_empty(cell.x * variants.x, cell.y * variants.y, false, Image.FORMAT_RGBA8)
	var base: Image = paint_cell(id, cell.x, cell.y, 0)
	for j in variants.y:
		for i in variants.x:
			atlas.blit_rect(base, Rect2i(0, 0, cell.x, cell.y), Vector2i(i * cell.x, j * cell.y))
	return atlas


# ----------------------------------------------------------------------------- lights and backdrop

static func radial_light_texture(size: int = 256) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.75))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = size
	t.height = size
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	return t


## Vertical sky gradient (top, bottom) as a texture: the fallback of ArtCatalog.backdrop(theme).
static func sky_gradient(top: Color, bottom: Color, w: int = 8, h: int = 256) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, top)
	g.set_color(1, bottom)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = w
	t.height = h
	t.fill = GradientTexture2D.FILL_LINEAR
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(0.5, 1.0)
	return t
