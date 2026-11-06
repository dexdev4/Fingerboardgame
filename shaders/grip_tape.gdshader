// Grip tape: near-black sandpaper. Real grip is bumpy, so besides the colour grit there is a
// procedural normal map (each ~0.1 mm grain tilts the surface a little) — it catches the light
// as the board moves. UV.y runs across the width (0..1): near the edges the tape is filed down
// and worn, so it turns slightly lighter and smoother, like a real fingerboard's grip edge.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 grip_color : source_color = vec3(0.07, 0.07, 0.075);
uniform vec3 worn_color : source_color = vec3(0.2, 0.2, 0.21);
uniform float worn_width = 0.06;    // fraction of the width on each side
uniform float grain_scale = 900.0;  // grains per world unit
uniform float bump = 0.55;          // how strongly grains tilt the surface

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 cell = floor(local_pos.xz * grain_scale);
	float grit = hash(cell);
	float edge = min(UV.y, 1.0 - UV.y);
	float worn = 1.0 - smoothstep(0.0, worn_width, edge);
	worn *= 0.6 + 0.4 * hash(floor(vec2(UV.x * 120.0, 0.0)));   // patchy, not a perfect stripe
	ALBEDO = mix(grip_color * (0.75 + 0.5 * grit), worn_color, worn * 0.8);
	ROUGHNESS = mix(0.75 + 0.25 * grit, 0.6, worn);
	// Each grain gets a random tilt (normal-map space: 0.5 = flat). Worn edges are smoother.
	vec2 tilt = vec2(hash(cell + 17.0), hash(cell + 41.0)) - 0.5;
	NORMAL_MAP = vec3(0.5 + tilt * bump * (1.0 - worn), 1.0);
}
