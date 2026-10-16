shader_type canvas_item;
#include "res://shaders/wardrobe_motion.gdshaderinc"
uniform vec4 palette_0 : source_color = vec4(1.0);
uniform vec4 palette_1 : source_color = vec4(1.0);
uniform vec4 palette_2 : source_color = vec4(1.0);
uniform vec3 source_0 = vec3(0.8);
uniform vec3 source_1 = vec3(0.5);
uniform vec3 source_2 = vec3(0.3);
uniform bool recolor = true;
varying vec4 vmod;
void vertex() { vmod = COLOR; }
void fragment() {
	vec2 pixel = UV * vec2(textureSize(TEXTURE, 0)) - vec2(0.0, float(direction) * 256.0);
	vec2 source = wardrobe_source(pixel);
	vec4 paint = texture(TEXTURE, wardrobe_uv(source));
	paint.a *= wardrobe_inside(source);
	if (recolor && paint.a > 0.0) {
		float value = max(max(paint.r, paint.g), paint.b);
		vec3 chroma = paint.rgb / max(value, 0.001);
		vec3 weights = vec3(
			exp(-160.0 * dot(chroma - source_0 / max(max(source_0.r, source_0.g), source_0.b), chroma - source_0 / max(max(source_0.r, source_0.g), source_0.b))),
			exp(-160.0 * dot(chroma - source_1 / max(max(source_1.r, source_1.g), source_1.b), chroma - source_1 / max(max(source_1.r, source_1.g), source_1.b))),
			exp(-160.0 * dot(chroma - source_2 / max(max(source_2.r, source_2.g), source_2.b), chroma - source_2 / max(max(source_2.r, source_2.g), source_2.b))));
		weights /= max(weights.r + weights.g + weights.b, 0.00001);
		vec3 reference = source_0 * weights.r + source_1 * weights.g + source_2 * weights.b;
		vec3 pigment = palette_0.rgb * weights.r + palette_1.rgb * weights.g + palette_2.rgb * weights.b;
		float shade = value / max(max(max(reference.r, reference.g), reference.b), 0.01);
		vec3 changed = shade <= 1.0 ? pigment * shade : mix(pigment, vec3(1.0), clamp((shade - 1.0) * 0.6, 0.0, 0.6));
		float ink = smoothstep(0.18, 0.34, dot(paint.rgb, vec3(0.299, 0.587, 0.114)));
		paint.rgb = mix(paint.rgb, changed, ink);
	}
	COLOR = paint * vmod;
}
