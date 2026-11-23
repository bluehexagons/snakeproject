shader_type canvas_item;

void fragment() {
	vec2 p = UV - 0.5;
	p.x *= SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float distance_from_center = length(p);
	float pool = exp(-dot(p, p) * 5.0);
	vec2 cell = abs(fract(p * 26.0) - 0.5);
	vec2 edge = smoothstep(vec2(0.468), vec2(0.5), cell);
	float grid = max(edge.x, edge.y);
	float ring = 1.0 - smoothstep(0.0005, 0.003, abs(distance_from_center - 0.48));
	float outer_ring = 1.0 - smoothstep(0.001, 0.003, abs(distance_from_center - 0.57));
	float sweep = 0.55 + 0.45 * sin(atan(p.y, p.x) * 3.0 + TIME * 0.37);
	vec3 ink = vec3(0.025, 0.044, 0.070);
	vec3 teal = vec3(0.075, 0.28, 0.33);
	COLOR = vec4(ink + teal * (pool * 0.36 + grid * pool * 0.13 + ring * sweep * 0.38 + outer_ring * 0.16), 1.0);
}
