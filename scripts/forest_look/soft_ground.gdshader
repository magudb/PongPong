shader_type canvas_item;
uniform sampler2D paint : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 repeats = vec2(1.0);
varying vec4 vmod;
void vertex() { vmod = COLOR; }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	vec4 n = fract(sin(vec4(dot(i,vec2(127.1,311.7)),dot(i+vec2(1,0),vec2(127.1,311.7)),dot(i+vec2(0,1),vec2(127.1,311.7)),dot(i+vec2(1,1),vec2(127.1,311.7))))*43758.5453);
	return mix(mix(n.x,n.y,f.x),mix(n.z,n.w,f.x),f.y);
}
void fragment() {
	float mask = texture(TEXTURE,UV).r;
	float edge = smoothstep(.45,.55,mask+(noise(UV*repeats*9.0)-.5)*.035);
	vec4 pigment = texture(paint,UV*repeats);
	COLOR = pigment * vmod;
	COLOR.a *= edge;
}
