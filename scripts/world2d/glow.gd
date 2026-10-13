class_name Glow
extends RefCounted
## Shared soft light / glow textures (generated once, tiny: gradients, no painting).
##   light_texture()  white centre -> transparent edge for PointLight2D (texture_scale 1 = radius 128 px)
##   halo_texture()   the same falloff for ADDITIVE glow sprites (lantern halos, windows, mushrooms): tinted by modulate and
##                    faded in with the night factor (IsoArea.set_night_factor)
##   ring_texture()   a thin ring for light bursts and selection rings
##   additive_material()  the shared CanvasItemMaterial with BLEND_MODE_ADD

static var _light: Texture2D
static var _halo: Texture2D
static var _ring: Texture2D
static var _additive: CanvasItemMaterial


static func light_texture() -> Texture2D:
	if _light == null:
		_light = PlaceholderArt.radial_light_texture(256)
	return _light


static func halo_texture() -> Texture2D:
	if _halo == null:
		_halo = PlaceholderArt.radial_light_texture(128)
	return _halo


static func ring_texture() -> Texture2D:
	if _ring == null:
		var img: Image = Image.create_empty(256, 256, false, Image.FORMAT_RGBA8)
		for y in 256:
			for x in 256:
				var d: float = Vector2(x + 0.5 - 128.0, y + 0.5 - 128.0).length() / 128.0
				var a: float = clampf(1.0 - absf(d - 0.88) * 9.0, 0.0, 1.0) * clampf((1.0 - d) * 8.0, 0.0, 1.0) if d < 1.0 else 0.0
				if a > 0.0:
					img.set_pixel(x, y, Color(1, 1, 1, a))
		_ring = ImageTexture.create_from_image(img)
	return _ring


static func additive_material() -> CanvasItemMaterial:
	if _additive == null:
		_additive = CanvasItemMaterial.new()
		_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _additive
