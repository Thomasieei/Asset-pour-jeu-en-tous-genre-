shader_type spatial;
uniform sampler2D albedo : source_color, filter_linear_mipmap;
void fragment() {
	vec3 color = texture(albedo,UV).rgb;
	if(color.r>0.4 && color.g>0.3 && color.g>color.r*0.6 && color.b<color.r*0.35) {
		color = vec3(0.56,0.22,0.065)*(0.6+color.r*0.4);
	}
	ALBEDO = color;
	ROUGHNESS = 0.95;
}
