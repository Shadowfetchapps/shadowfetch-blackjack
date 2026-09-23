// Casino felt: baked print texture + tiled fibre noise + a soft velvet sheen.
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D print_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D fiber_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 base_color : source_color = vec3(0.03, 0.2, 0.11);
uniform float has_print = 0.0;
uniform float fiber_scale = 34.0;
uniform float fiber_strength = 0.10;
uniform float sheen = 0.35;

void fragment() {
	vec3 col = mix(base_color, texture(print_tex, UV).rgb, has_print);
	vec2 fuv = UV * vec2(2.0, 1.0) * fiber_scale;
	float n = texture(fiber_tex, fuv).r * 0.65 + texture(fiber_tex, fuv * 3.3 + 0.37).r * 0.35;
	col *= 1.0 - fiber_strength + fiber_strength * 2.0 * n;
	ALBEDO = col;
	ROUGHNESS = 0.94;
	SPECULAR = 0.18;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = col * fres * sheen;
}
