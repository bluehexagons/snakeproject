shader_type spatial;
render_mode unshaded, shadows_disabled;

uniform vec4 deep_color : source_color = vec4(0.025, 0.044, 0.075, 1.0);
uniform vec4 current_color : source_color = vec4(0.08, 0.25, 0.31, 1.0);

varying vec2 surface_position;

void vertex() {
	surface_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 p = surface_position;
	vec2 flow = p * 0.23;
	flow.x += sin(flow.y * 0.72 + TIME * 0.18) * 0.9;
	flow.y += cos(flow.x * 0.89 - TIME * 0.14) * 0.7;
	float ripples = sin(flow.x + flow.y * 0.7 + TIME * 0.23)
		* sin(flow.y * 1.23 - flow.x * 0.38 - TIME * 0.17);
	float shimmer = smoothstep(0.65, 1.0, ripples);
	float falloff = 1.0 - smoothstep(10.0, 44.0, length(p));
	float edge_distance = max(abs(p.x), abs(p.y));
	float reflection = exp(-abs(edge_distance - 12.2) * 0.67);
	ALBEDO = deep_color.rgb + current_color.rgb * (reflection * 0.27 + (0.075 + shimmer * 0.26) * falloff);
}
