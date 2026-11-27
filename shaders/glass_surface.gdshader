shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_never, unshaded, shadows_disabled;

uniform vec4 glass_tint : source_color = vec4(0.32, 0.73, 0.96, 1.0);
uniform vec4 glow_tint : source_color = vec4(0.21, 0.62, 0.85, 1.0);
uniform float glow_strength = 0.3;
uniform float opacity : hint_range(0.0, 1.0) = 0.52;
uniform float impact : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 normal = normalize(NORMAL);
	vec3 view = normalize(VIEW);
	float facing = max(dot(normal, view), 0.0);
	float rim = pow(1.0 - facing, 2.2);
	vec3 reflection = reflect(-view, normal);

	// Two broad reflections keep the glass readable from both cameras
	// without sampling a screen texture.
	float key = pow(max(dot(reflection, vec3(-0.48, 0.62, 0.62)), 0.0), 13.0);
	float fill = pow(max(dot(reflection, vec3(0.73, -0.28, 0.62)), 0.0), 6.0);
	float bevel = smoothstep(-0.75, 0.85, reflection.y);
	vec3 ice = vec3(0.66, 0.87, 1.0);
	vec3 glass = glass_tint.rgb * (0.48 + bevel * 0.28)
		+ glow_tint.rgb * glow_strength * (0.17 + rim * 0.25);
	glass = mix(glass, mix(glass_tint.rgb, ice, 0.37), rim * 0.84);
	glass += ice * key * 0.64 + ice.bgr * fill * 0.20;
	ALBEDO = mix(glass, vec3(1.0), impact * 0.7);
	ALPHA = clamp(opacity + rim * 0.41 + key * 0.38 + fill * 0.14 + impact * 0.23,
		0.0, 0.98);
}
