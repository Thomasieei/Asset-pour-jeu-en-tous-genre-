shader_type spatial;
render_mode cull_disabled;
void fragment() {
	float ripple = sin(VERTEX.x*5.0 + TIME*1.8 + sin(VERTEX.z*6.0))*0.5+0.5;
	ALBEDO = mix(vec3(0.13,0.39,0.44),vec3(0.38,0.65,0.65),pow(ripple,12.0)*0.35);
	ROUGHNESS = 0.28;
	SPECULAR = 0.65;
}
