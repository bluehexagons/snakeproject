shader_type canvas_item;

vec3 glass_pane(vec3 backdrop, vec2 p, vec2 half_size, vec3 tint) {
	vec2 corner = abs(p) - half_size + 0.035;
	float distance_to_edge = length(max(corner, vec2(0.0)))
		+ min(max(corner.x, corner.y), 0.0) - 0.035;
	float inside = 1.0 - smoothstep(-0.001, 0.001, distance_to_edge);
	float rim = exp(-abs(distance_to_edge) * 440.0);
	float bevel = exp(-abs(distance_to_edge + 0.006) * 130.0) * inside;
	float softbox = exp(-abs(p.x + p.y * 0.66 - 0.035) * 23.0) * inside;
	float face = clamp(0.24 - p.y * 0.55, 0.08, 0.45);
	return mix(backdrop, tint * 0.45, inside * face)
		+ tint * (rim * 0.36 + bevel * 0.075 + softbox * 0.105);
}

void fragment() {
	vec2 p = UV - 0.5;
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 cyan_center = p + vec2(0.46, 0.21);
	vec2 lilac_center = p - vec2(0.49, 0.23);
	vec3 color = vec3(0.019, 0.032, 0.071);
	color += vec3(0.044, 0.28, 0.34) * exp(-dot(cyan_center, cyan_center) * 7.0);
	color += vec3(0.20, 0.10, 0.35) * exp(-dot(lilac_center, lilac_center) * 7.0);
	vec2 cell = abs(fract(p * 24.0) - 0.5);
	float grid = smoothstep(0.470, 0.498, max(cell.x, cell.y));
	color += vec3(0.11, 0.23, 0.34) * grid * 0.10 * exp(-dot(p, p) * 2.0);

	mat2 rotation = mat2(vec2(0.86, 0.51), vec2(-0.51, 0.86));
	vec2 drift = vec2(0.019, 0.012) * sin(TIME * 0.33);
	color = glass_pane(color, rotation * (p + vec2(0.30, 0.15) + drift),
		vec2(0.47, 0.16), vec3(0.29, 0.82, 0.95));
	color = glass_pane(color, rotation * (p - vec2(0.35, 0.17) - drift),
		vec2(0.48, 0.175), vec3(0.65, 0.54, 0.94));
	color = glass_pane(color, rotation * (p - vec2(0.63, -0.08) + drift),
		vec2(0.25, 0.079), vec3(0.41, 0.76, 0.93));
	COLOR = vec4(color, 1.0);
}
