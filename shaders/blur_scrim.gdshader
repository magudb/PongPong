shader_type canvas_item;
// Soft blur + night tint over whatever is behind (shop / quest book / inventory backdrops).
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0, 6.0) = 2.5;
uniform vec4 tint : source_color = vec4(0.11, 0.13, 0.22, 0.45);
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur_lod).rgb;
	COLOR = vec4(mix(c, tint.rgb, tint.a), 1.0);
}
