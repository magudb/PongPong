shader_type canvas_item;
#include "res://shaders/wardrobe_motion.gdshaderinc"
#include "res://shaders/wardrobe_fit.gdshaderinc"
uniform vec4 fit_source_rect = vec4(0.0, 0.0, 256.0, 256.0);
uniform vec4 fit_target_rect = vec4(0.0, 0.0, 256.0, 256.0);
uniform vec4 fit_shape = vec4(1.0, 1.0, 1.0, 0.0);
uniform float fabric_volume = 0.0;
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
	vec2 rest = wardrobe_source(pixel);
	vec2 source = tailored_source(rest, fit_source_rect, fit_target_rect, fit_shape);
	vec4 paint = texture(TEXTURE, wardrobe_uv(source));
	paint.a *= wardrobe_inside(source);
	if (recolor && paint.a > 0.0) {
		float value = max(max(paint.r, paint.g), paint.b);
		vec3 chroma = paint.rgb / max(value, 0.001);
		vec3 distances = vec3(
			dot(chroma - source_0 / max(max(source_0.r, source_0.g), source_0.b), chroma - source_0 / max(max(source_0.r, source_0.g), source_0.b)),
			dot(chroma - source_1 / max(max(source_1.r, source_1.g), source_1.b), chroma - source_1 / max(max(source_1.r, source_1.g), source_1.b)),
			dot(chroma - source_2 / max(max(source_2.r, source_2.g), source_2.b), chroma - source_2 / max(max(source_2.r, source_2.g), source_2.b)));
		// Subtract the nearest distance before exponentiation: even an unusual
		// painted pixel retains a valid dye mixture instead of washing to white.
		vec3 weights = exp(-160.0 * (distances - min(min(distances.r, distances.g), distances.b)));
		weights /= weights.r + weights.g + weights.b;
		vec3 reference = source_0 * weights.r + source_1 * weights.g + source_2 * weights.b;
		vec3 pigment = palette_0.rgb * weights.r + palette_1.rgb * weights.g + palette_2.rgb * weights.b;
		// A dark reference pigment is not a white point. Preserve the source's
		// cloth folds and grain when a pale dye replaces sage/brown fabric.
		float shade = value / max(max(max(reference.r, reference.g), reference.b), 0.85);
		vec3 changed = shade <= 1.0 ? pigment * shade : mix(pigment, vec3(1.0), clamp((shade - 1.0) * 0.35, 0.0, 0.12));
		float ink = smoothstep(0.18, 0.34, dot(paint.rgb, vec3(0.299, 0.587, 0.114)));
		paint.rgb = mix(paint.rgb, changed, ink);
	}
	// A restrained curved side shadow seats the existing painted fabric around
	// the torso. Preserve its grain, seams and authored highlights.
	vec2 fabric = (rest - fit_target_rect.xy) / max(fit_target_rect.zw, vec2(1.0));
	float edge = pow(clamp(abs(fabric.x-0.5)*2.0, 0.0, 1.0), 1.7);
	paint.rgb *= 1.0 - fabric_volume * edge;
	COLOR = paint * vmod;
}
