shader_type spatial;
render_mode blend_mix, depth_draw_never, unshaded, shadows_disabled, fog_disabled;

uniform vec4 marker_color : source_color = vec4(0.64, 0.85, 1.0, 1.0);
uniform float altitude = 1.0;
uniform float impact = -1.0;

void fragment() {
	float distance_to_center = length(UV - vec2(0.5)) * 3.0;
	if (impact < 0.0) {
		float radius = mix(0.54, 0.91, altitude);
		float ring = 1.0 - smoothstep(0.023, 0.064, abs(distance_to_center - radius));
		float shadow = 1.0 - smoothstep(0.15, 0.57, distance_to_center);
		ALBEDO = mix(vec3(0.015, 0.027, 0.045), marker_color.rgb, ring);
		ALPHA = max(ring * mix(0.90, 0.60, altitude), shadow * mix(0.63, 0.30, altitude));
	} else {
		float radius = mix(0.54, 1.22, impact);
		float ring = 1.0 - smoothstep(0.026, 0.072, abs(distance_to_center - radius));
		ALBEDO = marker_color.rgb;
		ALPHA = ring * 0.90 * (1.0 - impact);
	}
}
