shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec3 base_color : source_color = vec3(0.66, 0.62, 0.55);
uniform float cobble = 1.0;
uniform float cell_scale = 1.3;

varying vec3 wpos;

float hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 c = wpos.xz * cell_scale;
	c.x += step(1.0, mod(floor(c.y), 2.0)) * 0.5;
	vec2 cell = floor(c);
	vec2 f = fract(c);
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float stones = mix(1.0, mix(0.72, 1.0, smoothstep(0.03, 0.12, edge)) * (0.86 + 0.22 * hash(cell)), cobble);
	float grain = 0.9 + 0.2 * hash(floor(wpos.xz * 3.0));
	float border = smoothstep(0.0, 0.18, min(UV.x, 1.0 - UV.x) * 2.0);
	vec3 col = base_color * stones * mix(1.0, grain, 1.0 - cobble);
	ALBEDO = col * mix(0.78, 1.0, border);
	NORMAL = (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
	ROUGHNESS = 1.0;
}
