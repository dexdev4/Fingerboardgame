// Grip tape: near-black with fine sandpaper grit. UV.y runs across the width (0..1): near the
// edges the tape is filed down and worn, so it turns slightly lighter and smoother — like a real
// fingerboard's grip edge.
shader_type spatial;
render_mode cull_disabled;

uniform vec3 grip_color : source_color = vec3(0.07, 0.07, 0.075);
uniform vec3 worn_color : source_color = vec3(0.2, 0.2, 0.21);
uniform float worn_width = 0.06;   // fraction of the width on each side

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	float grit = hash(floor(local_pos.xz * 900.0));
	float edge = min(UV.y, 1.0 - UV.y);
	float worn = 1.0 - smoothstep(0.0, worn_width, edge);
	// Wear is patchy along the length, not a perfect stripe.
	worn *= 0.6 + 0.4 * hash(floor(vec2(UV.x * 120.0, 0.0)));
	vec3 col = mix(grip_color * (0.75 + 0.5 * grit), worn_color, worn * 0.8);
	ALBEDO = col;
	ROUGHNESS = mix(0.75 + 0.25 * grit, 0.6, worn);
}
