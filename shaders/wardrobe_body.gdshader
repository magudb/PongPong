shader_type canvas_item;
#include "res://shaders/wardrobe_motion.gdshaderinc"
#include "res://shaders/wardrobe_fit.gdshaderinc"
uniform vec4 fit_sources[7];
uniform vec4 fit_targets[7];
uniform vec4 fit_shapes[7];
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
float fitted_alpha(sampler2D garment, int index, vec2 source) {
	vec2 fitted = tailored_source(source, fit_sources[index], fit_targets[index], fit_shapes[index]);
	return texture(garment, wardrobe_uv(fitted)).a * wardrobe_inside(fitted);
}
void vertex() { vmod = COLOR; }
void fragment() {
	vec2 pixel = UV * vec2(textureSize(TEXTURE, 0)) - source_origin;
	vec2 source = wardrobe_source(pixel);
	vec2 at = wardrobe_uv(source);
	vec4 paint = texture(TEXTURE, UV);
	if (use_base) { paint = texture(base_image, at) * wardrobe_inside(source); }
	if (occluder) {
		float skin = texture(mask_image, at).a * wardrobe_inside(source);
		float overlap = 0.0;
		if (skin > 0.001) {
			overlap = fitted_alpha(garment_0, 0, source);
			overlap = max(overlap, fitted_alpha(garment_1, 1, source));
			overlap = max(overlap, fitted_alpha(garment_2, 2, source));
			overlap = max(overlap, fitted_alpha(garment_3, 3, source));
			overlap = max(overlap, fitted_alpha(garment_4, 4, source));
			overlap = max(overlap, fitted_alpha(garment_5, 5, source));
			overlap = max(overlap, fitted_alpha(garment_6, 6, source));
		}
		paint.a *= skin * overlap;
	}
	COLOR = paint * vmod;
}
