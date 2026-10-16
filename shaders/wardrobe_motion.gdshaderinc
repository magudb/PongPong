// Same inverse field as tools/art/drawn/pack.py:puppet. The owning body
// supplies discrete frame phases; clothing has no animation clock.
uniform float figure_height = 168.0;
uniform float frame_phase = 0.0;
uniform float pulse_phase = 0.0;
uniform int motion_kind = 0;
uniform int direction = 0;

vec2 wardrobe_source(vec2 pixel) {
	float wave = sin(frame_phase * 6.28318530718);
	float pulse = sin(pulse_phase * 3.14159265359);
	float u = (pixel.x - 127.5) / (figure_height * 0.5);
	float v = (pixel.y - (200.0 - figure_height)) / figure_height;
	float legs = clamp((v - 0.72) / 0.26, 0.0, 1.0);
	float left = exp(-pow((u + 0.45) / 0.28, 2.0));
	float right = exp(-pow((u - 0.45) / 0.28, 2.0));
	float arms = exp(-pow((abs(u) - 0.7) / 0.3, 2.0) - pow((v - 0.69) / 0.16, 2.0));
	float head = exp(-pow((v - 0.3) / 0.35, 4.0));
	float dx = 0.0;
	float dy = 0.0;
	float sx = 1.0;
	float sy = 1.0;
	float lift = 0.0;
	float lean = 0.0;
	if (motion_kind == 1 || motion_kind == 2) {
		float stride = motion_kind == 1 ? 4.5 : 7.0;
		dx += legs * (right - left) * wave * stride;
		dy -= legs * (left * max(wave, 0.0) + right * max(-wave, 0.0)) * stride;
		dy += arms * sign(u) * wave * 3.5;
		dx += head * wave * 0.8;
		sy = 1.0 - abs(wave) * 0.018;
		lean = wave * 0.012;
	} else if (motion_kind == 3 || motion_kind == 4) {
		float reach = motion_kind == 3 ? 8.0 : 14.0;
		dx -= arms * pulse * reach;
		dy -= arms * pulse * reach * 0.7;
		lean = -0.035 * pulse;
		dy += head * pulse * 1.5;
	} else if (motion_kind == 5) {
		dy -= arms * pulse * 17.0;
		dx += arms * sign(u) * pulse * 3.0;
		sy = 1.0 + wave * 0.025;
		lift = max(wave, 0.0) * 2.0;
	} else if (motion_kind == 6) {
		dx += arms * sign(u) * wave * 4.0;
		sy = 1.0 + wave * 0.012;
		lift = 4.0 + wave * 2.0;
	} else if (motion_kind == 7) {
		sy = 1.0 + wave * 0.055;
		lift = pulse * 8.0;
		dy -= arms * pulse * 6.0;
	} else if (motion_kind == 8) {
		sy = 1.03 + wave * 0.012;
		dy -= arms * 5.0;
	} else if (motion_kind == 9) {
		sy = 1.0 - pulse * 0.06;
		sx = 1.0 + pulse * 0.025;
	} else if (motion_kind == 10) {
		sy = 0.88 + wave * 0.008;
		sx = 1.025;
		lean = 0.04;
	} else if (motion_kind == 11) {
		lean = wave * 0.065;
		sy = 1.0 - pulse * 0.025;
	} else if (motion_kind == 12) {
		lean = wave * 0.04;
		sx = 1.0 + wave * 0.025;
		dy += head * cos(frame_phase * 6.28318530718) * 1.3;
		dx += arms * cos(frame_phase * 6.28318530718) * 3.0;
	} else if (motion_kind == 13) {
		dy += head * wave * 1.5;
		dy -= arms * max(wave, 0.0) * 3.0;
		sy = 1.0 + wave * 0.006;
	} else {
		sx = 1.0 + wave * 0.008;
		sy = 1.0 + wave * 0.006;
		dx += head * wave * 0.45;
	}
	return vec2(127.5 + (pixel.x - 127.5 - dx - (200.0 - pixel.y) * lean) / sx,
		200.0 + (pixel.y - 200.0 + lift - dy) / sy);
}

vec2 wardrobe_uv(vec2 source) {
	return (source + vec2(0.0, float(direction) * 256.0)) / vec2(256.0, 2048.0);
}

float wardrobe_inside(vec2 source) {
	return step(0.0, source.x) * step(source.x, 256.0) * step(0.0, source.y) * step(source.y, 256.0);
}
