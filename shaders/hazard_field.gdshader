shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, unshaded, shadows_disabled, fog_disabled;

uniform vec4 field_color : source_color = vec4(1.0, 0.20, 0.11, 1.0);

void fragment() {
	float height = 1.0 - UV.y;
	float joins = pow(max(0.0, cos(UV.x * 75.4)), 28.0);
	float lower = exp(-height * 5.8);
	float edge = smoothstep(0.970, 1.0, height);
	float reflection = exp(-abs(height - UV.x * 0.66 - 0.16) * 26.0);
	float fresnel = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.4);
	ALBEDO = mix(field_color.rgb, vec3(1.0, 0.61, 0.52), edge * 0.85 + reflection * 0.15);
	ALPHA = 0.055 + lower * 0.19 + joins * 0.11 + edge * 0.43
		+ reflection * 0.115 + fresnel * 0.08;
}
