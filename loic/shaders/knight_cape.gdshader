shader_type spatial;
uniform sampler2D albedo : source_color, filter_linear_mipmap;
void fragment() {
	vec4 color = texture(albedo,UV);
	if(color.r>color.g*1.5 && color.r>color.b*1.35 && color.r>0.15) {
		color.rgb = vec3(0.10,0.27,0.42)*(color.r*1.2+0.2);
	}
	ALBEDO = color.rgb;
	ROUGHNESS = 0.85;
}
