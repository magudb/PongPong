shader_type canvas_item;
#include "res://shaders/wardrobe_motion.gdshaderinc"
uniform sampler2D base_image : filter_linear_mipmap, repeat_disable;
uniform sampler2D mask_image : filter_linear_mipmap, repeat_disable;
uniform sampler2D garment_0 : filter_linear_mipmap, repeat_disable;
uniform sampler2D garment_1 : filter_linear_mipmap, repeat_disable;
uniform sampler2D garment_2 : filter_linear_mipmap, repeat_disable;
uniform sampler2D garment_3 : filter_linear_mipmap, repeat_disable;
uniform sampler2D garment_4 : filter_linear_mipmap, repeat_disable;
uniform sampler2D garment_5 : filter_linear_mipmap, repeat_disable;
uniform sampler2D garment_6 : filter_linear_mipmap, repeat_disable;
uniform bool use_base = false;
uniform bool occluder = false;
uniform vec2 source_origin = vec2(0.0);
varying vec4 vmod;
void vertex() { vmod = COLOR; }
void fragment() {
	vec2 pixel = UV * vec2(textureSize(TEXTURE, 0)) - source_origin;
	vec2 source = wardrobe_source(pixel);
	vec2 at = wardrobe_uv(source);
	vec4 paint = texture(TEXTURE, UV);
	if (use_base) { paint = texture(base_image, at) * wardrobe_inside(source); }
	if (occluder) {
		float overlap = max(max(max(texture(garment_0, at).a, texture(garment_1, at).a), max(texture(garment_2, at).a, texture(garment_3, at).a)), max(max(texture(garment_4, at).a, texture(garment_5, at).a), texture(garment_6, at).a));
		paint.a *= texture(mask_image, at).a * overlap * wardrobe_inside(source);
	}
	COLOR = paint * vmod;
}
