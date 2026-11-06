// City buildings around the plaza: a facade colour with a grid of windows in world space
// (floors every `floor_height`, bays every `bay_width`). Some windows are lit, chosen per window
// by a hash, so the skyline isn't a perfect pattern. Roofs (faces pointing up) are plain.
shader_type spatial;

uniform vec3 facade : source_color = vec3(0.62, 0.58, 0.52);
uniform vec3 glass : source_color = vec3(0.16, 0.2, 0.26);
uniform vec3 lit : source_color = vec3(0.95, 0.85, 0.6);
uniform float floor_height = 1.2;
uniform float bay_width = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec3 n = abs(world_normal);
	if (n.y > 0.7) {
		ALBEDO = facade * 0.8;
		ROUGHNESS = 0.9;
	} else {
		vec2 p = vec2(n.x > n.z ? world_pos.z : world_pos.x, world_pos.y);
		vec2 cell = vec2(p.x / bay_width, p.y / floor_height);
		vec2 f = fract(cell);
		float window = step(0.2, f.x) * step(f.x, 0.8) * step(0.3, f.y) * step(f.y, 0.85);
		float on = step(0.72, hash(floor(cell)));
		vec3 win = mix(glass, lit, on);
		ALBEDO = mix(facade, win, window);
		ROUGHNESS = mix(0.85, 0.2, window);
		EMISSION = lit * on * window * 0.4;
	}
}
