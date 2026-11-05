// Grip tape: near-black with fine sandpaper grit that catches the light here and there.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 grip_color : source_color = vec3(0.07, 0.07, 0.075);

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	float grit = hash(floor(local_pos.xz * 900.0));
	ALBEDO = grip_color * (0.75 + 0.5 * grit);
	ROUGHNESS = 0.75 + 0.25 * grit;
}
