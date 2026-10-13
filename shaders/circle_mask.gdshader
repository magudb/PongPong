shader_type canvas_item;
// Round minimap: draws the texture only inside the inscribed circle (anti-aliased edge).
uniform float edge : hint_range(0.0, 0.1) = 0.012;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = distance(UV, vec2(0.5));
	c.a *= 1.0 - smoothstep(0.5 - edge, 0.5, d);
	COLOR = c;
}
