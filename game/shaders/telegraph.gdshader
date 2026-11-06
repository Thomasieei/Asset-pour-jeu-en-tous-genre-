shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 color : source_color = vec4(1.0, 0.15, 0.1, 0.55);
uniform float progress = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	float ring = smoothstep(0.9, 0.97, r) * (1.0 - smoothstep(0.97, 1.0, r));
	float fill = step(r, progress) * 0.55;
	ALBEDO = color.rgb;
	ALPHA = color.a * clamp(ring * 1.6 + fill, 0.0, 1.0);
}
