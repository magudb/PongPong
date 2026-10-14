shader_type canvas_item;
render_mode unshaded, blend_disabled;

// Offline illustration pass for the existing code-authored sprite library.
// Alpha and coordinates stay untouched: animation cells, pivots and sorting remain exact.
uniform sampler2D paper : repeat_enable, filter_linear;
uniform vec2 cell_size = vec2(256.0);
uniform float contour = 0.76;
uniform float pigment = 0.075;
uniform float pencil = 0.11;
uniform float flatten = 0.68;
uniform bool pale_rim = false;
uniform vec3 ink = vec3(0.26, 0.19, 0.25);

float luminance(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	if (source.a < 0.004) {
		COLOR = source;
	} else {
		vec2 pixel = UV / TEXTURE_PIXEL_SIZE;
		vec2 local = mod(pixel, cell_size);
		float tooth = luminance(texture(paper, local / 128.0).rgb);
		float wash = luminance(texture(paper, local / 31.0 + vec2(0.37, 0.21)).rgb);
		float y = luminance(source.rgb);
		// Gentle value bands replace plastic rounded lighting with painted planes.
		float uneven_wash = (wash - 0.84) * 0.13 + sin(local.x * 0.085 + sin(local.y * 0.11)) * 0.008;
		float painted_y = mix(y, (floor((y + uneven_wash) * 9.0) + 0.5) / 9.0, flatten);
		vec3 paint = source.rgb * (painted_y / max(y, 0.035));
		paint = mix(paint, vec3(0.98, 0.94, 0.85), 0.028);
		paint += vec3((tooth - 0.77) * pigment * 2.8 + (wash - 0.77) * pigment);
		vec2 step_px = TEXTURE_PIXEL_SIZE * 1.65;
		vec4 left = texture(TEXTURE, UV - vec2(step_px.x, 0.0));
		vec4 right = texture(TEXTURE, UV + vec2(step_px.x, 0.0));
		vec4 up = texture(TEXTURE, UV - vec2(0.0, step_px.y));
		vec4 down = texture(TEXTURE, UV + vec2(0.0, step_px.y));
		float silhouette = 1.0 - min(min(left.a, right.a), min(up.a, down.a));
		// Contours also follow eyes, ears, seams and painted details, not just silhouettes.
		float detail = max(length(left.rgb - right.rgb), length(up.rgb - down.rgb));
		detail *= min(min(left.a, right.a), min(up.a, down.a));
		float wandering = 0.81 + 0.19 * sin(local.y * 0.33 + sin(local.x * 0.21));
		float line = max(silhouette * 0.86, smoothstep(0.17, 0.46, detail) * 0.55);
		// Legendary icons need their light outer rim to stay legible on the night tile.
		if (pale_rim) {
			line *= 1.0 - smoothstep(0.80, 0.93, y);
		}
		paint = mix(paint, ink, line * contour * wandering);
		// Broken diagonal pencil strokes collect in shadow; the pattern never uses TIME.
		float stroke = abs(sin((local.x + local.y * 0.63 + sin(local.y * 0.14)) * 1.5));
		float hatch = (1.0 - smoothstep(0.12, 0.38, stroke)) * (1.0 - smoothstep(0.28, 0.72, y));
		hatch *= smoothstep(0.52, 0.81, wash);
		paint = mix(paint, ink, hatch * pencil);
		COLOR = vec4(clamp(paint, vec3(0.0), vec3(1.0)), source.a);
	}
}
