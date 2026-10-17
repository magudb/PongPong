// Inverse tailoring in the REST body canvas. Animate the fitted result with
// wardrobe_source(), so cuffs, collars and skin use the same motion field.
vec2 tailored_source(vec2 pixel, vec4 from, vec4 to, vec4 shape) {
	vec2 unit = (pixel - to.xy) / max(to.zw, vec2(1.0));
	float side = abs(unit.x - 0.5) * 2.0;
	float shoulder = 1.0 - smoothstep(0.28, 0.76, unit.y);
	unit.y -= shape.w / max(to.w, 1.0) * smoothstep(0.25, 0.9, side) * shoulder;
	float width = mix(shape.x, shape.y, smoothstep(0.0, 0.45, unit.y));
	width = mix(width, shape.z, smoothstep(0.45, 1.0, unit.y));
	unit.x = (unit.x - 0.5) / max(width, 0.1) + 0.5;
	return from.xy + unit * from.zw;
}
