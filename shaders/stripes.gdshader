shader_type canvas_item;
// Placeholder / key-art backdrop from the style guide:
//   repeating-linear-gradient(135deg, a 0 w, b w 2w)  + optional rounded corners + ink border.
// Anti-aliased and resolution independent. Use through scripts/ui/components/tt_stripes.gd
// (it feeds rect_size), or on a white ColorRect.
uniform vec4 color_a : source_color = vec4(0.80, 0.88, 0.65, 1.0);
uniform vec4 color_b : source_color = vec4(0.75, 0.84, 0.58, 1.0);
uniform float band : hint_range(2.0, 200.0) = 14.0;
uniform vec2 rect_size = vec2(100.0, 100.0);
uniform vec4 radii = vec4(0.0);          // top-left, top-right, bottom-right, bottom-left
uniform float border = 0.0;              // ink border width inside the rect
uniform vec4 border_color : source_color = vec4(0.169, 0.137, 0.251, 1.0);
varying vec2 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	vec2 p = lp - rect_size * 0.5;
	vec2 b = rect_size * 0.5;
	float rad = p.x < 0.0 ? (p.y < 0.0 ? radii.x : radii.w) : (p.y < 0.0 ? radii.y : radii.z);
	rad = min(rad, min(b.x, b.y));
	vec2 q = abs(p) - b + vec2(rad);
	float d = min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - rad;   // <0 inside
	float aa = max(fwidth(d), 0.0001);
	float inside = 1.0 - smoothstep(-aa * 0.5, aa * 0.5, d);
	float t = (lp.x + lp.y) * 0.70710678;
	float m = mod(t, band * 2.0);
	float aat = max(fwidth(t), 0.0001);
	vec4 stripe = mix(color_a, color_b, smoothstep(band - aat, band + aat, m));
	float in_border = smoothstep(-border - aa * 0.5, -border + aa * 0.5, d);
	vec4 col = border > 0.0 ? mix(stripe, border_color, in_border) : stripe;
	COLOR = vec4(col.rgb, col.a * inside) * COLOR;
}
