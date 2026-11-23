shader_type spatial;

uniform vec4 rail_color : source_color = vec4(0.31, 0.095, 0.103, 1.0);
uniform vec4 lamp_color : source_color = vec4(1.0, 0.24, 0.14, 1.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 edge = abs(world_position.xz);
	float along = edge.x > edge.y ? world_position.z : world_position.x;
	float panel = fract(along * 0.72 + 0.5);
	float lamp = smoothstep(0.08, 0.13, panel) * (1.0 - smoothstep(0.83, 0.89, panel));
	float cross_rail = max(edge.x, edge.y);
	float strip = 1.0 - smoothstep(0.052, 0.091, abs(cross_rail - 10.80));
	float upper_face = smoothstep(0.33, 0.46, world_position.y);
	float vents = smoothstep(0.14, 0.48, fract(along * 1.45 + world_position.y * 2.4));
	float signal = lamp * strip * upper_face;
	ALBEDO = rail_color.rgb * (0.64 + upper_face * (0.24 + vents * 0.25));
	EMISSION = lamp_color.rgb * (signal * 1.6 + lamp * 0.06);
	METALLIC = 0.56;
	ROUGHNESS = 0.32;
}
