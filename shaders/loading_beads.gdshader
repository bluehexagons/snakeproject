shader_type canvas_item;

void fragment() {
	vec2 point = UV * vec2(132.0, 32.0);
	vec2 bead = vec2(mod(point.x - 6.0, 24.0) - 12.0, point.y - 16.0);
	float index = floor((point.x - 6.0) / 24.0);
	float wave = pow(0.5 + 0.5 * cos(TIME * 8.0 - index * 1.15), 2.0);
	float distance_to_center = length(bead);
	float glass = 1.0 - smoothstep(7.5, 8.5, distance_to_center);
	float rim = smoothstep(5.6, 8.0, distance_to_center) * glass;
	float glint = exp(-length(bead - vec2(-2.5, -3.0)) * 0.62) * glass;
	vec3 tint = mix(vec3(0.31, 0.65, 0.84), vec3(0.69, 0.85, 1.0), wave);
	vec3 color = tint * (0.42 + wave * 0.43 + rim * 0.24) + glint * 0.47;
	float halo = exp(-distance_to_center * 0.31) * wave * 0.78;
	float bounded = step(0.0, index) * step(index, 4.0);
	COLOR = vec4(color, (glass * (0.45 + wave * 0.45) + halo) * bounded);
}
