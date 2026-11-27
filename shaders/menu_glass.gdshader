shader_type canvas_item;

void fragment() {
	float top = exp(-UV.y * 13.0) * 0.16;
	float sweep = UV.y + UV.x * 0.46;
	float ribbon = exp(-abs(sweep - 0.50) * 15.0) * 0.056;
	float edge_fade = smoothstep(0.0, 0.045, min(UV.x, 1.0 - UV.x));
	vec3 cool = mix(vec3(0.43, 0.79, 0.96), vec3(0.72, 0.60, 0.96), UV.x);
	COLOR = vec4(cool, (top + ribbon) * edge_fade);
}
