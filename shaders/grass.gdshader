// Lawn around the park: two shades of green mixed by world-space noise.
shader_type spatial;

uniform vec3 light_green : source_color = vec3(0.36, 0.52, 0.22);
uniform vec3 dark_green : source_color = vec3(0.22, 0.36, 0.14);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	float g = noise(world_pos.xz * 0.6) * 0.6 + noise(world_pos.xz * 5.0) * 0.4;
	ALBEDO = mix(dark_green, light_green, g) * (0.9 + 0.1 * hash(floor(world_pos.xz * 60.0)));
	ROUGHNESS = 0.95;
}
