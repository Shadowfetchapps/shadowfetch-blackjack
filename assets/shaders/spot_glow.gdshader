// Pulsing ring drawn just above the felt to highlight a betting spot.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform float intensity = 0.0;
uniform float inner = 0.78;
uniform float outer = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ring = smoothstep(inner - 0.12, inner, r) * (1.0 - smoothstep(outer - 0.06, outer, r));
	float fill = (1.0 - smoothstep(0.0, inner, r)) * 0.12;
	float pulse = 0.75 + 0.25 * sin(TIME * 3.2);
	ALBEDO = glow_color.rgb;
	ALPHA = (ring + fill) * intensity * pulse;
}
