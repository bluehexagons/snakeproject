shader_type spatial;

uniform vec4 panel_color : source_color = vec4(0.16, 0.23, 0.28, 1.0);
uniform vec4 seam_color : source_color = vec4(0.048, 0.091, 0.12, 1.0);
uniform vec4 marking_color : source_color = vec4(0.17, 0.40, 0.46, 1.0);

varying vec2 surface_position;

void vertex() {
	surface_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float stroke(float distance, float width) {
	float aa = max(fwidth(distance), 0.004);
	return 1.0 - smoothstep(width - aa * 0.5, width + aa * 0.5, distance);
}

void fragment() {
	vec2 p = surface_position;
	vec2 cell = fract((p + 11.0) * 0.5);
	vec2 border = min(cell, 1.0 - cell) * 2.0;
	float seam_distance = min(border.x, border.y);
	float seam = stroke(seam_distance, 0.024);
	float bevel = stroke(seam_distance, 0.075);
	vec2 tile = floor((p + 11.0) * 0.5);
	float tile_tone = fract(sin(dot(tile, vec2(74.57, 21.41))) * 5312.8);
	float grain = sin(p.x * 47.0) * sin(p.y * 53.0);
	float center_light = 1.0 - smoothstep(2.0, 15.0, length(p));
	vec3 panel = panel_color.rgb * (0.74 + 0.26 * center_light + (tile_tone - 0.5) * 0.12 + grain * 0.014);
	ALBEDO = mix(panel * (1.0 + bevel * 0.14), seam_color.rgb, seam * 0.68);

	vec2 edge = abs(p);
	float edge_distance = max(edge.x, edge.y);
	float rail = stroke(abs(edge_distance - 10.12), 0.028);
	float ticks = stroke(abs(fract(min(edge.x, edge.y)) - 0.5), 0.035)
		* (smoothstep(9.74, 9.80, edge_distance) - smoothstep(10.07, 10.12, edge_distance));
	float distance_from_center = length(p);
	float center_ring = stroke(abs(distance_from_center - 2.75), 0.035);
	center_ring *= smoothstep(0.20, 0.27, min(edge.x, edge.y));
	float corner = stroke(abs(edge_distance - 9.37), 0.034) * smoothstep(8.7, 8.8, min(edge.x, edge.y));
	float markings = rail * 0.85 + ticks * 0.35 + center_ring * 0.25 + corner * 0.65;
	ALBEDO = mix(ALBEDO, marking_color.rgb, markings * 0.75);
	EMISSION = marking_color.rgb * markings * 0.18;
	METALLIC = 0.32;
	ROUGHNESS = 0.50 + seam * 0.26 - grain * 0.015;
}
