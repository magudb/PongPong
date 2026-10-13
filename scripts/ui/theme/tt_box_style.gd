@tool
class_name TTBoxStyle
extends StyleBox
## One scripted StyleBox that can reproduce every "box" in the Trætoppen style guide:
##   parchment panels (2px ink outline + double gold ring + soft shadow), buttons (hard ink
##   underside + darker lower band + lift/sink), inventory slots (inner top shade, selection
##   ring, rare ring), chips/pills, meters (inner highlight), dashed "disabled" boxes.
##
## It is composed from StyleBoxFlat layers, so it stays vector sharp at any stretch scale
## (unlike a baked 9-slice texture). The Control rect is the CSS "border box": rings and the
## shadow are drawn OUTSIDE it (like box-shadow), so HTML layout numbers carry over 1:1.
##
## Layer order (bottom to top): soft shadow, hard underside, rings (outermost first),
## body fill + ink border (or dashed border), inner band.
##
## Everything is a plain @export so a theme can be built from code (tools/ui/build_theme.gd)
## and the saved theme.tres keeps working without the global class cache.

enum BandSide { NONE, BOTTOM, TOP, LEFT }

@export_group("Body")
@export var fill := Color("#f4e6c4")
@export var border_color := Color("#2b2340")
@export var border_width := 2.0
@export var radius := 16.0               ## clamped to half the body's shorter side (pills)
## Where the body sits inside the Control rect (left, top, right, bottom). Buttons use top=2,
## bottom=4 to leave room for the hover lift and the hard underside.
@export var body_inset := Vector4(0, 0, 0, 0)
## Vertical displacement of the body: hover lift (-2) / pressed sink (+3).
@export var y_offset := 0.0
## Per-corner radii (tl, tr, br, bl). A negative entry means "use radius". Used for the journal
## sidebar / shop footer, which must follow the parent's rounded corners.
@export var corners := Vector4(-1, -1, -1, -1)
## Per-side border widths (left, top, right, bottom). Negative = use border_width.
@export var border_sides := Vector4(-1, -1, -1, -1)
@export var draw_body := true            ## false: rings only (focus ring)
@export var dashed := false              ## dashed border (disabled button / empty box)
@export var dash_length := 6.0
@export var dash_gap := 4.0

@export_group("Rings and shadows")
## Outward rings, innermost first: e.g. [GOLD, INK] with widths [4, 2] = the panel's double ring.
@export var ring_colors: PackedColorArray = PackedColorArray()
@export var ring_widths: PackedFloat32Array = PackedFloat32Array()
@export var soft_shadow_color := Color(0, 0, 0, 0)
@export var soft_shadow_blur := 28.0
@export var soft_shadow_offset := Vector2(0, 12)
@export var hard_shadow := 0.0           ## solid copy of the body shifted down by this many px
@export var hard_shadow_color := Color("#2b2340")

@export_group("Inner band")
@export var band_side: BandSide = BandSide.NONE
@export var band_size := 5.0
@export var band_color := Color(0.169, 0.137, 0.251, 0.30)

var _sb: StyleBoxFlat


func _flat() -> StyleBoxFlat:
	if _sb == null:
		_sb = StyleBoxFlat.new()
		_sb.anti_aliasing = true
		_sb.anti_aliasing_size = 1.0
		_sb.corner_detail = 12
	# reset the bits we mutate
	_sb.shadow_size = 0
	_sb.shadow_color = Color(0, 0, 0, 0)
	_sb.shadow_offset = Vector2.ZERO
	_sb.set_border_width_all(0)
	_sb.set_corner_radius_all(0)
	_sb.draw_center = true
	_sb.set_expand_margin_all(0)
	return _sb


func _body_rect(rect: Rect2) -> Rect2:
	return Rect2(
		rect.position + Vector2(body_inset.x, body_inset.y + y_offset),
		rect.size - Vector2(body_inset.x + body_inset.z, body_inset.y + body_inset.w))


func _radius_for(body: Rect2, extra: float = 0.0) -> int:
	var r := minf(radius, minf(body.size.x, body.size.y) * 0.5)
	return int(round(r + extra))


func _side(v: float) -> int:
	return int(round(border_width if v < 0.0 else v))


func _corner(v: float, body: Rect2) -> int:
	var r := radius if v < 0.0 else v
	return int(round(minf(r, minf(body.size.x, body.size.y) * 0.5)))


func _apply_corners(sb: StyleBoxFlat, body: Rect2) -> void:
	sb.corner_radius_top_left = _corner(corners.x, body)
	sb.corner_radius_top_right = _corner(corners.y, body)
	sb.corner_radius_bottom_right = _corner(corners.z, body)
	sb.corner_radius_bottom_left = _corner(corners.w, body)


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var body := _body_rect(rect)
	if body.size.x <= 0.0 or body.size.y <= 0.0:
		return
	var r_body := _radius_for(body)

	# 1. soft drop shadow (blurred, from the body's shape)
	if soft_shadow_color.a > 0.0 and draw_body:
		var sh := _flat()
		sh.bg_color = Color(0, 0, 0, 0)
		sh.set_corner_radius_all(r_body)
		sh.shadow_size = int(soft_shadow_blur * 0.5)
		sh.shadow_color = soft_shadow_color
		sh.shadow_offset = soft_shadow_offset
		sh.draw(to_canvas_item, body)

	# 2. hard "underside" (button)
	if hard_shadow > 0.0 and draw_body:
		var hs := _flat()
		hs.bg_color = hard_shadow_color
		hs.set_corner_radius_all(r_body)
		hs.draw(to_canvas_item, Rect2(body.position + Vector2(0, hard_shadow), body.size))

	# 3. rings, outermost first so each inner ring overlaps (no AA seams)
	var count := mini(ring_colors.size(), ring_widths.size())
	if count > 0 and not draw_body:
		# focus ring only: hollow frames so the control's own content stays visible
		var off := 0.0
		for i in count:
			var hr := _flat()
			hr.draw_center = false
			hr.bg_color = Color(0, 0, 0, 0)
			hr.border_color = ring_colors[i]
			hr.set_border_width_all(int(round(ring_widths[i])))
			hr.set_corner_radius_all(_radius_for(body, off + ring_widths[i]))
			hr.draw(to_canvas_item, body.grow(off + ring_widths[i]))
			off += ring_widths[i]
	elif count > 0:
		var total := 0.0
		for i in count:
			total += ring_widths[i]
		var grow := total
		for i in range(count - 1, -1, -1):
			var rs := _flat()
			rs.bg_color = ring_colors[i]
			rs.set_corner_radius_all(_radius_for(body, grow))
			rs.draw(to_canvas_item, body.grow(grow))
			grow -= ring_widths[i]

	if not draw_body:
		return

	# 4. body
	var bs := _flat()
	bs.bg_color = fill
	_apply_corners(bs, body)
	if dashed:
		bs.draw(to_canvas_item, body)
		_draw_dashed_border(to_canvas_item, body, r_body)
	else:
		bs.border_color = border_color
		bs.border_width_left = _side(border_sides.x)
		bs.border_width_top = _side(border_sides.y)
		bs.border_width_right = _side(border_sides.z)
		bs.border_width_bottom = _side(border_sides.w)
		bs.draw(to_canvas_item, body)

	# 5. inner band (clipped by the inner rounded corners)
	if band_side != BandSide.NONE and band_color.a > 0.0:
		var bw := border_width if not dashed else 0.0
		var inner := body.grow(-bw)
		var r_in := maxi(0, r_body - int(round(bw)))
		var band := _flat()
		band.bg_color = band_color
		var br: Rect2
		match band_side:
			BandSide.BOTTOM:
				br = Rect2(inner.position.x, inner.end.y - band_size, inner.size.x, band_size)
				band.corner_radius_bottom_left = r_in
				band.corner_radius_bottom_right = r_in
			BandSide.TOP:
				br = Rect2(inner.position.x, inner.position.y, inner.size.x, band_size)
				band.corner_radius_top_left = r_in
				band.corner_radius_top_right = r_in
			BandSide.LEFT:
				br = Rect2(inner.position.x, inner.position.y, band_size, inner.size.y)
				band.corner_radius_top_left = r_in
				band.corner_radius_bottom_left = r_in
		band.draw(to_canvas_item, br)


func _draw_dashed_border(ci: RID, body: Rect2, r: int) -> void:
	var half := border_width * 0.5
	var rr := body.grow(-half)
	var rad := maxf(0.0, float(r) - half)
	var pts := PackedVector2Array()
	var steps := 8
	# clockwise from the top-left corner's end of arc
	var corners := [
		[Vector2(rr.position.x + rad, rr.position.y + rad), PI],          # top-left
		[Vector2(rr.end.x - rad, rr.position.y + rad), PI * 1.5],         # top-right
		[Vector2(rr.end.x - rad, rr.end.y - rad), 0.0],                   # bottom-right
		[Vector2(rr.position.x + rad, rr.end.y - rad), PI * 0.5],         # bottom-left
	]
	for c in corners:
		for s in range(steps + 1):
			var a: float = c[1] + (PI * 0.5) * float(s) / float(steps)
			pts.append(c[0] + Vector2(cos(a), sin(a)) * rad)
	pts.append(pts[0])
	var col := PackedColorArray([border_color])
	var on := true
	var left := dash_length
	var seg := PackedVector2Array()
	seg.append(pts[0])
	for i in range(1, pts.size()):
		var a2 := pts[i - 1]
		var b2 := pts[i]
		var d := a2.distance_to(b2)
		var t := 0.0
		while d - t > 0.001:
			var take := minf(left, d - t)
			var p := a2.lerp(b2, (t + take) / d)
			if on:
				seg.append(p)
			t += take
			left -= take
			if left <= 0.001:
				if on and seg.size() >= 2:
					RenderingServer.canvas_item_add_polyline(ci, seg, col, border_width, true)
				on = not on
				left = dash_length if on else dash_gap
				seg = PackedVector2Array()
				if on:
					seg.append(p)
	if on and seg.size() >= 2:
		RenderingServer.canvas_item_add_polyline(ci, seg, col, border_width, true)


func _get_draw_rect(rect: Rect2) -> Rect2:
	var grow := 0.0
	for w in ring_widths:
		grow += w
	if soft_shadow_color.a > 0.0:
		grow = maxf(grow, soft_shadow_blur + maxf(absf(soft_shadow_offset.x), absf(soft_shadow_offset.y)))
	grow = maxf(grow, hard_shadow)
	return rect.grow(grow)


func _get_minimum_size() -> Vector2:
	return Vector2.ZERO
