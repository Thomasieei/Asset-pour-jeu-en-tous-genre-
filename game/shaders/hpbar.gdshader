shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform float fill = 1.0;
uniform float lag = 1.0;
uniform vec4 fill_color : source_color = vec4(0.9, 0.2, 0.2, 1.0);

void vertex() {
	// cylindrical-free billboard: always face the camera
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 uv = UV;
	float border = step(uv.x, 0.02) + step(0.98, uv.x) + step(uv.y, 0.12) + step(0.88, uv.y);
	vec3 col = vec3(0.08, 0.06, 0.12);
	if (uv.x < lag) { col = vec3(1.0, 0.85, 0.4); }
	if (uv.x < fill) { col = fill_color.rgb; }
	if (border > 0.0) { col = vec3(0.02, 0.02, 0.05); }
	ALBEDO = col;
	ALPHA = 0.95;
}
