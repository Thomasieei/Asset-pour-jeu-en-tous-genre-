shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec3 tint : source_color = vec3(0.42, 0.26, 0.95);
uniform vec3 rim_color : source_color = vec3(0.62, 0.42, 1.0);
uniform float rim_power = 2.2;

void fragment() {
	vec3 c = texture(tex, UV).rgb;
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	ALBEDO = mix(vec3(0.04, 0.02, 0.10), tint, clamp(l * 0.9, 0.0, 1.0));
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = rim_color * rim * 1.5 + tint * 0.12;
	ROUGHNESS = 0.8;
}
