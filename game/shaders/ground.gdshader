shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec3 grass_a : source_color = vec3(0.33, 0.55, 0.23);
uniform vec3 grass_b : source_color = vec3(0.47, 0.68, 0.29);
uniform vec3 dead_a : source_color = vec3(0.40, 0.42, 0.27);
uniform vec3 dead_b : source_color = vec3(0.52, 0.47, 0.31);
uniform vec2 hunt_center = vec2(0.0, -88.0);
uniform float hunt_radius = 34.0;

varying vec3 wpos;

float hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = vnoise(wpos.xz * 0.06) * 0.65 + vnoise(wpos.xz * 0.31) * 0.35;
	vec3 g = mix(grass_a, grass_b, n);
	vec3 dd = mix(dead_a, dead_b, n);
	float d = distance(wpos.xz, hunt_center);
	float h = 1.0 - smoothstep(hunt_radius - 10.0, hunt_radius + 8.0, d);
	ALBEDO = mix(g, dd, h);
	ROUGHNESS = 1.0;
}
