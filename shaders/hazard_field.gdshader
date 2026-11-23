shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, unshaded, shadows_disabled, fog_disabled;

uniform vec4 field_color : source_color = vec4(1.0, 0.20, 0.11, 1.0);

void fragment() {
	float height = 1.0 - UV.y;
	float bars = pow(max(0.0, cos(UV.x * 138.23)), 16.0);
	float lower = exp(-height * 7.0);
	float top = smoothstep(0.976, 0.995, height);
	float band = pow(max(0.0, sin(height * 24.0 - TIME * 2.2)), 12.0);
	ALBEDO = field_color.rgb;
	ALPHA = lower * 0.20 + bars * lower * 0.24 + top * 0.18 + band * 0.045 * (1.0 - height);
}
